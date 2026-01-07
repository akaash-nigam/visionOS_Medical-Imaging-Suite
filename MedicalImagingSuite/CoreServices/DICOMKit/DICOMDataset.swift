//
//  DICOMDataset.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// Represents a parsed DICOM dataset with tag-value pairs
class DICOMDataset {
    private var elements: [UInt32: DICOMElement] = [:]

    // MARK: - Element Storage

    /// Store a DICOM element
    func set(tag: DICOMTag, element: DICOMElement) {
        elements[tag.rawValue] = element
    }

    /// Retrieve a DICOM element
    func get(tag: DICOMTag) -> DICOMElement? {
        elements[tag.rawValue]
    }

    /// Check if tag exists
    func contains(tag: DICOMTag) -> Bool {
        elements[tag.rawValue] != nil
    }

    /// Remove a tag
    func remove(tag: DICOMTag) {
        elements.removeValue(forKey: tag.rawValue)
    }

    // MARK: - Convenience Accessors

    /// Get string value for tag
    func string(for tag: DICOMTag) -> String? {
        guard let element = get(tag: tag) else { return nil }
        return element.stringValue
    }

    /// Get integer value for tag
    func int(for tag: DICOMTag) -> Int? {
        guard let element = get(tag: tag) else { return nil }
        return element.intValue
    }

    /// Get float value for tag
    func float(for tag: DICOMTag) -> Float? {
        guard let element = get(tag: tag) else { return nil }
        return element.floatValue
    }

    /// Get date value for tag
    func date(for tag: DICOMTag) -> Date? {
        guard let element = get(tag: tag) else { return nil }
        return element.dateValue
    }

    /// Get raw data for tag
    func data(for tag: DICOMTag) -> Data? {
        guard let element = get(tag: tag) else { return nil }
        return element.data
    }

    // MARK: - Common DICOM Fields

    var patientName: String? {
        string(for: .patientName)
    }

    var patientID: String? {
        string(for: .patientID)
    }

    var studyInstanceUID: String? {
        string(for: .studyInstanceUID)
    }

    var seriesInstanceUID: String? {
        string(for: .seriesInstanceUID)
    }

    var sopInstanceUID: String? {
        string(for: .sopInstanceUID)
    }

    var studyDate: Date? {
        date(for: .studyDate)
    }

    var studyDescription: String? {
        string(for: .studyDescription)
    }

    var seriesDescription: String? {
        string(for: .seriesDescription)
    }

    var modality: String? {
        string(for: .modality)
    }

    var rows: Int? {
        int(for: .rows)
    }

    var columns: Int? {
        int(for: .columns)
    }

    var pixelData: Data? {
        data(for: .pixelData)
    }

    var windowCenter: Float? {
        float(for: .windowCenter)
    }

    var windowWidth: Float? {
        float(for: .windowWidth)
    }

    var rescaleSlope: Float? {
        float(for: .rescaleSlope) ?? 1.0
    }

    var rescaleIntercept: Float? {
        float(for: .rescaleIntercept) ?? 0.0
    }

    // MARK: - Description

    func description() -> String {
        var desc = "DICOM Dataset:\n"
        for (tagValue, element) in elements.sorted(by: { $0.key < $1.key }) {
            if let tag = DICOMTag(rawValue: tagValue) {
                desc += "  \(tag.name): \(element.stringValue ?? "<binary>")\n"
            }
        }
        return desc
    }
}

/// Represents a single DICOM data element
struct DICOMElement {
    let tag: UInt32
    let vr: ValueRepresentation?
    let valueLength: UInt32
    let data: Data

    // MARK: - Value Extraction

    /// Extract as string
    var stringValue: String? {
        guard data.count > 0 else { return nil }

        // Remove null padding
        var trimmedData = data
        while trimmedData.last == 0 {
            trimmedData = trimmedData.dropLast()
        }

        return String(data: trimmedData, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract as integer
    var intValue: Int? {
        guard data.count >= 2 else { return nil }

        switch data.count {
        case 2:
            // 16-bit integer
            let value = data.withUnsafeBytes { $0.load(as: UInt16.self) }
            return Int(value)
        case 4:
            // 32-bit integer
            let value = data.withUnsafeBytes { $0.load(as: UInt32.self) }
            return Int(value)
        default:
            // Try parsing as string
            return stringValue.flatMap { Int($0) }
        }
    }

    /// Extract as float
    var floatValue: Float? {
        guard data.count >= 4 else {
            // Try parsing as string
            return stringValue.flatMap { Float($0) }
        }

        return data.withUnsafeBytes { $0.load(as: Float.self) }
    }

    /// Extract as date (DICOM DA format: YYYYMMDD)
    var dateValue: Date? {
        guard let dateString = stringValue else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: dateString)
    }

    /// Extract as time (DICOM TM format: HHMMSS)
    var timeValue: Date? {
        guard let timeString = stringValue else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        return formatter.date(from: timeString)
    }
}

// MARK: - Errors

enum DICOMError: Error, LocalizedError {
    case invalidFormat(reason: String)
    case unsupportedTransferSyntax(String)
    case corruptedPixelData
    case missingRequiredTag(DICOMTag)
    case invalidTagValue(tag: DICOMTag, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let reason):
            return "Invalid DICOM format: \(reason)"
        case .unsupportedTransferSyntax(let syntax):
            return "Unsupported transfer syntax: \(syntax)"
        case .corruptedPixelData:
            return "Pixel data is corrupted or incomplete"
        case .missingRequiredTag(let tag):
            return "Missing required tag: \(tag.name)"
        case .invalidTagValue(let tag, let reason):
            return "Invalid value for \(tag.name): \(reason)"
        }
    }
}
