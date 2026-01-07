//
//  User.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import Foundation

/// Represents an application user (physician, radiologist, etc.)
struct User: Identifiable, Codable {
    let id: UUID
    let username: String
    let email: String
    let role: UserRole
    let hospitalID: String?

    init(
        id: UUID = UUID(),
        username: String,
        email: String = "",
        role: UserRole = .physician,
        hospitalID: String? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.role = role
        self.hospitalID = hospitalID
    }
}

/// User roles with different permission levels
enum UserRole: String, Codable, CaseIterable {
    case physician
    case radiologist
    case surgeon
    case resident
    case medicalStudent
    case administrator

    var displayName: String {
        switch self {
        case .physician: return "Physician"
        case .radiologist: return "Radiologist"
        case .surgeon: return "Surgeon"
        case .resident: return "Resident"
        case .medicalStudent: return "Medical Student"
        case .administrator: return "Administrator"
        }
    }

    /// Permissions for this role
    var permissions: Set<Permission> {
        switch self {
        case .physician, .radiologist, .surgeon:
            return [.viewStudies, .annotate, .export, .collaborate, .generateReports]
        case .resident:
            return [.viewStudies, .annotate, .collaborate]
        case .medicalStudent:
            return [.viewStudies]
        case .administrator:
            return Set(Permission.allCases)
        }
    }
}

/// Granular permissions for access control
enum Permission: String, Codable, CaseIterable {
    case viewStudies
    case downloadStudies
    case annotate
    case export
    case collaborate
    case generateReports
    case manageUsers
    case viewAuditLogs
    case configurePACS
}

// MARK: - Sample Data

extension User {
    static let sample = User(
        id: UUID(),
        username: "drsmith",
        email: "smith@hospital.com",
        role: .radiologist,
        hospitalID: "HOSP-001"
    )
}
