//
//  TestFixtures.swift
//  MedicalImagingSuiteTests
//
//  Created by Claude on 2025-11-24.
//

import Foundation
@testable import MedicalImagingSuite

/// Test fixtures and sample data for unit tests
enum TestFixtures {

    // MARK: - Patients

    static let samplePatient = Patient(
        id: UUID(),
        patientID: "TEST-001",
        name: PersonName(
            familyName: "Doe",
            givenName: "John",
            middleName: "M"
        ),
        birthDate: Calendar.current.date(byAdding: .year, value: -45, to: Date()),
        sex: .male
    )

    static let samplePatientFemale = Patient(
        id: UUID(),
        patientID: "TEST-002",
        name: PersonName(
            familyName: "Smith",
            givenName: "Jane"
        ),
        birthDate: Calendar.current.date(byAdding: .year, value: -32, to: Date()),
        sex: .female
    )

    // MARK: - Studies

    static let sampleCTStudy = Study(
        id: UUID(),
        studyInstanceUID: "1.2.840.113619.2.55.3.TEST.001",
        studyDate: Date(),
        studyDescription: "Chest CT with Contrast",
        accessionNumber: "ACC-TEST-001",
        modalities: [.ct],
        patient: samplePatient,
        series: [sampleCTSeries]
    )

    static let sampleMRStudy = Study(
        id: UUID(),
        studyInstanceUID: "1.2.840.113619.2.55.3.TEST.002",
        studyDate: Date(),
        studyDescription: "Brain MRI",
        accessionNumber: "ACC-TEST-002",
        modalities: [.mr],
        patient: samplePatient,
        series: [sampleMRSeries]
    )

    // MARK: - Series

    static let sampleCTSeries = Series(
        id: UUID(),
        seriesInstanceUID: "1.2.840.113619.2.55.3.TEST.001.1",
        seriesNumber: 1,
        seriesDescription: "Axial CT Chest",
        modality: .ct,
        instanceCount: 200,
        images: []
    )

    static let sampleMRSeries = Series(
        id: UUID(),
        seriesInstanceUID: "1.2.840.113619.2.55.3.TEST.002.1",
        seriesNumber: 1,
        seriesDescription: "T1 Axial Brain",
        modality: .mr,
        instanceCount: 150,
        images: []
    )

    // MARK: - Volume Data

    static let sampleCTVolume = VolumeData(
        seriesInstanceUID: "1.2.840.113619.2.55.3.TEST.001.1",
        dimensions: SIMD3(512, 512, 200),
        spacing: SIMD3(0.7, 0.7, 1.0),
        dataType: .int16,
        voxelData: Data(count: 512 * 512 * 200 * 2),  // 100MB of zeros
        windowCenter: 40,
        windowWidth: 400
    )

    static let smallCTVolume = VolumeData(
        seriesInstanceUID: "1.2.840.113619.2.55.3.TEST.SMALL",
        dimensions: SIMD3(128, 128, 50),
        spacing: SIMD3(1.0, 1.0, 1.0),
        dataType: .int16,
        voxelData: Data(count: 128 * 128 * 50 * 2),  // ~1.6MB
        windowCenter: 40,
        windowWidth: 400
    )

    // MARK: - Users

    static let sampleRadiologist = User(
        id: UUID(),
        username: "drsmith",
        email: "smith@hospital.com",
        role: .radiologist,
        hospitalID: "HOSP-001"
    )

    static let sampleSurgeon = User(
        id: UUID(),
        username: "drbrown",
        email: "brown@hospital.com",
        role: .surgeon,
        hospitalID: "HOSP-001"
    )

    static let sampleMedicalStudent = User(
        id: UUID(),
        username: "student1",
        email: "student@university.edu",
        role: .medicalStudent,
        hospitalID: nil
    )

    // MARK: - Synthetic DICOM Data

    /// Parameters for generating synthetic DICOM files
    struct DICOMGenerationParams {
        var rows: Int = 128
        var columns: Int = 128
        var bitsAllocated: Int = 16
        var pixelRepresentation: Int = 0  // 0=unsigned, 1=signed
        var samplesPerPixel: Int = 1
        var rescaleSlope: Float? = nil
        var rescaleIntercept: Float? = nil
        var pixelSpacing: (Float, Float)? = nil
        var windowCenter: Float? = nil
        var windowWidth: Float? = nil
        var modality: String = "CT"
    }

    /// Generate a minimal synthetic DICOM file for testing
    static func generateSyntheticDICOM(rows: Int = 128, columns: Int = 128) -> Data {
        generateSyntheticDICOM(params: DICOMGenerationParams(rows: rows, columns: columns))
    }

    /// Generate a synthetic DICOM file with custom parameters
    static func generateSyntheticDICOM(params: DICOMGenerationParams) -> Data {
        var data = Data()

        // 1. Preamble (128 bytes of zeros)
        data.append(Data(count: 128))

        // 2. DICM magic number
        data.append("DICM".data(using: .ascii)!)

        // 3. File Meta Information (Group 0002)
        // Transfer Syntax UID: Explicit VR Little Endian
        data.append(encodeExplicitVRElement(
            tag: DICOMTag.transferSyntaxUID.rawValue,
            vr: .UI,
            value: "1.2.840.10008.1.2.1".data(using: .ascii)!
        ))

        // 4. Patient Information
        data.append(encodeExplicitVRElement(
            tag: DICOMTag.patientName.rawValue,
            vr: .PN,
            value: "Test^Patient".data(using: .ascii)!
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.patientID.rawValue,
            vr: .LO,
            value: "TEST001".data(using: .ascii)!
        ))

        // 5. Study Information
        data.append(encodeExplicitVRElement(
            tag: DICOMTag.studyInstanceUID.rawValue,
            vr: .UI,
            value: "1.2.3.4.5".data(using: .ascii)!
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.studyDate.rawValue,
            vr: .DA,
            value: "20231124".data(using: .ascii)!
        ))

        // 6. Series Information
        data.append(encodeExplicitVRElement(
            tag: DICOMTag.seriesInstanceUID.rawValue,
            vr: .UI,
            value: "1.2.3.4.5.6".data(using: .ascii)!
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.modality.rawValue,
            vr: .CS,
            value: params.modality.data(using: .ascii)!
        ))

        // 7. Image Information
        data.append(encodeExplicitVRElement(
            tag: DICOMTag.rows.rawValue,
            vr: .US,
            value: withUnsafeBytes(of: UInt16(params.rows)) { Data($0) }
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.columns.rawValue,
            vr: .US,
            value: withUnsafeBytes(of: UInt16(params.columns)) { Data($0) }
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.bitsAllocated.rawValue,
            vr: .US,
            value: withUnsafeBytes(of: UInt16(params.bitsAllocated)) { Data($0) }
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.bitsStored.rawValue,
            vr: .US,
            value: withUnsafeBytes(of: UInt16(params.bitsAllocated)) { Data($0) }
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.highBit.rawValue,
            vr: .US,
            value: withUnsafeBytes(of: UInt16(params.bitsAllocated - 1)) { Data($0) }
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.pixelRepresentation.rawValue,
            vr: .US,
            value: withUnsafeBytes(of: UInt16(params.pixelRepresentation)) { Data($0) }
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.samplesPerPixel.rawValue,
            vr: .US,
            value: withUnsafeBytes(of: UInt16(params.samplesPerPixel)) { Data($0) }
        ))

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.photometricInterpretation.rawValue,
            vr: .CS,
            value: (params.samplesPerPixel == 1 ? "MONOCHROME2" : "RGB").data(using: .ascii)!
        ))

        // 8. Optional Rescale Parameters (for CT Hounsfield units)
        if let rescaleSlope = params.rescaleSlope {
            let slopeString = String(format: "%.6f", rescaleSlope)
            data.append(encodeExplicitVRElement(
                tag: DICOMTag.rescaleSlope.rawValue,
                vr: .DS,
                value: slopeString.data(using: .ascii)!
            ))
        }

        if let rescaleIntercept = params.rescaleIntercept {
            let interceptString = String(format: "%.6f", rescaleIntercept)
            data.append(encodeExplicitVRElement(
                tag: DICOMTag.rescaleIntercept.rawValue,
                vr: .DS,
                value: interceptString.data(using: .ascii)!
            ))
        }

        // 9. Optional Pixel Spacing
        if let pixelSpacing = params.pixelSpacing {
            let spacingString = "\(pixelSpacing.0)\\\(pixelSpacing.1)"
            data.append(encodeExplicitVRElement(
                tag: DICOMTag.pixelSpacing.rawValue,
                vr: .DS,
                value: spacingString.data(using: .ascii)!
            ))
        }

        // 10. Optional Windowing Parameters
        if let windowCenter = params.windowCenter {
            let centerString = String(format: "%.1f", windowCenter)
            data.append(encodeExplicitVRElement(
                tag: DICOMTag.windowCenter.rawValue,
                vr: .DS,
                value: centerString.data(using: .ascii)!
            ))
        }

        if let windowWidth = params.windowWidth {
            let widthString = String(format: "%.1f", windowWidth)
            data.append(encodeExplicitVRElement(
                tag: DICOMTag.windowWidth.rawValue,
                vr: .DS,
                value: widthString.data(using: .ascii)!
            ))
        }

        // 11. Pixel Data (simple gradient pattern)
        let pixelCount = params.rows * params.columns
        let bytesPerPixel = params.bitsAllocated / 8
        var pixelData = Data(count: pixelCount * bytesPerPixel * params.samplesPerPixel)

        if params.bitsAllocated == 8 {
            // 8-bit pixel data
            for i in 0..<pixelCount {
                let value = UInt8((i * 255) / pixelCount)  // Gradient 0-255
                pixelData[i] = value
            }
        } else if params.bitsAllocated == 16 {
            // 16-bit pixel data
            if params.pixelRepresentation == 0 {
                // Unsigned 16-bit
                for i in 0..<pixelCount {
                    let value = UInt16((i * 4095) / pixelCount)  // Gradient 0-4095
                    pixelData.replaceSubrange(i*2..<i*2+2, with: withUnsafeBytes(of: value) { Data($0) })
                }
            } else {
                // Signed 16-bit (CT Hounsfield units range: -1024 to 3071)
                for i in 0..<pixelCount {
                    let normalizedValue = Float(i) / Float(pixelCount)  // 0.0 to 1.0
                    let value = Int16(-1024 + Int(normalizedValue * 4095))  // -1024 to 3071
                    pixelData.replaceSubrange(i*2..<i*2+2, with: withUnsafeBytes(of: value) { Data($0) })
                }
            }
        }

        data.append(encodeExplicitVRElement(
            tag: DICOMTag.pixelData.rawValue,
            vr: .OW,
            value: pixelData
        ))

        return data
    }

    // MARK: - Helper Methods

    private static func encodeExplicitVRElement(tag: UInt32, vr: ValueRepresentation, value: Data) -> Data {
        var data = Data()

        // Tag (4 bytes)
        let group = UInt16((tag >> 16) & 0xFFFF)
        let element = UInt16(tag & 0xFFFF)
        data.append(contentsOf: withUnsafeBytes(of: group) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: element) { Array($0) })

        // VR (2 bytes)
        data.append(vr.rawValue.data(using: .ascii)!)

        // Value Length
        if vr.usesShortLength {
            // 2-byte length
            let length = UInt16(value.count)
            data.append(contentsOf: withUnsafeBytes(of: length) { Array($0) })
        } else {
            // 2 reserved bytes + 4-byte length
            data.append(0x00)
            data.append(0x00)
            let length = UInt32(value.count)
            data.append(contentsOf: withUnsafeBytes(of: length) { Array($0) })
        }

        // Value
        data.append(value)

        return data
    }

    /// Create a temporary file with DICOM data for testing
    static func createTemporaryDICOMFile(rows: Int = 128, columns: Int = 128) -> URL {
        let data = generateSyntheticDICOM(rows: rows, columns: columns)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).dcm")

        try! data.write(to: tempURL)
        return tempURL
    }

    /// Create a temporary file with custom DICOM parameters
    static func createTemporaryDICOMFile(params: DICOMGenerationParams) -> URL {
        let data = generateSyntheticDICOM(params: params)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).dcm")

        try! data.write(to: tempURL)
        return tempURL
    }

    // MARK: - Convenience Fixtures

    /// Generate a CT scan with Hounsfield units
    static func generateCTScan(rows: Int = 128, columns: Int = 128) -> Data {
        var params = DICOMGenerationParams(rows: rows, columns: columns)
        params.pixelRepresentation = 1  // Signed
        params.rescaleSlope = 1.0
        params.rescaleIntercept = -1024.0
        params.windowCenter = 40.0  // Soft tissue window
        params.windowWidth = 400.0
        params.pixelSpacing = (0.7, 0.7)  // 0.7mm pixel spacing
        params.modality = "CT"
        return generateSyntheticDICOM(params: params)
    }

    /// Generate an MRI scan
    static func generateMRIScan(rows: Int = 128, columns: Int = 128) -> Data {
        var params = DICOMGenerationParams(rows: rows, columns: columns)
        params.pixelRepresentation = 0  // Unsigned
        params.windowCenter = 128.0
        params.windowWidth = 256.0
        params.pixelSpacing = (1.0, 1.0)
        params.modality = "MR"
        return generateSyntheticDICOM(params: params)
    }
}
