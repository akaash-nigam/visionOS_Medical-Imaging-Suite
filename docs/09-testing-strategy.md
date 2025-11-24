# Testing Strategy Document
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Testing Pyramid

```
         ┌─────────────┐
         │   Manual    │  (2%)  Exploratory, usability
         │   Testing   │
         └─────────────┘
       ┌──────────────────┐
       │   E2E Tests       │  (8%)  Full workflow automation
       └──────────────────┘
    ┌───────────────────────┐
    │  Integration Tests     │  (20%)  Component interaction
    └───────────────────────┘
  ┌──────────────────────────────┐
  │     Unit Tests               │  (70%)  Pure logic, isolated
  └──────────────────────────────┘
```

## 2. Unit Testing

### 2.1 Test Structure

```swift
import XCTest
@testable import MedicalImagingSuite

final class DICOMParserTests: XCTestCase {
    var sut: DICOMParser!

    override func setUp() {
        super.setUp()
        sut = DICOMParser()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testParseValidDICOMFile() throws {
        // Given
        let testFile = Bundle(for: type(of: self)).url(forResource: "sample-ct", withExtension: "dcm")!

        // When
        let dataset = try sut.parse(url: testFile)

        // Then
        XCTAssertEqual(dataset.studyInstanceUID, "1.2.840.113619.2.55.3.12345")
        XCTAssertEqual(dataset.patientName, "Doe^John")
        XCTAssertEqual(dataset.rows, 512)
        XCTAssertEqual(dataset.columns, 512)
    }

    func testParseInvalidFile() {
        // Given
        let invalidFile = URL(fileURLWithPath: "/tmp/invalid.txt")

        // When/Then
        XCTAssertThrowsError(try sut.parse(url: invalidFile)) { error in
            XCTAssertTrue(error is DICOMError)
        }
    }
}
```

### 2.2 Mock Objects

```swift
class MockPACSClient: PACSClient {
    var shouldFailConnection = false
    var stubbedStudies: [DICOMQueryResult] = []

    func connect(to server: PACSServer) async throws {
        if shouldFailConnection {
            throw DICOMError.connectionFailed
        }
    }

    func find(query: DICOMQuery) async throws -> [DICOMQueryResult] {
        return stubbedStudies
    }

    func move(studyUID: String, to destinationAET: String) async throws {
        // Mock implementation
    }
}
```

### 2.3 Test Fixtures

```swift
enum TestFixtures {
    static let sampleCT: VolumeData = {
        VolumeData(
            id: UUID(),
            series: sampleSeries,
            dimensions: SIMD3(512, 512, 400),
            spacing: SIMD3(0.7, 0.7, 1.0),
            dataType: .int16,
            cacheURL: nil,
            windowCenter: 40,
            windowWidth: 400
        )
    }()

    static let samplePatient: Patient = {
        Patient(
            id: UUID(),
            patientID: "TEST-001",
            name: PersonName(familyName: "Test", givenName: "Patient", middleName: nil, prefix: nil, suffix: nil),
            birthDate: Date(),
            sex: .male
        )
    }()
}
```

## 3. Integration Testing

### 3.1 DICOM Workflow Tests

```swift
final class DICOMWorkflowTests: XCTestCase {
    var pacsClient: DICOMwebClient!
    var dicomService: DICOMService!
    var storageService: StorageService!

    func testCompleteStudyLoadWorkflow() async throws {
        // Given
        let studyUID = "1.2.840.113619.2.55.3.12345"

        // When: Query PACS
        let queryResults = try await pacsClient.queryStudies(filters: ["StudyInstanceUID": studyUID])

        // Then: Should find study
        XCTAssertEqual(queryResults.count, 1)

        // When: Retrieve study
        let studyData = try await pacsClient.retrieveStudy(studyUID: studyUID)

        // Then: Should have data
        XCTAssertFalse(studyData.isEmpty)

        // When: Parse DICOM
        let study = try await dicomService.loadStudy(from: studyData)

        // Then: Should parse correctly
        XCTAssertEqual(study.studyInstanceUID, studyUID)

        // When: Save to storage
        try await storageService.saveStudy(study)

        // Then: Should be retrievable
        let retrieved = try await storageService.retrieveStudy(uid: studyUID)
        XCTAssertNotNil(retrieved)
    }
}
```

### 3.2 Rendering Pipeline Tests

```swift
final class RenderingPipelineTests: XCTestCase {
    var renderingEngine: RenderingEngine!
    var metalDevice: MTLDevice!

    func testVolumeCreationAndRendering() async throws {
        // Given
        let volume = TestFixtures.sampleCT
        metalDevice = MTLCreateSystemDefaultDevice()!
        renderingEngine = RenderingEngineImpl(device: metalDevice)

        // When: Create volume entity
        let entity = try await renderingEngine.createVolume(from: volume)

        // Then: Should have valid entity
        XCTAssertNotNil(entity)

        // When: Apply windowing
        try await renderingEngine.applyWindowing(entity, window: WindowLevel(center: 300, width: 2000))

        // Then: Should complete without error
        // (Visual verification would be done in UI tests)
    }
}
```

## 4. End-to-End Testing

### 4.1 UI Testing

```swift
import XCTest

final class MedicalImagingSuiteUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testLoadAndViewStudy() {
        // Given: App is launched

        // When: Tap on first study in worklist
        let firstStudy = app.tables.cells.firstMatch
        XCTAssertTrue(firstStudy.waitForExistence(timeout: 5))
        firstStudy.tap()

        // Then: 3D volume should appear
        let volumeView = app.otherElements["VolumeView"]
        XCTAssertTrue(volumeView.waitForExistence(timeout: 10))

        // When: Perform pinch gesture to scale
        volumeView.pinch(withScale: 1.5, velocity: 1.0)

        // Then: Volume should be scaled (verify via accessibility)
        // (Actual spatial verification requires additional tooling)
    }

    func testAnnotationWorkflow() {
        // Load study
        let firstStudy = app.tables.cells.firstMatch
        firstStudy.tap()

        // Wait for volume
        let volumeView = app.otherElements["VolumeView"]
        XCTAssertTrue(volumeView.waitForExistence(timeout: 10))

        // Open annotation tools
        let toolsButton = app.buttons["AnnotationTools"]
        toolsButton.tap()

        // Select freehand tool
        let freehandButton = app.buttons["Freehand"]
        freehandButton.tap()

        // Draw annotation (simulated gesture)
        // (Actual gesture testing requires Vision Pro simulator/device)

        // Verify annotation appears
        let annotationsList = app.tables["AnnotationsList"]
        XCTAssertEqual(annotationsList.cells.count, 1)
    }
}
```

## 5. Performance Testing

### 5.1 Rendering Performance

```swift
final class RenderingPerformanceTests: XCTestCase {
    var renderingEngine: RenderingEngine!

    func testVolumeRenderingPerformance() {
        // Measure time to render 512³ volume
        let volume = TestFixtures.largeCT  // 512×512×512

        measure {
            let entity = try! await renderingEngine.createVolume(from: volume)
            // Force rendering
            _ = entity.bounds
        }

        // Assert: Should complete within performance budget
        // XCTest automatically reports baseline comparison
    }

    func testDICOMLoadingPerformance() async throws {
        let studyURL = TestFixtures.sampleCTURL

        // Measure
        let metrics: [XCTMetric] = [
            XCTClockMetric(),
            XCTMemoryMetric(),
            XCTStorageMetric()
        ]

        let measureOptions = XCTMeasureOptions()
        measureOptions.iterationCount = 5

        measure(metrics: metrics, options: measureOptions) {
            _ = try! await dicomService.loadStudy(from: studyURL)
        }
    }
}
```

### 5.2 Memory Testing

```swift
final class MemoryTests: XCTestCase {
    func testMemoryUsageUnderLoad() async throws {
        // Load multiple large studies
        let studies = [
            TestFixtures.largeCT1,
            TestFixtures.largeCT2,
            TestFixtures.largeCT3
        ]

        let initialMemory = getMemoryUsage()

        for study in studies {
            _ = try await renderingEngine.createVolume(from: study)
        }

        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        // Assert: Memory increase should be reasonable (<= 4GB for 3 large studies)
        XCTAssertLessThan(memoryIncrease, 4_000_000_000)
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}
```

## 6. Security Testing

### 6.1 Encryption Tests

```swift
final class EncryptionTests: XCTestCase {
    var encryptionService: EncryptionService!

    func testDataEncryptionDecryption() async throws {
        // Given
        let originalData = "Sensitive PHI Data".data(using: .utf8)!

        // When: Encrypt
        let encrypted = try await encryptionService.encrypt(originalData)

        // Then: Should be different
        XCTAssertNotEqual(encrypted.ciphertext, originalData)

        // When: Decrypt
        let decrypted = try await encryptionService.decrypt(encrypted)

        // Then: Should match original
        XCTAssertEqual(decrypted, originalData)
    }

    func testEncryptionUsesAES256() throws {
        let key = try encryptionService.getMasterKey()
        XCTAssertEqual(key.bitCount, 256)
    }
}
```

### 6.2 Authentication Tests

```swift
final class AuthenticationTests: XCTestCase {
    var authService: BiometricAuthService!

    func testFailedAuthenticationPreventsAccess() async {
        // Mock failed biometric authentication
        // (Requires test environment configuration)

        // Attempt to access protected resource
        let result = await authService.authenticate()

        // Should fail
        XCTAssertFalse(result)
    }
}
```

## 7. Clinical Validation Testing

### 7.1 DICOM Conformance

```swift
final class DICOMConformanceTests: XCTestCase {
    func testDICOMStandardCompliance() throws {
        // Test support for required DICOM tags
        let requiredTags: [DICOMTag] = [
            .studyInstanceUID,
            .seriesInstanceUID,
            .sopInstanceUID,
            .patientID,
            .patientName,
            .modality
        ]

        for tag in requiredTags {
            XCTAssertTrue(dicomParser.supportsTag(tag))
        }
    }

    func testTransferSyntaxSupport() {
        // Test support for common transfer syntaxes
        let supportedSyntaxes: [String] = [
            "1.2.840.10008.1.2",      // Implicit VR Little Endian
            "1.2.840.10008.1.2.1",    // Explicit VR Little Endian
            "1.2.840.10008.1.2.4.57", // JPEG Lossless
        ]

        for syntax in supportedSyntaxes {
            XCTAssertTrue(dicomParser.supportsTransferSyntax(syntax))
        }
    }
}
```

### 7.2 AI Model Validation

```swift
final class AIModelValidationTests: XCTestCase {
    func testLungNoduleDetectionAccuracy() async throws {
        // Load FDA-approved test dataset
        let testDataset = TestDatasets.lungNoduleDetection

        var truePositives = 0
        var falsePositives = 0
        var trueNegatives = 0
        var falseNegatives = 0

        for testCase in testDataset {
            let prediction = try await aiService.detectLesions(in: testCase.volume)
            let groundTruth = testCase.annotations

            // Compare
            // (Detailed comparison logic)
        }

        let sensitivity = Float(truePositives) / Float(truePositives + falseNegatives)
        let specificity = Float(trueNegatives) / Float(trueNegatives + falsePositives)

        // FDA requirements for CAD systems
        XCTAssertGreaterThan(sensitivity, 0.90, "Sensitivity must exceed 90%")
        XCTAssertGreaterThan(specificity, 0.85, "Specificity must exceed 85%")
    }
}
```

## 8. Test Coverage

### 8.1 Coverage Requirements

| Module | Target Coverage | Critical Paths |
|--------|----------------|----------------|
| **DICOMKit** | 90% | Parsing, encoding |
| **RenderingEngine** | 75% | Ray casting, mesh generation |
| **SecurityService** | 95% | Encryption, authentication |
| **PACSClient** | 85% | Network operations |
| **AIMLService** | 80% | Model inference |

### 8.2 Measuring Coverage

```bash
# Run tests with code coverage
xcodebuild test \
  -scheme MedicalImagingSuite \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  -enableCodeCoverage YES

# Generate coverage report
xcrun xccov view --report coverage.xccovreport
```

## 9. Continuous Integration

### 9.1 CI Pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app

      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -scheme MedicalImagingSuite \
            -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
            -enableCodeCoverage YES

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xccovreport
```

## 10. Test Data Management

### 10.1 Synthetic Test Data

```swift
struct SyntheticDICOMGenerator {
    func generateCTScan(dimensions: SIMD3<Int>) -> Data {
        // Generate synthetic DICOM file with known patterns
        // Useful for testing without real patient data
        let dataset = DICOMDataset()
        dataset.set(tag: .studyInstanceUID, value: UUID().uuidString)
        dataset.set(tag: .rows, value: dimensions.y)
        dataset.set(tag: .columns, value: dimensions.x)

        // Generate synthetic pixel data (e.g., sphere in center)
        let pixelData = generateSpherePattern(dimensions: dimensions)
        dataset.set(tag: .pixelData, value: pixelData)

        return dataset.encode()
    }

    private func generateSpherePattern(dimensions: SIMD3<Int>) -> Data {
        // Create sphere pattern for testing segmentation/rendering
        let center = SIMD3<Float>(
            Float(dimensions.x) / 2,
            Float(dimensions.y) / 2,
            Float(dimensions.z) / 2
        )
        let radius: Float = 50.0

        var voxels = [Int16](repeating: 0, count: dimensions.x * dimensions.y * dimensions.z)

        for z in 0..<dimensions.z {
            for y in 0..<dimensions.y {
                for x in 0..<dimensions.x {
                    let pos = SIMD3<Float>(Float(x), Float(y), Float(z))
                    let dist = distance(pos, center)

                    if dist <= radius {
                        let index = z * dimensions.y * dimensions.x + y * dimensions.x + x
                        voxels[index] = 1000  // Bone-like density
                    }
                }
            }
        }

        return Data(bytes: voxels, count: voxels.count * MemoryLayout<Int16>.stride)
    }
}
```

---

**Document Control**

- **Author**: QA Engineering Team
- **Reviewers**: Engineering Lead, Clinical Advisor
- **Approval**: VP of Engineering
- **Next Review**: Quarterly or after major releases

