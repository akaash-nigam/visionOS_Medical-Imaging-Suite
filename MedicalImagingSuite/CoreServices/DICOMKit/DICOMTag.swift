//
//  DICOMTag.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// DICOM data element tags (group, element)
/// Format: 0xGGGGEEEE where GGGG is group and EEEE is element
enum DICOMTag: UInt32, CaseIterable {
    // MARK: - Patient Information (Group 0010)
    case patientName = 0x00100010
    case patientID = 0x00100020
    case patientBirthDate = 0x00100030
    case patientSex = 0x00100040
    case patientAge = 0x00101010
    case patientWeight = 0x00101030

    // MARK: - Study Information (Group 0008, 0020)
    case studyDate = 0x00080020
    case seriesDate = 0x00080021
    case acquisitionDate = 0x00080022
    case studyTime = 0x00080030
    case seriesTime = 0x00080031
    case acquisitionTime = 0x00080032
    case accessionNumber = 0x00080050
    case modality = 0x00080060
    case manufacturer = 0x00080070
    case institutionName = 0x00080080
    case studyDescription = 0x00081030
    case seriesDescription = 0x0008103E
    case performingPhysicianName = 0x00081050

    // MARK: - Study/Series/Instance UIDs (Group 0020)
    case studyInstanceUID = 0x0020000D
    case seriesInstanceUID = 0x0020000E
    case studyID = 0x00200010
    case seriesNumber = 0x00200011
    case acquisitionNumber = 0x00200012
    case instanceNumber = 0x00200013
    case imagePositionPatient = 0x00200032
    case imageOrientationPatient = 0x00200037
    case frameOfReferenceUID = 0x00200052
    case sliceLocation = 0x00201041
    case numberOfFrames = 0x00280008

    // MARK: - Image Pixel Description (Group 0028)
    case samplesPerPixel = 0x00280002
    case photometricInterpretation = 0x00280004
    case rows = 0x00280010
    case columns = 0x00280011
    case pixelSpacing = 0x00280030
    case bitsAllocated = 0x00280100
    case bitsStored = 0x00280101
    case highBit = 0x00280102
    case pixelRepresentation = 0x00280103
    case windowCenter = 0x00281050
    case windowWidth = 0x00281051
    case rescaleIntercept = 0x00281052
    case rescaleSlope = 0x00281053
    case rescaleType = 0x00281054

    // MARK: - Pixel Data (Group 7FE0)
    case pixelData = 0x7FE00010

    // MARK: - Transfer Syntax & Meta Information (Group 0002)
    case transferSyntaxUID = 0x00020010
    case implementationClassUID = 0x00020012
    case implementationVersionName = 0x00020013

    // MARK: - SOP (Service-Object Pair) (Group 0008)
    case sopClassUID = 0x00080016
    case sopInstanceUID = 0x00080018

    /// Tag as (group, element) tuple
    var components: (group: UInt16, element: UInt16) {
        let value = self.rawValue
        let group = UInt16((value >> 16) & 0xFFFF)
        let element = UInt16(value & 0xFFFF)
        return (group, element)
    }

    /// Human-readable tag name
    var name: String {
        switch self {
        case .patientName: return "Patient's Name"
        case .patientID: return "Patient ID"
        case .patientBirthDate: return "Patient's Birth Date"
        case .patientSex: return "Patient's Sex"
        case .studyInstanceUID: return "Study Instance UID"
        case .seriesInstanceUID: return "Series Instance UID"
        case .sopInstanceUID: return "SOP Instance UID"
        case .studyDate: return "Study Date"
        case .studyDescription: return "Study Description"
        case .seriesDescription: return "Series Description"
        case .modality: return "Modality"
        case .rows: return "Rows"
        case .columns: return "Columns"
        case .pixelSpacing: return "Pixel Spacing"
        case .pixelData: return "Pixel Data"
        case .windowCenter: return "Window Center"
        case .windowWidth: return "Window Width"
        case .rescaleSlope: return "Rescale Slope"
        case .rescaleIntercept: return "Rescale Intercept"
        default: return "(\(String(format: "%04X", components.group)),\(String(format: "%04X", components.element)))"
        }
    }

    /// Create tag from group and element
    static func make(group: UInt16, element: UInt16) -> UInt32 {
        (UInt32(group) << 16) | UInt32(element)
    }

    /// Create tag from raw value if it exists in enum
    static func from(rawValue: UInt32) -> DICOMTag? {
        DICOMTag(rawValue: rawValue)
    }
}

/// Value Representation (VR) defines the data type of a DICOM element
enum ValueRepresentation: String {
    // MARK: - String Types
    case AE = "AE"  // Application Entity
    case AS = "AS"  // Age String
    case CS = "CS"  // Code String
    case DA = "DA"  // Date
    case DS = "DS"  // Decimal String
    case DT = "DT"  // Date Time
    case IS = "IS"  // Integer String
    case LO = "LO"  // Long String
    case LT = "LT"  // Long Text
    case PN = "PN"  // Person Name
    case SH = "SH"  // Short String
    case ST = "ST"  // Short Text
    case TM = "TM"  // Time
    case UC = "UC"  // Unlimited Characters
    case UI = "UI"  // Unique Identifier
    case UR = "UR"  // URI/URL
    case UT = "UT"  // Unlimited Text

    // MARK: - Numeric Types
    case FL = "FL"  // Floating Point Single
    case FD = "FD"  // Floating Point Double
    case SL = "SL"  // Signed Long
    case SS = "SS"  // Signed Short
    case UL = "UL"  // Unsigned Long
    case US = "US"  // Unsigned Short

    // MARK: - Binary Types
    case AT = "AT"  // Attribute Tag
    case OB = "OB"  // Other Byte
    case OD = "OD"  // Other Double
    case OF = "OF"  // Other Float
    case OL = "OL"  // Other Long
    case OW = "OW"  // Other Word
    case OV = "OV"  // Other 64-bit Very Long

    // MARK: - Special Types
    case SQ = "SQ"  // Sequence of Items
    case UN = "UN"  // Unknown

    /// Whether this VR uses 2-byte or 4-byte value length
    var usesShortLength: Bool {
        switch self {
        case .OB, .OD, .OF, .OL, .OW, .OV, .SQ, .UC, .UR, .UT, .UN:
            return false  // 4-byte length
        default:
            return true   // 2-byte length
        }
    }

    /// Expected data type
    var dataType: DICOMDataType {
        switch self {
        case .AE, .AS, .CS, .DA, .DS, .DT, .IS, .LO, .LT, .PN, .SH, .ST, .TM, .UC, .UI, .UR, .UT:
            return .string
        case .FL, .FD, .DS:
            return .float
        case .SL, .SS, .IS:
            return .signedInt
        case .UL, .US:
            return .unsignedInt
        case .OB, .OW, .OD, .OF, .OL, .OV, .UN:
            return .binary
        case .AT:
            return .attributeTag
        case .SQ:
            return .sequence
        }
    }
}

/// DICOM data type categories
enum DICOMDataType {
    case string
    case signedInt
    case unsignedInt
    case float
    case binary
    case attributeTag
    case sequence
}

/// Common DICOM transfer syntax UIDs
enum TransferSyntax: String {
    case implicitVRLittleEndian = "1.2.840.10008.1.2"
    case explicitVRLittleEndian = "1.2.840.10008.1.2.1"
    case explicitVRBigEndian = "1.2.840.10008.1.2.2"
    case jpegBaseline = "1.2.840.10008.1.2.4.50"
    case jpegLossless = "1.2.840.10008.1.2.4.57"
    case jpeg2000Lossless = "1.2.840.10008.1.2.4.90"
    case jpeg2000 = "1.2.840.10008.1.2.4.91"
    case rle = "1.2.840.10008.1.2.5"

    var isCompressed: Bool {
        switch self {
        case .implicitVRLittleEndian, .explicitVRLittleEndian, .explicitVRBigEndian:
            return false
        default:
            return true
        }
    }

    var isLittleEndian: Bool {
        self != .explicitVRBigEndian
    }

    var isExplicitVR: Bool {
        self != .implicitVRLittleEndian
    }
}
