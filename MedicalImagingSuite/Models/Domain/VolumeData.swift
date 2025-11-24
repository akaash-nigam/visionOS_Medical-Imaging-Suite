//
//  VolumeData.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// Represents reconstructed 3D volume data from a DICOM series
struct VolumeData: Identifiable {
    let id: UUID
    let seriesInstanceUID: String
    let dimensions: SIMD3<Int>      // (width, height, depth) in voxels
    let spacing: SIMD3<Float>       // Physical spacing in mm
    let dataType: VoxelDataType
    let voxelData: Data             // Raw voxel data
    let windowCenter: Float         // Hounsfield units (CT) or signal intensity
    let windowWidth: Float
    let rescaleSlope: Float         // For converting stored values to HU
    let rescaleIntercept: Float

    /// Total number of voxels
    var voxelCount: Int {
        dimensions.x * dimensions.y * dimensions.z
    }

    /// Physical dimensions in millimeters
    var physicalDimensions: SIMD3<Float> {
        SIMD3<Float>(
            Float(dimensions.x) * spacing.x,
            Float(dimensions.y) * spacing.y,
            Float(dimensions.z) * spacing.z
        )
    }

    /// Memory size in bytes
    var memorySize: Int {
        voxelCount * dataType.bytesPerVoxel
    }

    init(
        id: UUID = UUID(),
        seriesInstanceUID: String,
        dimensions: SIMD3<Int>,
        spacing: SIMD3<Float>,
        dataType: VoxelDataType,
        voxelData: Data,
        windowCenter: Float = 40,
        windowWidth: Float = 400,
        rescaleSlope: Float = 1.0,
        rescaleIntercept: Float = 0.0
    ) {
        self.id = id
        self.seriesInstanceUID = seriesInstanceUID
        self.dimensions = dimensions
        self.spacing = spacing
        self.dataType = dataType
        self.voxelData = voxelData
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.rescaleSlope = rescaleSlope
        self.rescaleIntercept = rescaleIntercept
    }
}

/// Voxel data type determines how to interpret raw bytes
enum VoxelDataType: String, Codable {
    case uint8          // 8-bit unsigned
    case int16          // 16-bit signed (CT Hounsfield units)
    case float32        // 32-bit float (processed data)

    var bytesPerVoxel: Int {
        switch self {
        case .uint8: return 1
        case .int16: return 2
        case .float32: return 4
        }
    }
}

/// Windowing preset for different tissue types
struct WindowLevel {
    let center: Float
    let width: Float
    let name: String

    /// Common CT windowing presets
    static let bone = WindowLevel(center: 300, width: 2000, name: "Bone")
    static let softTissue = WindowLevel(center: 40, width: 400, name: "Soft Tissue")
    static let lung = WindowLevel(center: -600, width: 1500, name: "Lung")
    static let brain = WindowLevel(center: 40, width: 80, name: "Brain")
    static let liver = WindowLevel(center: 60, width: 150, name: "Liver")
    static let mediastinum = WindowLevel(center: 50, width: 350, name: "Mediastinum")

    /// All common presets
    static let allPresets: [WindowLevel] = [
        .bone, .softTissue, .lung, .brain, .liver, .mediastinum
    ]
}

// MARK: - Sample Data

extension VolumeData {
    static let sample = VolumeData(
        seriesInstanceUID: "1.2.840.113619.2.55.3.12345.6789",
        dimensions: SIMD3(512, 512, 200),
        spacing: SIMD3(0.7, 0.7, 1.0),
        dataType: .int16,
        voxelData: Data(count: 512 * 512 * 200 * 2),
        windowCenter: 40,
        windowWidth: 400
    )
}
