//
//  VolumeRenderer.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import RealityKit
import SwiftUI

/// Renders 3D medical imaging volumes using RealityKit
@MainActor
class VolumeRenderer: ObservableObject {

    @Published var entity: ModelEntity?
    @Published var volumeScale: Float = 1.0
    @Published var opacity: Float = 1.0

    private var volumeData: VolumeData?
    private var currentWindowLevel: WindowLevel?

    // MARK: - Initialization

    init() {}

    // MARK: - Volume Loading

    /// Load and render a 3D volume
    /// - Parameters:
    ///   - volume: VolumeData to render
    ///   - windowLevel: Initial window/level settings
    func loadVolume(_ volume: VolumeData, windowLevel: WindowLevel? = nil) async {
        self.volumeData = volume
        self.currentWindowLevel = windowLevel

        print("🎨 Rendering volume: \(volume.dimensions)")

        // Create volume entity
        let volumeEntity = await createVolumeEntity(from: volume, windowLevel: windowLevel)
        self.entity = volumeEntity

        print("✅ Volume rendered successfully")
    }

    // MARK: - Entity Creation

    /// Create a RealityKit ModelEntity from volume data
    private func createVolumeEntity(
        from volume: VolumeData,
        windowLevel: WindowLevel?
    ) async -> ModelEntity {
        // Create mesh for the volume (simple box for now)
        let bounds = volume.physicalDimensions
        let mesh = MeshResource.generateBox(
            width: bounds.x / 1000.0,   // Convert mm to meters
            height: bounds.y / 1000.0,
            depth: bounds.z / 1000.0
        )

        // Create material with volume data
        var material = SimpleMaterial()
        material.color = .init(tint: .white.withAlphaComponent(0.8))
        material.roughness = .float(0.5)
        material.metallic = .float(0.0)

        // Create entity
        let entity = ModelEntity(mesh: mesh, materials: [material])

        // Add volume metadata as component for future ray marching
        entity.components.set(VolumeComponent(
            dimensions: volume.dimensions,
            spacing: volume.spacing,
            dataType: volume.dataType,
            windowCenter: volume.windowCenter,
            windowWidth: volume.windowWidth
        ))

        return entity
    }

    // MARK: - Window/Level Adjustment

    /// Update window/level settings
    /// - Parameter windowLevel: New window/level preset
    func updateWindowLevel(_ windowLevel: WindowLevel) async {
        guard let volume = volumeData else { return }

        self.currentWindowLevel = windowLevel

        // Recreate entity with new windowing
        let newEntity = await createVolumeEntity(from: volume, windowLevel: windowLevel)
        self.entity = newEntity

        print("🎨 Updated window/level: \(windowLevel.name)")
    }

    /// Apply custom window center and width
    /// - Parameters:
    ///   - center: Window center value
    ///   - width: Window width value
    func applyWindowing(center: Float, width: Float) async {
        let customLevel = WindowLevel(center: center, width: width, name: "Custom")
        await updateWindowLevel(customLevel)
    }

    // MARK: - Transform Controls

    /// Update volume scale
    /// - Parameter scale: Scale factor (1.0 = original size)
    func setScale(_ scale: Float) {
        self.volumeScale = scale
        entity?.scale = SIMD3<Float>(repeating: scale)
    }

    /// Update volume opacity
    /// - Parameter opacity: Opacity value (0.0 - 1.0)
    func setOpacity(_ opacity: Float) {
        self.opacity = opacity

        // Update material opacity
        if var material = entity?.model?.materials.first as? SimpleMaterial {
            material.color = .init(tint: .white.withAlphaComponent(CGFloat(opacity)))
            entity?.model?.materials = [material]
        }
    }

    /// Reset view to default
    func resetView() {
        setScale(1.0)
        setOpacity(1.0)
    }

    // MARK: - Volume Information

    /// Get current volume information for display
    var volumeInfo: String? {
        guard let volume = volumeData else { return nil }

        return """
        Dimensions: \(volume.dimensions.x)×\(volume.dimensions.y)×\(volume.dimensions.z)
        Spacing: \(String(format: "%.2f", volume.spacing.x))×\(String(format: "%.2f", volume.spacing.y))×\(String(format: "%.2f", volume.spacing.z)) mm
        Physical size: \(String(format: "%.1f", volume.physicalDimensions.x))×\(String(format: "%.1f", volume.physicalDimensions.y))×\(String(format: "%.1f", volume.physicalDimensions.z)) mm
        Data type: \(volume.dataType.rawValue)
        Memory: \(String(format: "%.1f", Double(volume.memorySize) / 1_048_576)) MB
        Window: \(volume.windowCenter) / \(volume.windowWidth)
        """
    }
}

// MARK: - Volume Component

/// RealityKit component storing volume metadata
struct VolumeComponent: Component {
    let dimensions: SIMD3<Int>
    let spacing: SIMD3<Float>
    let dataType: VoxelDataType
    let windowCenter: Float
    let windowWidth: Float

    /// Volume size in voxels
    var voxelCount: Int {
        dimensions.x * dimensions.y * dimensions.z
    }

    /// Physical dimensions in mm
    var physicalSize: SIMD3<Float> {
        SIMD3<Float>(
            Float(dimensions.x) * spacing.x,
            Float(dimensions.y) * spacing.y,
            Float(dimensions.z) * spacing.z
        )
    }
}

// MARK: - Volume View

/// SwiftUI view for displaying 3D volumes
struct VolumeView: View {
    @StateObject private var renderer = VolumeRenderer()
    let volume: VolumeData
    let windowLevel: WindowLevel?

    @State private var selectedPreset: WindowLevel?

    init(volume: VolumeData, windowLevel: WindowLevel? = nil) {
        self.volume = volume
        self.windowLevel = windowLevel
    }

    var body: some View {
        ZStack {
            // RealityKit view
            if let entity = renderer.entity {
                RealityView { content in
                    content.add(entity)
                } update: { content in
                    // Update content if needed
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                ProgressView("Loading volume...")
            }

            // Controls overlay
            VStack {
                Spacer()

                // Window/Level presets
                HStack {
                    ForEach(WindowLevel.allPresets, id: \.name) { preset in
                        Button(preset.name) {
                            selectedPreset = preset
                            Task {
                                await renderer.updateWindowLevel(preset)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()

                // Volume info
                if let info = renderer.volumeInfo {
                    Text(info)
                        .font(.caption)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
        .task {
            await renderer.loadVolume(volume, windowLevel: windowLevel)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VolumeView_Previews: PreviewProvider {
    static var previews: some View {
        VolumeView(
            volume: VolumeData.sample,
            windowLevel: .softTissue
        )
    }
}
#endif
