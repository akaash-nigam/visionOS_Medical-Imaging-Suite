//
//  TransferFunction.swift
//  MedicalImagingSuite
//
//  Transfer function definitions for volume rendering
//

import Foundation
import simd

// MARK: - Transfer Function Point

/// A point in a transfer function mapping intensity to color and opacity
struct TransferFunctionPoint {
    let intensity: Float  // Normalized [0, 1]
    let color: SIMD4<Float>  // RGBA

    init(intensity: Float, red: Float, green: Float, blue: Float, alpha: Float) {
        self.intensity = intensity
        self.color = SIMD4<Float>(red, green, blue, alpha)
    }
}

// MARK: - Transfer Function

/// Transfer function for mapping intensity values to colors and opacity
struct TransferFunction {
    let name: String
    let points: [TransferFunctionPoint]

    /// Evaluate the transfer function at a given intensity
    func evaluate(at intensity: Float) -> SIMD4<Float> {
        let clamped = min(max(intensity, 0.0), 1.0)

        guard !points.isEmpty else {
            // Default grayscale
            return SIMD4<Float>(clamped, clamped, clamped, clamped)
        }

        // Find surrounding points
        for i in 0..<(points.count - 1) {
            if clamped >= points[i].intensity && clamped <= points[i + 1].intensity {
                let t = (clamped - points[i].intensity) /
                       (points[i + 1].intensity - points[i].intensity)
                return mix(points[i].color, points[i + 1].color, t: t)
            }
        }

        // Outside range
        if clamped < points[0].intensity {
            return points[0].color
        }
        return points[points.count - 1].color
    }

    private func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, t: Float) -> SIMD4<Float> {
        return a * (1.0 - t) + b * t
    }
}

// MARK: - Windowing Presets

/// Predefined windowing presets for common clinical applications
enum WindowingPreset: String, CaseIterable {
    case bone = "Bone"
    case softTissue = "Soft Tissue"
    case lung = "Lung"
    case liver = "Liver"
    case brain = "Brain"
    case abdomen = "Abdomen"
    case mediastinum = "Mediastinum"
    case spine = "Spine"
    case custom = "Custom"

    /// Window center in Hounsfield Units
    var center: Float {
        switch self {
        case .bone: return 400
        case .softTissue: return 50
        case .lung: return -600
        case .liver: return 80
        case .brain: return 40
        case .abdomen: return 60
        case .mediastinum: return 50
        case .spine: return 50
        case .custom: return 0
        }
    }

    /// Window width in Hounsfield Units
    var width: Float {
        switch self {
        case .bone: return 2000
        case .softTissue: return 400
        case .lung: return 1500
        case .liver: return 150
        case .brain: return 80
        case .abdomen: return 400
        case .mediastinum: return 350
        case .spine: return 1800
        case .custom: return 2000
        }
    }

    var centerWidth: SIMD2<Float> {
        return SIMD2<Float>(center, width)
    }
}

// MARK: - Preset Transfer Functions

extension TransferFunction {

    /// Grayscale transfer function (default)
    static let grayscale = TransferFunction(name: "Grayscale", points: [
        TransferFunctionPoint(intensity: 0.0, red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
        TransferFunctionPoint(intensity: 1.0, red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    ])

    /// CT bone visualization
    static let ctBone = TransferFunction(name: "CT Bone", points: [
        TransferFunctionPoint(intensity: 0.0, red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
        TransferFunctionPoint(intensity: 0.3, red: 0.5, green: 0.25, blue: 0.15, alpha: 0.0),
        TransferFunctionPoint(intensity: 0.5, red: 0.9, green: 0.82, blue: 0.76, alpha: 0.3),
        TransferFunctionPoint(intensity: 0.7, red: 1.0, green: 0.95, blue: 0.9, alpha: 0.7),
        TransferFunctionPoint(intensity: 1.0, red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    ])

    /// CT soft tissue visualization
    static let ctSoftTissue = TransferFunction(name: "CT Soft Tissue", points: [
        TransferFunctionPoint(intensity: 0.0, red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
        TransferFunctionPoint(intensity: 0.3, red: 0.4, green: 0.2, blue: 0.2, alpha: 0.1),
        TransferFunctionPoint(intensity: 0.5, red: 0.8, green: 0.5, blue: 0.5, alpha: 0.4),
        TransferFunctionPoint(intensity: 0.8, red: 1.0, green: 0.8, blue: 0.8, alpha: 0.8),
        TransferFunctionPoint(intensity: 1.0, red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    ])

    /// CT lung visualization (inverted for air)
    static let ctLung = TransferFunction(name: "CT Lung", points: [
        TransferFunctionPoint(intensity: 0.0, red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
        TransferFunctionPoint(intensity: 0.2, red: 0.1, green: 0.1, blue: 0.2, alpha: 0.5),
        TransferFunctionPoint(intensity: 0.4, red: 0.3, green: 0.5, blue: 0.8, alpha: 0.7),
        TransferFunctionPoint(intensity: 0.7, red: 0.8, green: 0.9, blue: 1.0, alpha: 0.9),
        TransferFunctionPoint(intensity: 1.0, red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    ])

    /// MRI brain visualization
    static let mriBrain = TransferFunction(name: "MRI Brain", points: [
        TransferFunctionPoint(intensity: 0.0, red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
        TransferFunctionPoint(intensity: 0.2, red: 0.2, green: 0.1, blue: 0.3, alpha: 0.2),
        TransferFunctionPoint(intensity: 0.5, red: 0.6, green: 0.4, blue: 0.7, alpha: 0.5),
        TransferFunctionPoint(intensity: 0.8, red: 0.9, green: 0.7, blue: 1.0, alpha: 0.8),
        TransferFunctionPoint(intensity: 1.0, red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    ])

    /// Hot metal color map (good for highlighting)
    static let hotMetal = TransferFunction(name: "Hot Metal", points: [
        TransferFunctionPoint(intensity: 0.0, red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
        TransferFunctionPoint(intensity: 0.25, red: 0.5, green: 0.0, blue: 0.0, alpha: 0.5),
        TransferFunctionPoint(intensity: 0.5, red: 1.0, green: 0.5, blue: 0.0, alpha: 0.7),
        TransferFunctionPoint(intensity: 0.75, red: 1.0, green: 1.0, blue: 0.0, alpha: 0.9),
        TransferFunctionPoint(intensity: 1.0, red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    ])

    /// Rainbow color map
    static let rainbow = TransferFunction(name: "Rainbow", points: [
        TransferFunctionPoint(intensity: 0.0, red: 0.0, green: 0.0, blue: 0.5, alpha: 0.0),
        TransferFunctionPoint(intensity: 0.2, red: 0.0, green: 0.0, blue: 1.0, alpha: 0.5),
        TransferFunctionPoint(intensity: 0.4, red: 0.0, green: 1.0, blue: 1.0, alpha: 0.7),
        TransferFunctionPoint(intensity: 0.6, red: 0.0, green: 1.0, blue: 0.0, alpha: 0.8),
        TransferFunctionPoint(intensity: 0.8, red: 1.0, green: 1.0, blue: 0.0, alpha: 0.9),
        TransferFunctionPoint(intensity: 1.0, red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
    ])

    /// Vascular visualization (red tones)
    static let vascular = TransferFunction(name: "Vascular", points: [
        TransferFunctionPoint(intensity: 0.0, red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
        TransferFunctionPoint(intensity: 0.3, red: 0.3, green: 0.0, blue: 0.0, alpha: 0.2),
        TransferFunctionPoint(intensity: 0.6, red: 0.8, green: 0.2, blue: 0.2, alpha: 0.6),
        TransferFunctionPoint(intensity: 0.9, red: 1.0, green: 0.5, blue: 0.5, alpha: 0.9),
        TransferFunctionPoint(intensity: 1.0, red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    ])

    /// All preset transfer functions
    static let allPresets: [TransferFunction] = [
        .grayscale,
        .ctBone,
        .ctSoftTissue,
        .ctLung,
        .mriBrain,
        .hotMetal,
        .rainbow,
        .vascular
    ]
}

// MARK: - Transfer Function Manager

/// Manages transfer function selection and customization
@MainActor
final class TransferFunctionManager: ObservableObject {

    @Published var currentFunction: TransferFunction
    @Published var currentPreset: WindowingPreset
    @Published var customCenter: Float
    @Published var customWidth: Float

    init() {
        self.currentFunction = .grayscale
        self.currentPreset = .softTissue
        self.customCenter = WindowingPreset.softTissue.center
        self.customWidth = WindowingPreset.softTissue.width
    }

    /// Set transfer function preset
    func setTransferFunction(_ function: TransferFunction) {
        currentFunction = function
    }

    /// Set windowing preset
    func setWindowingPreset(_ preset: WindowingPreset) {
        currentPreset = preset
        if preset != .custom {
            customCenter = preset.center
            customWidth = preset.width
        }
    }

    /// Get current window center/width
    func getCurrentWindow() -> SIMD2<Float> {
        if currentPreset == .custom {
            return SIMD2<Float>(customCenter, customWidth)
        }
        return currentPreset.centerWidth
    }

    /// Adjust windowing interactively (for gestures)
    func adjustWindow(deltaCenter: Float, deltaWidth: Float) {
        customCenter += deltaCenter
        customWidth = max(1.0, customWidth + deltaWidth)
        currentPreset = .custom
    }
}
