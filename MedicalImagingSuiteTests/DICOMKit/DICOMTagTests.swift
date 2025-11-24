//
//  DICOMTagTests.swift
//  MedicalImagingSuiteTests
//
//  Created by Claude on 2025-11-24.
//

import XCTest
@testable import MedicalImagingSuite

final class DICOMTagTests: XCTestCase {

    func testTagRawValues() {
        // Test that tags have correct group/element values
        XCTAssertEqual(DICOMTag.patientName.rawValue, 0x00100010)
        XCTAssertEqual(DICOMTag.studyInstanceUID.rawValue, 0x0020000D)
        XCTAssertEqual(DICOMTag.pixelData.rawValue, 0x7FE00010)
    }

    func testTagComponents() {
        let tag = DICOMTag.patientName
        let (group, element) = tag.components

        XCTAssertEqual(group, 0x0010)
        XCTAssertEqual(element, 0x0010)
    }

    func testTagNames() {
        XCTAssertEqual(DICOMTag.patientName.name, "Patient's Name")
        XCTAssertEqual(DICOMTag.studyInstanceUID.name, "Study Instance UID")
        XCTAssertEqual(DICOMTag.rows.name, "Rows")
    }

    func testMakeTag() {
        let tag = DICOMTag.make(group: 0x0010, element: 0x0010)
        XCTAssertEqual(tag, 0x00100010)
        XCTAssertEqual(tag, DICOMTag.patientName.rawValue)
    }

    func testValueRepresentationShortLength() {
        // These VRs use 2-byte length
        XCTAssertTrue(ValueRepresentation.PN.usesShortLength)
        XCTAssertTrue(ValueRepresentation.US.usesShortLength)
        XCTAssertTrue(ValueRepresentation.DA.usesShortLength)

        // These VRs use 4-byte length
        XCTAssertFalse(ValueRepresentation.OB.usesShortLength)
        XCTAssertFalse(ValueRepresentation.OW.usesShortLength)
        XCTAssertFalse(ValueRepresentation.SQ.usesShortLength)
    }

    func testValueRepresentationDataTypes() {
        XCTAssertEqual(ValueRepresentation.PN.dataType, .string)
        XCTAssertEqual(ValueRepresentation.US.dataType, .unsignedInt)
        XCTAssertEqual(ValueRepresentation.SS.dataType, .signedInt)
        XCTAssertEqual(ValueRepresentation.FL.dataType, .float)
        XCTAssertEqual(ValueRepresentation.OB.dataType, .binary)
        XCTAssertEqual(ValueRepresentation.SQ.dataType, .sequence)
    }

    func testTransferSyntaxProperties() {
        let implicit = TransferSyntax.implicitVRLittleEndian
        XCTAssertFalse(implicit.isCompressed)
        XCTAssertTrue(implicit.isLittleEndian)
        XCTAssertFalse(implicit.isExplicitVR)

        let explicit = TransferSyntax.explicitVRLittleEndian
        XCTAssertFalse(explicit.isCompressed)
        XCTAssertTrue(explicit.isLittleEndian)
        XCTAssertTrue(explicit.isExplicitVR)

        let jpeg = TransferSyntax.jpegBaseline
        XCTAssertTrue(jpeg.isCompressed)
        XCTAssertTrue(jpeg.isLittleEndian)
    }

    func testAllTagsCaseIterable() {
        // Ensure we can iterate all tags
        let allTags = DICOMTag.allCases
        XCTAssertGreaterThan(allTags.count, 50, "Should have at least 50 tags defined")

        // Check some key tags are included
        XCTAssertTrue(allTags.contains(.patientName))
        XCTAssertTrue(allTags.contains(.studyInstanceUID))
        XCTAssertTrue(allTags.contains(.pixelData))
    }
}
