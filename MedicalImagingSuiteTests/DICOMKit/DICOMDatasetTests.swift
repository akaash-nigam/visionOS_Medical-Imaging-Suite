//
//  DICOMDatasetTests.swift
//  MedicalImagingSuiteTests
//
//  Created by Claude on 2025-11-24.
//

import XCTest
@testable import MedicalImagingSuite

final class DICOMDatasetTests: XCTestCase {
    var dataset: DICOMDataset!

    override func setUp() {
        super.setUp()
        dataset = DICOMDataset()
    }

    override func tearDown() {
        dataset = nil
        super.tearDown()
    }

    // MARK: - Element Storage Tests

    func testSetAndGetElement() {
        let element = DICOMElement(
            tag: DICOMTag.patientName.rawValue,
            vr: .PN,
            valueLength: 8,
            data: "Doe^John".data(using: .ascii)!
        )

        dataset.set(tag: .patientName, element: element)

        let retrieved = dataset.get(tag: .patientName)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.stringValue, "Doe^John")
    }

    func testContainsTag() {
        XCTAssertFalse(dataset.contains(tag: .patientName))

        let element = DICOMElement(
            tag: DICOMTag.patientName.rawValue,
            vr: .PN,
            valueLength: 8,
            data: "Doe^John".data(using: .ascii)!
        )
        dataset.set(tag: .patientName, element: element)

        XCTAssertTrue(dataset.contains(tag: .patientName))
    }

    func testRemoveTag() {
        let element = DICOMElement(
            tag: DICOMTag.patientName.rawValue,
            vr: .PN,
            valueLength: 8,
            data: "Doe^John".data(using: .ascii)!
        )
        dataset.set(tag: .patientName, element: element)

        XCTAssertTrue(dataset.contains(tag: .patientName))

        dataset.remove(tag: .patientName)

        XCTAssertFalse(dataset.contains(tag: .patientName))
    }

    // MARK: - String Value Tests

    func testStringValueExtraction() {
        let testString = "Test String"
        let element = DICOMElement(
            tag: DICOMTag.studyDescription.rawValue,
            vr: .LO,
            valueLength: UInt32(testString.count),
            data: testString.data(using: .ascii)!
        )

        XCTAssertEqual(element.stringValue, testString)
    }

    func testStringValueWithPadding() {
        // DICOM strings are often null-padded
        var data = "Test".data(using: .ascii)!
        data.append(0x00)  // Null padding

        let element = DICOMElement(
            tag: DICOMTag.studyDescription.rawValue,
            vr: .LO,
            valueLength: UInt32(data.count),
            data: data
        )

        XCTAssertEqual(element.stringValue, "Test")
    }

    // MARK: - Integer Value Tests

    func testIntegerValue16Bit() {
        let value: UInt16 = 512
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: value) { Array($0) })

        let element = DICOMElement(
            tag: DICOMTag.rows.rawValue,
            vr: .US,
            valueLength: 2,
            data: data
        )

        XCTAssertEqual(element.intValue, 512)
    }

    func testIntegerValue32Bit() {
        let value: UInt32 = 1024
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: value) { Array($0) })

        let element = DICOMElement(
            tag: DICOMTag.instanceNumber.rawValue,
            vr: .UL,
            valueLength: 4,
            data: data
        )

        XCTAssertEqual(element.intValue, 1024)
    }

    func testIntegerValueFromString() {
        // Some integer values are stored as strings (IS VR)
        let element = DICOMElement(
            tag: DICOMTag.instanceNumber.rawValue,
            vr: .IS,
            valueLength: 3,
            data: "123".data(using: .ascii)!
        )

        XCTAssertEqual(element.intValue, 123)
    }

    // MARK: - Float Value Tests

    func testFloatValue() {
        let value: Float = 0.7
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: value) { Array($0) })

        let element = DICOMElement(
            tag: DICOMTag.pixelSpacing.rawValue,
            vr: .FL,
            valueLength: 4,
            data: data
        )

        XCTAssertEqual(element.floatValue, 0.7, accuracy: 0.001)
    }

    func testFloatValueFromString() {
        // Some float values are stored as strings (DS VR)
        let element = DICOMElement(
            tag: DICOMTag.pixelSpacing.rawValue,
            vr: .DS,
            valueLength: 3,
            data: "0.7".data(using: .ascii)!
        )

        XCTAssertEqual(element.floatValue, 0.7, accuracy: 0.001)
    }

    // MARK: - Date Value Tests

    func testDateValueExtraction() {
        // DICOM date format: YYYYMMDD
        let element = DICOMElement(
            tag: DICOMTag.studyDate.rawValue,
            vr: .DA,
            valueLength: 8,
            data: "20231124".data(using: .ascii)!
        )

        XCTAssertNotNil(element.dateValue)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: element.dateValue!)

        XCTAssertEqual(components.year, 2023)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 24)
    }

    func testTimeValueExtraction() {
        // DICOM time format: HHMMSS
        let element = DICOMElement(
            tag: DICOMTag.studyTime.rawValue,
            vr: .TM,
            valueLength: 6,
            data: "143022".data(using: .ascii)!
        )

        XCTAssertNotNil(element.timeValue)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: element.timeValue!)

        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
        XCTAssertEqual(components.second, 22)
    }

    // MARK: - Convenience Accessor Tests

    func testPatientNameAccessor() {
        let element = DICOMElement(
            tag: DICOMTag.patientName.rawValue,
            vr: .PN,
            valueLength: 8,
            data: "Doe^John".data(using: .ascii)!
        )
        dataset.set(tag: .patientName, element: element)

        XCTAssertEqual(dataset.patientName, "Doe^John")
        XCTAssertEqual(dataset.string(for: .patientName), "Doe^John")
    }

    func testRowsColumnsAccessors() {
        var rowsData = Data()
        let rows: UInt16 = 512
        rowsData.append(contentsOf: withUnsafeBytes(of: rows) { Array($0) })

        let rowsElement = DICOMElement(
            tag: DICOMTag.rows.rawValue,
            vr: .US,
            valueLength: 2,
            data: rowsData
        )
        dataset.set(tag: .rows, element: rowsElement)

        var colsData = Data()
        let cols: UInt16 = 512
        colsData.append(contentsOf: withUnsafeBytes(of: cols) { Array($0) })

        let colsElement = DICOMElement(
            tag: DICOMTag.columns.rawValue,
            vr: .US,
            valueLength: 2,
            data: colsData
        )
        dataset.set(tag: .columns, element: colsElement)

        XCTAssertEqual(dataset.rows, 512)
        XCTAssertEqual(dataset.columns, 512)
    }

    func testMissingValueReturnsNil() {
        XCTAssertNil(dataset.patientName)
        XCTAssertNil(dataset.studyInstanceUID)
        XCTAssertNil(dataset.rows)
    }
}
