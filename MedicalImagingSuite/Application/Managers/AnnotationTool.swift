//
//  AnnotationTool.swift
//  MedicalImagingSuite
//
//  Clinical annotation system for marking and documenting findings
//

import Foundation
import simd
import SwiftUI
import RealityKit

// MARK: - Annotation Type

enum AnnotationType: String, Codable, CaseIterable {
    case freehand = "Freehand"
    case line = "Line"
    case arrow = "Arrow"
    case text = "Text"
    case circle = "Circle"
    case rectangle = "Rectangle"
    case polygon = "Polygon"

    var icon: String {
        switch self {
        case .freehand: return "scribble"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        case .text: return "text.cursor"
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .polygon: return "hexagon"
        }
    }
}

// MARK: - Annotation Style

struct AnnotationStyle: Codable {
    var color: CodableColor
    var lineWidth: Float
    var opacity: Float
    var filled: Bool

    static let `default` = AnnotationStyle(
        color: CodableColor(.yellow),
        lineWidth: 2.0,
        opacity: 1.0,
        filled: false
    )

    static let presets: [String: AnnotationStyle] = [
        "Finding": AnnotationStyle(color: CodableColor(.red), lineWidth: 3.0, opacity: 1.0, filled: false),
        "Normal": AnnotationStyle(color: CodableColor(.green), lineWidth: 2.0, opacity: 0.8, filled: false),
        "Question": AnnotationStyle(color: CodableColor(.yellow), lineWidth: 2.0, opacity: 0.9, filled: false),
        "ROI": AnnotationStyle(color: CodableColor(.blue), lineWidth: 2.0, opacity: 0.5, filled: true)
    ]
}

// MARK: - Annotation

/// A clinical annotation in 3D space
struct Annotation: Identifiable, Codable {
    let id: UUID
    let type: AnnotationType
    var points: [SIMD3<Float>]  // 3D points in world space
    var text: String?
    var style: AnnotationStyle
    let timestamp: Date
    var author: String?
    var category: String?  // e.g., "Finding", "Measurement", "Note"

    init(type: AnnotationType,
         points: [SIMD3<Float>] = [],
         text: String? = nil,
         style: AnnotationStyle = .default,
         author: String? = nil,
         category: String? = nil) {
        self.id = UUID()
        self.type = type
        self.points = points
        self.text = text
        self.style = style
        self.timestamp = Date()
        self.author = author
        self.category = category
    }

    /// Description for display
    var displayDescription: String {
        if let text = text, !text.isEmpty {
            return text
        }
        return "\(type.rawValue) annotation"
    }

    /// Statistics about the annotation
    var stats: String {
        switch type {
        case .freehand, .polygon:
            return "\(points.count) points"
        case .line, .arrow:
            if points.count >= 2 {
                let distance = simd_distance(points[0], points[1])
                return String(format: "%.1f mm", distance)
            }
            return "In progress"
        case .circle, .rectangle:
            return "\(points.count) control points"
        case .text:
            return text ?? "No text"
        }
    }
}

// MARK: - Annotation Tool Manager

/// Manages creation and editing of annotations
@MainActor
final class AnnotationToolManager: ObservableObject {

    @Published var annotations: [Annotation] = []
    @Published var activeAnnotationType: AnnotationType = .freehand
    @Published var activeStyle: AnnotationStyle = .default
    @Published var isActive: Bool = false
    @Published var currentCategory: String? = nil

    private var currentAnnotation: Annotation?
    private var currentAuthor: String?

    // MARK: - Configuration

    func setAuthor(_ author: String) {
        self.currentAuthor = author
    }

    func setAnnotationType(_ type: AnnotationType) {
        self.activeAnnotationType = type
    }

    func setStyle(_ style: AnnotationStyle) {
        self.activeStyle = style
    }

    func setStylePreset(_ presetName: String) {
        if let preset = AnnotationStyle.presets[presetName] {
            self.activeStyle = preset
            self.currentCategory = presetName
        }
    }

    // MARK: - Annotation Creation

    func startAnnotation() {
        isActive = true
        currentAnnotation = Annotation(
            type: activeAnnotationType,
            style: activeStyle,
            author: currentAuthor,
            category: currentCategory
        )
    }

    func addPoint(_ point: SIMD3<Float>) {
        guard isActive else { return }
        currentAnnotation?.points.append(point)
    }

    func finishAnnotation(text: String? = nil) {
        guard var annotation = currentAnnotation else { return }

        // Validate annotation has enough points
        guard isAnnotationValid(annotation) else {
            print("⚠️ Invalid annotation - not enough points")
            cancelAnnotation()
            return
        }

        annotation.text = text
        annotations.append(annotation)

        print("✅ Annotation created: \(annotation.displayDescription)")

        currentAnnotation = nil
        isActive = false
    }

    func cancelAnnotation() {
        currentAnnotation = nil
        isActive = false
    }

    private func isAnnotationValid(_ annotation: Annotation) -> Bool {
        switch annotation.type {
        case .freehand:
            return annotation.points.count >= 2
        case .line:
            return annotation.points.count >= 2
        case .arrow:
            return annotation.points.count >= 2
        case .text:
            return true  // Text can exist without points
        case .circle:
            return annotation.points.count >= 2  // Center + radius point
        case .rectangle:
            return annotation.points.count >= 2  // Two opposite corners
        case .polygon:
            return annotation.points.count >= 3
        }
    }

    // MARK: - Annotation Management

    func deleteAnnotation(_ annotation: Annotation) {
        annotations.removeAll { $0.id == annotation.id }
    }

    func deleteAll() {
        annotations.removeAll()
    }

    func updateText(for annotation: Annotation, text: String) {
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[index].text = text
        }
    }

    func updateCategory(for annotation: Annotation, category: String) {
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            annotations[index].category = category
        }
    }

    // MARK: - Filtering

    func annotations(ofType type: AnnotationType) -> [Annotation] {
        annotations.filter { $0.type == type }
    }

    func annotations(inCategory category: String) -> [Annotation] {
        annotations.filter { $0.category == category }
    }

    func annotations(by author: String) -> [Annotation] {
        annotations.filter { $0.author == author }
    }

    // MARK: - Export

    /// Export annotations as JSON
    func exportAsJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(annotations),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return json
    }

    /// Export as DICOM Structured Report (simplified)
    func exportAsDICOMSR() -> String {
        var sr = "DICOM Structured Report - Annotations\n"
        sr += "Generated: \(Date().ISO8601Format())\n"
        sr += "Total Annotations: \(annotations.count)\n\n"

        for (index, annotation) in annotations.enumerated() {
            sr += "[\(index + 1)] \(annotation.type.rawValue)\n"
            sr += "  Category: \(annotation.category ?? "None")\n"
            sr += "  Author: \(annotation.author ?? "Unknown")\n"
            sr += "  Time: \(annotation.timestamp.ISO8601Format())\n"
            if let text = annotation.text {
                sr += "  Text: \(text)\n"
            }
            sr += "  Points: \(annotation.points.count)\n"
            sr += "\n"
        }

        return sr
    }
}

// MARK: - Annotation Visualization

/// Entity for visualizing annotations in 3D
struct AnnotationEntity {

    /// Create a 3D entity for a freehand annotation
    static func createFreehandEntity(points: [SIMD3<Float>], style: AnnotationStyle) -> Entity {
        let container = Entity()

        // Draw lines between consecutive points
        for i in 0..<(points.count - 1) {
            let line = createLine(
                from: points[i],
                to: points[i + 1],
                color: style.color.color,
                width: style.lineWidth
            )
            container.addChild(line)
        }

        return container
    }

    /// Create a 3D entity for a line annotation
    static func createLineEntity(from p1: SIMD3<Float>, to p2: SIMD3<Float>, style: AnnotationStyle) -> Entity {
        let container = Entity()

        let line = createLine(from: p1, to: p2, color: style.color.color, width: style.lineWidth)
        container.addChild(line)

        // Add endpoint markers
        let marker1 = createMarker(at: p1, color: style.color.color)
        let marker2 = createMarker(at: p2, color: style.color.color)
        container.addChild(marker1)
        container.addChild(marker2)

        return container
    }

    /// Create a 3D entity for an arrow annotation
    static func createArrowEntity(from p1: SIMD3<Float>, to p2: SIMD3<Float>, style: AnnotationStyle) -> Entity {
        let container = Entity()

        // Main line
        let line = createLine(from: p1, to: p2, color: style.color.color, width: style.lineWidth)
        container.addChild(line)

        // Arrow head (simplified cone)
        let direction = normalize(p2 - p1)
        let arrowHead = createArrowHead(at: p2, direction: direction, color: style.color.color)
        container.addChild(arrowHead)

        return container
    }

    /// Create a 3D entity for a circle annotation
    static func createCircleEntity(center: SIMD3<Float>, radiusPoint: SIMD3<Float>, style: AnnotationStyle) -> Entity {
        let container = Entity()

        let radius = simd_distance(center, radiusPoint)

        // Create circle mesh (torus for visibility)
        let torus = MeshResource.generatePlane(width: radius * 2, depth: radius * 2)
        var material = UnlitMaterial()
        material.color = .init(tint: style.color.color.withAlphaComponent(CGFloat(style.opacity)))

        let entity = ModelEntity(mesh: torus, materials: [material])
        entity.position = center

        container.addChild(entity)

        return container
    }

    /// Create a 3D entity for a rectangle annotation
    static func createRectangleEntity(corner1: SIMD3<Float>, corner2: SIMD3<Float>, style: AnnotationStyle) -> Entity {
        let container = Entity()

        // Calculate the other two corners
        let corner3 = SIMD3<Float>(corner2.x, corner1.y, corner1.z)
        let corner4 = SIMD3<Float>(corner1.x, corner2.y, corner2.z)

        // Draw four edges
        let edges = [
            (corner1, corner3),
            (corner3, corner2),
            (corner2, corner4),
            (corner4, corner1)
        ]

        for (p1, p2) in edges {
            let line = createLine(from: p1, to: p2, color: style.color.color, width: style.lineWidth)
            container.addChild(line)
        }

        // Fill if needed
        if style.filled {
            let width = abs(corner2.x - corner1.x)
            let height = abs(corner2.y - corner1.y)
            let center = (corner1 + corner2) / 2

            let plane = MeshResource.generatePlane(width: width, depth: height)
            var material = UnlitMaterial()
            material.color = .init(tint: style.color.color.withAlphaComponent(CGFloat(style.opacity * 0.5)))

            let fill = ModelEntity(mesh: plane, materials: [material])
            fill.position = center

            container.addChild(fill)
        }

        return container
    }

    /// Create a 3D text label
    static func createTextEntity(text: String, at position: SIMD3<Float>, style: AnnotationStyle) -> Entity {
        let container = Entity()

        // Create text mesh
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.02)
        )

        var material = UnlitMaterial()
        material.color = .init(tint: style.color.color)

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position

        // Billboard effect - always face camera
        // TODO: Implement billboard behavior

        container.addChild(entity)

        return container
    }

    // MARK: - Helpers

    private static func createLine(from p1: SIMD3<Float>, to p2: SIMD3<Float>,
                                   color: Color, width: Float) -> Entity {
        let distance = simd_distance(p1, p2)
        let midpoint = (p1 + p2) / 2

        let cylinder = MeshResource.generateCylinder(height: distance, radius: width * 0.001)
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(color))

        let entity = ModelEntity(mesh: cylinder, materials: [material])

        // Orient cylinder
        let direction = normalize(p2 - p1)
        let up = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(from: up, to: direction)

        entity.position = midpoint
        entity.orientation = rotation

        return entity
    }

    private static func createMarker(at position: SIMD3<Float>, color: Color) -> Entity {
        let sphere = MeshResource.generateSphere(radius: 0.002)
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(color))

        let entity = ModelEntity(mesh: sphere, materials: [material])
        entity.position = position

        return entity
    }

    private static func createArrowHead(at position: SIMD3<Float>, direction: SIMD3<Float>, color: Color) -> Entity {
        let cone = MeshResource.generateCone(height: 0.01, radius: 0.003)
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(color))

        let entity = ModelEntity(mesh: cone, materials: [material])
        entity.position = position

        // Orient cone
        let up = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(from: up, to: direction)
        entity.orientation = rotation

        return entity
    }
}
