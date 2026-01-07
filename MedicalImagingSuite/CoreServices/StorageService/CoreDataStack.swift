//
//  CoreDataStack.swift
//  MedicalImagingSuite
//
//  Created by Claude on 2025-11-24.
//

import CoreData
import Foundation

/// Core Data stack for persistent storage
actor CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "MedicalImaging")

        // Configure persistent store
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Load persistent stores
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
            print("✅ Core Data store loaded: \(description.url?.lastPathComponent ?? "unknown")")
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
    }

    /// Main thread context for UI
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Create a new background context for async operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        return context
    }

    /// Save context if it has changes
    func save(context: NSManagedObjectContext) async throws {
        guard context.hasChanges else { return }

        try await context.perform {
            do {
                try context.save()
            } catch {
                print("❌ Failed to save context: \(error)")
                throw error
            }
        }
    }

    /// Delete all data (for testing/debugging)
    func deleteAllData() async throws {
        let context = newBackgroundContext()

        try await context.perform {
            let entities = ["PatientEntity", "StudyEntity", "SeriesEntity", "ImageEntity", "AnnotationEntity", "UserEntity", "AuditEventEntity"]

            for entityName in entities {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                try context.execute(deleteRequest)
            }

            try context.save()
            print("✅ Deleted all Core Data records")
        }
    }
}

// MARK: - Core Data Entity Extensions

/// Since we can't create .xcdatamodeld file programmatically,
/// these are the entity definitions that would be in the data model:

/*
 Entity: PatientEntity
 Attributes:
   - id: UUID
   - patientID: String (indexed)
   - familyName: String
   - givenName: String
   - middleName: String (optional)
   - birthDate: Date (optional)
   - sex: String (optional)
   - encryptedData: Binary Data (for PHI encryption)
   - createdAt: Date
   - lastAccessedAt: Date (indexed)

 Relationships:
   - studies: To-Many → StudyEntity

 ---

 Entity: StudyEntity
 Attributes:
   - id: UUID
   - studyInstanceUID: String (indexed, unique)
   - studyDate: Date (optional, indexed)
   - studyTime: Date (optional)
   - studyDescription: String (optional)
   - accessionNumber: String (optional)
   - modalitiesRaw: String (comma-separated)
   - createdAt: Date
   - lastAccessedAt: Date (indexed)
   - cacheExpiresAt: Date (indexed)

 Relationships:
   - patient: To-One → PatientEntity (inverse: studies)
   - series: To-Many → SeriesEntity (cascade delete)
   - annotations: To-Many → AnnotationEntity (cascade delete)

 ---

 Entity: SeriesEntity
 Attributes:
   - id: UUID
   - seriesInstanceUID: String (indexed, unique)
   - seriesNumber: Int32
   - seriesDescription: String (optional)
   - modality: String
   - instanceCount: Int32

 Relationships:
   - study: To-One → StudyEntity (inverse: series)
   - images: To-Many → ImageEntity (cascade delete)

 ---

 Entity: ImageEntity
 Attributes:
   - id: UUID
   - sopInstanceUID: String (indexed, unique)
   - instanceNumber: Int32
   - localPath: String (optional)
   - rows: Int32
   - columns: Int32
   - pixelSpacingX: Float
   - pixelSpacingY: Float
   - fileSizeBytes: Int64
   - cachedAt: Date

 Relationships:
   - series: To-One → SeriesEntity (inverse: images)

 ---

 Entity: AnnotationEntity
 Attributes:
   - id: UUID
   - createdAt: Date (indexed)
   - modifiedAt: Date
   - createdByUserID: UUID
   - type: String
   - geometryData: Binary Data
   - styleData: Binary Data
   - label: String (optional)
   - measurementType: String (optional)
   - measurementValue: Float
   - measurementUnit: String (optional)
   - syncedToPACS: Bool (indexed)
   - syncedAt: Date (optional)

 Relationships:
   - study: To-One → StudyEntity (inverse: annotations)

 ---

 Entity: UserEntity
 Attributes:
   - id: UUID
   - username: String (indexed, unique)
   - email: String
   - role: String
   - hospitalID: String (optional)
   - accessToken: String (encrypted)
   - refreshToken: String (encrypted, optional)
   - tokenExpiresAt: Date
   - lastLoginAt: Date

 Relationships:
   - auditEvents: To-Many → AuditEventEntity

 ---

 Entity: AuditEventEntity
 Attributes:
   - id: UUID
   - timestamp: Date (indexed)
   - action: String
   - resourceType: String
   - resourceIDHash: String
   - outcome: String
   - ipAddress: String
   - deviceID: String

 Relationships:
   - user: To-One → UserEntity (inverse: auditEvents)

 ---

 Indexes:
   PatientEntity: patientID, lastAccessedAt
   StudyEntity: studyInstanceUID, studyDate, cacheExpiresAt
   SeriesEntity: seriesInstanceUID
   ImageEntity: sopInstanceUID
   AnnotationEntity: createdAt, syncedToPACS
   AuditEventEntity: timestamp
   UserEntity: username

*/

// MARK: - Instructions for Xcode Setup

/*
 To create the Core Data model in Xcode:

 1. File → New → File
 2. Select "Data Model" under Core Data
 3. Name it "MedicalImaging.xcdatamodeld"
 4. Add entities as defined in comments above
 5. Set relationships and delete rules
 6. Add indexes as specified
 7. Build and run

 Alternative: Import this generated model:
 - The entities above can be created programmatically
 - Or use a .xcdatamodeld file from the repository
*/
