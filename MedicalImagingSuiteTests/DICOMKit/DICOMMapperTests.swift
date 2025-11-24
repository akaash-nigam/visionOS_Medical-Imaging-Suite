//
//  DICOMMapperTests.swift
//  MedicalImagingSuiteTests
//
//  Created by Claude on 2025-11-24.
//

import XCTest
@testable import MedicalImagingSuite

final class DICOMMapperTests: XCTestCase {

    var mapper: DICOMMapper!
    var parser: DICOMParserImpl!

    override func setUp() async throws {
        mapper = DICOMMapper()
        parser = DICOMParserImpl()
    }

    // MARK: - Patient Mapping Tests

    func testMapPatientFromDICOM() async throws {
        // Create a DICOM with patient information
        let dicomData = TestFixtures.generateSyntheticDICOM(rows: 64, columns: 64)
        let dataset = try await parser.parse(data: dicomData)

        // Map to patient
        let patient = await mapper.mapToPatient(from: dataset)

        // Verify patient was created
        XCTAssertNotNil(patient)
        XCTAssertEqual(patient?.patientID, "TEST001")
        XCTAssertEqual(patient?.name.familyName, "Test")
        XCTAssertEqual(patient?.name.givenName, "Patient")
    }

    func testMapPatientWithFullName() async throws {
        // Create a dataset with full patient name
        let dataset = DICOMDataset()

        // Add patient ID
        dataset.set(
            tag: .patientID,
            element: DICOMElement(
                tag: DICOMTag.patientID.rawValue,
                vr: .LO,
                valueLength: 7,
                data: "PAT-001".data(using: .ascii)!
            )
        )

        // Add patient name with all components
        dataset.set(
            tag: .patientName,
            element: DICOMElement(
                tag: DICOMTag.patientName.rawValue,
                vr: .PN,
                valueLength: 19,
                data: "Smith^John^M^Dr.^Jr.".data(using: .ascii)!
            )
        )

        // Add patient sex
        dataset.set(
            tag: .patientSex,
            element: DICOMElement(
                tag: DICOMTag.patientSex.rawValue,
                vr: .CS,
                valueLength: 1,
                data: "M".data(using: .ascii)!
            )
        )

        // Map to patient
        let patient = await mapper.mapToPatient(from: dataset)

        XCTAssertNotNil(patient)
        XCTAssertEqual(patient?.name.familyName, "Smith")
        XCTAssertEqual(patient?.name.givenName, "John")
        XCTAssertEqual(patient?.name.middleName, "M")
        XCTAssertEqual(patient?.name.prefix, "Dr.")
        XCTAssertEqual(patient?.name.suffix, "Jr.")
        XCTAssertEqual(patient?.sex, .male)
    }

    func testMapPatientWithMissingID() async throws {
        // Create a dataset without patient ID
        let dataset = DICOMDataset()

        dataset.set(
            tag: .patientName,
            element: DICOMElement(
                tag: DICOMTag.patientName.rawValue,
                vr: .PN,
                valueLength: 10,
                data: "Doe^Jane".data(using: .ascii)!
            )
        )

        // Should return nil without patient ID
        let patient = await mapper.mapToPatient(from: dataset)
        XCTAssertNil(patient)
    }

    func testMapPatientSexValues() async throws {
        let sexValues: [(String, Sex)] = [
            ("M", .male),
            ("F", .female),
            ("O", .other),
            ("U", .unknown)
        ]

        for (dicomValue, expectedSex) in sexValues {
            let dataset = DICOMDataset()

            dataset.set(
                tag: .patientID,
                element: DICOMElement(
                    tag: DICOMTag.patientID.rawValue,
                    vr: .LO,
                    valueLength: 6,
                    data: "PAT001".data(using: .ascii)!
                )
            )

            dataset.set(
                tag: .patientSex,
                element: DICOMElement(
                    tag: DICOMTag.patientSex.rawValue,
                    vr: .CS,
                    valueLength: UInt32(dicomValue.count),
                    data: dicomValue.data(using: .ascii)!
                )
            )

            let patient = await mapper.mapToPatient(from: dataset)
            XCTAssertEqual(patient?.sex, expectedSex, "Failed for sex value: \(dicomValue)")
        }
    }

    // MARK: - Study Mapping Tests

    func testMapStudyFromDICOM() async throws {
        let dicomData = TestFixtures.generateCTScan(rows: 128, columns: 128)
        let dataset = try await parser.parse(data: dicomData)

        // Create patient first
        guard let patient = await mapper.mapToPatient(from: dataset) else {
            XCTFail("Failed to map patient")
            return
        }

        // Map to study
        let study = await mapper.mapToStudy(from: dataset, patient: patient)

        XCTAssertNotNil(study)
        XCTAssertEqual(study?.studyInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(study?.studyDescription, "Chest CT with Contrast")
        XCTAssertEqual(study?.patient.patientID, patient.patientID)
        XCTAssertTrue(study?.modalities.contains(.ct) ?? false)
    }

    func testMapStudyWithMissingUID() async throws {
        let dataset = DICOMDataset()
        let patient = Patient(patientID: "TEST", name: PersonName(familyName: "Doe", givenName: "John"))

        // Study without UID should return nil
        let study = await mapper.mapToStudy(from: dataset, patient: patient)
        XCTAssertNil(study)
    }

    func testMapStudyModalities() async throws {
        let modalities: [(String, Modality)] = [
            ("CT", .ct),
            ("MR", .mr),
            ("PT", .pt),
            ("US", .us),
            ("XA", .xa),
            ("DX", .dx)
        ]

        let patient = Patient(patientID: "TEST", name: PersonName(familyName: "Test", givenName: "Patient"))

        for (dicomModality, expectedModality) in modalities {
            let dataset = DICOMDataset()

            dataset.set(
                tag: .studyInstanceUID,
                element: DICOMElement(
                    tag: DICOMTag.studyInstanceUID.rawValue,
                    vr: .UI,
                    valueLength: 9,
                    data: "1.2.3.4.5".data(using: .ascii)!
                )
            )

            dataset.set(
                tag: .modality,
                element: DICOMElement(
                    tag: DICOMTag.modality.rawValue,
                    vr: .CS,
                    valueLength: UInt32(dicomModality.count),
                    data: dicomModality.data(using: .ascii)!
                )
            )

            let study = await mapper.mapToStudy(from: dataset, patient: patient)
            XCTAssertTrue(study?.modalities.contains(expectedModality) ?? false,
                         "Failed for modality: \(dicomModality)")
        }
    }

    // MARK: - Series Mapping Tests

    func testMapSeriesFromDICOM() async throws {
        let dicomData = TestFixtures.generateCTScan(rows: 128, columns: 128)
        let dataset = try await parser.parse(data: dicomData)

        let series = await mapper.mapToSeries(from: dataset)

        XCTAssertNotNil(series)
        XCTAssertEqual(series?.seriesInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(series?.seriesNumber, 1)
        XCTAssertEqual(series?.seriesDescription, "Axial CT Chest")
        XCTAssertEqual(series?.modality, .ct)
    }

    func testMapSeriesWithMissingUID() async throws {
        let dataset = DICOMDataset()

        dataset.set(
            tag: .seriesNumber,
            element: DICOMElement(
                tag: DICOMTag.seriesNumber.rawValue,
                vr: .IS,
                valueLength: 1,
                data: "1".data(using: .ascii)!
            )
        )

        // Series without UID should return nil
        let series = await mapper.mapToSeries(from: dataset)
        XCTAssertNil(series)
    }

    // MARK: - Image Instance Mapping Tests

    func testMapImageInstanceFromDICOM() async throws {
        let dicomData = TestFixtures.generateCTScan(rows: 128, columns: 128)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        // Add SOP Instance UID to dataset
        dataset.set(
            tag: .sopInstanceUID,
            element: DICOMElement(
                tag: DICOMTag.sopInstanceUID.rawValue,
                vr: .UI,
                valueLength: 11,
                data: "1.2.3.4.5.7".data(using: .ascii)!
            )
        )

        let image = await mapper.mapToImageInstance(from: dataset, pixelData: pixelData)

        XCTAssertNotNil(image)
        XCTAssertEqual(image?.sopInstanceUID, "1.2.3.4.5.7")
        XCTAssertEqual(image?.rows, 128)
        XCTAssertEqual(image?.columns, 128)
        XCTAssertEqual(image?.dimensions.x, 128)
        XCTAssertEqual(image?.dimensions.y, 128)
        XCTAssertEqual(image?.pixelSpacing?.x, 0.7)
        XCTAssertEqual(image?.pixelSpacing?.y, 0.7)
    }

    func testMapImageInstanceWithPosition() async throws {
        let dataset = DICOMDataset()
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

        // Add SOP Instance UID
        dataset.set(
            tag: .sopInstanceUID,
            element: DICOMElement(
                tag: DICOMTag.sopInstanceUID.rawValue,
                vr: .UI,
                valueLength: 11,
                data: "1.2.3.4.5.7".data(using: .ascii)!
            )
        )

        // Add image position
        dataset.set(
            tag: .imagePositionPatient,
            element: DICOMElement(
                tag: DICOMTag.imagePositionPatient.rawValue,
                vr: .DS,
                valueLength: 15,
                data: "-100.0\\-50.0\\25.5".data(using: .ascii)!
            )
        )

        let image = await mapper.mapToImageInstance(from: dataset, pixelData: pixelData)

        XCTAssertNotNil(image?.imagePosition)
        XCTAssertEqual(image?.imagePosition?.x, -100.0)
        XCTAssertEqual(image?.imagePosition?.y, -50.0)
        XCTAssertEqual(image?.imagePosition?.z, 25.5)
        XCTAssertTrue(image?.hasPositionInfo ?? false)
        XCTAssertEqual(image?.zPosition, 25.5)
    }

    // MARK: - Complete Hierarchy Mapping Tests

    func testMapCompleteHierarchy() async throws {
        // Generate a complete DICOM file
        let dicomData = TestFixtures.generateCTScan(rows: 256, columns: 256)
        let dataset = try await parser.parse(data: dicomData)
        let pixelData = try parser.extractPixelData(from: dataset)

        // Add SOP Instance UID
        dataset.set(
            tag: .sopInstanceUID,
            element: DICOMElement(
                tag: DICOMTag.sopInstanceUID.rawValue,
                vr: .UI,
                valueLength: 11,
                data: "1.2.3.4.5.7".data(using: .ascii)!
            )
        )

        // Map complete hierarchy
        let hierarchy = await mapper.mapToHierarchy(from: dataset, pixelData: pixelData)

        XCTAssertNotNil(hierarchy)

        // Verify patient
        XCTAssertEqual(hierarchy?.patient.patientID, "TEST001")

        // Verify study
        XCTAssertEqual(hierarchy?.study.studyInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(hierarchy?.study.patient.patientID, hierarchy?.patient.patientID)

        // Verify series
        XCTAssertEqual(hierarchy?.series.seriesInstanceUID, "1.2.3.4.5.6")
        XCTAssertEqual(hierarchy?.series.modality, .ct)

        // Verify image
        XCTAssertEqual(hierarchy?.image.sopInstanceUID, "1.2.3.4.5.7")
        XCTAssertEqual(hierarchy?.image.rows, 256)
        XCTAssertEqual(hierarchy?.image.columns, 256)
    }

    func testMapHierarchyWithMissingPatient() async throws {
        // Create dataset without patient ID
        let dataset = DICOMDataset()
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

        // Should return nil without patient
        let hierarchy = await mapper.mapToHierarchy(from: dataset, pixelData: pixelData)
        XCTAssertNil(hierarchy)
    }

    // MARK: - Integration Tests

    func testCompleteWorkflowFromFileToHierarchy() async throws {
        // Create temporary DICOM file
        var params = TestFixtures.DICOMGenerationParams()
        params.rows = 128
        params.columns = 128
        params.pixelRepresentation = 1
        params.rescaleSlope = 1.0
        params.rescaleIntercept = -1024.0
        params.pixelSpacing = (0.625, 0.625)

        let tempURL = TestFixtures.createTemporaryDICOMFile(params: params)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Parse DICOM
        let dataset = try await parser.parse(url: tempURL)

        // Extract pixel data
        let pixelData = try parser.extractPixelData(from: dataset)

        // Add SOP Instance UID
        dataset.set(
            tag: .sopInstanceUID,
            element: DICOMElement(
                tag: DICOMTag.sopInstanceUID.rawValue,
                vr: .UI,
                valueLength: 11,
                data: "1.2.3.4.5.7".data(using: .ascii)!
            )
        )

        // Map to hierarchy
        let hierarchy = await mapper.mapToHierarchy(from: dataset, pixelData: pixelData)

        // Verify complete workflow
        XCTAssertNotNil(hierarchy)
        XCTAssertEqual(hierarchy?.image.rows, 128)
        XCTAssertEqual(hierarchy?.image.columns, 128)
        XCTAssertEqual(hierarchy?.image.pixelSpacing?.x, 0.625)
    }
}
