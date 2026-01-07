# API Design Document
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Executive Summary

This document defines the internal API design for Medical Imaging Suite, covering protocols, async patterns, error handling, and dependency injection. The APIs prioritize type safety, testability, and Swift concurrency.

## 2. Design Principles

### 2.1 Protocol-Oriented Design

All major components defined as protocols with concrete implementations:

```swift
protocol DICOMService {
    func loadStudy(from url: URL) async throws -> DICOMStudy
    func parseMetadata(_ data: Data) throws -> DICOMMetadata
}

// Concrete implementation
actor DICOMServiceImpl: DICOMService {
    // Implementation
}

// Test mock
class MockDICOMService: DICOMService {
    var stubbedStudy: DICOMStudy?

    func loadStudy(from url: URL) async throws -> DICOMStudy {
        guard let study = stubbedStudy else {
            throw TestError.noStubbedData
        }
        return study
    }
}
```

### 2.2 Async/Await First

All I/O and long-running operations use Swift concurrency:

```swift
// Good: Async/await
func loadStudy() async throws -> Study

// Avoid: Completion handlers
func loadStudy(completion: @escaping (Result<Study, Error>) -> Void)
```

### 2.3 Actors for State Management

Use actors to protect mutable state:

```swift
actor StudyCache {
    private var cache: [String: Study] = [:]

    func get(_ uid: String) -> Study? {
        cache[uid]
    }

    func set(_ uid: String, study: Study) {
        cache[uid] = study
    }
}
```

## 3. Core Service Protocols

### 3.1 DICOM Service API

```swift
protocol DICOMService {
    /// Load a DICOM study from a URL
    /// - Parameter url: Local file URL or remote URL
    /// - Returns: Parsed DICOM study
    /// - Throws: `DICOMError` if parsing fails
    func loadStudy(from url: URL) async throws -> DICOMStudy

    /// Parse DICOM metadata without loading pixel data
    /// - Parameter data: Raw DICOM file data
    /// - Returns: DICOM metadata
    /// - Throws: `DICOMError` if parsing fails
    func parseMetadata(_ data: Data) throws -> DICOMMetadata

    /// Extract volume data from a series
    /// - Parameter study: DICOM study containing series
    /// - Returns: Reconstructed 3D volume
    func extractVolumeData(_ study: DICOMStudy) async -> VolumeData
}
```

### 3.2 Rendering Engine API

```swift
protocol RenderingEngine {
    /// Create a renderable volume entity from volume data
    /// - Parameter data: Volume data
    /// - Returns: RealityKit entity for spatial display
    func createVolume(from data: VolumeData) async -> VolumeEntity

    /// Apply windowing to adjust brightness/contrast
    /// - Parameters:
    ///   - volume: Target volume entity
    ///   - window: Window center and width
    func applyWindowing(_ volume: VolumeEntity, window: WindowLevel) async

    /// Update the transfer function for rendering
    /// - Parameters:
    ///   - volume: Target volume entity
    ///   - function: Transfer function mapping intensity to color/opacity
    func updateTransferFunction(_ volume: VolumeEntity, function: TransferFunction) async

    /// Generate a surface mesh from segmentation mask
    /// - Parameter segmentation: Binary segmentation mask
    /// - Returns: ModelEntity with generated mesh
    func generateSurface(from segmentation: SegmentationMask) async -> ModelEntity
}
```

### 3.3 PACS Client API

```swift
protocol PACSClient {
    /// Connect to a PACS server
    /// - Parameter server: Server configuration
    /// - Throws: `PACSError.connectionFailed` if connection fails
    func connect(to server: PACSServer) async throws

    /// Disconnect from the current server
    func disconnect() async

    /// Query the PACS worklist
    /// - Parameter filters: Query filters
    /// - Returns: Array of worklist items
    /// - Throws: `PACSError.queryFailed` if query fails
    func queryWorklist(filters: QueryFilters) async throws -> [WorklistItem]

    /// Retrieve a study from PACS
    /// - Parameter studyInstanceUID: DICOM study instance UID
    /// - Returns: Local URL of downloaded study
    /// - Throws: `PACSError.retrieveFailed` if retrieval fails
    func retrieveStudy(studyInstanceUID: String) async throws -> URL

    /// Store annotations back to PACS as DICOM SR
    /// - Parameters:
    ///   - annotations: Annotations to store
    ///   - studyUID: Associated study UID
    /// - Throws: `PACSError.storeFailed` if store fails
    func storeAnnotations(_ annotations: [Annotation], for studyUID: String) async throws
}
```

### 3.4 Storage Service API

```swift
protocol StorageService {
    /// Save a study to local storage
    /// - Parameter study: Study to save
    /// - Throws: `StorageError.saveFailed` if save fails
    func saveStudy(_ study: Study) async throws

    /// Retrieve a study from local storage
    /// - Parameter uid: Study instance UID
    /// - Returns: Cached study, or nil if not found
    func retrieveStudy(uid: String) async throws -> Study?

    /// Delete a study from local storage
    /// - Parameter uid: Study instance UID
    func deleteStudy(uid: String) async throws

    /// Clear expired cache entries
    func clearExpiredCache() async throws

    /// Get current cache size in bytes
    /// - Returns: Total cache size
    func getCacheSize() async -> UInt64
}
```

### 3.5 AI Service API

```swift
protocol AIMLService {
    /// Detect lesions in a volume
    /// - Parameter volume: Volume data
    /// - Returns: Array of detections with confidence scores
    /// - Throws: `AIError.inferenceFailed` if inference fails
    func detectLesions(in volume: VolumeData) async throws -> [Detection]

    /// Segment organs in a volume
    /// - Parameter volume: Volume data
    /// - Returns: Segmentation mask for each organ
    /// - Throws: `AIError.inferenceFailed` if inference fails
    func segmentOrgans(in volume: VolumeData) async throws -> [String: SegmentationMask]

    /// Quantify a measurement
    /// - Parameters:
    ///   - type: Measurement type (volume, distance, etc.)
    ///   - segmentation: Segmentation mask
    /// - Returns: Measurement value
    func quantify(_ type: MeasurementType, for segmentation: SegmentationMask) async -> Float
}
```

## 4. Manager Classes (Application Layer)

### 4.1 Study Manager API

```swift
@MainActor
class StudyManager: ObservableObject {
    @Published var activeStudies: [Study] = []
    @Published var selectedStudy: Study?
    @Published var comparisonMode: ComparisonMode = .sideBySide

    private let dicomService: DICOMService
    private let renderingEngine: RenderingEngine
    private let storageService: StorageService

    init(
        dicomService: DICOMService,
        renderingEngine: RenderingEngine,
        storageService: StorageService
    ) {
        self.dicomService = dicomService
        self.renderingEngine = renderingEngine
        self.storageService = storageService
    }

    /// Load a study from a source (PACS, local file, etc.)
    func loadStudy(from source: StudySource) async throws {
        // Implementation
    }

    /// Compare multiple studies side-by-side
    func compareStudies(_ studies: [Study], mode: ComparisonMode) async {
        // Implementation
    }

    /// Synchronize view transformations across studies
    func synchronizeViews(rotation: simd_quatf, scale: Float) async {
        // Implementation
    }
}

enum StudySource {
    case pacs(studyUID: String)
    case localFile(URL)
    case cache(studyUID: String)
}

enum ComparisonMode {
    case sideBySide
    case overlay
    case grid2x2
}
```

### 4.2 Annotation Manager API

```swift
@MainActor
class AnnotationManager: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var activeTool: AnnotationTool?

    private let storageService: StorageService
    private let pacsClient: PACSClient

    /// Create a new annotation
    func createAnnotation(
        type: AnnotationType,
        points: [SIMD3<Float>],
        style: AnnotationStyle
    ) async throws {
        let annotation = Annotation(
            id: UUID(),
            studyInstanceUID: currentStudyUID,
            createdAt: Date(),
            createdBy: currentUser,
            type: type,
            geometry: .points(points),
            style: style,
            label: nil,
            measurement: nil
        )

        annotations.append(annotation)

        // Save locally
        try await storageService.saveAnnotation(annotation)
    }

    /// Attach annotation to a volume entity
    func attachToVolume(_ annotation: Annotation, volume: VolumeEntity) {
        // Implementation
    }

    /// Export annotations as DICOM Structured Report
    func exportAsDICOMSR() async throws -> Data {
        // Implementation
    }

    /// Sync annotations to PACS
    func syncToPACS() async throws {
        let unsyncedAnnotations = annotations.filter { !$0.syncedToPACS }
        try await pacsClient.storeAnnotations(unsyncedAnnotations, for: currentStudyUID)
    }
}
```

## 5. Error Handling

### 5.1 Error Types

```swift
enum MedicalImagingError: Error, LocalizedError {
    // DICOM Errors
    case invalidDICOMFormat(reason: String)
    case unsupportedTransferSyntax(String)
    case corruptedPixelData

    // PACS Errors
    case pacsConnectionFailed(underlying: Error)
    case studyNotFound(studyUID: String)
    case networkTimeout

    // Rendering Errors
    case volumeCreationFailed(reason: String)
    case insufficientMemory
    case metalDeviceUnavailable

    // Security Errors
    case authenticationFailed
    case unauthorizedAccess(resource: String)
    case encryptionFailed

    // AI Errors
    case modelLoadFailed(modelName: String)
    case inferenceFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidDICOMFormat(let reason):
            return "Invalid DICOM format: \(reason)"
        case .unsupportedTransferSyntax(let syntax):
            return "Unsupported transfer syntax: \(syntax)"
        case .pacsConnectionFailed(let error):
            return "PACS connection failed: \(error.localizedDescription)"
        case .studyNotFound(let uid):
            return "Study not found: \(uid)"
        case .authenticationFailed:
            return "Authentication failed. Please log in again."
        // ... other cases
        }
    }
}
```

### 5.2 Error Recovery

```swift
extension PACSClient {
    func retrieveStudyWithRetry(studyInstanceUID: String, maxAttempts: Int = 3) async throws -> URL {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await retrieveStudy(studyInstanceUID: studyInstanceUID)
            } catch {
                lastError = error
                print("Attempt \(attempt) failed: \(error)")

                if attempt < maxAttempts {
                    // Exponential backoff
                    let delay = TimeInterval(pow(2.0, Double(attempt)))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? PACSError.retrieveFailed
    }
}
```

## 6. Dependency Injection

### 6.1 Service Container

```swift
@MainActor
class ServiceContainer {
    static let shared = ServiceContainer()

    // Core Services
    lazy var dicomService: DICOMService = DICOMServiceImpl()
    lazy var renderingEngine: RenderingEngine = RenderingEngineImpl(device: MTLCreateSystemDefaultDevice()!)
    lazy var pacsClient: PACSClient = DICOMwebClientImpl(baseURL: configuration.pacsURL, authProvider: oauthProvider)
    lazy var storageService: StorageService = FileStorageService()
    lazy var aiService: AIMLService = AIMLServiceImpl()
    lazy var securityService: SecurityService = SecurityServiceImpl()

    // Managers
    lazy var studyManager = StudyManager(
        dicomService: dicomService,
        renderingEngine: renderingEngine,
        storageService: storageService
    )

    lazy var annotationManager = AnnotationManager(
        storageService: storageService,
        pacsClient: pacsClient
    )

    lazy var collaborationManager = CollaborationManager()

    private init() {}

    // For testing: inject mocks
    func configure(with testServices: TestServices) {
        self.dicomService = testServices.dicomService
        self.pacsClient = testServices.pacsClient
        // ...
    }
}

struct TestServices {
    let dicomService: DICOMService
    let pacsClient: PACSClient
    // ... other services
}
```

### 6.2 Environment Injection (SwiftUI)

```swift
struct MedicalImagingSuiteApp: App {
    @StateObject private var studyManager = ServiceContainer.shared.studyManager
    @StateObject private var annotationManager = ServiceContainer.shared.annotationManager

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(studyManager)
                .environmentObject(annotationManager)
        }
    }
}

// Usage in views
struct StudyListView: View {
    @EnvironmentObject var studyManager: StudyManager

    var body: some View {
        List(studyManager.activeStudies) { study in
            StudyRow(study: study)
        }
    }
}
```

## 7. Codable Models

### 7.1 JSON Serialization

```swift
struct Study: Codable, Identifiable {
    let id: UUID
    let studyInstanceUID: String
    let studyDate: Date?
    let studyDescription: String?
    let patient: Patient
    let series: [Series]

    enum CodingKeys: String, CodingKey {
        case id
        case studyInstanceUID = "study_instance_uid"
        case studyDate = "study_date"
        case studyDescription = "study_description"
        case patient
        case series
    }
}

// Custom date encoding
extension Study {
    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
```

## 8. API Versioning

### 8.1 Version Header

```swift
struct APIVersion {
    static let current = "1.0"

    enum Compatibility {
        case compatible
        case deprecated
        case incompatible
    }

    static func checkCompatibility(serverVersion: String) -> Compatibility {
        let components = serverVersion.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else { return .incompatible }

        let major = components[0]
        let minor = components[1]

        // Same major version = compatible
        if major == 1 {
            return .compatible
        }

        return .incompatible
    }
}
```

## 9. Logging & Debugging

### 9.1 Structured Logging

```swift
import Logging

extension Logger {
    static let dicom = Logger(label: "com.medicalimaging.dicom")
    static let rendering = Logger(label: "com.medicalimaging.rendering")
    static let network = Logger(label: "com.medicalimaging.network")
    static let security = Logger(label: "com.medicalimaging.security")
}

// Usage
func loadStudy(from url: URL) async throws -> Study {
    Logger.dicom.info("Loading study", metadata: [
        "url": .string(url.path),
        "size": .stringConvertible(getFileSize(url))
    ])

    do {
        let study = try await parse(url)
        Logger.dicom.info("Study loaded successfully", metadata: [
            "studyUID": .string(study.studyInstanceUID)
        ])
        return study
    } catch {
        Logger.dicom.error("Failed to load study", metadata: [
            "error": .string(error.localizedDescription)
        ])
        throw error
    }
}
```

## 10. API Documentation

### 10.1 DocC Comments

```swift
/// A service for loading and parsing DICOM medical imaging files.
///
/// Use `DICOMService` to load DICOM studies from local files or remote PACS servers.
/// The service handles parsing of DICOM metadata, pixel data extraction, and volume reconstruction.
///
/// ## Topics
///
/// ### Loading Studies
/// - ``loadStudy(from:)``
/// - ``parseMetadata(_:)``
///
/// ### Volume Reconstruction
/// - ``extractVolumeData(_:)``
///
/// ## Example
///
/// ```swift
/// let service = DICOMServiceImpl()
/// let study = try await service.loadStudy(from: studyURL)
/// let volume = await service.extractVolumeData(study)
/// ```
public protocol DICOMService {
    /// Loads a DICOM study from the specified URL.
    ///
    /// This method parses the DICOM file(s) and constructs a `DICOMStudy` object
    /// containing all series and images.
    ///
    /// - Parameter url: The URL of the DICOM file or directory.
    /// - Returns: A parsed `DICOMStudy` object.
    /// - Throws: ``DICOMError/invalidDICOMFormat(reason:)`` if the file is not valid DICOM.
    ///
    /// - Note: This method may take several seconds for large studies.
    func loadStudy(from url: URL) async throws -> DICOMStudy
}
```

---

**Document Control**

- **Author**: API Design Team
- **Reviewers**: Engineering Team
- **Approval**: Technical Lead
- **Next Review**: Quarterly or when adding new APIs

