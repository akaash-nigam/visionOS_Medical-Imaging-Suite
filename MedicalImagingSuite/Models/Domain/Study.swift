//
//  Study.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// Represents a DICOM imaging study
struct Study: Identifiable, Codable {
    let id: UUID
    let studyInstanceUID: String    // DICOM (0020,000D)
    let studyDate: Date?            // DICOM (0008,0020)
    let studyTime: Date?            // DICOM (0008,0030)
    let studyDescription: String?   // DICOM (0008,1030)
    let accessionNumber: String?    // DICOM (0008,0050)
    let modalities: [Modality]
    let patient: Patient
    let series: [Series]

    /// Combined study date and time
    var studyDateTime: Date? {
        guard let date = studyDate else { return nil }

        if let time = studyTime {
            return Calendar.current.date(
                byAdding: .second,
                value: Int(time.timeIntervalSince1970),
                to: date
            )
        }

        return date
    }

    init(
        id: UUID = UUID(),
        studyInstanceUID: String,
        studyDate: Date? = nil,
        studyTime: Date? = nil,
        studyDescription: String? = nil,
        accessionNumber: String? = nil,
        modalities: [Modality] = [],
        patient: Patient,
        series: [Series] = []
    ) {
        self.id = id
        self.studyInstanceUID = studyInstanceUID
        self.studyDate = studyDate
        self.studyTime = studyTime
        self.studyDescription = studyDescription
        self.accessionNumber = accessionNumber
        self.modalities = modalities
        self.patient = patient
        self.series = series
    }
}

/// Represents a DICOM series within a study
struct Series: Identifiable, Codable {
    let id: UUID
    let seriesInstanceUID: String   // DICOM (0020,000E)
    let seriesNumber: Int?          // DICOM (0020,0011)
    let seriesDescription: String?  // DICOM (0008,103E)
    let modality: Modality          // DICOM (0008,0060)
    let instanceCount: Int
    let images: [ImageInstance]

    init(
        id: UUID = UUID(),
        seriesInstanceUID: String,
        seriesNumber: Int? = nil,
        seriesDescription: String? = nil,
        modality: Modality,
        instanceCount: Int = 0,
        images: [ImageInstance] = []
    ) {
        self.id = id
        self.seriesInstanceUID = seriesInstanceUID
        self.seriesNumber = seriesNumber
        self.seriesDescription = seriesDescription
        self.modality = modality
        self.instanceCount = instanceCount
        self.images = images
    }
}

/// Represents a single DICOM image instance
struct ImageInstance: Identifiable, Codable {
    let id: UUID
    let sopInstanceUID: String      // DICOM (0008,0018)
    let instanceNumber: Int?        // DICOM (0020,0013)
    let localURL: URL?              // Path to cached DICOM file
    let dimensions: SIMD2<Int>      // (rows, columns)
    let pixelSpacing: SIMD2<Float>? // mm per pixel

    init(
        id: UUID = UUID(),
        sopInstanceUID: String,
        instanceNumber: Int? = nil,
        localURL: URL? = nil,
        dimensions: SIMD2<Int> = SIMD2(0, 0),
        pixelSpacing: SIMD2<Float>? = nil
    ) {
        self.id = id
        self.sopInstanceUID = sopInstanceUID
        self.instanceNumber = instanceNumber
        self.localURL = localURL
        self.dimensions = dimensions
        self.pixelSpacing = pixelSpacing
    }
}

/// DICOM modality types
enum Modality: String, Codable, CaseIterable {
    case ct = "CT"                  // Computed Tomography
    case mr = "MR"                  // Magnetic Resonance
    case pt = "PT"                  // Positron Emission Tomography
    case us = "US"                  // Ultrasound
    case xa = "XA"                  // X-ray Angiography
    case cr = "CR"                  // Computed Radiography
    case dx = "DX"                  // Digital Radiography
    case mg = "MG"                  // Mammography
    case nm = "NM"                  // Nuclear Medicine
    case other = "OT"

    var displayName: String {
        switch self {
        case .ct: return "CT Scan"
        case .mr: return "MRI"
        case .pt: return "PET Scan"
        case .us: return "Ultrasound"
        case .xa: return "Angiography"
        case .cr, .dx: return "X-Ray"
        case .mg: return "Mammography"
        case .nm: return "Nuclear Medicine"
        case .other: return "Other"
        }
    }
}

// MARK: - Sample Data

extension Study {
    static let sample = Study(
        id: UUID(),
        studyInstanceUID: "1.2.840.113619.2.55.3.12345",
        studyDate: Date(),
        studyDescription: "Chest CT with Contrast",
        accessionNumber: "ACC001",
        modalities: [.ct],
        patient: .sample,
        series: [.sample]
    )
}

extension Series {
    static let sample = Series(
        id: UUID(),
        seriesInstanceUID: "1.2.840.113619.2.55.3.12345.6789",
        seriesNumber: 1,
        seriesDescription: "Axial CT Chest",
        modality: .ct,
        instanceCount: 200,
        images: []
    )
}
