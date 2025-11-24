//
//  VolumeRealityView.swift
//  MedicalImagingSuite
//
//  RealityKit integration for spatial volume visualization
//

import SwiftUI
import RealityKit
import simd

// MARK: - Volume Reality View

/// SwiftUI view that displays medical volumes in a spatial RealityKit scene
struct VolumeRealityView: View {
    @StateObject private var coordinator = VolumeCoordinator()

    let volume: VolumeData
    let initialWindowLevel: WindowLevel?

    @State private var currentScale: Float = 1.0
    @State private var currentRotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))

    init(volume: VolumeData, windowLevel: WindowLevel? = nil) {
        self.volume = volume
        self.initialWindowLevel = windowLevel
    }

    var body: some View {
        ZStack {
            // Main RealityKit view
            RealityView { content in
                await coordinator.setup(content: content, volume: volume, windowLevel: initialWindowLevel)
            } update: { content in
                coordinator.update(content: content)
            }
            .gesture(rotationGesture)
            .gesture(scaleGesture)
            .gesture(resetGesture)

            // Spatial UI Ornaments
            VStack {
                Spacer()
                controlsOrnament
            }
        }
        .ornament(
            visibility: .visible,
            attachmentAnchor: .scene(.bottom)
        ) {
            windowingControls
        }
    }

    // MARK: - Gestures

    private var rotationGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let sensitivity: Float = 0.01
                let deltaX = Float(value.translation.width) * sensitivity
                let deltaY = Float(value.translation.height) * sensitivity

                // Rotate around Y axis for horizontal drag
                let yRotation = simd_quatf(angle: deltaX, axis: SIMD3<Float>(0, 1, 0))

                // Rotate around X axis for vertical drag
                let xRotation = simd_quatf(angle: -deltaY, axis: SIMD3<Float>(1, 0, 0))

                // Combine rotations
                currentRotation = yRotation * xRotation * currentRotation
                coordinator.setRotation(currentRotation)
            }
    }

    private var scaleGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = currentScale * Float(value)
                coordinator.setScale(newScale)
            }
            .onEnded { value in
                currentScale = currentScale * Float(value)
            }
    }

    private var resetGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                // Reset to default view
                currentScale = 1.0
                currentRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
                coordinator.resetView()
            }
    }

    // MARK: - UI Components

    private var controlsOrnament: some View {
        HStack(spacing: 20) {
            // Scale controls
            VStack {
                Text("Scale")
                    .font(.caption)
                Slider(value: $currentScale, in: 0.5...3.0) { _ in
                    coordinator.setScale(currentScale)
                }
                .frame(width: 150)
                Text(String(format: "%.1f×", currentScale))
                    .font(.caption2)
                    .monospacedDigit()
            }

            Divider()

            // Opacity controls
            VStack {
                Text("Opacity")
                    .font(.caption)
                Slider(value: $coordinator.opacity, in: 0.0...1.0)
                    .frame(width: 150)
                Text(String(format: "%.0f%%", coordinator.opacity * 100))
                    .font(.caption2)
                    .monospacedDigit()
            }

            Divider()

            // Reset button
            Button(action: {
                currentScale = 1.0
                currentRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
                coordinator.resetView()
            }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .glassBackgroundEffect()
    }

    private var windowingControls: some View {
        VStack(spacing: 12) {
            Text("Windowing")
                .font(.headline)

            // Preset buttons
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(WindowLevel.allPresets, id: \.name) { preset in
                    Button(preset.name) {
                        coordinator.setWindowLevel(preset)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider()

            // Custom windowing sliders
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Center:")
                        .font(.caption)
                    Slider(value: $coordinator.windowCenter, in: -1000...1000, step: 10)
                    Text("\(Int(coordinator.windowCenter))")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 50)
                }

                HStack {
                    Text("Width:")
                        .font(.caption)
                    Slider(value: $coordinator.windowWidth, in: 1...4000, step: 10)
                    Text("\(Int(coordinator.windowWidth))")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 50)
                }
            }
        }
        .padding()
        .frame(width: 400)
        .glassBackgroundEffect()
    }
}

// MARK: - Volume Coordinator

/// Coordinates RealityKit volume entity and interactions
@MainActor
final class VolumeCoordinator: ObservableObject {

    @Published var opacity: Float = 1.0
    @Published var windowCenter: Float = 50.0
    @Published var windowWidth: Float = 400.0

    private var volumeEntity: ModelEntity?
    private var volumeData: VolumeData?
    private var baseScale: Float = 1.0

    // MARK: - Setup

    func setup(content: RealityViewContent, volume: VolumeData, windowLevel: WindowLevel?) async {
        self.volumeData = volume

        // Set initial windowing
        if let windowLevel = windowLevel {
            self.windowCenter = windowLevel.center
            self.windowWidth = windowLevel.width
        } else {
            self.windowCenter = volume.windowCenter
            self.windowWidth = volume.windowWidth
        }

        // Create volume entity
        let entity = createVolumeEntity(volume: volume)
        content.add(entity)
        self.volumeEntity = entity

        // Add lighting
        addLighting(to: content)

        print("✅ RealityKit scene setup complete")
    }

    func update(content: RealityViewContent) {
        // Update entity properties if needed
        volumeEntity?.components[OpacityComponent.self]?.opacity = opacity
    }

    // MARK: - Entity Creation

    private func createVolumeEntity(volume: VolumeData) -> ModelEntity {
        // Calculate physical size in meters
        let physicalSize = volume.physicalDimensions
        let widthM = physicalSize.x / 1000.0  // mm to meters
        let heightM = physicalSize.y / 1000.0
        let depthM = physicalSize.z / 1000.0

        // Create bounding box mesh
        let mesh = MeshResource.generateBox(
            width: widthM,
            height: heightM,
            depth: depthM
        )

        // Create material with volume appearance
        var material = UnlitMaterial()
        material.color = .init(tint: .white.withAlphaComponent(0.9))

        // TODO: Replace with custom Material using Metal shader
        // This would integrate with MetalVolumeRenderer

        let entity = ModelEntity(mesh: mesh, materials: [material])

        // Set position at life-size scale (1:1 for medical imaging)
        entity.position = SIMD3<Float>(0, heightM / 2, -1.0)

        // Add custom components
        entity.components.set(VolumeComponent(
            dimensions: volume.dimensions,
            spacing: volume.spacing,
            dataType: volume.dataType,
            windowCenter: volume.windowCenter,
            windowWidth: volume.windowWidth
        ))

        entity.components.set(OpacityComponent(opacity: 1.0))

        return entity
    }

    private func addLighting(to content: RealityViewContent) {
        // Add directional light
        let light = DirectionalLight()
        light.light.intensity = 1000
        light.look(at: SIMD3<Float>(0, 0, 0),
                   from: SIMD3<Float>(1, 1, 1),
                   relativeTo: nil)

        content.add(light)

        // Add ambient light
        let ambientLight = Entity()
        ambientLight.components.set(ImageBasedLightComponent(
            source: .single(.init(named: "default_environment"))
        ))
        content.add(ambientLight)
    }

    // MARK: - Transformations

    func setScale(_ scale: Float) {
        volumeEntity?.scale = SIMD3<Float>(repeating: scale)
    }

    func setRotation(_ rotation: simd_quatf) {
        volumeEntity?.orientation = rotation
    }

    func resetView() {
        volumeEntity?.scale = SIMD3<Float>(repeating: 1.0)
        volumeEntity?.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        volumeEntity?.position.y = (volumeData?.physicalDimensions.y ?? 200) / 2000.0
        opacity = 1.0
    }

    // MARK: - Windowing

    func setWindowLevel(_ windowLevel: WindowLevel) {
        windowCenter = windowLevel.center
        windowWidth = windowLevel.width

        // Update volume rendering with new windowing
        updateVolumeRendering()
    }

    func setCustomWindowing(center: Float, width: Float) {
        windowCenter = center
        windowWidth = width
        updateVolumeRendering()
    }

    private func updateVolumeRendering() {
        // TODO: Trigger re-render with MetalVolumeRenderer
        print("🎨 Windowing updated: C=\(windowCenter), W=\(windowWidth)")
    }
}

// MARK: - Custom Components

/// Component to store opacity
struct OpacityComponent: Component {
    var opacity: Float
}

// MARK: - Gesture Handlers

/// Handles spatial gestures for volume manipulation
struct VolumeGestureHandler {

    private var initialScale: Float = 1.0
    private var initialRotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))

    // Two-finger pinch to scale
    mutating func handlePinch(magnification: Float) -> Float {
        return initialScale * magnification
    }

    // Two-finger rotation
    mutating func handleRotation(angle: Float, axis: SIMD3<Float>) -> simd_quatf {
        let rotation = simd_quatf(angle: angle, axis: axis)
        return rotation * initialRotation
    }

    // Pan to translate
    func handlePan(translation: SIMD3<Float>) -> SIMD3<Float> {
        return translation * 0.001  // Scale down for precision
    }

    // Reset gestures
    mutating func reset() {
        initialScale = 1.0
        initialRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    }
}

// MARK: - Preview

#if DEBUG
struct VolumeRealityView_Previews: PreviewProvider {
    static var previews: some View {
        VolumeRealityView(
            volume: VolumeData.sample,
            windowLevel: .softTissue
        )
    }
}
#endif
