//
//  VolumeReconstructorTests.swift
//  MedicalImagingSuiteTests
//
//  Created by Claude on 2025-11-24.
//

import XCTest
@testable import MedicalImagingSuite

final class VolumeReconstructorTests: XCTestCase {

    var reconstructor: VolumeReconstructor!

    override func setUp() async throws {
        reconstructor = VolumeReconstructor()
    }

    // MARK: - Basic Reconstruction Tests

    func testReconstructVolumeFromMultipleSlices() async throws {
        // Create 10 slices with consistent parameters
        let sliceCount = 10
        var images: [(instance: ImageInstance, pixelData: ProcessedPixelData)] = []

        for i in 0..<sliceCount {
            let zPosition = Float(i) * 1.0  // 1mm spacing
            let instance = ImageInstance(
                sopInstanceUID: "1.2.3.4.5.\(i)",
                instanceNumber: i,
                dimensions: SIMD2(128, 128),
                pixelSpacing: SIMD2<Float>(0.7, 0.7),
                sliceLocation: zPosition
            )

            let pixelData = ProcessedPixelData(
                rows: 128,
                columns: 128,
                bitsAllocated: 16,
                samplesPerPixel: 1,
                pixelSpacing: SIMD2<Float>(0.7, 0.7),
                photometricInterpretation: "MONOCHROME2",
                windowCenter: 40,
                windowWidth: 400,
                rescaleSlope: 1.0,
                rescaleIntercept: -1024.0,
                pixelData: Data(count: 128 * 128 * 2)
            )

            images.append((instance, pixelData))
        }

        // Reconstruct volume
        let volume = try await reconstructor.reconstructVolume(
            from: images,
            seriesUID: "1.2.3.4.5"
        )

        // Verify volume properties
        XCTAssertEqual(volume.dimensions.x, 128)
        XCTAssertEqual(volume.dimensions.y, 128)
        XCTAssertEqual(volume.dimensions.z, 10)
        XCTAssertEqual(volume.spacing.x, 0.7)
        XCTAssertEqual(volume.spacing.y, 0.7)
        XCTAssertEqual(volume.spacing.z, 1.0)
        XCTAssertEqual(volume.dataType, .int16)
        XCTAssertEqual(volume.voxelData.count, 128 * 128 * 10 * 2)
    }

    func testReconstructVolumeWithUnsortedSlices() async throws {
        // Create slices in random order
        var images: [(instance: ImageInstance, pixelData: ProcessedPixelData)] = []

        let zPositions: [Float] = [5.0, 2.0, 8.0, 1.0, 4.0, 7.0, 3.0, 6.0, 0.0, 9.0]

        for (i, z) in zPositions.enumerated() {
            let instance = ImageInstance(
                sopInstanceUID: "1.2.3.4.5.\(i)",
                instanceNumber: i,
                dimensions: SIMD2(64, 64),
                pixelSpacing: SIMD2<Float>(1.0, 1.0),
                sliceLocation: z
            )

            let pixelData = ProcessedPixelData(
                rows: 64,
                columns: 64,
                bitsAllocated: 16,
                samplesPerPixel: 1,
                pixelSpacing: SIMD2<Float>(1.0, 1.0),
                photometricInterpretation: "MONOCHROME2",
                windowCenter: 40,
                windowWidth: 400,
                rescaleSlope: 1.0,
                rescaleIntercept: 0.0,
                pixelData: Data(count: 64 * 64 * 2)
            )

            images.append((instance, pixelData))
        }

        // Should successfully reconstruct and sort automatically
        let volume = try await reconstructor.reconstructVolume(
            from: images,
            seriesUID: "1.2.3.4.5"
        )

        XCTAssertEqual(volume.dimensions.z, 10)
        XCTAssertEqual(volume.spacing.z, 1.0)
    }

    func testSingleSliceVolume() async throws {
        let instance = ImageInstance(
            sopInstanceUID: "1.2.3.4.5.0",
            instanceNumber: 0,
            dimensions: SIMD2(256, 256),
            pixelSpacing: SIMD2<Float>(0.5, 0.5),
            sliceLocation: 0.0
        )

        let pixelData = ProcessedPixelData(
            rows: 256,
            columns: 256,
            bitsAllocated: 16,
            samplesPerPixel: 1,
            pixelSpacing: SIMD2<Float>(0.5, 0.5),
            photometricInterpretation: "MONOCHROME2",
            windowCenter: 40,
            windowWidth: 400,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0,
            pixelData: Data(count: 256 * 256 * 2)
        )

        let volume = await reconstructor.createSingleSliceVolume(
            from: instance,
            pixelData: pixelData,
            seriesUID: "1.2.3.4.5"
        )

        XCTAssertEqual(volume.dimensions.x, 256)
        XCTAssertEqual(volume.dimensions.y, 256)
        XCTAssertEqual(volume.dimensions.z, 1)
        XCTAssertEqual(volume.spacing.x, 0.5)
        XCTAssertEqual(volume.spacing.y, 0.5)
    }

    // MARK: - Validation Error Tests

    func testEmptyImageSetError() async throws {
        let images: [(instance: ImageInstance, pixelData: ProcessedPixelData)] = []

        await XCTAssertThrowsError(
            try await reconstructor.reconstructVolume(from: images, seriesUID: "1.2.3")
        ) { error in
            guard case VolumeReconstructionError.emptyImageSet = error else {
                XCTFail("Expected emptyImageSet error")
                return
            }
        }
    }

    func testMissingPositionInfoError() async throws {
        // Create image without position information
        let instance = ImageInstance(
            sopInstanceUID: "1.2.3.4.5.0",
            instanceNumber: 0,
            dimensions: SIMD2(128, 128),
            pixelSpacing: SIMD2<Float>(1.0, 1.0)
            // No sliceLocation or imagePosition
        )

        let pixelData = ProcessedPixelData(
            rows: 128,
            columns: 128,
            bitsAllocated: 16,
            samplesPerPixel: 1,
            pixelSpacing: SIMD2<Float>(1.0, 1.0),
            photometricInterpretation: "MONOCHROME2",
            windowCenter: 40,
            windowWidth: 400,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0,
            pixelData: Data(count: 128 * 128 * 2)
        )

        let images = [(instance, pixelData)]

        await XCTAssertThrowsError(
            try await reconstructor.reconstructVolume(from: images, seriesUID: "1.2.3")
        ) { error in
            guard case VolumeReconstructionError.missingPositionInfo = error else {
                XCTFail("Expected missingPositionInfo error")
                return
            }
        }
    }

    func testInconsistentDimensionsError() async throws {
        // Create slices with different dimensions
        var images: [(instance: ImageInstance, pixelData: ProcessedPixelData)] = []

        // First slice: 128x128
        let instance1 = ImageInstance(
            sopInstanceUID: "1.2.3.4.5.0",
            instanceNumber: 0,
            dimensions: SIMD2(128, 128),
            pixelSpacing: SIMD2<Float>(1.0, 1.0),
            sliceLocation: 0.0
        )
        let pixelData1 = ProcessedPixelData(
            rows: 128,
            columns: 128,
            bitsAllocated: 16,
            samplesPerPixel: 1,
            pixelSpacing: SIMD2<Float>(1.0, 1.0),
            photometricInterpretation: "MONOCHROME2",
            windowCenter: 40,
            windowWidth: 400,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0,
            pixelData: Data(count: 128 * 128 * 2)
        )
        images.append((instance1, pixelData1))

        // Second slice: 256x256 (different!)
        let instance2 = ImageInstance(
            sopInstanceUID: "1.2.3.4.5.1",
            instanceNumber: 1,
            dimensions: SIMD2(256, 256),
            pixelSpacing: SIMD2<Float>(1.0, 1.0),
            sliceLocation: 1.0
        )
        let pixelData2 = ProcessedPixelData(
            rows: 256,
            columns: 256,
            bitsAllocated: 16,
            samplesPerPixel: 1,
            pixelSpacing: SIMD2<Float>(1.0, 1.0),
            photometricInterpretation: "MONOCHROME2",
            windowCenter: 40,
            windowWidth: 400,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0,
            pixelData: Data(count: 256 * 256 * 2)
        )
        images.append((instance2, pixelData2))

        await XCTAssertThrowsError(
            try await reconstructor.reconstructVolume(from: images, seriesUID: "1.2.3")
        ) { error in
            guard case VolumeReconstructionError.inconsistentDimensions = error else {
                XCTFail("Expected inconsistentDimensions error, got \(error)")
                return
            }
        }
    }

    func testInconsistentBitDepthError() async throws {
        // Create slices with different bit depths
        var images: [(instance: ImageInstance, pixelData: ProcessedPixelData)] = []

        // First slice: 16-bit
        let instance1 = ImageInstance(
            sopInstanceUID: "1.2.3.4.5.0",
            instanceNumber: 0,
            dimensions: SIMD2(128, 128),
            pixelSpacing: SIMD2<Float>(1.0, 1.0),
            sliceLocation: 0.0
        )
        let pixelData1 = ProcessedPixelData(
            rows: 128,
            columns: 128,
            bitsAllocated: 16,
            samplesPerPixel: 1,
            pixelSpacing: SIMD2<Float>(1.0, 1.0),
            photometricInterpretation: "MONOCHROME2",
            windowCenter: 40,
            windowWidth: 400,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0,
            pixelData: Data(count: 128 * 128 * 2)
        )
        images.append((instance1, pixelData1))

        // Second slice: 8-bit (different!)
        let instance2 = ImageInstance(
            sopInstanceUID: "1.2.3.4.5.1",
            instanceNumber: 1,
            dimensions: SIMD2(128, 128),
            pixelSpacing: SIMD2<Float>(1.0, 1.0),
            sliceLocation: 1.0
        )
        let pixelData2 = ProcessedPixelData(
            rows: 128,
            columns: 128,
            bitsAllocated: 8,
            samplesPerPixel: 1,
            pixelSpacing: SIMD2<Float>(1.0, 1.0),
            photometricInterpretation: "MONOCHROME2",
            windowCenter: 128,
            windowWidth: 256,
            rescaleSlope: 1.0,
            rescaleIntercept: 0.0,
            pixelData: Data(count: 128 * 128)
        )
        images.append((instance2, pixelData2))

        await XCTAssertThrowsError(
            try await reconstructor.reconstructVolume(from: images, seriesUID: "1.2.3")
        ) { error in
            guard case VolumeReconstructionError.inconsistentBitDepth = error else {
                XCTFail("Expected inconsistentBitDepth error")
                return
            }
        }
    }

    // MARK: - Spacing Tests

    func testVariableSpacingDetection() async throws {
        // Create slices with slightly variable spacing
        var images: [(instance: ImageInstance, pixelData: ProcessedPixelData)] = []

        let zPositions: [Float] = [0.0, 1.0, 2.0, 3.1, 4.0]  // Note: 3.1 instead of 3.0

        for (i, z) in zPositions.enumerated() {
            let instance = ImageInstance(
                sopInstanceUID: "1.2.3.4.5.\(i)",
                instanceNumber: i,
                dimensions: SIMD2(64, 64),
                pixelSpacing: SIMD2<Float>(1.0, 1.0),
                sliceLocation: z
            )

            let pixelData = ProcessedPixelData(
                rows: 64,
                columns: 64,
                bitsAllocated: 16,
                samplesPerPixel: 1,
                pixelSpacing: SIMD2<Float>(1.0, 1.0),
                photometricInterpretation: "MONOCHROME2",
                windowCenter: 40,
                windowWidth: 400,
                rescaleSlope: 1.0,
                rescaleIntercept: 0.0,
                pixelData: Data(count: 64 * 64 * 2)
            )

            images.append((instance, pixelData))
        }

        // Should succeed but log warning
        let volume = try await reconstructor.reconstructVolume(
            from: images,
            seriesUID: "1.2.3.4.5"
        )

        XCTAssertEqual(volume.dimensions.z, 5)
        XCTAssertEqual(volume.spacing.z, 1.0)  // Based on first two slices
    }

    // MARK: - Integration Tests

    func testCompleteVolumeReconstructionWorkflow() async throws {
        // Create a realistic CT series with 50 slices
        let sliceCount = 50
        var images: [(instance: ImageInstance, pixelData: ProcessedPixelData)] = []

        for i in 0..<sliceCount {
            let zPosition = Float(i) * 0.625  // 0.625mm spacing (typical CT)

            let instance = ImageInstance(
                sopInstanceUID: "1.2.840.113619.2.55.3.\(i)",
                instanceNumber: i,
                dimensions: SIMD2(512, 512),
                pixelSpacing: SIMD2<Float>(0.7, 0.7),
                imagePosition: SIMD3<Float>(100.0, -50.0, zPosition),
                sliceLocation: zPosition
            )

            let pixelData = ProcessedPixelData(
                rows: 512,
                columns: 512,
                bitsAllocated: 16,
                samplesPerPixel: 1,
                pixelSpacing: SIMD2<Float>(0.7, 0.7),
                photometricInterpretation: "MONOCHROME2",
                windowCenter: 40,
                windowWidth: 400,
                rescaleSlope: 1.0,
                rescaleIntercept: -1024.0,
                pixelData: Data(count: 512 * 512 * 2)
            )

            images.append((instance, pixelData))
        }

        // Reconstruct volume
        let volume = try await reconstructor.reconstructVolume(
            from: images,
            seriesUID: "1.2.840.113619.2.55.3"
        )

        // Verify clinical-size volume
        XCTAssertEqual(volume.dimensions.x, 512)
        XCTAssertEqual(volume.dimensions.y, 512)
        XCTAssertEqual(volume.dimensions.z, 50)
        XCTAssertEqual(volume.spacing.x, 0.7)
        XCTAssertEqual(volume.spacing.y, 0.7)
        XCTAssertEqual(volume.spacing.z, 0.625, accuracy: 0.001)

        // Verify volume size (512 * 512 * 50 * 2 bytes = ~25MB)
        let expectedSize = 512 * 512 * 50 * 2
        XCTAssertEqual(volume.voxelData.count, expectedSize)

        // Verify CT-specific parameters
        XCTAssertTrue(volume.rescaleSlope == 1.0)
        XCTAssertTrue(volume.rescaleIntercept == -1024.0)
    }

    // MARK: - Performance Tests

    func testVolumeReconstructionPerformance() async throws {
        // Test with moderately sized volume (128x128x100)
        var images: [(instance: ImageInstance, pixelData: ProcessedPixelData)] = []

        for i in 0..<100 {
            let instance = ImageInstance(
                sopInstanceUID: "1.2.3.4.5.\(i)",
                instanceNumber: i,
                dimensions: SIMD2(128, 128),
                pixelSpacing: SIMD2<Float>(1.0, 1.0),
                sliceLocation: Float(i)
            )

            let pixelData = ProcessedPixelData(
                rows: 128,
                columns: 128,
                bitsAllocated: 16,
                samplesPerPixel: 1,
                pixelSpacing: SIMD2<Float>(1.0, 1.0),
                photometricInterpretation: "MONOCHROME2",
                windowCenter: 40,
                windowWidth: 400,
                rescaleSlope: 1.0,
                rescaleIntercept: 0.0,
                pixelData: Data(count: 128 * 128 * 2)
            )

            images.append((instance, pixelData))
        }

        measure {
            Task {
                _ = try await reconstructor.reconstructVolume(
                    from: images,
                    seriesUID: "1.2.3.4.5"
                )
            }
        }
    }
}

// Helper for async throwing assertions
func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown")
    } catch {
        errorHandler(error)
    }
}
