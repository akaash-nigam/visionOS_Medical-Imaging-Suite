//
//  VolumeRaycast.metal
//  MedicalImagingSuite
//
//  High-performance volume ray casting shader for medical imaging
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct RaycastUniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 inverseModelViewMatrix;
    float3 volumeDimensions;      // Width, height, depth in voxels
    float3 voxelSpacing;          // Physical spacing in mm
    float2 windowCenterWidth;     // HU window center and width
    float stepSize;               // Ray marching step size
    float densityScale;           // Overall opacity multiplier
    int maxSteps;                 // Maximum ray marching iterations
    int renderMode;               // 0: DVR, 1: MIP, 2: MinIP
};

struct TransferFunctionPoint {
    float intensity;      // Normalized [0, 1]
    float4 color;        // RGBA
};

// MARK: - Ray Generation

struct Ray {
    float3 origin;
    float3 direction;
};

// Generate ray from camera through pixel
Ray generateRay(float2 uv, constant RaycastUniforms& uniforms) {
    // Convert UV to normalized device coordinates [-1, 1]
    float2 ndc = uv * 2.0 - 1.0;

    // Ray in view space
    float4 nearPoint = float4(ndc.x, ndc.y, -1.0, 1.0);
    float4 farPoint = float4(ndc.x, ndc.y, 1.0, 1.0);

    // Transform to world space
    float4 nearWorld = uniforms.inverseModelViewMatrix * nearPoint;
    float4 farWorld = uniforms.inverseModelViewMatrix * farPoint;

    nearWorld /= nearWorld.w;
    farWorld /= farWorld.w;

    Ray ray;
    ray.origin = nearWorld.xyz;
    ray.direction = normalize(farWorld.xyz - nearWorld.xyz);

    return ray;
}

// MARK: - Volume Sampling

// Trilinear interpolation for smooth volume sampling
float sampleVolume(float3 position,
                   texture3d<float, access::sample> volumeTexture,
                   sampler volumeSampler) {
    // Position is in normalized texture coordinates [0, 1]
    return volumeTexture.sample(volumeSampler, position).r;
}

// Sample with gradient calculation for lighting
struct VolumeGradient {
    float value;
    float3 gradient;
};

VolumeGradient sampleVolumeWithGradient(float3 position,
                                        texture3d<float, access::sample> volumeTexture,
                                        sampler volumeSampler,
                                        constant RaycastUniforms& uniforms) {
    VolumeGradient result;
    result.value = sampleVolume(position, volumeTexture, volumeSampler);

    // Central difference gradient calculation
    float delta = 1.0 / max(max(uniforms.volumeDimensions.x,
                                uniforms.volumeDimensions.y),
                            uniforms.volumeDimensions.z);

    float3 dx = float3(delta, 0.0, 0.0);
    float3 dy = float3(0.0, delta, 0.0);
    float3 dz = float3(0.0, 0.0, delta);

    result.gradient.x = sampleVolume(position + dx, volumeTexture, volumeSampler) -
                       sampleVolume(position - dx, volumeTexture, volumeSampler);
    result.gradient.y = sampleVolume(position + dy, volumeTexture, volumeSampler) -
                       sampleVolume(position - dy, volumeTexture, volumeSampler);
    result.gradient.z = sampleVolume(position + dz, volumeTexture, volumeSampler) -
                       sampleVolume(position - dz, volumeTexture, volumeSampler);

    result.gradient = normalize(result.gradient);

    return result;
}

// MARK: - Transfer Function

// Apply transfer function to convert intensity to color and opacity
float4 applyTransferFunction(float intensity,
                            constant TransferFunctionPoint* transferFunction,
                            int numPoints) {
    // Clamp intensity to [0, 1]
    intensity = clamp(intensity, 0.0, 1.0);

    // Find the two transfer function points to interpolate between
    if (numPoints == 0) {
        // Default grayscale
        return float4(intensity, intensity, intensity, intensity);
    }

    // Linear search for surrounding points
    for (int i = 0; i < numPoints - 1; i++) {
        if (intensity >= transferFunction[i].intensity &&
            intensity <= transferFunction[i + 1].intensity) {

            // Linear interpolation
            float t = (intensity - transferFunction[i].intensity) /
                     (transferFunction[i + 1].intensity - transferFunction[i].intensity);

            return mix(transferFunction[i].color,
                      transferFunction[i + 1].color,
                      t);
        }
    }

    // Outside range - use first or last
    if (intensity < transferFunction[0].intensity) {
        return transferFunction[0].color;
    }
    return transferFunction[numPoints - 1].color;
}

// MARK: - Windowing

// Apply CT windowing (level/width) to normalize Hounsfield units
float applyWindowing(float huValue, float2 windowCenterWidth) {
    float center = windowCenterWidth.x;
    float width = windowCenterWidth.y;

    float minHU = center - width / 2.0;
    float maxHU = center + width / 2.0;

    // Clamp and normalize to [0, 1]
    return clamp((huValue - minHU) / (maxHU - minHU), 0.0, 1.0);
}

// MARK: - Lighting

// Blinn-Phong shading for volume rendering
float3 computeLighting(float3 normal, float3 viewDir, float3 lightDir) {
    // Ambient
    float3 ambient = float3(0.3);

    // Diffuse
    float diff = max(dot(normal, lightDir), 0.0);
    float3 diffuse = float3(0.6) * diff;

    // Specular (Blinn-Phong)
    float3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(normal, halfDir), 0.0), 32.0);
    float3 specular = float3(0.4) * spec;

    return ambient + diffuse + specular;
}

// MARK: - Ray-Box Intersection

// Calculate ray intersection with unit cube [0, 1]^3
bool intersectBox(Ray ray, thread float& tNear, thread float& tFar) {
    float3 invDir = 1.0 / ray.direction;
    float3 tMin = (float3(0.0) - ray.origin) * invDir;
    float3 tMax = (float3(1.0) - ray.origin) * invDir;

    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);

    tNear = max(max(t1.x, t1.y), t1.z);
    tFar = min(min(t2.x, t2.y), t2.z);

    return tNear <= tFar && tFar > 0.0;
}

// MARK: - Ray Marching

// Direct Volume Rendering (DVR) with compositing
float4 rayMarchDVR(Ray ray,
                   texture3d<float, access::sample> volumeTexture,
                   sampler volumeSampler,
                   constant RaycastUniforms& uniforms,
                   constant TransferFunctionPoint* transferFunction,
                   int numTFPoints) {
    float tNear, tFar;
    if (!intersectBox(ray, tNear, tFar)) {
        return float4(0.0); // Transparent
    }

    // Start position
    tNear = max(tNear, 0.0);
    float3 position = ray.origin + ray.direction * tNear;

    // Accumulation
    float4 accumulatedColor = float4(0.0);
    float3 lightDir = normalize(float3(1.0, 1.0, 1.0));

    // Ray marching
    int steps = min(int((tFar - tNear) / uniforms.stepSize), uniforms.maxSteps);

    for (int i = 0; i < steps; i++) {
        if (accumulatedColor.a >= 0.95) {
            break; // Early ray termination
        }

        // Check bounds
        if (any(position < float3(0.0)) || any(position > float3(1.0))) {
            break;
        }

        // Sample volume with gradient
        VolumeGradient sample = sampleVolumeWithGradient(position, volumeTexture,
                                                         volumeSampler, uniforms);

        // Apply windowing
        float normalizedValue = applyWindowing(sample.value, uniforms.windowCenterWidth);

        // Get color and opacity from transfer function
        float4 sampleColor = applyTransferFunction(normalizedValue,
                                                   transferFunction, numTFPoints);

        // Apply lighting if gradient is significant
        if (length(sample.gradient) > 0.1 && sampleColor.a > 0.01) {
            float3 lighting = computeLighting(sample.gradient,
                                            -ray.direction,
                                            lightDir);
            sampleColor.rgb *= lighting;
        }

        // Apply density scale
        sampleColor.a *= uniforms.densityScale;

        // Front-to-back compositing
        float weight = sampleColor.a * (1.0 - accumulatedColor.a);
        accumulatedColor.rgb += sampleColor.rgb * weight;
        accumulatedColor.a += weight;

        // March forward
        position += ray.direction * uniforms.stepSize;
    }

    return accumulatedColor;
}

// Maximum Intensity Projection (MIP)
float4 rayMarchMIP(Ray ray,
                   texture3d<float, access::sample> volumeTexture,
                   sampler volumeSampler,
                   constant RaycastUniforms& uniforms) {
    float tNear, tFar;
    if (!intersectBox(ray, tNear, tFar)) {
        return float4(0.0);
    }

    tNear = max(tNear, 0.0);
    float3 position = ray.origin + ray.direction * tNear;

    float maxIntensity = 0.0;
    int steps = min(int((tFar - tNear) / uniforms.stepSize), uniforms.maxSteps);

    for (int i = 0; i < steps; i++) {
        if (any(position < float3(0.0)) || any(position > float3(1.0))) {
            break;
        }

        float value = sampleVolume(position, volumeTexture, volumeSampler);
        float normalized = applyWindowing(value, uniforms.windowCenterWidth);
        maxIntensity = max(maxIntensity, normalized);

        position += ray.direction * uniforms.stepSize;
    }

    // Convert to grayscale
    return float4(maxIntensity, maxIntensity, maxIntensity, maxIntensity > 0.0 ? 1.0 : 0.0);
}

// Minimum Intensity Projection (MinIP)
float4 rayMarchMinIP(Ray ray,
                     texture3d<float, access::sample> volumeTexture,
                     sampler volumeSampler,
                     constant RaycastUniforms& uniforms) {
    float tNear, tFar;
    if (!intersectBox(ray, tNear, tFar)) {
        return float4(0.0);
    }

    tNear = max(tNear, 0.0);
    float3 position = ray.origin + ray.direction * tNear;

    float minIntensity = 1.0;
    int steps = min(int((tFar - tNear) / uniforms.stepSize), uniforms.maxSteps);

    for (int i = 0; i < steps; i++) {
        if (any(position < float3(0.0)) || any(position > float3(1.0))) {
            break;
        }

        float value = sampleVolume(position, volumeTexture, volumeSampler);
        float normalized = applyWindowing(value, uniforms.windowCenterWidth);
        minIntensity = min(minIntensity, normalized);

        position += ray.direction * uniforms.stepSize;
    }

    return float4(minIntensity, minIntensity, minIntensity, minIntensity < 1.0 ? 1.0 : 0.0);
}

// MARK: - Kernel Entry Point

kernel void volumeRaycastKernel(texture2d<float, access::write> outputTexture [[texture(0)]],
                                texture3d<float, access::sample> volumeTexture [[texture(1)]],
                                constant RaycastUniforms& uniforms [[buffer(0)]],
                                constant TransferFunctionPoint* transferFunction [[buffer(1)]],
                                constant int& numTFPoints [[buffer(2)]],
                                uint2 gid [[thread_position_in_grid]]) {
    // Get output texture dimensions
    uint width = outputTexture.get_width();
    uint height = outputTexture.get_height();

    // Check bounds
    if (gid.x >= width || gid.y >= height) {
        return;
    }

    // Generate UV coordinates [0, 1]
    float2 uv = float2(gid) / float2(width, height);

    // Generate ray
    Ray ray = generateRay(uv, uniforms);

    // Create sampler for volume texture
    constexpr sampler volumeSampler(coord::normalized,
                                    address::clamp_to_edge,
                                    filter::linear);

    // Ray march based on render mode
    float4 color;
    switch (uniforms.renderMode) {
        case 0: // DVR
            color = rayMarchDVR(ray, volumeTexture, volumeSampler,
                               uniforms, transferFunction, numTFPoints);
            break;
        case 1: // MIP
            color = rayMarchMIP(ray, volumeTexture, volumeSampler, uniforms);
            break;
        case 2: // MinIP
            color = rayMarchMinIP(ray, volumeTexture, volumeSampler, uniforms);
            break;
        default:
            color = float4(1.0, 0.0, 1.0, 1.0); // Magenta error color
    }

    // Write to output
    outputTexture.write(color, gid);
}
