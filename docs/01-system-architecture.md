# System Architecture Document
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Executive Summary

This document defines the technical architecture for Medical Imaging Suite, a spatial computing application for medical imaging visualization and surgical planning on Apple Vision Pro. The architecture prioritizes performance (60fps rendering), security (HIPAA compliance), and modularity (independent feature development).

## 2. Architecture Overview

### 2.1 High-Level System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         visionOS Application                     │
├─────────────────────────────────────────────────────────────────┤
│  Presentation Layer (SwiftUI + RealityKit)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Spatial UI   │  │ 3D Viewport  │  │ Collaboration│         │
│  │ Windows      │  │ (RealityView)│  │ UI           │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
├─────────────────────────────────────────────────────────────────┤
│  Application Layer (Swift)                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Study        │  │ Annotation   │  │ Collaboration│         │
│  │ Manager      │  │ Manager      │  │ Manager      │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
├─────────────────────────────────────────────────────────────────┤
│  Core Services Layer                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ DICOM        │  │ 3D Rendering │  │ AI/ML        │         │
│  │ Service      │  │ Engine       │  │ Service      │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ PACS Client  │  │ Storage      │  │ Security     │         │
│  │              │  │ Service      │  │ Service      │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
├─────────────────────────────────────────────────────────────────┤
│  Platform Layer                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ RealityKit   │  │ Metal        │  │ Core ML      │         │
│  │ SwiftUI      │  │ Core Data    │  │ Network      │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   ┌──────────┐        ┌──────────┐        ┌──────────┐
   │ Hospital │        │ Local    │        │ Network  │
   │ PACS/EHR │        │ Storage  │        │ Collab   │
   └──────────┘        └──────────┘        └──────────┘
```

### 2.2 Key Architectural Principles

1. **Separation of Concerns**: Clear boundaries between UI, business logic, and services
2. **Protocol-Oriented Design**: Dependency injection via Swift protocols for testability
3. **Actor-Based Concurrency**: Swift actors for thread-safe state management
4. **Privacy by Design**: PHI encryption at rest and in transit
5. **Performance First**: Metal GPU acceleration, memory pooling, progressive loading
6. **Fail-Safe Operations**: Graceful degradation, offline mode support

## 3. Module Architecture

### 3.1 Module Dependency Graph

```
MedicalImagingSuite (App Target)
    │
    ├─── PresentationLayer
    │       ├─── SwiftUI Views
    │       └─── RealityKit Components
    │
    ├─── ApplicationLayer
    │       ├─── StudyManager
    │       ├─── AnnotationManager
    │       └─── CollaborationManager
    │
    ├─── CoreServices
    │       ├─── DICOMKit (Framework)
    │       ├─── RenderingEngine (Framework)
    │       ├─── AIMLService (Framework)
    │       ├─── PACSClient (Framework)
    │       ├─── StorageService (Framework)
    │       └─── SecurityService (Framework)
    │
    └─── SharedModels
            ├─── Domain Models
            └─── DTOs
```

### 3.2 Framework Responsibilities

| Framework | Responsibility | Dependencies |
|-----------|---------------|--------------|
| **DICOMKit** | DICOM parsing, encoding, networking | Foundation, Network |
| **RenderingEngine** | Volume rendering, mesh generation, spatial display | Metal, RealityKit |
| **AIMLService** | Model inference, segmentation, detection | Core ML, Accelerate |
| **PACSClient** | PACS/EHR integration, FHIR client | DICOMKit, Network |
| **StorageService** | Encrypted caching, Core Data, file management | Core Data, CryptoKit |
| **SecurityService** | Authentication, audit logging, encryption | CryptoKit, LocalAuthentication |
| **SharedModels** | Domain entities, value objects | Foundation |

## 4. Component Design

### 4.1 DICOM Service

**Responsibility**: Load, parse, and manage DICOM datasets

```swift
protocol DICOMService {
    func loadStudy(from url: URL) async throws -> DICOMStudy
    func parseMetadata(_ data: Data) throws -> DICOMMetadata
    func extractVolumeData(_ study: DICOMStudy) async -> VolumeData
}

actor DICOMServiceImpl: DICOMService {
    private let parser: DICOMParser
    private let cache: DICOMCache
    private let decoder: ImageDecoder
}
```

**Key Operations**:
- DICOM tag parsing (VR, VL, Value extraction)
- Transfer syntax handling (Implicit/Explicit VR, JPEG, RLE)
- Multi-frame image decoding
- Pixel data extraction and normalization
- Metadata caching

**Performance Targets**:
- Parse 500-slice CT: < 5 seconds
- Memory overhead: < 20% of raw data size
- Streaming support for large datasets

### 4.2 3D Rendering Engine

**Responsibility**: Volume rendering, mesh generation, spatial display

```swift
protocol RenderingEngine {
    func createVolume(from data: VolumeData) async -> VolumeEntity
    func applyWindowing(_ volume: VolumeEntity, window: WindowLevel)
    func updateTransferFunction(_ volume: VolumeEntity, function: TransferFunction)
    func generateSurface(from segmentation: SegmentationMask) -> ModelEntity
}

actor RenderingEngineImpl: RenderingEngine {
    private let metalDevice: MTLDevice
    private let computePipeline: MTLComputePipelineState
    private let volumeTextureCache: TextureCache
}
```

**Rendering Pipeline**:
1. Upload volume data to GPU (Metal texture)
2. Ray casting compute shader
3. Transfer function lookup
4. Gradient-based lighting
5. Compositing and output

**Optimization Strategies**:
- Texture compression (BC4/BC5 for medical data)
- Octree spatial acceleration
- Level-of-detail based on distance
- Early ray termination
- Empty space skipping

### 4.3 Study Manager

**Responsibility**: Coordinate study loading, multi-study comparison, state management

```swift
@MainActor
class StudyManager: ObservableObject {
    @Published var activeStudies: [Study] = []
    @Published var selectedStudy: Study?
    @Published var comparisonMode: ComparisonMode = .sideBySide

    private let dicomService: DICOMService
    private let renderingEngine: RenderingEngine
    private let storageService: StorageService

    func loadStudy(from source: StudySource) async throws
    func compareStudies(_ studies: [Study], mode: ComparisonMode)
    func synchronizeViews(rotation: simd_quatf, scale: Float)
}
```

### 4.4 Annotation Manager

**Responsibility**: Handle surgical planning annotations and measurements

```swift
@MainActor
class AnnotationManager: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var activeTool: AnnotationTool?

    func createAnnotation(type: AnnotationType, points: [SIMD3<Float>]) async
    func attachToVolume(_ annotation: Annotation, volume: VolumeEntity)
    func exportAsDICOMSR() async throws -> Data
    func saveToStorage() async throws
}
```

### 4.5 Collaboration Manager

**Responsibility**: Multi-user session coordination, state synchronization

```swift
actor CollaborationManager {
    private var session: GroupSession<MedicalImagingActivity>?
    private var messenger: GroupSessionMessenger?

    func startSession(for study: Study) async throws
    func joinSession(from invitation: GroupActivityInvitation) async throws
    func broadcastAnnotation(_ annotation: Annotation) async
    func synchronizeState(_ state: SpatialState) async
}
```

### 4.6 PACS Client

**Responsibility**: DICOM network operations, FHIR integration

```swift
protocol PACSClient {
    func connect(to server: PACSServer) async throws
    func queryWorklist(filters: QueryFilters) async throws -> [WorklistItem]
    func retrieveStudy(studyInstanceUID: String) async throws -> URL
    func storeAnnotations(_ data: Data, for studyUID: String) async throws
}

actor PACSClientImpl: PACSClient {
    private let dimseClient: DIMSEClient  // C-FIND, C-MOVE, C-STORE
    private let dicomWebClient: DICOMwebClient  // WADO-RS, QIDO-RS
    private let fhirClient: FHIRClient
}
```

### 4.7 Storage Service

**Responsibility**: Encrypted local caching, Core Data persistence

```swift
actor StorageService {
    private let coreDataStack: CoreDataStack
    private let fileManager: EncryptedFileManager
    private let cache: LRUCache<String, Data>

    func saveStudy(_ study: Study) async throws
    func retrieveStudy(uid: String) async throws -> Study?
    func clearCache(olderThan: TimeInterval) async
    func encryptAndStore(_ data: Data, key: String) async throws
}
```

**Storage Strategy**:
- Core Data for metadata and annotations
- File system for DICOM pixel data (encrypted)
- LRU cache for frequently accessed studies
- Automatic purging based on privacy policy

### 4.8 Security Service

**Responsibility**: Authentication, authorization, audit logging, encryption

```swift
actor SecurityService {
    func authenticate() async throws -> User
    func checkPermission(_ action: Action, for resource: Resource) -> Bool
    func logAccess(_ event: AuditEvent) async
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}
```

**Security Features**:
- OpticID biometric authentication
- Role-based access control (RBAC)
- Audit trail for all PHI access
- AES-256 encryption at rest
- TLS 1.3 for network transmission

### 4.9 AI/ML Service

**Responsibility**: Model inference, segmentation, detection

```swift
actor AIMLService {
    private let models: [String: MLModel]

    func detectLesions(in volume: VolumeData) async throws -> [Detection]
    func segmentOrgans(in volume: VolumeData) async throws -> SegmentationMask
    func quantify(_ measurement: MeasurementType, for segmentation: SegmentationMask) async -> Float
}
```

**Model Pipeline**:
1. Pre-processing (normalization, resampling)
2. Core ML inference
3. Post-processing (thresholding, connected components)
4. Confidence scoring
5. Result formatting

## 5. Data Flow

### 5.1 Study Loading Flow

```
User selects study from worklist
    ↓
StudyManager.loadStudy()
    ↓
PACSClient.retrieveStudy()
    ↓
DICOMService.loadStudy()
    ↓
DICOMService.parseMetadata()
    ↓
DICOMService.extractVolumeData()
    ↓
StorageService.saveStudy()
    ↓
RenderingEngine.createVolume()
    ↓
Display in RealityView
```

### 5.2 Annotation Sync Flow (Collaborative Session)

```
User creates annotation
    ↓
AnnotationManager.createAnnotation()
    ↓
CollaborationManager.broadcastAnnotation()
    ↓
[Network: GroupSession message]
    ↓
Remote peer receives message
    ↓
Remote AnnotationManager applies annotation
    ↓
StorageService.saveAnnotation()
    ↓
PACSClient.storeAnnotations() (DICOM SR)
```

## 6. Concurrency Model

### 6.1 Threading Strategy

| Component | Concurrency Model | Rationale |
|-----------|-------------------|-----------|
| **UI Layer** | @MainActor | SwiftUI/RealityKit require main thread |
| **Study Manager** | @MainActor | Published state for UI binding |
| **DICOM Service** | Actor | Thread-safe parsing, isolated state |
| **Rendering Engine** | Actor | GPU command encoding synchronization |
| **PACS Client** | Actor | Serial network operations |
| **Storage Service** | Actor | Protect Core Data/file system access |
| **AI/ML Service** | Actor | Model inference serialization |

### 6.2 Async/Await Patterns

```swift
// Pattern 1: Sequential operations
func loadAndRender(studyUID: String) async throws {
    let study = try await pacsClient.retrieveStudy(studyUID: studyUID)
    let dicomStudy = try await dicomService.loadStudy(from: study)
    let volume = await renderingEngine.createVolume(from: dicomStudy.volumeData)
    await MainActor.run {
        self.activeStudy = volume
    }
}

// Pattern 2: Concurrent operations
func compareStudies(studyUIDs: [String]) async throws {
    try await withThrowingTaskGroup(of: VolumeEntity.self) { group in
        for uid in studyUIDs {
            group.addTask {
                let study = try await self.pacsClient.retrieveStudy(studyUID: uid)
                let dicomStudy = try await self.dicomService.loadStudy(from: study)
                return await self.renderingEngine.createVolume(from: dicomStudy.volumeData)
            }
        }

        var volumes: [VolumeEntity] = []
        for try await volume in group {
            volumes.append(volume)
        }

        await MainActor.run {
            self.displayComparison(volumes)
        }
    }
}
```

## 7. Memory Management

### 7.1 Memory Budget (Vision Pro M2: 16GB RAM)

| Component | Budget | Strategy |
|-----------|--------|----------|
| **System/OS** | 4GB | Reserved by visionOS |
| **Application** | 8GB | Active study data |
| **DICOM Cache** | 2GB | LRU cache for recent studies |
| **GPU Textures** | 1.5GB | Volume textures, meshes |
| **AI Models** | 500MB | Core ML models loaded on-demand |

### 7.2 Memory Management Strategies

1. **Progressive Loading**: Load slices on-demand, not entire volume upfront
2. **Texture Streaming**: Stream volume data to GPU in chunks
3. **LRU Cache**: Evict least-recently-used studies when memory pressure high
4. **Weak References**: Use weak refs for non-critical cached data
5. **Memory Warnings**: Listen to system memory warnings, purge aggressively
6. **Compression**: Use lossy compression for non-diagnostic visualization

### 7.3 Large Dataset Handling

For datasets > 4GB (e.g., cardiac 4D CT):
- Out-of-core rendering (load visible region only)
- Brick-based volume decomposition
- Asynchronous loading with placeholders
- Quality degradation under memory pressure

## 8. Performance Optimization

### 8.1 Rendering Performance

**Targets**:
- 60fps minimum (16.67ms per frame)
- 90fps ideal (11.11ms per frame)
- Sub-100ms interaction latency

**Optimization Techniques**:
- Metal compute shaders for ray casting
- Frustum culling for multi-study views
- Level-of-detail (LOD) based on distance
- Occlusion culling for overlapping volumes
- Asynchronous texture loading
- Double-buffering for smooth updates

### 8.2 DICOM Loading Performance

**Targets**:
- 512-slice CT: < 10 seconds to first render
- Metadata query: < 500ms
- Network transfer: Limited by bandwidth

**Optimization Techniques**:
- Parallel slice decoding (8+ concurrent)
- Incremental display (show as slices arrive)
- Delta encoding for series downloads
- HTTP/2 multiplexing for WADO-RS
- Predictive prefetching of likely studies

### 8.3 Profiling & Monitoring

```swift
struct PerformanceMetrics {
    var frameTime: TimeInterval
    var memoryUsage: UInt64
    var networkLatency: TimeInterval
    var dicomLoadTime: TimeInterval
    var renderingTime: TimeInterval
}

actor PerformanceMonitor {
    func record(_ metric: PerformanceMetrics)
    func generateReport() -> PerformanceReport
    func alertOnThreshold(_ threshold: Threshold)
}
```

## 9. Error Handling

### 9.1 Error Hierarchy

```swift
enum MedicalImagingError: Error {
    // DICOM errors
    case invalidDICOMFormat(reason: String)
    case unsupportedTransferSyntax(String)
    case corruptedPixelData

    // Network errors
    case pacsConnectionFailed(underlyingError: Error)
    case studyNotFound(studyUID: String)
    case networkTimeout

    // Rendering errors
    case volumeCreationFailed(reason: String)
    case insufficientMemory
    case metalDeviceUnavailable

    // Security errors
    case authenticationFailed
    case unauthorizedAccess(resource: String)
    case encryptionFailed

    // AI errors
    case modelLoadFailed(modelName: String)
    case inferenceFailed(reason: String)
}
```

### 9.2 Error Recovery Strategies

| Error Type | Strategy |
|------------|----------|
| **Network transient** | Exponential backoff retry (3 attempts) |
| **DICOM parse error** | Skip invalid slices, log warning |
| **Memory pressure** | Purge cache, reduce quality, warn user |
| **Authentication failure** | Force re-login, clear local data |
| **Metal errors** | Fallback to CPU rendering, degrade quality |

## 10. Testing Architecture

### 10.1 Test Pyramid

```
         ┌────────────┐
         │   E2E      │  (5%)  Full workflow tests
         │   Tests    │
         └────────────┘
       ┌──────────────────┐
       │  Integration     │  (15%)  Component interaction
       │  Tests           │
       └──────────────────┘
    ┌───────────────────────┐
    │   Unit Tests          │  (80%)  Pure logic, protocols
    └───────────────────────┘
```

### 10.2 Test Infrastructure

```swift
// Mock protocols for testing
protocol MockDICOMService: DICOMService {
    var stubbedStudy: DICOMStudy? { get set }
}

protocol MockPACSClient: PACSClient {
    var shouldFailConnection: Bool { get set }
}

// Test fixtures
struct TestFixtures {
    static let sampleCT512: DICOMStudy
    static let sampleMRI256: DICOMStudy
    static let patientMetadata: PatientInfo
}
```

## 11. Build Configuration

### 11.1 Build Targets

| Target | Configuration | Purpose |
|--------|---------------|---------|
| **MedicalImagingSuite** | Release | Production app |
| **MedicalImagingSuite** | Debug | Development with logging |
| **MedicalImagingSuiteTests** | Test | Unit tests |
| **MedicalImagingSuiteUITests** | Test | UI automation |
| **DICOMKitFramework** | Framework | Reusable DICOM library |

### 11.2 Compiler Settings

```swift
// Debug
SWIFT_OPTIMIZATION_LEVEL = -Onone
SWIFT_COMPILATION_MODE = incremental
ENABLE_TESTABILITY = YES

// Release
SWIFT_OPTIMIZATION_LEVEL = -O
SWIFT_COMPILATION_MODE = wholemodule
ENABLE_BITCODE = NO (visionOS doesn't support)
```

## 12. Deployment Architecture

### 12.1 Distribution

- **App Store**: Primary distribution channel
- **TestFlight**: Beta testing (closed, open)
- **Enterprise**: Hospital-specific builds (optional)

### 12.2 Version Management

```
Version format: MAJOR.MINOR.PATCH
- MAJOR: Breaking changes, new core features
- MINOR: New features, backward compatible
- PATCH: Bug fixes, performance improvements

Example: 1.2.3
```

### 12.3 Feature Flags

```swift
enum FeatureFlag: String {
    case aiSegmentation
    case collaborationMode
    case cloudSync

    var isEnabled: Bool {
        // Check remote config or local override
        RemoteConfig.shared.isEnabled(self)
    }
}
```

## 13. Dependency Management

### 13.1 Swift Package Manager (SPM)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
    // DICOM library (open-source or custom)
]
```

### 13.2 Third-Party Libraries (Minimal)

- **Swift Log**: Structured logging
- **Swift Crypto**: Cryptographic operations
- **DCMTK** (C++ via bridging): DICOM parsing (if needed)

**Philosophy**: Minimize dependencies for security and compliance reasons.

## 14. Observability

### 14.1 Logging

```swift
import Logging

let logger = Logger(label: "com.medical-imaging.app")

logger.info("Study loaded", metadata: [
    "studyUID": .string(studyUID),
    "sliceCount": .stringConvertible(sliceCount),
    "loadTime": .stringConvertible(loadTime)
])
```

**Log Levels**:
- **trace**: Detailed diagnostic info
- **debug**: Helpful for debugging
- **info**: Important events
- **warning**: Recoverable issues
- **error**: Serious problems
- **critical**: System failures

**IMPORTANT**: Never log PHI (patient names, dates of birth, etc.)

### 14.2 Crash Reporting

```swift
// Use MetricKit for crash reporting (privacy-safe)
import MetricKit

class MetricsManager: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        // Analyze crashes, hangs, disk writes
        // Send to internal analytics (PHI-scrubbed)
    }
}
```

### 14.3 Performance Monitoring

Track key metrics:
- Frame times (histogram)
- Memory usage (peak, average)
- Network latency (p50, p95, p99)
- DICOM load times
- AI inference times

## 15. Future Architecture Considerations

### 15.1 Scalability

- **Cloud PACS**: Support cloud-based PACS (Ambra, Nuance)
- **Multi-Device**: Share sessions across Vision Pro + iPad
- **Offline Mode**: Full functionality without network

### 15.2 Extensibility

- **Plugin System**: Third-party measurement tools
- **Custom AI Models**: Hospital-specific fine-tuned models
- **Integration APIs**: Surgical navigation system SDKs

### 15.3 Performance Enhancements

- **Neural Rendering**: AI upscaling for lower-res volumes
- **Predictive Loading**: ML-based prefetching
- **Adaptive Quality**: Dynamic LOD based on interaction

## 16. Architecture Decision Records (ADRs)

### ADR-001: Swift Concurrency over Grand Central Dispatch

**Decision**: Use Swift actors and async/await instead of GCD queues and completion handlers.

**Rationale**:
- Type-safe concurrency
- Eliminates data races at compile time
- Cleaner async code (no pyramid of doom)
- Better integration with SwiftUI

**Trade-offs**: Requires iOS 15+/visionOS 1.0+ (acceptable for Vision Pro)

### ADR-002: RealityKit over SceneKit

**Decision**: Use RealityKit for 3D rendering instead of SceneKit.

**Rationale**:
- Native spatial computing support
- Better performance on visionOS
- Designed for Vision Pro from ground up
- Future-proof (Apple's investment)

**Trade-offs**: Less mature than SceneKit, but rapidly evolving

### ADR-003: On-Device AI Inference (Core ML)

**Decision**: Run AI models locally using Core ML instead of cloud-based inference.

**Rationale**:
- Privacy: PHI never leaves device
- Latency: No network round-trip
- Offline capability
- HIPAA compliance simpler

**Trade-offs**: Limited to models that fit on-device, can't use latest large models

### ADR-004: Protocol-Oriented Architecture

**Decision**: Design around Swift protocols with concrete implementations, not class hierarchies.

**Rationale**:
- Testability: Easy to create mocks
- Flexibility: Composition over inheritance
- Swift best practice
- Decoupling: Swap implementations

**Trade-offs**: More boilerplate (protocol + implementation)

## 17. Security Architecture

### 17.1 Threat Model

| Threat | Mitigation |
|--------|------------|
| **Unauthorized device access** | OpticID biometric lock, auto-logout |
| **Network eavesdropping** | TLS 1.3, certificate pinning |
| **Data theft (lost device)** | AES-256 encryption at rest |
| **Insider threat** | Audit logging, RBAC, least privilege |
| **Malicious DICOM files** | Input validation, sandboxed parsing |
| **Session hijacking** | Signed tokens, short TTLs |

### 17.2 Secure Coding Practices

- Input validation for all DICOM tags
- Bounds checking for pixel data access
- Memory-safe Swift (avoid unsafe pointers)
- Code signing and notarization
- Regular security audits and penetration testing

## 18. Compliance Architecture

### 18.1 HIPAA Technical Safeguards

| Requirement | Implementation |
|-------------|----------------|
| **Access Control** | OpticID + role-based permissions |
| **Audit Controls** | SecurityService audit logging |
| **Integrity** | Hash verification for DICOM files |
| **Transmission Security** | TLS 1.3, VPN support |

### 18.2 FDA Software Validation

- **Design Controls**: Documented requirements (PRD)
- **Risk Analysis**: FMEA for critical functions
- **Verification Testing**: Test coverage >80%
- **Validation Testing**: Clinical studies
- **Traceability**: Requirements → Code → Tests

## 19. Appendix

### 19.1 Technology Stack Summary

| Layer | Technologies |
|-------|-------------|
| **Language** | Swift 6.0+ |
| **UI Framework** | SwiftUI, RealityKit |
| **Graphics** | Metal, Metal Performance Shaders |
| **ML** | Core ML, Create ML |
| **Networking** | URLSession, Network framework |
| **Storage** | Core Data, FileManager, SQLite |
| **Security** | CryptoKit, LocalAuthentication |
| **Logging** | Swift Log, OSLog |

### 19.2 Key Files and Locations

```
MedicalImagingSuite/
├── App/
│   ├── MedicalImagingSuiteApp.swift
│   └── AppConfiguration.swift
├── Presentation/
│   ├── Views/
│   ├── ViewModels/
│   └── RealityViews/
├── Application/
│   ├── StudyManager.swift
│   ├── AnnotationManager.swift
│   └── CollaborationManager.swift
├── CoreServices/
│   ├── DICOMKit/
│   ├── RenderingEngine/
│   ├── AIMLService/
│   ├── PACSClient/
│   ├── StorageService/
│   └── SecurityService/
├── Models/
│   ├── Domain/
│   └── DTOs/
└── Tests/
    ├── UnitTests/
    └── IntegrationTests/
```

---

**Document Control**

- **Author**: Technical Architecture Team
- **Reviewers**: Engineering Lead, Security Officer, Compliance Officer
- **Approval**: CTO
- **Next Review**: Upon major architecture changes

