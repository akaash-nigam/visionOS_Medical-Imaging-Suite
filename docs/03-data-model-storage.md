# Data Model & Storage Design Document
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Executive Summary

This document defines the data model and storage architecture for Medical Imaging Suite, covering DICOM metadata persistence, pixel data caching, annotation storage, and encryption strategies. The design prioritizes HIPAA compliance, performance (fast study retrieval), and privacy (automatic cache expiration).

## 2. Storage Overview

### 2.1 Storage Layers

```
┌──────────────────────────────────────────────────┐
│         Application Layer                         │
├──────────────────────────────────────────────────┤
│  Domain Models (Swift structs/classes)           │
│  - Study, Series, Image, Annotation              │
└──────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────┐
│         Persistence Layer                         │
├──────────────────────────────────────────────────┤
│  Core Data (Metadata)          File System (Data)│
│  - Study metadata              - DICOM files     │
│  - Annotations                 - Volume caches   │
│  - Audit logs                  - AI models       │
└──────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────┐
│         Encryption Layer                          │
│  AES-256 encryption for all PHI                  │
└──────────────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────────────┐
│         Physical Storage                          │
│  - App Container (Documents, Caches)             │
│  - Keychain (Encryption keys)                    │
└──────────────────────────────────────────────────┘
```

### 2.2 Storage Allocation

| Data Type | Storage Type | Encryption | Retention |
|-----------|-------------|------------|-----------|
| **DICOM Metadata** | Core Data | Yes | User-configurable (7-30 days) |
| **DICOM Pixel Data** | File System | Yes | LRU cache (auto-expire) |
| **Annotations** | Core Data | Yes | Permanent (sync to PACS) |
| **Surgical Plans** | File System | Yes | User-managed |
| **AI Models** | File System | No | Permanent |
| **Audit Logs** | Core Data | Yes | 2 years minimum |
| **User Preferences** | UserDefaults | No | Permanent |

## 3. Domain Model

### 3.1 Core Entities

```swift
// Domain models (independent of persistence)

struct Patient {
    let id: UUID
    let patientID: String           // DICOM (0010,0020)
    let name: PersonName            // DICOM (0010,0010)
    let birthDate: Date?            // DICOM (0010,0030)
    let sex: Sex?                   // DICOM (0010,0040)

    // Derived
    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }
}

struct PersonName {
    let familyName: String
    let givenName: String
    let middleName: String?
    let prefix: String?
    let suffix: String?

    var formatted: String {
        var components = [givenName, middleName, familyName].compactMap { $0 }
        if let prefix = prefix { components.insert(prefix, at: 0) }
        if let suffix = suffix { components.append(suffix) }
        return components.joined(separator: " ")
    }
}

enum Sex: String, Codable {
    case male = "M"
    case female = "F"
    case other = "O"
    case unknown = "U"
}

struct Study {
    let id: UUID
    let studyInstanceUID: String    // DICOM (0020,000D)
    let studyDate: Date?            // DICOM (0008,0020)
    let studyTime: Date?            // DICOM (0008,0030)
    let studyDescription: String?   // DICOM (0008,1030)
    let accessionNumber: String?    // DICOM (0008,0050)
    let modalities: [Modality]
    let patient: Patient
    let series: [Series]

    var studyDateTime: Date? {
        guard let date = studyDate else { return nil }
        if let time = studyTime {
            return Calendar.current.date(byAdding: .second, value: Int(time.timeIntervalSince1970), to: date)
        }
        return date
    }
}

struct Series {
    let id: UUID
    let seriesInstanceUID: String   // DICOM (0020,000E)
    let seriesNumber: Int?          // DICOM (0020,0011)
    let seriesDescription: String?  // DICOM (0008,103E)
    let modality: Modality          // DICOM (0008,0060)
    let instanceCount: Int
    let images: [ImageInstance]
}

struct ImageInstance {
    let id: UUID
    let sopInstanceUID: String      // DICOM (0008,0018)
    let instanceNumber: Int?        // DICOM (0020,0013)
    let localURL: URL?              // Path to cached DICOM file
    let dimensions: SIMD2<Int>      // (rows, columns)
    let pixelSpacing: SIMD2<Float>? // mm per pixel
}

enum Modality: String, Codable {
    case ct = "CT"                  // Computed Tomography
    case mr = "MR"                  // Magnetic Resonance
    case pt = "PT"                  // Positron Emission Tomography
    case us = "US"                  // Ultrasound
    case xa = "XA"                  // X-ray Angiography
    case cr = "CR"                  // Computed Radiography
    case dx = "DX"                  // Digital Radiography
    case mg = "MG"                  // Mammography
    case other = "OT"
}

struct VolumeData {
    let id: UUID
    let series: Series
    let dimensions: SIMD3<Int>      // (width, height, depth)
    let spacing: SIMD3<Float>       // Physical spacing (mm)
    let dataType: VoxelDataType
    let cacheURL: URL?              // Reconstructed volume cache
    let windowCenter: Float
    let windowWidth: Float
}

enum VoxelDataType: String, Codable {
    case uint8
    case int16
    case float32
}
```

### 3.2 Annotation Model

```swift
struct Annotation {
    let id: UUID
    let studyInstanceUID: String
    let createdAt: Date
    let createdBy: User
    let type: AnnotationType
    let geometry: AnnotationGeometry
    let style: AnnotationStyle
    let label: String?
    let measurement: Measurement?
}

enum AnnotationType: String, Codable {
    case freehandLine
    case straightLine
    case arrow
    case circle
    case rectangle
    case polygon
    case text
    case measurement
    case volumeROI
}

enum AnnotationGeometry: Codable {
    case points([SIMD3<Float>])     // World coordinates
    case volume(SegmentationMask)   // 3D mask
}

struct AnnotationStyle {
    let color: RGBColor
    let lineWidth: Float
    let opacity: Float
    let font: String?
    let fontSize: Float?
}

struct RGBColor: Codable {
    let r: Float
    let g: Float
    let b: Float
}

struct Measurement {
    let type: MeasurementType
    let value: Float
    let unit: String
}

enum MeasurementType: String, Codable {
    case linear         // Distance in mm
    case angular        // Angle in degrees
    case volumetric     // Volume in cm³
    case hounsfield     // HU density
}

struct SegmentationMask {
    let dimensions: SIMD3<Int>
    let voxelData: Data             // Binary mask (1 bit per voxel)
    let label: String
}
```

### 3.3 User & Session Model

```swift
struct User {
    let id: UUID
    let username: String
    let email: String
    let role: UserRole
    let credentials: Credentials
}

enum UserRole: String, Codable {
    case physician
    case radiologist
    case surgeon
    case medicalStudent
    case administrator
}

struct Credentials {
    let hospitalID: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct AuditEvent {
    let id: UUID
    let timestamp: Date
    let user: User
    let action: AuditAction
    let resourceType: String
    let resourceID: String          // Hashed patient/study ID
    let outcome: Outcome
    let ipAddress: String
}

enum AuditAction: String, Codable {
    case login
    case logout
    case studyAccessed
    case studyDownloaded
    case annotationCreated
    case annotationModified
    case reportGenerated
    case collaborationStarted
}

enum Outcome: String, Codable {
    case success
    case failure
}
```

## 4. Core Data Schema

### 4.1 Entity Relationship Diagram

```
┌─────────────┐         ┌─────────────┐
│   Patient   │────1:N──│    Study    │
│   Entity    │         │   Entity    │
└─────────────┘         └─────────────┘
                              │
                             1:N
                              │
                        ┌─────────────┐
                        │   Series    │
                        │   Entity    │
                        └─────────────┘
                              │
                             1:N
                              │
                        ┌─────────────┐
                        │    Image    │
                        │   Entity    │
                        └─────────────┘

┌─────────────┐         ┌─────────────┐
│    Study    │────1:N──│ Annotation  │
│   Entity    │         │   Entity    │
└─────────────┘         └─────────────┘

┌─────────────┐
│    User     │
│   Entity    │
└─────────────┘
      │
     1:N
      │
┌─────────────┐
│ AuditEvent  │
│   Entity    │
└─────────────┘
```

### 4.2 Core Data Entities

```swift
// Core Data managed object classes

@objc(PatientEntity)
class PatientEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var patientID: String
    @NSManaged var familyName: String
    @NSManaged var givenName: String
    @NSManaged var middleName: String?
    @NSManaged var birthDate: Date?
    @NSManaged var sex: String?
    @NSManaged var createdAt: Date
    @NSManaged var lastAccessedAt: Date

    // Relationships
    @NSManaged var studies: Set<StudyEntity>

    // Encryption: Store PHI encrypted
    @NSManaged var encryptedData: Data  // Contains all PHI fields
}

@objc(StudyEntity)
class StudyEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var studyInstanceUID: String  // Indexed
    @NSManaged var studyDate: Date?
    @NSManaged var studyTime: Date?
    @NSManaged var studyDescription: String?
    @NSManaged var accessionNumber: String?
    @NSManaged var modalitiesRaw: String     // Comma-separated
    @NSManaged var createdAt: Date
    @NSManaged var lastAccessedAt: Date
    @NSManaged var cacheExpiresAt: Date

    // Relationships
    @NSManaged var patient: PatientEntity
    @NSManaged var series: Set<SeriesEntity>
    @NSManaged var annotations: Set<AnnotationEntity>

    // Computed
    var modalities: [Modality] {
        get { modalitiesRaw.split(separator: ",").compactMap { Modality(rawValue: String($0)) } }
        set { modalitiesRaw = newValue.map { $0.rawValue }.joined(separator: ",") }
    }
}

@objc(SeriesEntity)
class SeriesEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var seriesInstanceUID: String  // Indexed
    @NSManaged var seriesNumber: Int32
    @NSManaged var seriesDescription: String?
    @NSManaged var modality: String
    @NSManaged var instanceCount: Int32

    // Relationships
    @NSManaged var study: StudyEntity
    @NSManaged var images: Set<ImageEntity>
}

@objc(ImageEntity)
class ImageEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var sopInstanceUID: String    // Indexed
    @NSManaged var instanceNumber: Int32
    @NSManaged var localPath: String?        // Relative path to DICOM file
    @NSManaged var rows: Int32
    @NSManaged var columns: Int32
    @NSManaged var pixelSpacingX: Float
    @NSManaged var pixelSpacingY: Float
    @NSManaged var fileSizeBytes: Int64
    @NSManaged var cachedAt: Date

    // Relationships
    @NSManaged var series: SeriesEntity
}

@objc(AnnotationEntity)
class AnnotationEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var createdAt: Date
    @NSManaged var modifiedAt: Date
    @NSManaged var createdByUserID: UUID
    @NSManaged var type: String              // AnnotationType raw value
    @NSManaged var geometryData: Data        // Encoded AnnotationGeometry
    @NSManaged var styleData: Data           // Encoded AnnotationStyle
    @NSManaged var label: String?
    @NSManaged var measurementType: String?
    @NSManaged var measurementValue: Float
    @NSManaged var measurementUnit: String?
    @NSManaged var syncedToPACS: Bool
    @NSManaged var syncedAt: Date?

    // Relationships
    @NSManaged var study: StudyEntity
}

@objc(UserEntity)
class UserEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var username: String
    @NSManaged var email: String
    @NSManaged var role: String
    @NSManaged var hospitalID: String
    @NSManaged var accessToken: String       // Encrypted
    @NSManaged var refreshToken: String      // Encrypted
    @NSManaged var tokenExpiresAt: Date
    @NSManaged var lastLoginAt: Date

    // Relationships
    @NSManaged var auditEvents: Set<AuditEventEntity>
}

@objc(AuditEventEntity)
class AuditEventEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var timestamp: Date           // Indexed
    @NSManaged var action: String
    @NSManaged var resourceType: String
    @NSManaged var resourceIDHash: String    // SHA256 hash
    @NSManaged var outcome: String
    @NSManaged var ipAddress: String
    @NSManaged var deviceID: String

    // Relationships
    @NSManaged var user: UserEntity
}
```

### 4.3 Core Data Stack

```swift
actor CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "MedicalImaging")

        // Enable persistent history tracking for sync
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data stack initialization failed: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func save(context: NSManagedObjectContext) async throws {
        guard context.hasChanges else { return }

        try await context.perform {
            try context.save()
        }
    }
}
```

### 4.4 Indexes

```swift
// Core Data model indexes (defined in .xcdatamodeld)

// PatientEntity
// - index on: patientID
// - index on: lastAccessedAt (for cache cleanup)

// StudyEntity
// - index on: studyInstanceUID (primary lookup)
// - index on: studyDate (for timeline queries)
// - index on: cacheExpiresAt (for cleanup)
// - compound index: (patientID, studyDate) for patient history

// SeriesEntity
// - index on: seriesInstanceUID

// ImageEntity
// - index on: sopInstanceUID

// AnnotationEntity
// - index on: studyInstanceUID (for loading annotations per study)
// - index on: createdAt
// - index on: syncedToPACS (for pending sync queries)

// AuditEventEntity
// - index on: timestamp (for audit log queries)
// - index on: user + timestamp (compound)
```

## 5. File System Storage

### 5.1 Directory Structure

```
Application Container
├── Documents/
│   ├── SurgicalPlans/
│   │   └── {study-uid}/
│   │       ├── plan.json
│   │       └── implants/
│   │           └── {implant-id}.stl
│   └── Exports/
│       └── reports/
│
├── Library/
│   ├── Caches/
│   │   ├── DICOM/
│   │   │   └── {study-uid}/
│   │   │       └── {series-uid}/
│   │   │           └── {instance-uid}.dcm (encrypted)
│   │   ├── Volumes/
│   │   │   └── {series-uid}.vol (raw volume cache, encrypted)
│   │   └── Thumbnails/
│   │       └── {study-uid}.jpg
│   └── Application Support/
│       ├── CoreMLModels/
│       │   ├── lesion-detection-v1.mlmodelc
│       │   ├── organ-segmentation-v2.mlmodelc
│       │   └── model-manifest.json
│       └── Configuration/
│           └── app-config.json
│
└── tmp/
    └── Downloads/
        └── {temp-dicom-files}
```

### 5.2 File Manager Abstraction

```swift
actor FileStorageService {
    private let fileManager = FileManager.default
    private let encryptionService: EncryptionService

    // Base directories
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var cachesURL: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    private var dicomCacheURL: URL {
        cachesURL.appendingPathComponent("DICOM", isDirectory: true)
    }

    private var volumeCacheURL: URL {
        cachesURL.appendingPathComponent("Volumes", isDirectory: true)
    }

    // DICOM file operations
    func saveDICOMFile(_ data: Data, studyUID: String, seriesUID: String, instanceUID: String) async throws -> URL {
        let directoryURL = dicomCacheURL
            .appendingPathComponent(studyUID, isDirectory: true)
            .appendingPathComponent(seriesUID, isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent("\(instanceUID).dcm")

        // Encrypt before writing
        let encryptedData = try await encryptionService.encrypt(data)
        try encryptedData.write(to: fileURL, options: .atomic)

        return fileURL
    }

    func loadDICOMFile(at url: URL) async throws -> Data {
        let encryptedData = try Data(contentsOf: url)
        return try await encryptionService.decrypt(encryptedData)
    }

    func deleteDICOMFiles(for studyUID: String) async throws {
        let studyDirectory = dicomCacheURL.appendingPathComponent(studyUID, isDirectory: true)
        guard fileManager.fileExists(atPath: studyDirectory.path) else { return }
        try fileManager.removeItem(at: studyDirectory)
    }

    // Volume cache operations
    func saveVolumeCache(_ volume: VolumeData, seriesUID: String) async throws -> URL {
        try fileManager.createDirectory(at: volumeCacheURL, withIntermediateDirectories: true)

        let fileURL = volumeCacheURL.appendingPathComponent("\(seriesUID).vol")

        // Serialize volume data
        let data = try encodeVolume(volume)
        let encryptedData = try await encryptionService.encrypt(data)
        try encryptedData.write(to: fileURL, options: .atomic)

        return fileURL
    }

    func loadVolumeCache(seriesUID: String) async throws -> VolumeData {
        let fileURL = volumeCacheURL.appendingPathComponent("\(seriesUID).vol")
        let encryptedData = try Data(contentsOf: fileURL)
        let data = try await encryptionService.decrypt(encryptedData)
        return try decodeVolume(data)
    }

    // Cache cleanup
    func clearExpiredCache() async throws {
        // Delete files older than retention policy
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 3600)  // 7 days

        let enumerator = fileManager.enumerator(at: dicomCacheURL, includingPropertiesForKeys: [.contentModificationDateKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            if let modificationDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               modificationDate < cutoffDate {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }

    func getCacheSize() -> UInt64 {
        var totalSize: UInt64 = 0

        if let enumerator = fileManager.enumerator(at: cachesURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += UInt64(fileSize)
                }
            }
        }

        return totalSize
    }
}
```

## 6. Caching Strategy

### 6.1 LRU Cache Implementation

```swift
actor LRUCache<Key: Hashable, Value> {
    private struct CacheEntry {
        let value: Value
        var lastAccessed: Date
    }

    private var cache: [Key: CacheEntry] = [:]
    private let maxSize: Int
    private let maxMemoryBytes: UInt64

    init(maxSize: Int = 100, maxMemoryBytes: UInt64 = 2_000_000_000) {  // 2GB
        self.maxSize = maxSize
        self.maxMemoryBytes = maxMemoryBytes
    }

    func get(_ key: Key) -> Value? {
        guard var entry = cache[key] else { return nil }

        // Update access time
        entry.lastAccessed = Date()
        cache[key] = entry

        return entry.value
    }

    func set(_ key: Key, value: Value) {
        let entry = CacheEntry(value: value, lastAccessed: Date())
        cache[key] = entry

        // Evict if over capacity
        if cache.count > maxSize {
            evictOldest()
        }
    }

    func remove(_ key: Key) {
        cache.removeValue(forKey: key)
    }

    func clear() {
        cache.removeAll()
    }

    private func evictOldest() {
        guard let oldestKey = cache.min(by: { $0.value.lastAccessed < $1.value.lastAccessed })?.key else {
            return
        }

        cache.removeValue(forKey: oldestKey)
    }
}
```

### 6.2 Volume Cache Manager

```swift
actor VolumeCacheManager {
    private let cache = LRUCache<String, VolumeData>(maxSize: 10, maxMemoryBytes: 4_000_000_000)  // 4GB
    private let fileStorage: FileStorageService

    func getVolume(seriesUID: String) async throws -> VolumeData? {
        // Try in-memory cache first
        if let cached = await cache.get(seriesUID) {
            return cached
        }

        // Try file cache
        if let fileVolume = try? await fileStorage.loadVolumeCache(seriesUID: seriesUID) {
            await cache.set(seriesUID, value: fileVolume)
            return fileVolume
        }

        return nil
    }

    func cacheVolume(_ volume: VolumeData, seriesUID: String) async throws {
        // Cache in memory
        await cache.set(seriesUID, value: volume)

        // Persist to disk asynchronously
        Task.detached {
            try? await self.fileStorage.saveVolumeCache(volume, seriesUID: seriesUID)
        }
    }

    func clearCache() async {
        await cache.clear()
    }
}
```

## 7. Encryption

### 7.1 Encryption Service

```swift
import CryptoKit

actor EncryptionService {
    private let keychain = KeychainService.shared

    // Get or create master encryption key
    private func getMasterKey() throws -> SymmetricKey {
        if let keyData = try? keychain.get(key: "master-encryption-key") {
            return SymmetricKey(data: keyData)
        } else {
            // Generate new key
            let key = SymmetricKey(size: .bits256)
            try keychain.set(key: "master-encryption-key", value: key.withUnsafeBytes { Data($0) })
            return key
        }
    }

    func encrypt(_ data: Data) throws -> Data {
        let key = try getMasterKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decrypt(_ encryptedData: Data) throws -> Data {
        let key = try getMasterKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // For large files (streaming encryption)
    func encryptFile(at sourceURL: URL, to destinationURL: URL) async throws {
        let key = try getMasterKey()
        let chunkSize = 1024 * 1024  // 1MB chunks

        let inputStream = InputStream(url: sourceURL)!
        let outputStream = OutputStream(url: destinationURL, append: false)!

        inputStream.open()
        outputStream.open()

        defer {
            inputStream.close()
            outputStream.close()
        }

        var buffer = [UInt8](repeating: 0, count: chunkSize)

        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&buffer, maxLength: chunkSize)
            guard bytesRead > 0 else { break }

            let chunk = Data(buffer[0..<bytesRead])
            let encryptedChunk = try encrypt(chunk)

            encryptedChunk.withUnsafeBytes { ptr in
                outputStream.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: encryptedChunk.count)
            }
        }
    }
}
```

### 7.2 Keychain Service

```swift
import Security

actor KeychainService {
    static let shared = KeychainService()

    func set(key: String, value: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)  // Delete existing

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    func get(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.notFound
        }

        return data
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}

enum KeychainError: Error {
    case saveFailed(status: OSStatus)
    case notFound
    case deleteFailed(status: OSStatus)
}
```

## 8. Data Access Layer

### 8.1 Repository Pattern

```swift
protocol StudyRepository {
    func fetchStudy(uid: String) async throws -> Study?
    func fetchAllStudies() async throws -> [Study]
    func fetchStudies(for patient: Patient) async throws -> [Study]
    func saveStudy(_ study: Study) async throws
    func deleteStudy(uid: String) async throws
}

actor CoreDataStudyRepository: StudyRepository {
    private let coreDataStack = CoreDataStack.shared

    func fetchStudy(uid: String) async throws -> Study? {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let fetchRequest: NSFetchRequest<StudyEntity> = StudyEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "studyInstanceUID == %@", uid)
            fetchRequest.fetchLimit = 1

            guard let entity = try context.fetch(fetchRequest).first else {
                return nil
            }

            return self.mapToDomain(entity)
        }
    }

    func fetchAllStudies() async throws -> [Study] {
        let context = coreDataStack.viewContext

        return try await context.perform {
            let fetchRequest: NSFetchRequest<StudyEntity> = StudyEntity.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "studyDate", ascending: false)]

            let entities = try context.fetch(fetchRequest)
            return entities.map { self.mapToDomain($0) }
        }
    }

    func saveStudy(_ study: Study) async throws {
        let context = coreDataStack.newBackgroundContext()

        try await context.perform {
            // Check if exists
            let fetchRequest: NSFetchRequest<StudyEntity> = StudyEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "studyInstanceUID == %@", study.studyInstanceUID)
            fetchRequest.fetchLimit = 1

            let entity: StudyEntity
            if let existing = try context.fetch(fetchRequest).first {
                entity = existing
            } else {
                entity = StudyEntity(context: context)
                entity.id = study.id
                entity.studyInstanceUID = study.studyInstanceUID
                entity.createdAt = Date()
            }

            // Update fields
            self.mapToEntity(study, entity: entity)
            entity.lastAccessedAt = Date()

            try context.save()
        }
    }

    func deleteStudy(uid: String) async throws {
        let context = coreDataStack.newBackgroundContext()

        try await context.perform {
            let fetchRequest: NSFetchRequest<StudyEntity> = StudyEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "studyInstanceUID == %@", uid)

            if let entity = try context.fetch(fetchRequest).first {
                context.delete(entity)
                try context.save()
            }
        }
    }

    // Mapping functions
    private func mapToDomain(_ entity: StudyEntity) -> Study {
        let patient = mapPatientToDomain(entity.patient)
        let series = entity.series.map { mapSeriesToDomain($0) }

        return Study(
            id: entity.id,
            studyInstanceUID: entity.studyInstanceUID,
            studyDate: entity.studyDate,
            studyTime: entity.studyTime,
            studyDescription: entity.studyDescription,
            accessionNumber: entity.accessionNumber,
            modalities: entity.modalities,
            patient: patient,
            series: series
        )
    }

    private func mapToEntity(_ study: Study, entity: StudyEntity) {
        entity.studyDate = study.studyDate
        entity.studyTime = study.studyTime
        entity.studyDescription = study.studyDescription
        entity.accessionNumber = study.accessionNumber
        entity.modalities = study.modalities
    }

    // Additional mapping functions...
}
```

## 9. Data Migration

### 9.1 Core Data Migrations

```swift
// Lightweight migrations (automatic)
// - Adding new attributes
// - Adding new entities
// - Deleting attributes (with default values)

// Heavyweight migrations (custom)
class MigrationManager {
    func migrateIfNeeded() throws {
        let storeURL = CoreDataStack.shared.container.persistentStoreDescriptions.first!.url!

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL)

        let model = CoreDataStack.shared.container.managedObjectModel

        if !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
            // Perform heavyweight migration
            try performHeavyweightMigration(from: metadata, to: model)
        }
    }

    private func performHeavyweightMigration(from metadata: [String: Any], to model: NSManagedObjectModel) throws {
        // Custom migration logic
        // Example: Transform old schema to new schema
    }
}
```

## 10. Backup & Restore

### 10.1 Export Strategy

```swift
actor BackupService {
    func exportStudy(_ study: Study, format: ExportFormat) async throws -> URL {
        switch format {
        case .dicom:
            return try await exportAsDICOM(study)
        case .pdf:
            return try await exportAsPDF(study)
        case .json:
            return try await exportAsJSON(study)
        }
    }

    private func exportAsJSON(_ study: Study) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(study)

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(study.studyInstanceUID).json")

        try data.write(to: exportURL)

        return exportURL
    }
}

enum ExportFormat {
    case dicom
    case pdf
    case json
}
```

## 11. Performance Optimization

### 11.1 Batch Operations

```swift
extension CoreDataStudyRepository {
    func saveStudies(_ studies: [Study]) async throws {
        let context = coreDataStack.newBackgroundContext()

        try await context.perform {
            for study in studies {
                let entity = StudyEntity(context: context)
                self.mapToEntity(study, entity: entity)
            }

            try context.save()
        }
    }
}
```

### 11.2 Prefetching Relationships

```swift
func fetchStudiesWithDetails() async throws -> [Study] {
    let context = coreDataStack.viewContext

    return try await context.perform {
        let fetchRequest: NSFetchRequest<StudyEntity> = StudyEntity.fetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = ["patient", "series", "series.images"]

        let entities = try context.fetch(fetchRequest)
        return entities.map { self.mapToDomain($0) }
    }
}
```

## 12. Testing

### 12.1 In-Memory Core Data Stack (for tests)

```swift
class TestCoreDataStack {
    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "MedicalImaging")

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
}
```

---

**Document Control**

- **Author**: Data Engineering Team
- **Reviewers**: Backend Lead, Security Officer
- **Approval**: CTO
- **Next Review**: After initial data model implementation

