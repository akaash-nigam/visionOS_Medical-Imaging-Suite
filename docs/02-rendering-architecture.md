# 3D Rendering Architecture Document
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Executive Summary

This document defines the 3D rendering architecture for Medical Imaging Suite, focusing on high-performance volume rendering of medical scans (CT, MRI, PET) at 60+ fps on Apple Vision Pro. The architecture leverages Metal for GPU-accelerated ray casting, RealityKit for spatial integration, and advanced optimization techniques for handling large datasets (512×512×500+ voxels).

## 2. Rendering Overview

### 2.1 Rendering Modes

The application supports multiple rendering modes optimized for different clinical use cases:

| Mode | Description | Use Case | Performance Target |
|------|-------------|----------|-------------------|
| **Volume Rendering** | Semi-transparent 3D view | General anatomy review | 60 fps |
| **Surface Rendering** | Opaque segmented structures | Bone visualization | 90 fps |
| **MIP (Maximum Intensity Projection)** | Brightest voxels along ray | Angiography | 90 fps |
| **MPR (Multi-Planar Reconstruction)** | Orthogonal 2D slices | Slice-by-slice review | 90 fps |
| **Hybrid Rendering** | Surfaces + transparency | Surgical planning | 60 fps |

### 2.2 High-Level Rendering Pipeline

```
DICOM Volume Data (CPU)
        ↓
Volume Texture Upload (CPU → GPU)
        ↓
┌─────────────────────────────────┐
│   Metal Compute Shader Pipeline │
├─────────────────────────────────┤
│ 1. Ray Generation               │
│ 2. Volume Sampling (3D Texture) │
│ 3. Transfer Function Lookup     │
│ 4. Gradient Calculation         │
│ 5. Lighting (Phong/Blinn)       │
│ 6. Compositing (Front-to-Back)  │
└─────────────────────────────────┘
        ↓
RealityKit Entity (Spatial Display)
        ↓
Vision Pro Display (90Hz)
```

## 3. Volume Representation

### 3.1 Voxel Data Structure

```swift
struct VolumeData {
    let dimensions: SIMD3<Int>        // e.g., (512, 512, 400)
    let spacing: SIMD3<Float>         // Physical spacing in mm
    let voxels: UnsafeMutableRawPointer  // Raw voxel data
    let bytesPerVoxel: Int            // 1, 2, or 4 bytes
    let dataType: VoxelDataType       // UInt8, Int16, Float32

    // Metadata
    let windowCenter: Float           // Hounsfield units (CT)
    let windowWidth: Float
    let rescaleSlope: Float           // DICOM (0028,1053)
    let rescaleIntercept: Float       // DICOM (0028,1052)
}

enum VoxelDataType {
    case uint8        // 8-bit grayscale
    case int16        // 16-bit CT (Hounsfield units)
    case float32      // Normalized float
}
```

### 3.2 Memory Layout

**Optimal Layout**: Z-Y-X (slice-major) for slice-by-slice access
- Memory address: `voxel[z][y][x] = base + (z * height * width + y * width + x) * bytesPerVoxel`
- Cache-friendly for axial slice iteration
- Matches DICOM file order

**GPU Texture Format**:
- **MTLPixelFormat.r16Sint**: 16-bit signed integer for CT
- **MTLPixelFormat.r8Unorm**: 8-bit normalized for MRI
- **MTLPixelFormat.r32Float**: 32-bit float for processing

### 3.3 Texture Compression

For memory optimization:
- **BC4**: Single-channel compression (5:1 ratio)
- **Lossless**: For diagnostic accuracy regions
- **Lossy**: For peripheral/non-diagnostic areas

```swift
func compressVolume(_ volume: VolumeData) -> MTLTexture {
    let descriptor = MTLTextureDescriptor()
    descriptor.pixelFormat = .bc4_unorm  // Block compression
    descriptor.width = volume.dimensions.x
    descriptor.height = volume.dimensions.y
    descriptor.depth = volume.dimensions.z
    descriptor.textureType = .type3D
    descriptor.usage = [.shaderRead]

    return device.makeTexture(descriptor: descriptor)!
}
```

## 4. Ray Casting Algorithm

### 4.1 Ray Casting Overview

**Core Algorithm**: Front-to-back compositing along rays cast from eye through each pixel into volume.

```metal
kernel void rayCastVolume(
    texture3d<float, access::sample> volumeTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant RenderUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // 1. Calculate ray direction
    float2 uv = (float2(gid) + 0.5) / float2(outputTexture.get_width(), outputTexture.get_height());
    float3 rayOrigin = uniforms.cameraPosition;
    float3 rayDir = normalize(calculateRayDirection(uv, uniforms));

    // 2. Compute volume entry/exit points
    float2 tNearFar = intersectAABB(rayOrigin, rayDir, uniforms.volumeBounds);
    if (tNearFar.x > tNearFar.y) {
        outputTexture.write(float4(0.0), gid);
        return;
    }

    // 3. Ray marching
    float t = tNearFar.x;
    float tMax = tNearFar.y;
    float stepSize = uniforms.stepSize;  // ~0.5-1.0 voxel

    float4 accumulatedColor = float4(0.0);

    constexpr sampler volumeSampler(coord::normalized, filter::linear, address::clamp_to_edge);

    while (t < tMax && accumulatedColor.a < 0.95) {  // Early ray termination
        float3 samplePos = rayOrigin + t * rayDir;
        float3 uvw = worldToTexCoord(samplePos, uniforms);

        // 4. Sample volume
        float density = volumeTexture.sample(volumeSampler, uvw).r;

        // 5. Apply transfer function
        float4 color = transferFunction(density, uniforms);

        // 6. Calculate gradient for lighting
        float3 gradient = computeGradient(volumeTexture, volumeSampler, uvw);
        float3 normal = normalize(gradient);

        // 7. Lighting
        float diffuse = max(dot(normal, uniforms.lightDir), 0.0);
        color.rgb *= (uniforms.ambientLight + diffuse * uniforms.diffuseLight);

        // 8. Front-to-back compositing
        color.a *= stepSize;  // Opacity correction
        accumulatedColor.rgb += (1.0 - accumulatedColor.a) * color.a * color.rgb;
        accumulatedColor.a += (1.0 - accumulatedColor.a) * color.a;

        t += stepSize;
    }

    outputTexture.write(accumulatedColor, gid);
}
```

### 4.2 Transfer Function

Maps voxel intensity to color and opacity.

```metal
float4 transferFunction(float intensity, constant RenderUniforms& uniforms) {
    // Windowing (CT)
    float windowMin = uniforms.windowCenter - uniforms.windowWidth / 2.0;
    float windowMax = uniforms.windowCenter + uniforms.windowWidth / 2.0;
    float normalized = (intensity - windowMin) / (windowMax - windowMin);
    normalized = clamp(normalized, 0.0, 1.0);

    // Presets
    if (uniforms.preset == PRESET_BONE) {
        // Bone: High intensity → opaque white
        if (intensity > 300.0) {  // 300+ HU = bone
            return float4(1.0, 1.0, 1.0, 0.8 * normalized);
        } else {
            return float4(0.0, 0.0, 0.0, 0.0);  // Transparent
        }
    } else if (uniforms.preset == PRESET_SOFT_TISSUE) {
        // Soft tissue: Mid intensity → semi-transparent
        float4 color = float4(0.9, 0.6, 0.4, 0.3 * normalized);  // Amber
        return color;
    } else {
        // Custom ramp
        return uniforms.transferFunctionTexture.sample(uniforms.sampler, normalized);
    }
}
```

### 4.3 Gradient Calculation

For lighting and edge detection.

```metal
float3 computeGradient(
    texture3d<float, access::sample> volume,
    sampler volumeSampler,
    float3 uvw
) {
    float delta = 0.001;  // Sampling offset

    float dx = volume.sample(volumeSampler, uvw + float3(delta, 0, 0)).r
             - volume.sample(volumeSampler, uvw - float3(delta, 0, 0)).r;

    float dy = volume.sample(volumeSampler, uvw + float3(0, delta, 0)).r
             - volume.sample(volumeSampler, uvw - float3(0, delta, 0)).r;

    float dz = volume.sample(volumeSampler, uvw + float3(0, 0, delta)).r
             - volume.sample(volumeSampler, uvw - float3(0, 0, delta)).r;

    return float3(dx, dy, dz) / (2.0 * delta);
}
```

## 5. Optimization Techniques

### 5.1 Early Ray Termination

Stop ray when accumulated opacity exceeds threshold.

```metal
if (accumulatedColor.a > 0.95) {
    break;  // Fully opaque, no need to continue
}
```

**Performance gain**: 30-50% for opaque structures (bone)

### 5.2 Empty Space Skipping

Precompute min/max volume texture (mipmaps) to skip empty regions.

```swift
func generateMinMaxMipmap(volume: VolumeData) -> MTLTexture {
    // Create mipmap chain where each level stores min/max of child voxels
    // Used to skip empty space during ray marching
    let mipmapLevels = log2(Float(max(volume.dimensions.x, volume.dimensions.y, volume.dimensions.z)))
    // Implementation: downsample volume with min/max filter
}
```

**Performance gain**: 2-3× for volumes with large air regions (chest CT)

### 5.3 Adaptive Step Size

Increase step size in homogeneous regions, decrease near edges.

```metal
float adaptiveStepSize = baseStepSize * (1.0 + 3.0 * smoothstep(0.0, 0.1, length(gradient)));
```

**Performance gain**: 20-30% with minimal visual impact

### 5.4 Octree Acceleration Structure

Spatial subdivision for fast empty space skipping.

```swift
struct VolumeOctree {
    let root: OctreeNode
    let maxDepth: Int

    struct OctreeNode {
        let bounds: AxisAlignedBoundingBox
        let children: [OctreeNode]?  // nil if leaf
        let isEmpty: Bool            // true if no data in this region
        let minValue: Float
        let maxValue: Float
    }

    func intersect(ray: Ray) -> [OctreeNode] {
        // Return only non-empty nodes along ray
    }
}
```

**Performance gain**: 3-5× for sparse volumes

### 5.5 Level of Detail (LOD)

Reduce sampling rate for distant/peripheral volumes.

```swift
enum LODLevel {
    case high      // Full resolution, 0.5 voxel steps
    case medium    // Half resolution, 1.0 voxel steps
    case low       // Quarter resolution, 2.0 voxel steps
}

func computeLOD(distance: Float, screenSize: Float) -> LODLevel {
    if distance < 1.0 && screenSize > 0.3 {
        return .high
    } else if distance < 3.0 && screenSize > 0.1 {
        return .medium
    } else {
        return .low
    }
}
```

### 5.6 Parallel Dispatch

Tile-based rendering for large viewports.

```swift
let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
let threadgroupCount = MTLSize(
    width: (textureWidth + 15) / 16,
    height: (textureHeight + 15) / 16,
    depth: 1
)

computeEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
```

## 6. Surface Rendering

For segmented structures (bones, organs, tumors).

### 6.1 Marching Cubes Algorithm

Extract isosurface mesh from volume.

```swift
protocol SurfaceExtractor {
    func extractSurface(from volume: VolumeData, isoValue: Float) async -> MeshData
}

struct MarchingCubesExtractor: SurfaceExtractor {
    func extractSurface(from volume: VolumeData, isoValue: Float) async -> MeshData {
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        // Iterate through all cubes (8 voxels)
        for z in 0..<volume.dimensions.z-1 {
            for y in 0..<volume.dimensions.y-1 {
                for x in 0..<volume.dimensions.x-1 {
                    let cubeValues = extractCubeValues(volume, x, y, z)
                    let cubeIndex = computeCubeIndex(cubeValues, isoValue)

                    if cubeIndex == 0 || cubeIndex == 255 {
                        continue  // No intersection
                    }

                    let edges = marchingCubesEdgeTable[cubeIndex]
                    let triangles = marchingCubesTriangleTable[cubeIndex]

                    // Generate vertices via linear interpolation
                    for triangle in triangles {
                        // Add vertices, normals, indices
                    }
                }
            }
        }

        return MeshData(vertices: vertices, normals: normals, indices: indices)
    }
}
```

### 6.2 Mesh Optimization

Reduce polygon count for real-time rendering.

```swift
func decimateMesh(_ mesh: MeshData, targetReduction: Float) -> MeshData {
    // Quadric error decimation
    // Preserve sharp features (high curvature)
    // Target: 50K-200K triangles for smooth 60fps
}
```

### 6.3 RealityKit Integration

Convert mesh to ModelEntity.

```swift
func createSurfaceEntity(from mesh: MeshData) -> ModelEntity {
    var meshDescriptor = MeshDescriptor()
    meshDescriptor.positions = MeshBuffer(mesh.vertices)
    meshDescriptor.normals = MeshBuffer(mesh.normals)
    meshDescriptor.primitives = .triangles(mesh.indices)

    let meshResource = try! MeshResource.generate(from: [meshDescriptor])

    var material = PhysicallyBasedMaterial()
    material.baseColor = .init(tint: .white)
    material.roughness = 0.3
    material.metallic = 0.0

    return ModelEntity(mesh: meshResource, materials: [material])
}
```

## 7. Multi-Planar Reconstruction (MPR)

Display orthogonal slices (axial, sagittal, coronal).

### 7.1 Slice Extraction

```swift
struct SliceExtractor {
    func extractSlice(
        from volume: VolumeData,
        plane: SlicePlane,
        index: Int
    ) -> MTLTexture {
        // Extract 2D slice from 3D volume
        switch plane {
        case .axial:
            // Z-slice at index
            return extractAxialSlice(volume, z: index)
        case .sagittal:
            // X-slice at index
            return extractSagittalSlice(volume, x: index)
        case .coronal:
            // Y-slice at index
            return extractCoronalSlice(volume, y: index)
        }
    }
}

enum SlicePlane {
    case axial      // XY plane (top-down)
    case sagittal   // YZ plane (side)
    case coronal    // XZ plane (front)
}
```

### 7.2 Oblique Slicing

Arbitrary slice planes for surgical planning.

```swift
func extractObliqueSlice(
    from volume: VolumeData,
    planeOrigin: SIMD3<Float>,
    planeNormal: SIMD3<Float>,
    sliceSize: SIMD2<Int>
) -> MTLTexture {
    // Construct tangent and bitangent vectors
    let tangent = normalize(cross(planeNormal, SIMD3<Float>(0, 1, 0)))
    let bitangent = normalize(cross(planeNormal, tangent))

    // Sample volume along slice grid
    let texture = device.makeTexture(descriptor: sliceDescriptor)!

    for y in 0..<sliceSize.y {
        for x in 0..<sliceSize.x {
            let u = Float(x) / Float(sliceSize.x) - 0.5
            let v = Float(y) / Float(sliceSize.y) - 0.5
            let worldPos = planeOrigin + u * tangent + v * bitangent

            let value = sampleVolume(volume, at: worldPos)
            texture.setPixel(x, y, value: value)
        }
    }

    return texture
}
```

## 8. RealityKit Integration

### 8.1 Volume Entity Structure

```swift
class VolumeEntity: Entity {
    let volumeTexture: MTLTexture
    let renderPipeline: MTLComputePipelineState
    let uniformsBuffer: MTLBuffer

    private var outputTexture: MTLTexture
    private var materialResource: MaterialResource

    init(volume: VolumeData, device: MTLDevice) {
        self.volumeTexture = uploadVolumeToGPU(volume, device: device)
        self.renderPipeline = createRayCastPipeline(device: device)
        self.uniformsBuffer = device.makeBuffer(length: MemoryLayout<RenderUniforms>.stride)!

        // Create output texture for ray casting result
        self.outputTexture = createOutputTexture(device: device)

        // Create material that displays the ray-cast result
        self.materialResource = createVolumeMaterial(outputTexture: outputTexture)

        super.init()

        // Add mesh component (billboard quad) with custom material
        self.components[ModelComponent.self] = createBillboardModel(material: materialResource)
    }

    func update(commandBuffer: MTLCommandBuffer) {
        // Dispatch ray casting compute shader
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(renderPipeline)
        encoder.setTexture(volumeTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        encoder.setBuffer(uniformsBuffer, offset: 0, index: 0)
        encoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
    }
}
```

### 8.2 Spatial Layout

```swift
@MainActor
class SpatialVolumeManager {
    func placeVolume(_ volume: VolumeEntity, mode: PlacementMode) {
        switch mode {
        case .lifeSize:
            // Scale to actual anatomical dimensions
            let physicalSize = volume.physicalDimensions  // in meters
            volume.scale = SIMD3<Float>(repeating: 1.0)  // 1:1 scale

        case .tableTOP:
            // Scale to fit on table (0.3m)
            let targetSize: Float = 0.3
            let scale = targetSize / max(volume.physicalDimensions.x, volume.physicalDimensions.y, volume.physicalDimensions.z)
            volume.scale = SIMD3<Float>(repeating: scale)

        case .floating:
            // Float at eye level, 1m away
            volume.position = SIMD3<Float>(0, 1.5, -1.0)
        }
    }
}

enum PlacementMode {
    case lifeSize    // Actual anatomical scale
    case tableTop    // Scaled to fit on table
    case floating    // Floating window in front of user
}
```

## 9. Performance Profiling

### 9.1 Key Metrics

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| **Frame Time** | < 11ms (90fps) | < 16.67ms (60fps) |
| **Ray Casting Time** | < 8ms | < 12ms |
| **Texture Upload** | < 2ms | < 5ms |
| **Memory Usage** | < 1.5GB per volume | < 3GB |
| **GPU Utilization** | 70-80% | < 95% |

### 9.2 Profiling Tools

```swift
import MetalKit

class RenderProfiler {
    private var frameStartTime: CFTimeInterval = 0
    private var frameTimings: [Double] = []

    func beginFrame() {
        frameStartTime = CACurrentMediaTime()
    }

    func endFrame() {
        let frameTime = CACurrentMediaTime() - frameStartTime
        frameTimings.append(frameTime * 1000)  // ms

        if frameTimings.count >= 120 {
            let avgFrameTime = frameTimings.reduce(0, +) / Double(frameTimings.count)
            let maxFrameTime = frameTimings.max() ?? 0
            print("Avg: \(avgFrameTime)ms, Max: \(maxFrameTime)ms, FPS: \(1000/avgFrameTime)")
            frameTimings.removeAll()
        }
    }

    func recordGPUTime(commandBuffer: MTLCommandBuffer) {
        commandBuffer.addCompletedHandler { buffer in
            let gpuTime = (buffer.GPUEndTime - buffer.GPUStartTime) * 1000  // ms
            print("GPU Time: \(gpuTime)ms")
        }
    }
}
```

### 9.3 Xcode Instruments

- **Metal System Trace**: GPU pipeline analysis
- **Time Profiler**: CPU hotspots
- **Allocations**: Memory leak detection
- **GPU Frame Capture**: Shader debugging

## 10. Advanced Rendering Techniques

### 10.1 Ambient Occlusion

Enhance depth perception with screen-space ambient occlusion (SSAO).

```metal
float computeAmbientOcclusion(float3 position, float3 normal, texture3d<float> volume) {
    float occlusion = 0.0;
    int numSamples = 8;

    for (int i = 0; i < numSamples; i++) {
        float3 sampleDir = randomHemisphereDirection(normal, i);
        float3 samplePos = position + sampleDir * 0.01;  // Small radius

        float sampleDensity = volume.sample(sampler, samplePos).r;
        if (sampleDensity > threshold) {
            occlusion += 1.0;
        }
    }

    return 1.0 - (occlusion / float(numSamples));
}
```

### 10.2 Edge Enhancement

Highlight anatomical boundaries.

```metal
float detectEdge(texture3d<float> volume, float3 uvw) {
    float3 gradient = computeGradient(volume, uvw);
    float edgeStrength = length(gradient);
    return smoothstep(0.1, 0.5, edgeStrength);  // Enhance strong gradients
}
```

### 10.3 Depth of Field (Optional)

Focus on region of interest, blur surroundings.

```metal
float computeDepthBlur(float depth, float focalDepth, float focalRange) {
    float distance = abs(depth - focalDepth);
    return smoothstep(0.0, focalRange, distance);
}
```

## 11. Memory Management

### 11.1 Texture Streaming

For volumes larger than GPU memory (> 2GB):

```swift
class VolumeStreamer {
    private let brickSize = 128  // 128³ voxels per brick

    func streamBrick(index: SIMD3<Int>) async -> MTLTexture {
        // Load brick from disk/network on-demand
        // LRU cache for recently accessed bricks
    }

    func visibleBricks(frustum: Frustum, volume: VolumeData) -> [SIMD3<Int>] {
        // Determine which bricks are visible
        // Prefetch adjacent bricks
    }
}
```

### 11.2 GPU Memory Budget

| Component | Memory Budget |
|-----------|---------------|
| **Volume Texture** | 500MB - 1GB |
| **Transfer Function LUT** | 4KB - 1MB |
| **Output Render Target** | 20MB (2K×2K RGBA) |
| **Mesh Geometry** | 50-200MB |
| **Intermediate Buffers** | 100MB |
| **Total** | ~1-1.5GB per volume |

## 12. Quality Settings

### 12.1 Adaptive Quality

Dynamically adjust rendering quality based on performance.

```swift
enum RenderQuality {
    case diagnostic    // Full resolution, high samples
    case interactive   // Reduced samples, adaptive steps
    case preview       // Low resolution, large steps
}

class AdaptiveQualityController {
    private var currentQuality: RenderQuality = .interactive
    private var recentFrameTimes: [Double] = []

    func adjustQuality() {
        let avgFrameTime = recentFrameTimes.average()

        if avgFrameTime > 16.67 {  // Below 60fps
            downgradeQuality()
        } else if avgFrameTime < 11.11 && !isInteracting {  // Above 90fps
            upgradeQuality()
        }
    }

    private func downgradeQuality() {
        switch currentQuality {
        case .diagnostic:
            currentQuality = .interactive
            stepSize *= 1.5
        case .interactive:
            currentQuality = .preview
            stepSize *= 2.0
            resolution *= 0.75
        case .preview:
            // Already at lowest
            break
        }
    }
}
```

## 13. Multi-Volume Rendering

For side-by-side comparison (up to 4 volumes).

### 13.1 Spatial Layout

```swift
func layoutMultipleVolumes(_ volumes: [VolumeEntity], mode: ComparisonMode) {
    switch mode {
    case .sideBySide:
        // Arrange in a row
        for (index, volume) in volumes.enumerated() {
            volume.position.x = Float(index) * 0.8  // 0.8m spacing
        }

    case .grid2x2:
        // Arrange in 2×2 grid
        let positions: [SIMD3<Float>] = [
            SIMD3(-0.4, 0.4, 0),
            SIMD3(0.4, 0.4, 0),
            SIMD3(-0.4, -0.4, 0),
            SIMD3(0.4, -0.4, 0)
        ]
        for (volume, position) in zip(volumes, positions) {
            volume.position = position
        }

    case .overlay:
        // Same position, different colors
        for volume in volumes {
            volume.position = .zero
        }
    }
}
```

### 13.2 Synchronized Interaction

```swift
class SynchronizedViewController {
    var volumes: [VolumeEntity] = []
    var syncRotation = true
    var syncWindowing = true

    func rotateAll(by rotation: simd_quatf) {
        if syncRotation {
            for volume in volumes {
                volume.orientation *= rotation
            }
        }
    }

    func adjustWindowing(center: Float, width: Float) {
        if syncWindowing {
            for volume in volumes {
                volume.updateWindowing(center: center, width: width)
            }
        }
    }
}
```

## 14. Shader Code Organization

### 14.1 File Structure

```
Shaders/
├── Common.metal              // Shared utilities
├── RayCasting.metal          // Volume rendering kernels
├── SurfaceRendering.metal    // Mesh rendering
├── MPR.metal                 // Slice extraction
├── TransferFunctions.metal   // TF lookups
└── PostProcessing.metal      // Edge detection, AO
```

### 14.2 Shader Compilation

```swift
func createRenderPipeline(device: MTLDevice) -> MTLComputePipelineState {
    guard let library = device.makeDefaultLibrary() else {
        fatalError("Failed to load Metal library")
    }

    guard let function = library.makeFunction(name: "rayCastVolume") else {
        fatalError("Failed to load shader function")
    }

    return try! device.makeComputePipelineState(function: function)
}
```

## 15. Testing & Validation

### 15.1 Visual Regression Tests

```swift
func testRenderingConsistency() async throws {
    let volume = TestFixtures.sampleCT512
    let renderer = RenderingEngine(device: MTLCreateSystemDefaultDevice()!)

    let entity = await renderer.createVolume(from: volume)
    let snapshot = await captureSnapshot(entity)

    // Compare with golden reference image
    let similarity = compareImages(snapshot, TestFixtures.goldenCT512Render)
    XCTAssertGreaterThan(similarity, 0.95, "Rendering differs from reference")
}
```

### 15.2 Performance Tests

```swift
func testRenderingPerformance() async throws {
    let volume = TestFixtures.largeCT1024  // 1024³ volume
    let renderer = RenderingEngine(device: MTLCreateSystemDefaultDevice()!)

    measure {
        let _ = await renderer.createVolume(from: volume)
    }

    // Assert frame time < 16.67ms
}
```

## 16. Future Enhancements

### 16.1 Neural Rendering

Use AI to upscale low-resolution volumes in real-time.

```swift
protocol NeuralUpscaler {
    func upscale(lowRes: VolumeData, factor: Int) async -> VolumeData
}
```

### 16.2 Real-Time Denoising

Reduce artifacts in low-dose CT.

```swift
protocol Denoiser {
    func denoise(volume: VolumeData) async -> VolumeData
}
```

### 16.3 4D Rendering

Animate cardiac or respiratory motion.

```swift
struct TemporalVolume {
    let timeFrames: [VolumeData]
    let frameRate: Float  // fps
}
```

---

**Document Control**

- **Author**: Graphics Engineering Team
- **Reviewers**: Senior Graphics Engineer, Clinical Radiologist
- **Approval**: CTO
- **Next Review**: After initial rendering prototype

