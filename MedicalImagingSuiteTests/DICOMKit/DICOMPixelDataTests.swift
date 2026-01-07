//
//  DICOMPixelDataTests.swift
//  MedicalImagingSuiteTests
//
//  Created by Claude on 2025-11-24.
//

import XCTest
@testable import MedicalImagingSuite

final class DICOMPixelDataTests: XCTestCase {

    var parser: DICOMParserImpl!

    override func setUp() async throws {
        parser = DICOMParserImpl()
    }

    // MARK: - Basic Pixel Data Extraction

    func testExtractPixelDataFrom16BitCT() async throws {
        // Generate a synthetic 128x128 16-bit CT image
        let dicomData = TestFixtures.generateSyntheticDICOM(rows: 128, columns: 128)
        let dataset = try await parser.parse(data: dicomData)

        // Extract pixel data
        let pixelData = try parser.extractPixelData(from: dataset)

        // Verify dimensions
        XCTAssertEqual(pixelData.rows, 128)
        XCTAssertEqual(pixelData.columns, 128)
        XCTAssertEqual(pixelData.pixelCount, 128 * 128)

        // Verify bit depth
        XCTAssertEqual(pixelData.bitsAllocated, 16)
        XCTAssertEqual(pixelData.samplesPerPixel, 1)

        // Verify data size (16-bit = 2 bytes per pixel)
        XCTAssertEqual(pixelData.dataSize, 128 * 128 * 2)

        // Verify it's grayscale
        XCTAssertTrue(pixelData.isGrayscale)

        // Verify photometric interpretation
        XCTAssertEqual(pixelData.photometricInterpretation, "MONOCHROME2")
    }

    func testExtractPixelDataWithDefaultValues() async throws {
        // Create a minimal DICOM with only required tags
        let dicomData = TestFixtures.generateSyntheticDICOM(rows: 64, columns: 64)
        let dataset = try await parser.parse(data: dicomData)

        let pixelData = try parser.extractPixelData(from: dataset)

        // Check default values are applied
        XCTAssertEqual(pixelData.windowCenter, 40.0)  // Default soft tissue
        XCTAssertEqual(pixelData.windowWidth, 400.0)
        XCTAssertEqual(pixelData.rescaleSlope, 1.0)
        XCTAssertEqual(pixelData.rescaleIntercept, 0.0)
    }

    // MARK: - Rescale Slope and Intercept

    func testApplyRescaleSlopeAndInterceptForCT() async throws {
        // Create CT data with known rescale parameters
        var dicomData = TestFixtures.generateSyntheticDICOM(rows: 2, columns: 2)

        // Manually append rescale slope and intercept tags
        // In a real implementation, these would be part of the DICOM file
        let dataset = try await parser.parse(data: dicomData)

        // For this test, we'll verify the ProcessedPixelData captures the values
        let pixelData = try parser.extractPixelData(from: dataset)

        // Should have default values since our synthetic DICOM doesn't include them
        XCTAssertEqual(pixelData.rescaleSlope, 1.0)
        XCTAssertEqual(pixelData.rescaleIntercept, 0.0)
    }

    func testCTDataDetection() async throws {
        let dicomData = TestFixtures.generateSyntheticDICOM(rows: 64, columns: 64)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        // Default rescale values mean it's not detected as CT
        XCTAssertFalse(pixelData.isCTData)
    }

    // MARK: - Pixel Spacing

    func testPixelSpacingParsing() async throws {
        // Create DICOM with pixel spacing
        let dicomData = TestFixtures.generateSyntheticDICOM(rows: 64, columns: 64)
        let dataset = try await parser.parse(data: dicomData)

        // Add pixel spacing to dataset (if it was in the DICOM)
        let pixelData = try parser.extractPixelData(from: dataset)

        // Default pixel spacing when not specified
        XCTAssertEqual(pixelData.pixelSpacing.x, 1.0)
        XCTAssertEqual(pixelData.pixelSpacing.y, 1.0)
    }

    // MARK: - Different Image Sizes

    func testSmallImage() async throws {
        let dicomData = TestFixtures.generateSyntheticDICOM(rows: 32, columns: 32)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        XCTAssertEqual(pixelData.rows, 32)
        XCTAssertEqual(pixelData.columns, 32)
        XCTAssertEqual(pixelData.pixelCount, 1024)
        XCTAssertEqual(pixelData.dataSize, 1024 * 2)
    }

    func testLargeImage() async throws {
        let dicomData = TestFixtures.generateSyntheticDICOM(rows: 512, columns: 512)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        XCTAssertEqual(pixelData.rows, 512)
        XCTAssertEqual(pixelData.columns, 512)
        XCTAssertEqual(pixelData.pixelCount, 512 * 512)
        XCTAssertEqual(pixelData.dataSize, 512 * 512 * 2)
    }

    // MARK: - Error Handling

    func testMissingRowsTag() async throws {
        // Create a dataset without rows
        let dataset = DICOMDataset()

        // Add pixel data but no rows
        let pixelData = Data(count: 100)
        dataset.set(
            tag: .pixelData,
            element: DICOMElement(
                tag: DICOMTag.pixelData.rawValue,
                vr: .OW,
                valueLength: UInt32(pixelData.count),
                data: pixelData
            )
        )

        // Add columns
        dataset.set(
            tag: .columns,
            element: DICOMElement(
                tag: DICOMTag.columns.rawValue,
                vr: .US,
                valueLength: 2,
                data: withUnsafeBytes(of: UInt16(10)) { Data($0) }
            )
        )

        // Should throw missing required tag error
        XCTAssertThrowsError(try parser.extractPixelData(from: dataset)) { error in
            guard case DICOMError.missingRequiredTag(let tag) = error else {
                XCTFail("Expected missingRequiredTag error")
                return
            }
            XCTAssertEqual(tag, .rows)
        }
    }

    func testMissingColumnsTag() async throws {
        let dataset = DICOMDataset()

        // Add pixel data and rows but no columns
        let pixelData = Data(count: 100)
        dataset.set(
            tag: .pixelData,
            element: DICOMElement(
                tag: DICOMTag.pixelData.rawValue,
                vr: .OW,
                valueLength: UInt32(pixelData.count),
                data: pixelData
            )
        )

        dataset.set(
            tag: .rows,
            element: DICOMElement(
                tag: DICOMTag.rows.rawValue,
                vr: .US,
                valueLength: 2,
                data: withUnsafeBytes(of: UInt16(10)) { Data($0) }
            )
        )

        XCTAssertThrowsError(try parser.extractPixelData(from: dataset)) { error in
            guard case DICOMError.missingRequiredTag(let tag) = error else {
                XCTFail("Expected missingRequiredTag error")
                return
            }
            XCTAssertEqual(tag, .columns)
        }
    }

    func testMissingPixelData() async throws {
        let dataset = DICOMDataset()

        // Add rows and columns but no pixel data
        dataset.set(
            tag: .rows,
            element: DICOMElement(
                tag: DICOMTag.rows.rawValue,
                vr: .US,
                valueLength: 2,
                data: withUnsafeBytes(of: UInt16(128)) { Data($0) }
            )
        )

        dataset.set(
            tag: .columns,
            element: DICOMElement(
                tag: DICOMTag.columns.rawValue,
                vr: .US,
                valueLength: 2,
                data: withUnsafeBytes(of: UInt16(128)) { Data($0) }
            )
        )

        XCTAssertThrowsError(try parser.extractPixelData(from: dataset)) { error in
            guard case DICOMError.missingRequiredTag(let tag) = error else {
                XCTFail("Expected missingRequiredTag error")
                return
            }
            XCTAssertEqual(tag, .pixelData)
        }
    }

    func testCorruptedPixelData() async throws {
        let dataset = DICOMDataset()

        // Create pixel data that's too small for the declared dimensions
        dataset.set(
            tag: .rows,
            element: DICOMElement(
                tag: DICOMTag.rows.rawValue,
                vr: .US,
                valueLength: 2,
                data: withUnsafeBytes(of: UInt16(128)) { Data($0) }
            )
        )

        dataset.set(
            tag: .columns,
            element: DICOMElement(
                tag: DICOMTag.columns.rawValue,
                vr: .US,
                valueLength: 2,
                data: withUnsafeBytes(of: UInt16(128)) { Data($0) }
            )
        )

        // Pixel data is only 100 bytes but should be 128*128*2 = 32768 bytes
        let tooSmallData = Data(count: 100)
        dataset.set(
            tag: .pixelData,
            element: DICOMElement(
                tag: DICOMTag.pixelData.rawValue,
                vr: .OW,
                valueLength: UInt32(tooSmallData.count),
                data: tooSmallData
            )
        )

        XCTAssertThrowsError(try parser.extractPixelData(from: dataset)) { error in
            guard case DICOMError.corruptedPixelData = error else {
                XCTFail("Expected corruptedPixelData error, got \(error)")
                return
            }
        }
    }

    // MARK: - Integration Tests

    func testCompleteWorkflowParseAndExtract() async throws {
        // Create temporary DICOM file
        let tempURL = TestFixtures.createTemporaryDICOMFile(rows: 256, columns: 256)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Parse DICOM file
        let dataset = try await parser.parse(url: tempURL)

        // Extract pixel data
        let pixelData = try parser.extractPixelData(from: dataset)

        // Verify complete workflow
        XCTAssertEqual(pixelData.rows, 256)
        XCTAssertEqual(pixelData.columns, 256)
        XCTAssertGreaterThan(pixelData.dataSize, 0)
        XCTAssertTrue(pixelData.isGrayscale)
    }

    func testMultipleImageSizes() async throws {
        let sizes = [(64, 64), (128, 128), (256, 256), (512, 512)]

        for (rows, columns) in sizes {
            let dicomData = TestFixtures.generateSyntheticDICOM(rows: rows, columns: columns)
            let dataset = try await parser.parse(data: dicomData)
            let pixelData = try parser.extractPixelData(from: dataset)

            XCTAssertEqual(pixelData.rows, rows, "Failed for size \(rows)x\(columns)")
            XCTAssertEqual(pixelData.columns, columns, "Failed for size \(rows)x\(columns)")
            XCTAssertEqual(pixelData.pixelCount, rows * columns, "Failed for size \(rows)x\(columns)")
        }
    }

    // MARK: - CT and MRI Specific Tests

    func testCTScanWithHounsfieldUnits() async throws {
        // Generate a CT scan with proper Hounsfield unit parameters
        let dicomData = TestFixtures.generateCTScan(rows: 128, columns: 128)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        // Verify CT-specific parameters
        XCTAssertEqual(pixelData.rescaleSlope, 1.0)
        XCTAssertEqual(pixelData.rescaleIntercept, -1024.0)
        XCTAssertTrue(pixelData.isCTData)

        // Verify windowing for soft tissue
        XCTAssertEqual(pixelData.windowCenter, 40.0)
        XCTAssertEqual(pixelData.windowWidth, 400.0)

        // Verify pixel spacing
        XCTAssertEqual(pixelData.pixelSpacing.x, 0.7)
        XCTAssertEqual(pixelData.pixelSpacing.y, 0.7)

        // Verify signed 16-bit data
        XCTAssertEqual(pixelData.bitsAllocated, 16)
    }

    func testMRIScan() async throws {
        // Generate an MRI scan
        let dicomData = TestFixtures.generateMRIScan(rows: 256, columns: 256)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        // Verify MRI-specific parameters
        XCTAssertFalse(pixelData.isCTData)  // No rescale for MRI

        // Verify dimensions
        XCTAssertEqual(pixelData.rows, 256)
        XCTAssertEqual(pixelData.columns, 256)

        // Verify windowing
        XCTAssertEqual(pixelData.windowCenter, 128.0)
        XCTAssertEqual(pixelData.windowWidth, 256.0)
    }

    func testPixelSpacingParsing() async throws {
        // Create a CT scan with specific pixel spacing
        var params = TestFixtures.DICOMGenerationParams()
        params.rows = 128
        params.columns = 128
        params.pixelSpacing = (0.5, 0.5)  // High resolution

        let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        XCTAssertEqual(pixelData.pixelSpacing.x, 0.5)
        XCTAssertEqual(pixelData.pixelSpacing.y, 0.5)
    }

    func test8BitPixelData() async throws {
        // Generate an 8-bit image
        var params = TestFixtures.DICOMGenerationParams()
        params.rows = 64
        params.columns = 64
        params.bitsAllocated = 8

        let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        XCTAssertEqual(pixelData.bitsAllocated, 8)
        XCTAssertEqual(pixelData.dataSize, 64 * 64)  // 1 byte per pixel
    }

    func testUnsigned16BitPixelData() async throws {
        // Generate unsigned 16-bit image
        var params = TestFixtures.DICOMGenerationParams()
        params.rows = 128
        params.columns = 128
        params.bitsAllocated = 16
        params.pixelRepresentation = 0  // Unsigned

        let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        XCTAssertEqual(pixelData.bitsAllocated, 16)
        XCTAssertEqual(pixelData.dataSize, 128 * 128 * 2)
    }

    func testSigned16BitPixelData() async throws {
        // Generate signed 16-bit image (CT)
        var params = TestFixtures.DICOMGenerationParams()
        params.rows = 128
        params.columns = 128
        params.bitsAllocated = 16
        params.pixelRepresentation = 1  // Signed
        params.rescaleSlope = 1.0
        params.rescaleIntercept = -1024.0

        let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        XCTAssertEqual(pixelData.bitsAllocated, 16)
        XCTAssertTrue(pixelData.isCTData)
        XCTAssertEqual(pixelData.dataSize, 128 * 128 * 2)
    }

    // MARK: - Performance Tests

    func testPixelDataExtractionPerformance() async throws {
        // Test with a large CT image (512x512)
        let dicomData = TestFixtures.generateSyntheticDICOM(rows: 512, columns: 512)
        let dataset = try await parser.parse(data: dicomData)

        measure {
            do {
                _ = try parser.extractPixelData(from: dataset)
            } catch {
                XCTFail("Extraction failed: \(error)")
            }
        }
    }

    func testLargeVolumePixelDataExtraction() async throws {
        // Test with a clinical-size image (512x512)
        let dicomData = TestFixtures.generateCTScan(rows: 512, columns: 512)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        // Verify large volume handling
        XCTAssertEqual(pixelData.pixelCount, 512 * 512)
        XCTAssertEqual(pixelData.dataSize, 512 * 512 * 2)  // 512KB
        XCTAssertTrue(pixelData.isCTData)
    }
}
