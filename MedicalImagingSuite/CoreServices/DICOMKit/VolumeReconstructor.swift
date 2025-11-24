//
//  VolumeReconstructor.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// Reconstructs 3D volumes from series of 2D DICOM images
actor VolumeReconstructor {

    // MARK: - Volume Reconstruction

    /// Reconstruct a 3D volume from a series of DICOM images
    /// - Parameters:
    ///   - images: Array of image instances with pixel data
    ///   - seriesUID: Series instance UID for the volume
    /// - Returns: Reconstructed VolumeData or nil if reconstruction fails
    /// - Throws: VolumeReconstructionError if validation fails
    func reconstructVolume(
        from images: [(instance: ImageInstance, pixelData: ProcessedPixelData)],
        seriesUID: String
    ) throws -> VolumeData {
        // Validate input
        guard !images.isEmpty else {
            throw VolumeReconstructionError.emptyImageSet
        }

        // Sort images by z-position
        let sortedImages = try sortImagesByPosition(images)

        // Validate image consistency
        try validateImageConsistency(sortedImages)

        // Extract volume parameters
        let firstImage = sortedImages[0].instance
        let firstPixelData = sortedImages[0].pixelData

        let width = firstImage.columns
        let height = firstImage.rows
        let depth = sortedImages.count

        // Calculate z-spacing
        let zSpacing = try calculateZSpacing(sortedImages)

        // Use pixel spacing from first image
        let pixelSpacing = firstPixelData.pixelSpacing
        let spacing = SIMD3<Float>(pixelSpacing.x, pixelSpacing.y, zSpacing)

        // Determine data type
        let dataType: VoxelDataType = firstPixelData.bitsAllocated == 8 ? .uint8 : .int16

        // Combine pixel data into volume
        let voxelData = try combinePixelData(sortedImages, width: width, height: height, depth: depth)

        // Use windowing from first image
        let windowCenter = firstPixelData.windowCenter
        let windowWidth = firstPixelData.windowWidth
        let rescaleSlope = firstPixelData.rescaleSlope
        let rescaleIntercept = firstPixelData.rescaleIntercept

        return VolumeData(
            seriesInstanceUID: seriesUID,
            dimensions: SIMD3<Int>(width, height, depth),
            spacing: spacing,
            dataType: dataType,
            voxelData: voxelData,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            rescaleSlope: rescaleSlope,
            rescaleIntercept: rescaleIntercept
        )
    }

    // MARK: - Image Sorting

    /// Sort images by z-position (ascending)
    private func sortImagesByPosition(
        _ images: [(instance: ImageInstance, pixelData: ProcessedPixelData)]
    ) throws -> [(instance: ImageInstance, pixelData: ProcessedPixelData)] {
        // Check if all images have position information
        let allHavePosition = images.allSatisfy { $0.instance.hasPositionInfo }

        guard allHavePosition else {
            throw VolumeReconstructionError.missingPositionInfo
        }

        // Sort by z-position
        return images.sorted { (img1, img2) -> Bool in
            let z1 = img1.instance.zPosition ?? 0
            let z2 = img2.instance.zPosition ?? 0
            return z1 < z2
        }
    }

    // MARK: - Validation

    /// Validate that all images have consistent dimensions and parameters
    private func validateImageConsistency(
        _ images: [(instance: ImageInstance, pixelData: ProcessedPixelData)]
    ) throws {
        guard let first = images.first else {
            throw VolumeReconstructionError.emptyImageSet
        }

        let referenceWidth = first.instance.columns
        let referenceHeight = first.instance.rows
        let referenceBitsAllocated = first.pixelData.bitsAllocated

        // Check all images have same dimensions
        for (index, image) in images.enumerated() {
            if image.instance.columns != referenceWidth || image.instance.rows != referenceHeight {
                throw VolumeReconstructionError.inconsistentDimensions(
                    index: index,
                    expected: SIMD2(referenceWidth, referenceHeight),
                    actual: SIMD2(image.instance.columns, image.instance.rows)
                )
            }

            if image.pixelData.bitsAllocated != referenceBitsAllocated {
                throw VolumeReconstructionError.inconsistentBitDepth(
                    index: index,
                    expected: referenceBitsAllocated,
                    actual: image.pixelData.bitsAllocated
                )
            }
        }

        // Validate minimum number of slices for 3D volume
        if images.count < 2 {
            throw VolumeReconstructionError.insufficientSlices(count: images.count)
        }
    }

    /// Calculate z-spacing between slices
    private func calculateZSpacing(
        _ images: [(instance: ImageInstance, pixelData: ProcessedPixelData)]
    ) throws -> Float {
        guard images.count >= 2 else {
            // For single slice, use pixel spacing as estimate
            return images[0].pixelData.pixelSpacing.x
        }

        // Calculate spacing from first two slices
        guard let z1 = images[0].instance.zPosition,
              let z2 = images[1].instance.zPosition else {
            throw VolumeReconstructionError.missingPositionInfo
        }

        let spacing = abs(z2 - z1)

        // Validate spacing is reasonable (between 0.1mm and 10mm)
        guard spacing > 0.1 && spacing < 10.0 else {
            throw VolumeReconstructionError.invalidSpacing(spacing: spacing)
        }

        // Check consistency across all slices
        for i in 1..<images.count-1 {
            guard let currentZ = images[i].instance.zPosition,
                  let nextZ = images[i+1].instance.zPosition else {
                continue
            }

            let currentSpacing = abs(nextZ - currentZ)
            let difference = abs(currentSpacing - spacing)

            // Allow 10% tolerance for spacing variations
            if difference > spacing * 0.1 {
                print("⚠️ Warning: Inconsistent z-spacing at slice \(i): \(currentSpacing)mm vs \(spacing)mm")
            }
        }

        return spacing
    }

    // MARK: - Data Combination

    /// Combine 2D pixel data into 3D volume
    private func combinePixelData(
        _ images: [(instance: ImageInstance, pixelData: ProcessedPixelData)],
        width: Int,
        height: Int,
        depth: Int
    ) throws -> Data {
        let bytesPerVoxel = images[0].pixelData.bitsAllocated / 8
        let sliceSize = width * height * bytesPerVoxel
        let totalSize = sliceSize * depth

        var volumeData = Data(count: totalSize)

        // Copy each slice into the volume
        for (index, image) in images.enumerated() {
            let pixelData = image.pixelData.pixelData

            // Validate slice data size
            guard pixelData.count >= sliceSize else {
                throw VolumeReconstructionError.corruptedSliceData(
                    index: index,
                    expected: sliceSize,
                    actual: pixelData.count
                )
            }

            // Copy slice data
            let offset = index * sliceSize
            volumeData.replaceSubrange(offset..<offset+sliceSize, with: pixelData.prefix(sliceSize))
        }

        return volumeData
    }

    // MARK: - Single Slice Volume

    /// Create a volume from a single 2D image (for preview or single-slice studies)
    func createSingleSliceVolume(
        from image: ImageInstance,
        pixelData: ProcessedPixelData,
        seriesUID: String
    ) -> VolumeData {
        let width = image.columns
        let height = image.rows
        let depth = 1

        let pixelSpacing = pixelData.pixelSpacing
        let spacing = SIMD3<Float>(pixelSpacing.x, pixelSpacing.y, pixelSpacing.x)

        let dataType: VoxelDataType = pixelData.bitsAllocated == 8 ? .uint8 : .int16

        return VolumeData(
            seriesInstanceUID: seriesUID,
            dimensions: SIMD3<Int>(width, height, depth),
            spacing: spacing,
            dataType: dataType,
            voxelData: pixelData.pixelData,
            windowCenter: pixelData.windowCenter,
            windowWidth: pixelData.windowWidth,
            rescaleSlope: pixelData.rescaleSlope,
            rescaleIntercept: pixelData.rescaleIntercept
        )
    }
}

// MARK: - Errors

enum VolumeReconstructionError: Error, LocalizedError {
    case emptyImageSet
    case missingPositionInfo
    case inconsistentDimensions(index: Int, expected: SIMD2<Int>, actual: SIMD2<Int>)
    case inconsistentBitDepth(index: Int, expected: Int, actual: Int)
    case insufficientSlices(count: Int)
    case invalidSpacing(spacing: Float)
    case corruptedSliceData(index: Int, expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .emptyImageSet:
            return "Cannot reconstruct volume from empty image set"
        case .missingPositionInfo:
            return "Images are missing position information required for 3D reconstruction"
        case .inconsistentDimensions(let index, let expected, let actual):
            return "Image \(index) has inconsistent dimensions: expected \(expected.x)x\(expected.y), got \(actual.x)x\(actual.y)"
        case .inconsistentBitDepth(let index, let expected, let actual):
            return "Image \(index) has inconsistent bit depth: expected \(expected), got \(actual)"
        case .insufficientSlices(let count):
            return "Insufficient slices for 3D volume: \(count) (minimum 2 required)"
        case .invalidSpacing(let spacing):
            return "Invalid z-spacing: \(spacing)mm (must be between 0.1mm and 10mm)"
        case .corruptedSliceData(let index, let expected, let actual):
            return "Slice \(index) has corrupted data: expected \(expected) bytes, got \(actual)"
        }
    }
}
