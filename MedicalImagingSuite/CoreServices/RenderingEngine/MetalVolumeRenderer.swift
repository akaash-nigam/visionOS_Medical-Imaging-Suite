//
//  MetalVolumeRenderer.swift
//  MedicalImagingSuite
//
//  High-performance Metal-based volume renderer with GPU ray casting
//

import Foundation
import Metal
import MetalKit
import simd

// MARK: - Render Mode

enum RenderMode: Int {
    case dvr = 0        // Direct Volume Rendering
    case mip = 1        // Maximum Intensity Projection
    case minip = 2      // Minimum Intensity Projection

    var name: String {
        switch self {
        case .dvr: return "DVR"
        case .mip: return "MIP"
        case .minip: return "MinIP"
        }
    }
}

// MARK: - Raycast Uniforms

/// Uniform data passed to Metal shader
struct RaycastUniforms {
    var modelViewProjectionMatrix: simd_float4x4
    var inverseModelViewMatrix: simd_float4x4
    var volumeDimensions: SIMD3<Float>
    var voxelSpacing: SIMD3<Float>
    var windowCenterWidth: SIMD2<Float>
    var stepSize: Float
    var densityScale: Float
    var maxSteps: Int32
    var renderMode: Int32
}

// MARK: - Metal Volume Renderer

/// High-performance GPU-accelerated volume renderer
@MainActor
final class MetalVolumeRenderer {

    // MARK: - Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLComputePipelineState?
    private var volumeTexture: MTLTexture?

    private(set) var renderMode: RenderMode = .dvr
    private(set) var transferFunction: TransferFunction = .grayscale
    private(set) var windowCenterWidth: SIMD2<Float>
    private(set) var stepSize: Float = 0.01
    private(set) var densityScale: Float = 1.0
    private(set) var maxSteps: Int = 1000

    // Camera transform
    private var cameraTransform: simd_float4x4 = matrix_identity_float4x4

    // MARK: - Initialization

    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal is not supported on this device")
            return nil
        }

        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ Failed to create Metal command queue")
            return nil
        }

        self.commandQueue = commandQueue
        self.windowCenterWidth = WindowingPreset.softTissue.centerWidth

        setupPipeline()
    }

    // MARK: - Pipeline Setup

    private func setupPipeline() {
        guard let library = try? device.makeDefaultLibrary() else {
            print("❌ Failed to create Metal library")
            return
        }

        guard let kernelFunction = library.makeFunction(name: "volumeRaycastKernel") else {
            print("❌ Failed to find kernel function")
            return
        }

        do {
            pipelineState = try device.makeComputePipelineState(function: kernelFunction)
            print("✅ Metal pipeline created successfully")
        } catch {
            print("❌ Failed to create pipeline state: \(error)")
        }
    }

    // MARK: - Volume Loading

    /// Load volume data into GPU texture
    func loadVolume(_ volumeData: VolumeData) {
        let dimensions = volumeData.dimensions

        // Create 3D texture descriptor
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = .r16Float  // 16-bit float for medical data
        textureDescriptor.width = dimensions.x
        textureDescriptor.height = dimensions.y
        textureDescriptor.depth = dimensions.z
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            print("❌ Failed to create 3D texture")
            return
        }

        // Upload pixel data to texture
        let bytesPerRow = dimensions.x * MemoryLayout<Float16>.stride
        let bytesPerImage = bytesPerRow * dimensions.y

        // Convert pixel data to Float16
        let float16Data = convertToFloat16(volumeData: volumeData)

        float16Data.withUnsafeBytes { bytes in
            let region = MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: dimensions.x, height: dimensions.y, depth: dimensions.z)
            )

            texture.replace(
                region: region,
                mipmapLevel: 0,
                slice: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerImage
            )
        }

        self.volumeTexture = texture

        print("✅ Volume loaded to GPU: \(dimensions.x)×\(dimensions.y)×\(dimensions.z)")
    }

    // MARK: - Data Conversion

    private func convertToFloat16(volumeData: VolumeData) -> Data {
        let voxelCount = volumeData.dimensions.x * volumeData.dimensions.y * volumeData.dimensions.z
        var float16Array = [Float16](repeating: 0, count: voxelCount)

        volumeData.data.withUnsafeBytes { rawBuffer in
            switch volumeData.dataType {
            case .int16:
                let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
                for i in 0..<voxelCount {
                    // Normalize to Float16 with rescaling
                    let value = Float(int16Buffer[i])
                    let rescaled = value * volumeData.rescaleSlope + volumeData.rescaleIntercept
                    float16Array[i] = Float16(rescaled)
                }

            case .uint8:
                let uint8Buffer = rawBuffer.bindMemory(to: UInt8.self)
                for i in 0..<voxelCount {
                    let value = Float(uint8Buffer[i])
                    let rescaled = value * volumeData.rescaleSlope + volumeData.rescaleIntercept
                    float16Array[i] = Float16(rescaled)
                }

            case .uint16:
                let uint16Buffer = rawBuffer.bindMemory(to: UInt16.self)
                for i in 0..<voxelCount {
                    let value = Float(uint16Buffer[i])
                    let rescaled = value * volumeData.rescaleSlope + volumeData.rescaleIntercept
                    float16Array[i] = Float16(rescaled)
                }
            }
        }

        return Data(bytes: float16Array, count: voxelCount * MemoryLayout<Float16>.stride)
    }

    // MARK: - Rendering

    /// Render the volume to an output texture
    func render(to outputTexture: MTLTexture,
                viewMatrix: simd_float4x4,
                projectionMatrix: simd_float4x4) {
        guard let volumeTexture = volumeTexture,
              let pipelineState = pipelineState else {
            print("⚠️ Renderer not ready")
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("❌ Failed to create command buffer/encoder")
            return
        }

        // Set pipeline
        computeEncoder.setComputePipelineState(pipelineState)

        // Set textures
        computeEncoder.setTexture(outputTexture, index: 0)
        computeEncoder.setTexture(volumeTexture, index: 1)

        // Prepare uniforms
        var uniforms = RaycastUniforms(
            modelViewProjectionMatrix: projectionMatrix * viewMatrix,
            inverseModelViewMatrix: simd_inverse(viewMatrix),
            volumeDimensions: SIMD3<Float>(
                Float(volumeTexture.width),
                Float(volumeTexture.height),
                Float(volumeTexture.depth)
            ),
            voxelSpacing: SIMD3<Float>(1.0, 1.0, 1.0),  // Normalized
            windowCenterWidth: windowCenterWidth,
            stepSize: stepSize,
            densityScale: densityScale,
            maxSteps: Int32(maxSteps),
            renderMode: Int32(renderMode.rawValue)
        )

        // Set uniforms buffer
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<RaycastUniforms>.stride, index: 0)

        // Set transfer function
        var tfPoints = transferFunction.points.map { point in
            return (point.intensity, point.color)
        }
        var numTFPoints = Int32(tfPoints.count)

        if !tfPoints.isEmpty {
            computeEncoder.setBytes(&tfPoints,
                                   length: tfPoints.count * MemoryLayout<(Float, SIMD4<Float>)>.stride,
                                   index: 1)
        }
        computeEncoder.setBytes(&numTFPoints, length: MemoryLayout<Int32>.stride, index: 2)

        // Calculate thread groups
        let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadGroups = MTLSize(
            width: (outputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (outputTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    // MARK: - Configuration

    /// Set render mode (DVR, MIP, MinIP)
    func setRenderMode(_ mode: RenderMode) {
        self.renderMode = mode
    }

    /// Set transfer function
    func setTransferFunction(_ function: TransferFunction) {
        self.transferFunction = function
    }

    /// Set windowing parameters
    func setWindowing(center: Float, width: Float) {
        self.windowCenterWidth = SIMD2<Float>(center, width)
    }

    /// Set windowing preset
    func setWindowingPreset(_ preset: WindowingPreset) {
        self.windowCenterWidth = preset.centerWidth
    }

    /// Set ray marching step size (smaller = higher quality, slower)
    func setStepSize(_ size: Float) {
        self.stepSize = max(0.001, min(size, 0.1))
    }

    /// Set density scale (affects overall opacity)
    func setDensityScale(_ scale: Float) {
        self.densityScale = max(0.0, min(scale, 5.0))
    }

    /// Set maximum ray marching steps
    func setMaxSteps(_ steps: Int) {
        self.maxSteps = max(100, min(steps, 5000))
    }

    // MARK: - Camera Control

    func setCameraTransform(_ transform: simd_float4x4) {
        self.cameraTransform = transform
    }
}

// MARK: - Matrix Helpers

extension simd_float4x4 {
    static var identity: simd_float4x4 {
        return matrix_identity_float4x4
    }

    /// Create perspective projection matrix
    static func perspective(fovyRadians: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let ys = 1 / tanf(fovyRadians * 0.5)
        let xs = ys / aspect
        let zs = far / (near - far)

        return simd_float4x4(
            SIMD4<Float>(xs, 0, 0, 0),
            SIMD4<Float>(0, ys, 0, 0),
            SIMD4<Float>(0, 0, zs, -1),
            SIMD4<Float>(0, 0, near * zs, 0)
        )
    }

    /// Create look-at view matrix
    static func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)

        return simd_float4x4(
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
        )
    }
}
