//
//  Patient.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// Represents a patient in the medical imaging system
struct Patient: Identifiable, Codable, Hashable {
    let id: UUID
    let patientID: String           // DICOM (0010,0020)
    let name: PersonName            // DICOM (0010,0010)
    let birthDate: Date?            // DICOM (0010,0030)
    let sex: Sex?                   // DICOM (0010,0040)

    /// Computed age from birth date
    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    init(
        id: UUID = UUID(),
        patientID: String,
        name: PersonName,
        birthDate: Date? = nil,
        sex: Sex? = nil
    ) {
        self.id = id
        self.patientID = patientID
        self.name = name
        self.birthDate = birthDate
        self.sex = sex
    }
}

/// Patient name components following DICOM PN (Person Name) format
struct PersonName: Codable, Hashable {
    let familyName: String
    let givenName: String
    let middleName: String?
    let prefix: String?
    let suffix: String?

    /// Formatted name for display (e.g., "Dr. John M. Doe Jr.")
    var formatted: String {
        var components: [String] = []

        if let prefix = prefix {
            components.append(prefix)
        }

        components.append(givenName)

        if let middleName = middleName {
            components.append(middleName)
        }

        components.append(familyName)

        if let suffix = suffix {
            components.append(suffix)
        }

        return components.joined(separator: " ")
    }

    /// DICOM format (Family^Given^Middle^Prefix^Suffix)
    var dicomFormat: String {
        [
            familyName,
            givenName,
            middleName ?? "",
            prefix ?? "",
            suffix ?? ""
        ].joined(separator: "^")
    }

    init(
        familyName: String,
        givenName: String,
        middleName: String? = nil,
        prefix: String? = nil,
        suffix: String? = nil
    ) {
        self.familyName = familyName
        self.givenName = givenName
        self.middleName = middleName
        self.prefix = prefix
        self.suffix = suffix
    }

    /// Parse from DICOM format string
    static func from(dicomString: String) -> PersonName {
        let components = dicomString.split(separator: "^", maxSplits: 4, omittingEmptySubsequences: false)

        return PersonName(
            familyName: components.count > 0 ? String(components[0]) : "",
            givenName: components.count > 1 ? String(components[1]) : "",
            middleName: components.count > 2 && !components[2].isEmpty ? String(components[2]) : nil,
            prefix: components.count > 3 && !components[3].isEmpty ? String(components[3]) : nil,
            suffix: components.count > 4 && !components[4].isEmpty ? String(components[4]) : nil
        )
    }
}

/// Patient sex following DICOM standard
enum Sex: String, Codable {
    case male = "M"
    case female = "F"
    case other = "O"
    case unknown = "U"
}

// MARK: - Sample Data

extension Patient {
    static let sample = Patient(
        id: UUID(),
        patientID: "12345",
        name: PersonName(
            familyName: "Doe",
            givenName: "John",
            middleName: "M"
        ),
        birthDate: Calendar.current.date(byAdding: .year, value: -45, to: Date()),
        sex: .male
    )
}
