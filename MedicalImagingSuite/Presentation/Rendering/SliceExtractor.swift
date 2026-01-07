//
//  SliceExtractor.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation
import SwiftUI

/// Extracts 2D slices from 3D volume data
actor SliceExtractor {

    // MARK: - Slice Extraction

    /// Extract a 2D slice from volume at specified plane and index
    /// - Parameters:
    ///   - volume: Source volume data
    ///   - plane: Anatomical plane (axial, coronal, sagittal)
    ///   - index: Slice index in the plane
    /// - Returns: 2D slice data and metadata
    func extractSlice(
        from volume: VolumeData,
        plane: AnatomicalPlane,
        index: Int
    ) throws -> SliceData {
        // Validate index
        let maxIndex = volume.sliceCount(for: plane)
        guard index >= 0 && index < maxIndex else {
            throw SliceExtractionError.indexOutOfBounds(index: index, max: maxIndex)
        }

        // Extract slice based on plane
        let sliceData: Data
        let width: Int
        let height: Int

        switch plane {
        case .axial:
            // XY plane (looking down from top)
            sliceData = try extractAxialSlice(from: volume, index: index)
            width = volume.dimensions.x
            height = volume.dimensions.y

        case .coronal:
            // XZ plane (looking from front)
            sliceData = try extractCoronalSlice(from: volume, index: index)
            width = volume.dimensions.x
            height = volume.dimensions.z

        case .sagittal:
            // YZ plane (looking from side)
            sliceData = try extractSagittalSlice(from: volume, index: index)
            width = volume.dimensions.y
            height = volume.dimensions.z
        }

        return SliceData(
            data: sliceData,
            width: width,
            height: height,
            plane: plane,
            index: index,
            dataType: volume.dataType,
            windowCenter: volume.windowCenter,
            windowWidth: volume.windowWidth
        )
    }

    // MARK: - Plane-Specific Extraction

    /// Extract axial (transverse) slice
    private func extractAxialSlice(from volume: VolumeData, index: Int) throws -> Data {
        let width = volume.dimensions.x
        let height = volume.dimensions.y
        let bytesPerVoxel = volume.dataType.bytesPerVoxel

        let sliceSize = width * height * bytesPerVoxel
        let offset = index * sliceSize

        guard offset + sliceSize <= volume.voxelData.count else {
            throw SliceExtractionError.dataCorrupted
        }

        return volume.voxelData.subdata(in: offset..<offset+sliceSize)
    }

    /// Extract coronal (frontal) slice
    private func extractCoronalSlice(from volume: VolumeData, index: Int) throws -> Data {
        let width = volume.dimensions.x
        let height = volume.dimensions.z
        let depth = volume.dimensions.y
        let bytesPerVoxel = volume.dataType.bytesPerVoxel

        var sliceData = Data(count: width * height * bytesPerVoxel)

        // Copy rows from each axial slice
        for z in 0..<height {
            for x in 0..<width {
                let volumeIndex = z * (width * depth) + index * width + x
                let sliceIndex = z * width + x
                let volumeOffset = volumeIndex * bytesPerVoxel
                let sliceOffset = sliceIndex * bytesPerVoxel

                guard volumeOffset + bytesPerVoxel <= volume.voxelData.count else {
                    throw SliceExtractionError.dataCorrupted
                }

                let voxelData = volume.voxelData.subdata(
                    in: volumeOffset..<volumeOffset+bytesPerVoxel
                )
                sliceData.replaceSubrange(
                    sliceOffset..<sliceOffset+bytesPerVoxel,
                    with: voxelData
                )
            }
        }

        return sliceData
    }

    /// Extract sagittal (lateral) slice
    private func extractSagittalSlice(from volume: VolumeData, index: Int) throws -> Data {
        let width = volume.dimensions.y
        let height = volume.dimensions.z
        let volumeWidth = volume.dimensions.x
        let volumeDepth = volume.dimensions.y
        let bytesPerVoxel = volume.dataType.bytesPerVoxel

        var sliceData = Data(count: width * height * bytesPerVoxel)

        // Copy columns from each axial slice
        for z in 0..<height {
            for y in 0..<width {
                let volumeIndex = z * (volumeWidth * volumeDepth) + y * volumeWidth + index
                let sliceIndex = z * width + y
                let volumeOffset = volumeIndex * bytesPerVoxel
                let sliceOffset = sliceIndex * bytesPerVoxel

                guard volumeOffset + bytesPerVoxel <= volume.voxelData.count else {
                    throw SliceExtractionError.dataCorrupted
                }

                let voxelData = volume.voxelData.subdata(
                    in: volumeOffset..<volumeOffset+bytesPerVoxel
                )
                sliceData.replaceSubrange(
                    sliceOffset..<sliceOffset+bytesPerVoxel,
                    with: voxelData
                )
            }
        }

        return sliceData
    }

    // MARK: - Image Conversion

    /// Convert slice data to CGImage for display
    func createImage(from slice: SliceData) -> CGImage? {
        // Apply windowing to convert to 8-bit display values
        let displayData = applyWindowing(slice)

        // Create grayscale color space
        let colorSpace = CGColorSpaceCreateDeviceGray()

        // Create data provider
        guard let provider = CGDataProvider(data: displayData as CFData) else {
            return nil
        }

        // Create CGImage
        return CGImage(
            width: slice.width,
            height: slice.height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: slice.width,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// Apply window/level transformation to convert to 8-bit display
    private func applyWindowing(_ slice: SliceData) -> Data {
        var displayData = Data(count: slice.width * slice.height)

        let windowMin = slice.windowCenter - slice.windowWidth / 2
        let windowMax = slice.windowCenter + slice.windowWidth / 2

        for i in 0..<(slice.width * slice.height) {
            let value: Float

            switch slice.dataType {
            case .uint8:
                value = Float(slice.data[i])

            case .int16:
                let offset = i * 2
                guard offset + 1 < slice.data.count else { continue }
                let rawValue = slice.data.withUnsafeBytes { bytes in
                    bytes.load(fromByteOffset: offset, as: Int16.self)
                }
                value = Float(rawValue)
            }

            // Apply windowing
            let normalized: Float
            if value <= windowMin {
                normalized = 0.0
            } else if value >= windowMax {
                normalized = 255.0
            } else {
                normalized = ((value - windowMin) / slice.windowWidth) * 255.0
            }

            displayData[i] = UInt8(max(0, min(255, normalized)))
        }

        return displayData
    }
}

// MARK: - Data Structures

/// Anatomical planes for slice extraction
enum AnatomicalPlane: String, CaseIterable {
    case axial = "Axial"          // Transverse (XY)
    case coronal = "Coronal"      // Frontal (XZ)
    case sagittal = "Sagittal"    // Lateral (YZ)

    var icon: String {
        switch self {
        case .axial: return "circle.circle"
        case .coronal: return "square.split.2x1"
        case .sagittal: return "square.split.1x2"
        }
    }
}

/// Represents a 2D slice extracted from volume
struct SliceData {
    let data: Data
    let width: Int
    let height: Int
    let plane: AnatomicalPlane
    let index: Int
    let dataType: VoxelDataType
    let windowCenter: Float
    let windowWidth: Float

    var pixelCount: Int {
        width * height
    }
}

/// Extension to get slice counts for each plane
extension VolumeData {
    func sliceCount(for plane: AnatomicalPlane) -> Int {
        switch plane {
        case .axial:
            return dimensions.z
        case .coronal:
            return dimensions.y
        case .sagittal:
            return dimensions.x
        }
    }
}

// MARK: - Errors

enum SliceExtractionError: Error, LocalizedError {
    case indexOutOfBounds(index: Int, max: Int)
    case dataCorrupted

    var errorDescription: String? {
        switch self {
        case .indexOutOfBounds(let index, let max):
            return "Slice index \(index) out of bounds (max: \(max))"
        case .dataCorrupted:
            return "Volume data is corrupted or incomplete"
        }
    }
}
