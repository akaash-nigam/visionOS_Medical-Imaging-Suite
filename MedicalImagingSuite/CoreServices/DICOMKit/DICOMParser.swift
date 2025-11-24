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

            // Process pixel data separately
            if tag == DICOMTag.pixelData.rawValue {
                // Pixel data element is already stored in dataset
                // Continue to process any remaining elements after pixel data if needed
                break
            }
        }

        print("✅ Parsed DICOM file: \(dataset.description())")

        return dataset
    }

    // MARK: - Pixel Data Extraction

    /// Extract and process pixel data from a DICOM dataset
    /// - Parameter dataset: Parsed DICOM dataset containing pixel data
    /// - Returns: Processed pixel data ready for rendering
    /// - Throws: DICOMError if pixel data is invalid or missing required tags
    func extractPixelData(from dataset: DICOMDataset) throws -> ProcessedPixelData {
        // Extract required image dimensions
        guard let rows = dataset.rows else {
            throw DICOMError.missingRequiredTag(.rows)
        }
        guard let columns = dataset.columns else {
            throw DICOMError.missingRequiredTag(.columns)
        }
        guard let rawPixelData = dataset.pixelData else {
            throw DICOMError.missingRequiredTag(.pixelData)
        }

        // Extract pixel description
        let bitsAllocated = dataset.int(for: .bitsAllocated) ?? 16
        let bitsStored = dataset.int(for: .bitsStored) ?? bitsAllocated
        let highBit = dataset.int(for: .highBit) ?? (bitsStored - 1)
        let pixelRepresentation = dataset.int(for: .pixelRepresentation) ?? 0  // 0=unsigned, 1=signed
        let samplesPerPixel = dataset.int(for: .samplesPerPixel) ?? 1
        let photometricInterpretation = dataset.string(for: .photometricInterpretation) ?? "MONOCHROME2"

        // Extract rescale parameters (for CT Hounsfield units)
        let rescaleSlope = dataset.rescaleSlope ?? 1.0
        let rescaleIntercept = dataset.rescaleIntercept ?? 0.0

        // Extract windowing parameters
        let windowCenter = dataset.windowCenter ?? 40.0
        let windowWidth = dataset.windowWidth ?? 400.0

        // Extract pixel spacing (mm)
        let pixelSpacingString = dataset.string(for: .pixelSpacing)
        let pixelSpacing = parsePixelSpacing(pixelSpacingString) ?? SIMD2<Float>(1.0, 1.0)

        // Validate pixel data size
        let expectedSize = rows * columns * samplesPerPixel * (bitsAllocated / 8)
        guard rawPixelData.count >= expectedSize else {
            throw DICOMError.corruptedPixelData
        }

        // Process pixel data based on bit depth and representation
        let processedData: Data
        switch (bitsAllocated, pixelRepresentation, samplesPerPixel) {
        case (8, 0, 1):
            // 8-bit unsigned grayscale
            processedData = processUInt8PixelData(
                rawPixelData,
                rows: rows,
                columns: columns,
                rescaleSlope: rescaleSlope,
                rescaleIntercept: rescaleIntercept
            )

        case (16, 0, 1):
            // 16-bit unsigned grayscale
            processedData = try processUInt16PixelData(
                rawPixelData,
                rows: rows,
                columns: columns,
                rescaleSlope: rescaleSlope,
                rescaleIntercept: rescaleIntercept
            )

        case (16, 1, 1):
            // 16-bit signed grayscale (most common for CT)
            processedData = try processInt16PixelData(
                rawPixelData,
                rows: rows,
                columns: columns,
                rescaleSlope: rescaleSlope,
                rescaleIntercept: rescaleIntercept
            )

        case (_, _, 3):
            // RGB color image
            processedData = rawPixelData  // No rescaling for RGB

        default:
            throw DICOMError.invalidFormat(
                reason: "Unsupported pixel format: \(bitsAllocated)-bit, representation=\(pixelRepresentation), samples=\(samplesPerPixel)"
            )
        }

        return ProcessedPixelData(
            rows: rows,
            columns: columns,
            bitsAllocated: bitsAllocated,
            samplesPerPixel: samplesPerPixel,
            pixelSpacing: pixelSpacing,
            photometricInterpretation: photometricInterpretation,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            rescaleSlope: rescaleSlope,
            rescaleIntercept: rescaleIntercept,
            pixelData: processedData
        )
    }

    // MARK: - Pixel Data Processing

    private func processUInt8PixelData(
        _ data: Data,
        rows: Int,
        columns: Int,
        rescaleSlope: Float,
        rescaleIntercept: Float
    ) -> Data {
        // For 8-bit data, typically no rescaling needed
        // But we'll apply it if non-default values are present
        if rescaleSlope == 1.0 && rescaleIntercept == 0.0 {
            return data
        }

        var processedData = Data(count: data.count)
        for i in 0..<data.count {
            let rawValue = Float(data[i])
            let rescaledValue = rawValue * rescaleSlope + rescaleIntercept
            processedData[i] = UInt8(max(0, min(255, rescaledValue)))
        }

        return processedData
    }

    private func processUInt16PixelData(
        _ data: Data,
        rows: Int,
        columns: Int,
        rescaleSlope: Float,
        rescaleIntercept: Float
    ) throws -> Data {
        let pixelCount = rows * columns
        var processedData = Data(count: pixelCount * 2)

        for i in 0..<pixelCount {
            let offset = i * 2
            guard offset + 1 < data.count else {
                throw DICOMError.corruptedPixelData
            }

            let rawValue = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt16.self)
            }

            let rescaledValue = Float(rawValue) * rescaleSlope + rescaleIntercept
            let finalValue = UInt16(max(0, min(65535, rescaledValue)))

            processedData.withUnsafeMutableBytes { bytes in
                bytes.storeBytes(of: finalValue, toByteOffset: offset, as: UInt16.self)
            }
        }

        return processedData
    }

    private func processInt16PixelData(
        _ data: Data,
        rows: Int,
        columns: Int,
        rescaleSlope: Float,
        rescaleIntercept: Float
    ) throws -> Data {
        // This is the most common format for CT scans
        // Raw values are in "stored pixel values", convert to Hounsfield Units
        let pixelCount = rows * columns
        var processedData = Data(count: pixelCount * 2)

        for i in 0..<pixelCount {
            let offset = i * 2
            guard offset + 1 < data.count else {
                throw DICOMError.corruptedPixelData
            }

            let rawValue = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: Int16.self)
            }

            // Apply rescale to get Hounsfield Units (HU)
            // HU = rawValue * rescaleSlope + rescaleIntercept
            let hounsfieldValue = Float(rawValue) * rescaleSlope + rescaleIntercept

            // Store as Int16 (typical range: -1024 to +3071 HU)
            let finalValue = Int16(max(-32768, min(32767, hounsfieldValue)))

            processedData.withUnsafeMutableBytes { bytes in
                bytes.storeBytes(of: finalValue, toByteOffset: offset, as: Int16.self)
            }
        }

        return processedData
    }

    private func parsePixelSpacing(_ spacingString: String?) -> SIMD2<Float>? {
        guard let spacingString = spacingString else { return nil }

        // Pixel spacing format: "row_spacing\\column_spacing" (in mm)
        let components = spacingString.split(separator: "\\")
        guard components.count == 2,
              let rowSpacing = Float(components[0]),
              let colSpacing = Float(components[1]) else {
            return nil
        }

        return SIMD2<Float>(rowSpacing, colSpacing)
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

// MARK: - Processed Pixel Data

/// Represents extracted and processed pixel data from a DICOM image
struct ProcessedPixelData {
    /// Image dimensions
    let rows: Int
    let columns: Int

    /// Bits allocated per pixel (8 or 16)
    let bitsAllocated: Int

    /// Number of samples per pixel (1 for grayscale, 3 for RGB)
    let samplesPerPixel: Int

    /// Physical spacing between pixels in mm (row, column)
    let pixelSpacing: SIMD2<Float>

    /// Photometric interpretation (MONOCHROME2, RGB, etc.)
    let photometricInterpretation: String

    /// Window/Level parameters for display
    let windowCenter: Float
    let windowWidth: Float

    /// Rescale parameters (for CT Hounsfield units)
    let rescaleSlope: Float
    let rescaleIntercept: Float

    /// Processed pixel data ready for rendering
    /// For 8-bit: Data contains UInt8 values
    /// For 16-bit: Data contains Int16 or UInt16 values
    let pixelData: Data

    /// Total number of pixels
    var pixelCount: Int {
        rows * columns
    }

    /// Memory size in bytes
    var dataSize: Int {
        pixelData.count
    }

    /// Whether this is grayscale or color
    var isGrayscale: Bool {
        samplesPerPixel == 1
    }

    /// Whether this is CT data with Hounsfield units
    var isCTData: Bool {
        rescaleSlope != 1.0 || rescaleIntercept != 0.0
    }
}
