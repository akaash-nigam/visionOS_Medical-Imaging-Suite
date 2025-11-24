//
//  DICOMParser.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// Protocol for DICOM file parsing
protocol DICOMParser {
    /// Parse a DICOM file from URL
    /// - Parameter url: File URL to parse
    /// - Returns: Parsed DICOM dataset
    /// - Throws: DICOMError if parsing fails
    func parse(url: URL) async throws -> DICOMDataset

    /// Parse DICOM data from memory
    /// - Parameter data: Raw DICOM file data
    /// - Returns: Parsed DICOM dataset
    /// - Throws: DICOMError if parsing fails
    func parse(data: Data) async throws -> DICOMDataset
}

/// Basic DICOM parser implementation
actor DICOMParserImpl: DICOMParser {
    private let bufferSize = 65536  // 64KB read buffer

    func parse(url: URL) async throws -> DICOMDataset {
        // Read file data
        let data = try Data(contentsOf: url)
        return try await parse(data: data)
    }

    func parse(data: Data) async throws -> DICOMDataset {
        var offset = 0
        let dataset = DICOMDataset()

        // 1. Verify DICOM preamble (128 bytes + "DICM" magic number)
        guard data.count >= 132 else {
            throw DICOMError.invalidFormat(reason: "File too small")
        }

        // Skip 128-byte preamble
        offset = 128

        // Check for "DICM" magic string
        let magic = data[offset..<offset+4]
        guard let magicString = String(data: magic, encoding: .ascii), magicString == "DICM" else {
            throw DICOMError.invalidFormat(reason: "Missing DICM magic number")
        }

        offset += 4

        // 2. Parse file meta information (Group 0002)
        // These are always Explicit VR Little Endian
        var transferSyntax: TransferSyntax = .explicitVRLittleEndian

        while offset < data.count {
            let tag = readTag(from: data, at: offset)
            let group = UInt16((tag >> 16) & 0xFFFF)

            // Stop when we leave group 0002 (file meta information)
            if group != 0x0002 {
                break
            }

            // Parse element with Explicit VR
            let (element, bytesRead) = try parseExplicitVRElement(from: data, at: offset)
            dataset.set(tag: .from(rawValue: tag) ?? .transferSyntaxUID, element: element)
            offset += bytesRead

            // Capture transfer syntax
            if tag == DICOMTag.transferSyntaxUID.rawValue {
                if let uid = element.stringValue,
                   let syntax = TransferSyntax(rawValue: uid) {
                    transferSyntax = syntax
                }
            }
        }

        // 3. Parse remaining dataset with detected transfer syntax
        while offset < data.count - 8 {  // Need at least tag + VR/VL
            let tag = readTag(from: data, at: offset)

            // Parse based on transfer syntax
            let (element, bytesRead): (DICOMElement, Int)

            if transferSyntax.isExplicitVR {
                (element, bytesRead) = try parseExplicitVRElement(from: data, at: offset)
            } else {
                (element, bytesRead) = try parseImplicitVRElement(from: data, at: offset)
            }

            if let dicomTag = DICOMTag.from(rawValue: tag) {
                dataset.set(tag: dicomTag, element: element)
            }

            offset += bytesRead

            // Stop at pixel data for now (handle separately)
            if tag == DICOMTag.pixelData.rawValue {
                break
            }
        }

        print("✅ Parsed DICOM file: \(dataset.description())")

        return dataset
    }

    // MARK: - Parsing Helpers

    private func readTag(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }

        let group = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt16.self)
        }

        let element = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset + 2, as: UInt16.self)
        }

        return DICOMTag.make(group: group, element: element)
    }

    private func parseExplicitVRElement(from data: Data, at offset: Int) throws -> (DICOMElement, Int) {
        var currentOffset = offset

        // Read tag (4 bytes)
        let tag = readTag(from: data, at: currentOffset)
        currentOffset += 4

        // Read VR (2 bytes)
        guard currentOffset + 2 <= data.count else {
            throw DICOMError.invalidFormat(reason: "Incomplete VR at offset \(currentOffset)")
        }

        let vrBytes = data[currentOffset..<currentOffset+2]
        guard let vrString = String(data: vrBytes, encoding: .ascii),
              let vr = ValueRepresentation(rawValue: vrString) else {
            throw DICOMError.invalidFormat(reason: "Invalid VR at offset \(currentOffset)")
        }

        currentOffset += 2

        // Read value length
        let valueLength: UInt32

        if vr.usesShortLength {
            // 2-byte length
            valueLength = UInt32(data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: currentOffset, as: UInt16.self)
            })
            currentOffset += 2
        } else {
            // Skip 2 reserved bytes, then read 4-byte length
            currentOffset += 2
            valueLength = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: currentOffset, as: UInt32.self)
            }
            currentOffset += 4
        }

        // Read value
        let valueData: Data
        if valueLength == 0xFFFFFFFF {
            // Undefined length (for sequences)
            valueData = Data()
        } else {
            guard currentOffset + Int(valueLength) <= data.count else {
                throw DICOMError.invalidFormat(reason: "Value extends beyond file")
            }
            valueData = data[currentOffset..<currentOffset+Int(valueLength)]
            currentOffset += Int(valueLength)
        }

        let element = DICOMElement(
            tag: tag,
            vr: vr,
            valueLength: valueLength,
            data: valueData
        )

        let bytesRead = currentOffset - offset
        return (element, bytesRead)
    }

    private func parseImplicitVRElement(from data: Data, at offset: Int) throws -> (DICOMElement, Int) {
        var currentOffset = offset

        // Read tag (4 bytes)
        let tag = readTag(from: data, at: currentOffset)
        currentOffset += 4

        // Read value length (4 bytes)
        let valueLength = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: currentOffset, as: UInt32.self)
        }
        currentOffset += 4

        // Read value
        let valueData: Data
        if valueLength == 0xFFFFFFFF {
            valueData = Data()
        } else {
            guard currentOffset + Int(valueLength) <= data.count else {
                throw DICOMError.invalidFormat(reason: "Value extends beyond file")
            }
            valueData = data[currentOffset..<currentOffset+Int(valueLength)]
            currentOffset += Int(valueLength)
        }

        let element = DICOMElement(
            tag: tag,
            vr: nil,  // VR is implicit
            valueLength: valueLength,
            data: valueData
        )

        let bytesRead = currentOffset - offset
        return (element, bytesRead)
    }
}
