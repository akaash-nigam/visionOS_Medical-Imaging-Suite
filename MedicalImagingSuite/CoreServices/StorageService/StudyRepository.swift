//
//  StudyRepository.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import CoreData
import Foundation

/// Protocol for study data access
protocol StudyRepository {
    func fetchStudy(uid: String) async throws -> Study?
    func fetchAllStudies() async throws -> [Study]
    func fetchRecentStudies(limit: Int) async throws -> [Study]
    func saveStudy(_ study: Study) async throws
    func deleteStudy(uid: String) async throws
    func setExpiration(studyUID: String, expiresAt: Date) async throws
    func fetchExpiredStudies() async throws -> [Study]
}

/// Core Data implementation of StudyRepository
actor CoreDataStudyRepository: StudyRepository {
    private let stack = CoreDataStack.shared

    func fetchStudy(uid: String) async throws -> Study? {
        let context = stack.viewContext

        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StudyEntity")
            fetchRequest.predicate = NSPredicate(format: "studyInstanceUID == %@", uid)
            fetchRequest.fetchLimit = 1

            // Note: In real implementation, this would fetch actual managed objects
            // For now, returning nil since we don't have the actual Core Data model yet
            // This will be functional once .xcdatamodeld is created in Xcode

            // guard let entity = try context.fetch(fetchRequest).first else {
            //     return nil
            // }
            // return self.mapToDomain(entity)

            return nil  // Placeholder until Core Data model is created
        }
    }

    func fetchAllStudies() async throws -> [Study] {
        let context = stack.viewContext

        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StudyEntity")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "studyDate", ascending: false)]

            // let entities = try context.fetch(fetchRequest)
            // return entities.map { self.mapToDomain($0) }

            return []  // Placeholder
        }
    }

    func fetchRecentStudies(limit: Int = 20) async throws -> [Study] {
        let context = stack.viewContext

        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StudyEntity")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastAccessedAt", ascending: false)]
            fetchRequest.fetchLimit = limit

            // let entities = try context.fetch(fetchRequest)
            // return entities.map { self.mapToDomain($0) }

            return []  // Placeholder
        }
    }

    func saveStudy(_ study: Study) async throws {
        let context = stack.newBackgroundContext()

        try await context.perform {
            // Check if study exists
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StudyEntity")
            fetchRequest.predicate = NSPredicate(format: "studyInstanceUID == %@", study.studyInstanceUID)
            fetchRequest.fetchLimit = 1

            // let existingEntity = try? context.fetch(fetchRequest).first

            // if let existing = existingEntity {
            //     // Update existing
            //     self.mapToEntity(study, entity: existing)
            // } else {
            //     // Create new
            //     let entity = NSEntityDescription.insertNewObject(forEntityName: "StudyEntity", into: context)
            //     self.mapToEntity(study, entity: entity)
            // }

            // entity.setValue(Date(), forKey: "lastAccessedAt")
            // try context.save()

            print("✅ Study saved (placeholder): \(study.studyInstanceUID)")
        }
    }

    func deleteStudy(uid: String) async throws {
        let context = stack.newBackgroundContext()

        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StudyEntity")
            fetchRequest.predicate = NSPredicate(format: "studyInstanceUID == %@", uid)

            // if let entity = try context.fetch(fetchRequest).first {
            //     context.delete(entity)
            //     try context.save()
            //     print("✅ Study deleted: \(uid)")
            // }
        }
    }

    func setExpiration(studyUID: String, expiresAt: Date) async throws {
        let context = stack.newBackgroundContext()

        try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StudyEntity")
            fetchRequest.predicate = NSPredicate(format: "studyInstanceUID == %@", studyUID)
            fetchRequest.fetchLimit = 1

            // if let entity = try context.fetch(fetchRequest).first {
            //     entity.setValue(expiresAt, forKey: "cacheExpiresAt")
            //     try context.save()
            // }
        }
    }

    func fetchExpiredStudies() async throws -> [Study] {
        let context = stack.viewContext
        let now = Date()

        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StudyEntity")
            fetchRequest.predicate = NSPredicate(format: "cacheExpiresAt < %@", now as NSDate)

            // let entities = try context.fetch(fetchRequest)
            // return entities.map { self.mapToDomain($0) }

            return []  // Placeholder
        }
    }

    // MARK: - Mapping (Domain ↔ Core Data)

    // These will be implemented once Core Data model is created
    /*
    private func mapToDomain(_ entity: NSManagedObject) -> Study {
        let id = entity.value(forKey: "id") as! UUID
        let studyInstanceUID = entity.value(forKey: "studyInstanceUID") as! String
        let studyDate = entity.value(forKey: "studyDate") as? Date
        let studyDescription = entity.value(forKey: "studyDescription") as? String
        // ... map all fields

        let patient = mapPatientToDomain(entity.value(forKey: "patient") as! NSManagedObject)
        let series = (entity.value(forKey: "series") as? Set<NSManagedObject>)?.map { mapSeriesToDomain($0) } ?? []

        return Study(
            id: id,
            studyInstanceUID: studyInstanceUID,
            studyDate: studyDate,
            studyDescription: studyDescription,
            patient: patient,
            series: series
        )
    }

    private func mapToEntity(_ study: Study, entity: NSManagedObject) {
        entity.setValue(study.id, forKey: "id")
        entity.setValue(study.studyInstanceUID, forKey: "studyInstanceUID")
        entity.setValue(study.studyDate, forKey: "studyDate")
        entity.setValue(study.studyDescription, forKey: "studyDescription")
        // ... map all fields
    }
    */
}

// MARK: - Storage Service

/// High-level storage service
actor StorageService {
    let studyRepository: StudyRepository
    private let fileManager = FileManager.default

    init(studyRepository: StudyRepository = CoreDataStudyRepository()) {
        self.studyRepository = studyRepository
    }

    /// Save a study with automatic cache expiration
    func saveStudy(_ study: Study, cacheRetentionDays: Int = 7) async throws {
        try await studyRepository.saveStudy(study)

        let expirationDate = Calendar.current.date(byAdding: .day, value: cacheRetentionDays, to: Date())!
        try await studyRepository.setExpiration(studyUID: study.studyInstanceUID, expiresAt: expirationDate)
    }

    /// Retrieve a study and update last accessed time
    func retrieveStudy(uid: String) async throws -> Study? {
        guard let study = try await studyRepository.fetchStudy(uid: uid) else {
            return nil
        }

        // Update last accessed time
        try await studyRepository.saveStudy(study)

        return study
    }

    /// Get recent studies
    func getRecentStudies(limit: Int = 20) async throws -> [Study] {
        try await studyRepository.fetchRecentStudies(limit: limit)
    }

    /// Clean up expired studies
    func cleanupExpiredStudies() async throws {
        let expiredStudies = try await studyRepository.fetchExpiredStudies()

        for study in expiredStudies {
            // Delete from Core Data
            try await studyRepository.deleteStudy(uid: study.studyInstanceUID)

            // Delete DICOM files
            try await deleteDICOMFiles(for: study.studyInstanceUID)

            print("✅ Cleaned up expired study: \(study.studyInstanceUID)")
        }
    }

    /// Get total cache size
    func getCacheSize() async -> UInt64 {
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return 0
        }

        let dicomCacheURL = cachesURL.appendingPathComponent("DICOM", isDirectory: true)

        var totalSize: UInt64 = 0

        if let enumerator = fileManager.enumerator(at: dicomCacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += UInt64(fileSize)
                }
            }
        }

        return totalSize
    }

    // MARK: - Private Helpers

    private func deleteDICOMFiles(for studyUID: String) async throws {
        guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let studyDirectory = cachesURL
            .appendingPathComponent("DICOM", isDirectory: true)
            .appendingPathComponent(studyUID, isDirectory: true)

        if fileManager.fileExists(atPath: studyDirectory.path) {
            try fileManager.removeItem(at: studyDirectory)
        }
    }
}

// MARK: - Storage Errors

enum StorageError: Error, LocalizedError {
    case saveFailed(reason: String)
    case fetchFailed(reason: String)
    case deleteFailed(reason: String)
    case diskFull
    case corruptedData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let reason):
            return "Failed to save: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete: \(reason)"
        case .diskFull:
            return "Disk is full"
        case .corruptedData:
            return "Data is corrupted"
        }
    }
}
