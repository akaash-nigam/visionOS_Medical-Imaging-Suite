//
//  MeasurementTool.swift
//  MedicalImagingSuite
//
//  Clinical measurement tools for distance and angle measurements
//

import Foundation
import simd
import RealityKit
import SwiftUI

// MARK: - Measurement Type

enum MeasurementType: String, Codable, CaseIterable {
    case distance = "Distance"
    case angle = "Angle"
    case area = "Area"
    case volume = "Volume"

    var icon: String {
        switch self {
        case .distance: return "ruler"
        case .angle: return "angle"
        case .area: return "square.on.square"
        case .volume: return "cube"
        }
    }
}

// MARK: - Measurement Point

/// A 3D point in measurement space
struct MeasurementPoint: Codable, Identifiable {
    let id: UUID
    let position: SIMD3<Float>  // Position in world space
    let voxelPosition: SIMD3<Int>  // Position in voxel coordinates
    let intensity: Float  // Voxel intensity at this point

    init(position: SIMD3<Float>, voxelPosition: SIMD3<Int>, intensity: Float) {
        self.id = UUID()
        self.position = position
        self.voxelPosition = voxelPosition
        self.intensity = intensity
    }
}

// MARK: - Measurement

/// A measurement in 3D space
struct Measurement: Identifiable, Codable {
    let id: UUID
    let type: MeasurementType
    let points: [MeasurementPoint]
    let value: Float  // Computed value (mm, degrees, mm², mm³)
    let unit: String
    let timestamp: Date
    var label: String?
    var color: CodableColor

    init(type: MeasurementType,
         points: [MeasurementPoint],
         value: Float,
         unit: String,
         label: String? = nil,
         color: CodableColor = CodableColor(.yellow)) {
        self.id = UUID()
        self.type = type
        self.points = points
        self.value = value
        self.unit = unit
        self.timestamp = Date()
        self.label = label
        self.color = color
    }

    /// Formatted measurement value
    var formattedValue: String {
        switch type {
        case .distance:
            return String(format: "%.2f %@", value, unit)
        case .angle:
            return String(format: "%.1f%@", value, unit)
        case .area:
            return String(format: "%.2f %@", value, unit)
        case .volume:
            return String(format: "%.2f %@", value, unit)
        }
    }

    /// Description for display
    var displayDescription: String {
        if let label = label {
            return "\(label): \(formattedValue)"
        }
        return "\(type.rawValue): \(formattedValue)"
    }
}

// MARK: - Codable Color

/// SwiftUI Color that can be encoded/decoded
struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(_ color: Color) {
        // Extract components (simplified)
        // In production, use proper color component extraction
        self.red = 1.0
        self.green = 0.8
        self.blue = 0.0
        self.alpha = 1.0
    }

    var color: Color {
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Measurement Calculator

/// Calculates measurement values from points
struct MeasurementCalculator {

    /// Calculate Euclidean distance between two points
    static func distance(from p1: SIMD3<Float>, to p2: SIMD3<Float>) -> Float {
        let delta = p2 - p1
        return sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z)
    }

    /// Calculate angle between three points (p1-p2-p3, angle at p2)
    static func angle(p1: SIMD3<Float>, vertex p2: SIMD3<Float>, p3: SIMD3<Float>) -> Float {
        let v1 = p1 - p2
        let v2 = p3 - p2

        let dot = simd_dot(v1, v2)
        let mag1 = simd_length(v1)
        let mag2 = simd_length(v2)

        let cosAngle = dot / (mag1 * mag2)
        let angleRad = acos(max(-1.0, min(1.0, cosAngle)))

        return angleRad * 180.0 / .pi  // Convert to degrees
    }

    /// Calculate area of triangle given three points
    static func triangleArea(p1: SIMD3<Float>, p2: SIMD3<Float>, p3: SIMD3<Float>) -> Float {
        let v1 = p2 - p1
        let v2 = p3 - p1
        let cross = simd_cross(v1, v2)
        return simd_length(cross) / 2.0
    }

    /// Calculate volume of tetrahedron given four points
    static func tetrahedronVolume(p1: SIMD3<Float>, p2: SIMD3<Float>,
                                  p3: SIMD3<Float>, p4: SIMD3<Float>) -> Float {
        let v1 = p2 - p1
        let v2 = p3 - p1
        let v3 = p4 - p1

        return abs(simd_dot(v1, simd_cross(v2, v3))) / 6.0
    }
}

// MARK: - Measurement Tool Manager

/// Manages creation and editing of measurements
@MainActor
final class MeasurementToolManager: ObservableObject {

    @Published var measurements: [Measurement] = []
    @Published var activeMeasurementType: MeasurementType = .distance
    @Published var isActive: Bool = false

    private var currentPoints: [MeasurementPoint] = []
    private var volumeSpacing: SIMD3<Float> = SIMD3<Float>(1, 1, 1)

    // MARK: - Configuration

    func setVolumeSpacing(_ spacing: SIMD3<Float>) {
        self.volumeSpacing = spacing
    }

    func setMeasurementType(_ type: MeasurementType) {
        self.activeMeasurementType = type
        resetCurrentMeasurement()
    }

    func startMeasurement() {
        isActive = true
        resetCurrentMeasurement()
    }

    func cancelMeasurement() {
        isActive = false
        resetCurrentMeasurement()
    }

    private func resetCurrentMeasurement() {
        currentPoints.removeAll()
    }

    // MARK: - Point Addition

    /// Add a point to the current measurement
    func addPoint(worldPosition: SIMD3<Float>, voxelPosition: SIMD3<Int>, intensity: Float) {
        let point = MeasurementPoint(
            position: worldPosition,
            voxelPosition: voxelPosition,
            intensity: intensity
        )

        currentPoints.append(point)

        // Check if measurement is complete
        if isM easurementComplete() {
            completeMeasurement()
        }
    }

    private func isM easurementComplete() -> Bool {
        switch activeMeasurementType {
        case .distance:
            return currentPoints.count >= 2
        case .angle:
            return currentPoints.count >= 3
        case .area:
            return currentPoints.count >= 3
        case .volume:
            return currentPoints.count >= 4
        }
    }

    private func completeMeasurement() {
        guard let measurement = createMeasurement() else {
            resetCurrentMeasurement()
            return
        }

        measurements.append(measurement)
        resetCurrentMeasurement()
        isActive = false

        print("✅ Measurement created: \(measurement.displayDescription)")
    }

    // MARK: - Measurement Creation

    private func createMeasurement() -> Measurement? {
        guard !currentPoints.isEmpty else { return nil }

        switch activeMeasurementType {
        case .distance:
            return createDistanceMeasurement()
        case .angle:
            return createAngleMeasurement()
        case .area:
            return createAreaMeasurement()
        case .volume:
            return createVolumeMeasurement()
        }
    }

    private func createDistanceMeasurement() -> Measurement? {
        guard currentPoints.count >= 2 else { return nil }

        let p1 = currentPoints[0].position
        let p2 = currentPoints[1].position

        let distance = MeasurementCalculator.distance(from: p1, to: p2)

        return Measurement(
            type: .distance,
            points: Array(currentPoints.prefix(2)),
            value: distance,
            unit: "mm",
            label: "Distance",
            color: CodableColor(.yellow)
        )
    }

    private func createAngleMeasurement() -> Measurement? {
        guard currentPoints.count >= 3 else { return nil }

        let p1 = currentPoints[0].position
        let p2 = currentPoints[1].position  // Vertex
        let p3 = currentPoints[2].position

        let angle = MeasurementCalculator.angle(p1: p1, vertex: p2, p3: p3)

        return Measurement(
            type: .angle,
            points: Array(currentPoints.prefix(3)),
            value: angle,
            unit: "°",
            label: "Angle",
            color: CodableColor(.green)
        )
    }

    private func createAreaMeasurement() -> Measurement? {
        guard currentPoints.count >= 3 else { return nil }

        let p1 = currentPoints[0].position
        let p2 = currentPoints[1].position
        let p3 = currentPoints[2].position

        let area = MeasurementCalculator.triangleArea(p1: p1, p2: p2, p3: p3)

        return Measurement(
            type: .area,
            points: Array(currentPoints.prefix(3)),
            value: area,
            unit: "mm²",
            label: "Area",
            color: CodableColor(.blue)
        )
    }

    private func createVolumeMeasurement() -> Measurement? {
        guard currentPoints.count >= 4 else { return nil }

        let p1 = currentPoints[0].position
        let p2 = currentPoints[1].position
        let p3 = currentPoints[2].position
        let p4 = currentPoints[3].position

        let volume = MeasurementCalculator.tetrahedronVolume(p1: p1, p2: p2, p3: p3, p4: p4)

        return Measurement(
            type: .volume,
            points: Array(currentPoints.prefix(4)),
            value: volume,
            unit: "mm³",
            label: "Volume",
            color: CodableColor(.purple)
        )
    }

    // MARK: - Measurement Management

    func deleteMeasurement(_ measurement: Measurement) {
        measurements.removeAll { $0.id == measurement.id }
    }

    func deleteAll() {
        measurements.removeAll()
    }

    func updateLabel(for measurement: Measurement, label: String) {
        if let index = measurements.firstIndex(where: { $0.id == measurement.id }) {
            measurements[index].label = label
        }
    }

    // MARK: - Export

    /// Export measurements as JSON
    func exportAsJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(measurements),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return json
    }

    /// Export measurements as CSV
    func exportAsCSV() -> String {
        var csv = "ID,Type,Value,Unit,Timestamp,Label,Points\n"

        for measurement in measurements {
            let pointsStr = measurement.points.map { point in
                "(\(point.position.x),\(point.position.y),\(point.position.z))"
            }.joined(separator: ";")

            csv += "\(measurement.id.uuidString),"
            csv += "\(measurement.type.rawValue),"
            csv += "\(measurement.value),"
            csv += "\(measurement.unit),"
            csv += "\(measurement.timestamp.ISO8601Format()),"
            csv += "\(measurement.label ?? ""),"
            csv += "\"\(pointsStr)\"\n"
        }

        return csv
    }
}

// MARK: - Measurement Visualization

/// Entity for visualizing measurements in 3D
struct MeasurementEntity {

    /// Create a 3D entity for a distance measurement
    static func createDistanceEntity(from p1: SIMD3<Float>, to p2: SIMD3<Float>) -> Entity {
        let container = Entity()

        // Line between points
        let line = createLine(from: p1, to: p2, color: .yellow)
        container.addChild(line)

        // Spheres at endpoints
        let sphere1 = createSphere(at: p1, radius: 0.002, color: .yellow)
        let sphere2 = createSphere(at: p2, radius: 0.002, color: .yellow)
        container.addChild(sphere1)
        container.addChild(sphere2)

        return container
    }

    /// Create a 3D entity for an angle measurement
    static func createAngleEntity(p1: SIMD3<Float>, vertex p2: SIMD3<Float>, p3: SIMD3<Float>) -> Entity {
        let container = Entity()

        // Lines from vertex
        let line1 = createLine(from: p2, to: p1, color: .green)
        let line2 = createLine(from: p2, to: p3, color: .green)
        container.addChild(line1)
        container.addChild(line2)

        // Spheres at points
        let sphere1 = createSphere(at: p1, radius: 0.002, color: .green)
        let sphere2 = createSphere(at: p2, radius: 0.003, color: .green)  // Vertex larger
        let sphere3 = createSphere(at: p3, radius: 0.002, color: .green)
        container.addChild(sphere1)
        container.addChild(sphere2)
        container.addChild(sphere3)

        // Arc at vertex (simplified - would need proper arc mesh)
        // TODO: Add proper arc visualization

        return container
    }

    // MARK: - Helpers

    private static func createLine(from p1: SIMD3<Float>, to p2: SIMD3<Float>, color: UIColor) -> Entity {
        let distance = simd_distance(p1, p2)
        let midpoint = (p1 + p2) / 2

        let cylinder = MeshResource.generateCylinder(height: distance, radius: 0.0005)
        var material = UnlitMaterial()
        material.color = .init(tint: color)

        let entity = ModelEntity(mesh: cylinder, materials: [material])

        // Orient cylinder from p1 to p2
        let direction = normalize(p2 - p1)
        let up = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(from: up, to: direction)

        entity.position = midpoint
        entity.orientation = rotation

        return entity
    }

    private static func createSphere(at position: SIMD3<Float>, radius: Float, color: UIColor) -> Entity {
        let sphere = MeshResource.generateSphere(radius: radius)
        var material = UnlitMaterial()
        material.color = .init(tint: color)

        let entity = ModelEntity(mesh: sphere, materials: [material])
        entity.position = position

        return entity
    }
}
