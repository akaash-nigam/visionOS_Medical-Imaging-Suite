//
//  PatientTests.swift
//  MedicalImagingSuiteTests
//
//  Created by Claude on 2025-11-24.
//

import XCTest
@testable import MedicalImagingSuite

final class PatientTests: XCTestCase {

    func testPatientInitialization() {
        let patient = Patient(
            patientID: "12345",
            name: PersonName(familyName: "Doe", givenName: "John"),
            birthDate: Date(),
            sex: .male
        )

        XCTAssertEqual(patient.patientID, "12345")
        XCTAssertEqual(patient.name.familyName, "Doe")
        XCTAssertEqual(patient.name.givenName, "John")
        XCTAssertEqual(patient.sex, .male)
    }

    func testPatientAgeCalculation() {
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -45, to: Date())!

        let patient = Patient(
            patientID: "12345",
            name: PersonName(familyName: "Doe", givenName: "John"),
            birthDate: birthDate,
            sex: .male
        )

        XCTAssertEqual(patient.age, 45)
    }

    func testPatientAgeWhenBirthDateIsNil() {
        let patient = Patient(
            patientID: "12345",
            name: PersonName(familyName: "Doe", givenName: "John"),
            birthDate: nil
        )

        XCTAssertNil(patient.age)
    }

    func testPersonNameFormatted() {
        let name = PersonName(
            familyName: "Doe",
            givenName: "John",
            middleName: "M",
            prefix: "Dr.",
            suffix: "Jr."
        )

        XCTAssertEqual(name.formatted, "Dr. John M Doe Jr.")
    }

    func testPersonNameFormattedWithoutOptionals() {
        let name = PersonName(
            familyName: "Doe",
            givenName: "John"
        )

        XCTAssertEqual(name.formatted, "John Doe")
    }

    func testPersonNameDICOMFormat() {
        let name = PersonName(
            familyName: "Doe",
            givenName: "John",
            middleName: "M",
            prefix: "Dr.",
            suffix: "Jr."
        )

        XCTAssertEqual(name.dicomFormat, "Doe^John^M^Dr.^Jr.")
    }

    func testPersonNameFromDICOMString() {
        let dicomString = "Doe^John^M^Dr.^Jr."
        let name = PersonName.from(dicomString: dicomString)

        XCTAssertEqual(name.familyName, "Doe")
        XCTAssertEqual(name.givenName, "John")
        XCTAssertEqual(name.middleName, "M")
        XCTAssertEqual(name.prefix, "Dr.")
        XCTAssertEqual(name.suffix, "Jr.")
    }

    func testPersonNameFromDICOMStringMinimal() {
        let dicomString = "Doe^John"
        let name = PersonName.from(dicomString: dicomString)

        XCTAssertEqual(name.familyName, "Doe")
        XCTAssertEqual(name.givenName, "John")
        XCTAssertNil(name.middleName)
        XCTAssertNil(name.prefix)
        XCTAssertNil(name.suffix)
    }

    func testPersonNameFromDICOMStringWithEmptyComponents() {
        let dicomString = "Doe^John^^Dr."  // Empty middle name
        let name = PersonName.from(dicomString: dicomString)

        XCTAssertEqual(name.familyName, "Doe")
        XCTAssertEqual(name.givenName, "John")
        XCTAssertNil(name.middleName)
        XCTAssertEqual(name.prefix, "Dr.")
        XCTAssertNil(name.suffix)
    }

    func testSexEnum() {
        XCTAssertEqual(Sex.male.rawValue, "M")
        XCTAssertEqual(Sex.female.rawValue, "F")
        XCTAssertEqual(Sex.other.rawValue, "O")
        XCTAssertEqual(Sex.unknown.rawValue, "U")
    }

    func testPatientCodable() throws {
        let patient = Patient(
            patientID: "12345",
            name: PersonName(familyName: "Doe", givenName: "John"),
            birthDate: Date(),
            sex: .male
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(patient)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Patient.self, from: data)

        XCTAssertEqual(decoded.patientID, patient.patientID)
        XCTAssertEqual(decoded.name.familyName, patient.name.familyName)
        XCTAssertEqual(decoded.name.givenName, patient.name.givenName)
        XCTAssertEqual(decoded.sex, patient.sex)
    }

    func testPatientHashable() {
        let patient1 = Patient(
            patientID: "12345",
            name: PersonName(familyName: "Doe", givenName: "John")
        )

        let patient2 = Patient(
            patientID: "12345",
            name: PersonName(familyName: "Doe", givenName: "John")
        )

        // Same values but different instances should hash differently (due to UUID)
        XCTAssertNotEqual(patient1, patient2)

        // But if we use the same instance
        let patient3 = patient1
        XCTAssertEqual(patient1, patient3)
    }

    func testSampleData() {
        let sample = Patient.sample

        XCTAssertNotNil(sample.id)
        XCTAssertEqual(sample.patientID, "12345")
        XCTAssertEqual(sample.sex, .male)
    }
}
