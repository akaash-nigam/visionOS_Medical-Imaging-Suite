//
//  DICOMImportServiceTests.swift
//  MedicalImagingSuiteTests
//
//  Created by Claude on 2025-11-24.
//

import XCTest
@testable import MedicalImagingSuite

final class DICOMImportServiceTests: XCTestCase {

    var importService: DICOMImportService!
    var tempDirectory: URL!

    override func setUp() async throws {
        importService = DICOMImportService()

        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMImportTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: - Single File Import Tests

    func testImportSingleCTFile() async throws {
        // Create a temporary CT DICOM file
        let dicomData = TestFixtures.generateCTScan(rows: 256, columns: 256)
        let fileURL = tempDirectory.appendingPathComponent("ct_slice.dcm")
        try dicomData.write(to: fileURL)

        // Import the file
        let result = try await importService.importFile(fileURL)

        // Verify patient
        XCTAssertEqual(result.patient.patientID, "TEST001")
        XCTAssertEqual(result.patient.name.familyName, "Test")
        XCTAssertEqual(result.patient.name.givenName, "Patient")

        // Verify study
        XCTAssertEqual(result.study.studyInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(result.study.studyDescription, "Chest CT with Contrast")

        // Verify series
        XCTAssertEqual(result.series.seriesInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(result.series.modality, .ct)

        // Verify images
        XCTAssertEqual(result.images.count, 1)
        XCTAssertEqual(result.images[0].rows, 256)
        XCTAssertEqual(result.images[0].columns, 256)

        // Verify volume (single slice)
        XCTAssertEqual(result.volume.dimensions.x, 256)
        XCTAssertEqual(result.volume.dimensions.y, 256)
        XCTAssertEqual(result.volume.dimensions.z, 1)

        // Verify CT-specific parameters
        XCTAssertEqual(result.volume.rescaleSlope, 1.0)
        XCTAssertEqual(result.volume.rescaleIntercept, -1024.0)

        // Verify summary
        let summary = result.summary
        XCTAssertTrue(summary.contains("Test Patient"))
        XCTAssertTrue(summary.contains("256×256×1"))
    }

    func testImportSingleMRIFile() async throws {
        // Create a temporary MRI DICOM file
        let dicomData = TestFixtures.generateMRIScan(rows: 128, columns: 128)
        let fileURL = tempDirectory.appendingPathComponent("mri_slice.dcm")
        try dicomData.write(to: fileURL)

        // Import the file
        let result = try await importService.importFile(fileURL)

        // Verify MRI-specific parameters
        XCTAssertFalse(result.volume.rescaleSlope != 1.0 || result.volume.rescaleIntercept != 0.0)
        XCTAssertEqual(result.volume.windowCenter, 128.0)
        XCTAssertEqual(result.volume.windowWidth, 256.0)
    }

    // MARK: - Series Import Tests

    func testImportCTSeries() async throws {
        // Create a series of 20 CT slices
        let sliceCount = 20
        var fileURLs: [URL] = []

        for i in 0..<sliceCount {
            var params = TestFixtures.DICOMGenerationParams()
            params.rows = 128
            params.columns = 128
            params.pixelRepresentation = 1
            params.rescaleSlope = 1.0
            params.rescaleIntercept = -1024.0
            params.pixelSpacing = (0.7, 0.7)

            let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
            let fileURL = tempDirectory.appendingPathComponent("ct_\(String(format: "%03d", i)).dcm")
            try dicomData.write(to: fileURL)
            fileURLs.append(fileURL)
        }

        // Import the series
        let result = try await importService.importSeries(fileURLs)

        // Verify all images imported
        XCTAssertEqual(result.images.count, sliceCount)
        XCTAssertEqual(result.series.instanceCount, sliceCount)

        // Verify 3D volume reconstruction
        XCTAssertEqual(result.volume.dimensions.x, 128)
        XCTAssertEqual(result.volume.dimensions.y, 128)
        XCTAssertEqual(result.volume.dimensions.z, sliceCount)

        // Verify volume memory size
        let expectedSize = 128 * 128 * sliceCount * 2  // 2 bytes per pixel
        XCTAssertEqual(result.volume.memorySize, expectedSize)

        // Verify total data size
        XCTAssertEqual(result.totalDataSize, expectedSize)
    }

    func testImportSeriesWithDifferentSizes() async throws {
        // Create series with varied image dimensions (should succeed with reconstruction)
        let sliceCount = 5
        var fileURLs: [URL] = []

        for i in 0..<sliceCount {
            var params = TestFixtures.DICOMGenerationParams()
            params.rows = 128
            params.columns = 128
            params.pixelSpacing = (1.0, 1.0)

            let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
            let fileURL = tempDirectory.appendingPathComponent("slice_\(i).dcm")
            try dicomData.write(to: fileURL)
            fileURLs.append(fileURL)
        }

        // Should successfully import
        let result = try await importService.importSeries(fileURLs)
        XCTAssertEqual(result.images.count, sliceCount)
    }

    func testImportEmptySeries() async throws {
        // Empty file list should throw error
        await XCTAssertThrowsError(
            try await importService.importSeries([])
        ) { error in
            guard case DICOMImportError.emptyFileList = error else {
                XCTFail("Expected emptyFileList error")
                return
            }
        }
    }

    // MARK: - Directory Import Tests

    func testImportDirectory() async throws {
        // Create multiple series in a directory
        // Series 1: CT with 10 slices
        let ct1Directory = tempDirectory.appendingPathComponent("CT_Series_1")
        try FileManager.default.createDirectory(at: ct1Directory, withIntermediateDirectories: true)

        for i in 0..<10 {
            var params = TestFixtures.DICOMGenerationParams()
            params.rows = 128
            params.columns = 128
            params.modality = "CT"

            let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
            let fileURL = ct1Directory.appendingPathComponent("slice_\(i).dcm")
            try dicomData.write(to: fileURL)
        }

        // Series 2: MRI with 15 slices (different modality)
        let mr1Directory = tempDirectory.appendingPathComponent("MR_Series_1")
        try FileManager.default.createDirectory(at: mr1Directory, withIntermediateDirectories: true)

        for i in 0..<15 {
            var params = TestFixtures.DICOMGenerationParams()
            params.rows = 256
            params.columns = 256
            params.modality = "MR"

            let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
            let fileURL = mr1Directory.appendingPathComponent("slice_\(i).dcm")
            try dicomData.write(to: fileURL)
        }

        // Import entire directory
        let results = try await importService.importDirectory(tempDirectory)

        // Should find 2 series
        XCTAssertEqual(results.count, 2)

        // Verify first series (CT or MR depending on processing order)
        let ctResults = results.filter { $0.series.modality == .ct }
        let mrResults = results.filter { $0.series.modality == .mr }

        XCTAssertEqual(ctResults.count, 1)
        XCTAssertEqual(mrResults.count, 1)

        // Verify CT series
        if let ctResult = ctResults.first {
            XCTAssertEqual(ctResult.images.count, 10)
            XCTAssertEqual(ctResult.volume.dimensions.z, 10)
        }

        // Verify MR series
        if let mrResult = mrResults.first {
            XCTAssertEqual(mrResult.images.count, 15)
            XCTAssertEqual(mrResult.volume.dimensions.z, 15)
        }
    }

    func testImportEmptyDirectory() async throws {
        // Empty directory should throw error
        let emptyDir = tempDirectory.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        await XCTAssertThrowsError(
            try await importService.importDirectory(emptyDir)
        ) { error in
            guard case DICOMImportError.noDICOMFiles = error else {
                XCTFail("Expected noDICOMFiles error")
                return
            }
        }
    }

    func testImportDirectoryWithMixedFiles() async throws {
        // Create directory with DICOM and non-DICOM files
        for i in 0..<5 {
            // DICOM files
            let dicomData = TestFixtures.generateSyntheticDICOM(rows: 64, columns: 64)
            let dcmURL = tempDirectory.appendingPathComponent("image_\(i).dcm")
            try dicomData.write(to: dcmURL)

            // Non-DICOM files (should be ignored)
            let txtURL = tempDirectory.appendingPathComponent("notes_\(i).txt")
            try "Some notes".write(to: txtURL, atomically: true, encoding: .utf8)
        }

        // Should only import DICOM files
        let results = try await importService.importDirectory(tempDirectory)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].images.count, 5)
    }

    // MARK: - Performance Tests

    func testImportLargeSeriesPerformance() async throws {
        // Create a realistic series (50 slices of 512×512)
        let sliceCount = 50
        var fileURLs: [URL] = []

        for i in 0..<sliceCount {
            var params = TestFixtures.DICOMGenerationParams()
            params.rows = 512
            params.columns = 512
            params.pixelRepresentation = 1
            params.rescaleSlope = 1.0
            params.rescaleIntercept = -1024.0
            params.pixelSpacing = (0.625, 0.625)

            let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
            let fileURL = tempDirectory.appendingPathComponent("ct_\(String(format: "%03d", i)).dcm")
            try dicomData.write(to: fileURL)
            fileURLs.append(fileURL)
        }

        // Measure import performance
        measure {
            Task {
                _ = try await importService.importSeries(fileURLs)
            }
        }
    }

    // MARK: - Integration Tests

    func testCompleteWorkflow() async throws {
        // Test complete workflow from file creation to volume reconstruction
        // This simulates a real clinical scenario

        // 1. Create a realistic CT chest series
        let sliceCount = 30
        var fileURLs: [URL] = []

        for i in 0..<sliceCount {
            var params = TestFixtures.DICOMGenerationParams()
            params.rows = 256
            params.columns = 256
            params.pixelRepresentation = 1
            params.rescaleSlope = 1.0
            params.rescaleIntercept = -1024.0
            params.windowCenter = 40.0  // Soft tissue window
            params.windowWidth = 400.0
            params.pixelSpacing = (0.7, 0.7)
            params.modality = "CT"

            let dicomData = TestFixtures.generateSyntheticDICOM(params: params)
            let fileURL = tempDirectory.appendingPathComponent("ct_chest_\(String(format: "%03d", i)).dcm")
            try dicomData.write(to: fileURL)
            fileURLs.append(fileURL)
        }

        // 2. Import the series
        let result = try await importService.importSeries(fileURLs)

        // 3. Verify complete data hierarchy
        XCTAssertNotNil(result.patient)
        XCTAssertNotNil(result.study)
        XCTAssertNotNil(result.series)
        XCTAssertEqual(result.images.count, sliceCount)
        XCTAssertEqual(result.pixelData.count, sliceCount)

        // 4. Verify 3D volume
        XCTAssertEqual(result.volume.dimensions.x, 256)
        XCTAssertEqual(result.volume.dimensions.y, 256)
        XCTAssertEqual(result.volume.dimensions.z, sliceCount)

        // 5. Verify CT-specific parameters
        XCTAssertEqual(result.volume.rescaleSlope, 1.0)
        XCTAssertEqual(result.volume.rescaleIntercept, -1024.0)
        XCTAssertEqual(result.volume.windowCenter, 40.0)
        XCTAssertEqual(result.volume.windowWidth, 400.0)

        // 6. Verify physical dimensions
        let expectedVolumeSize = 256 * 0.7  // pixels * mm/pixel
        XCTAssertEqual(result.volume.physicalDimensions.x, expectedVolumeSize, accuracy: 0.1)

        // 7. Verify memory size is reasonable
        let expectedMemory = 256 * 256 * sliceCount * 2  // ~4MB
        XCTAssertEqual(result.volume.memorySize, expectedMemory)

        // 8. Verify summary is well-formatted
        let summary = result.summary
        XCTAssertTrue(summary.contains("Patient:"))
        XCTAssertTrue(summary.contains("Study:"))
        XCTAssertTrue(summary.contains("Series:"))
        XCTAssertTrue(summary.contains("Volume:"))
        XCTAssertTrue(summary.contains("256×256×\(sliceCount)"))
    }
}
