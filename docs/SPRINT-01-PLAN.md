# Sprint 1 Plan: Foundation & DICOM Parser
## Medical Imaging Suite - MVP Development

**Sprint Duration**: 2 weeks (Weeks 1-2)
**Sprint Goal**: Establish project foundation and implement DICOM parser capable of extracting metadata and pixel data from CT/MRI scans

---

## Sprint Objectives

1. ✅ Create functional Xcode project for visionOS
2. ✅ Set up project architecture with modular structure
3. ✅ Implement DICOM tag parser for common transfer syntaxes
4. ✅ Extract pixel data from DICOM files
5. ✅ Create domain models and Core Data schema
6. ✅ Achieve 70%+ unit test coverage for parser

---

## Team Capacity

- **Lead iOS Engineer**: 10 days (80 hours)
- **Backend Engineer**: 10 days (80 hours)
- **Total Capacity**: 160 hours

---

## Sprint Backlog

### Epic 1: Foundation & Project Setup (24 hours)

#### Story 1.1: Create Xcode Project (4 hours)
**Assignee**: Lead iOS Engineer
**Points**: 2

**Tasks**:
- [ ] Create new Xcode project (visionOS App)
- [ ] Set deployment target to visionOS 2.0+
- [ ] Configure Swift 6.0 language mode
- [ ] Set bundle identifier: `com.medicalimaging.suite`
- [ ] Configure app icons and display name
- [ ] Test app launches on Vision Pro simulator

**Acceptance Criteria**:
```swift
// App should launch and display:
WindowGroup {
    Text("Medical Imaging Suite")
}
```

**Deliverable**: Runnable empty app

---

#### Story 1.2: Project Structure & Modules (6 hours)
**Assignee**: Lead iOS Engineer
**Points**: 3

**Tasks**:
- [ ] Create directory structure:
  ```
  MedicalImagingSuite/
  ├── App/
  │   └── MedicalImagingSuiteApp.swift
  ├── Presentation/
  │   ├── Views/
  │   └── ViewModels/
  ├── Application/
  │   └── Managers/
  ├── CoreServices/
  │   ├── DICOMKit/
  │   ├── RenderingEngine/
  │   └── StorageService/
  ├── Models/
  │   ├── Domain/
  │   └── DTOs/
  └── Tests/
      ├── UnitTests/
      └── IntegrationTests/
  ```
- [ ] Create Swift packages for frameworks (DICOMKit, etc.)
- [ ] Set up module dependencies
- [ ] Add README.md to each module

**Acceptance Criteria**:
- All modules compile independently
- No circular dependencies

---

#### Story 1.3: Core Data Model Setup (6 hours)
**Assignee**: Backend Engineer
**Points**: 3

**Tasks**:
- [ ] Create `MedicalImaging.xcdatamodeld`
- [ ] Define entities:
  - PatientEntity
  - StudyEntity
  - SeriesEntity
  - ImageEntity
  - AnnotationEntity
- [ ] Set up relationships
- [ ] Add indexes (studyInstanceUID, patientID, etc.)
- [ ] Create CoreDataStack actor
- [ ] Test stack initialization

**Acceptance Criteria**:
```swift
let stack = await CoreDataStack.shared
let context = stack.viewContext
XCTAssertNotNil(context)
```

---

#### Story 1.4: Testing Infrastructure (4 hours)
**Assignee**: Backend Engineer
**Points**: 2

**Tasks**:
- [ ] Create test target: `MedicalImagingSuiteTests`
- [ ] Set up XCTest framework
- [ ] Create test base class with setup/teardown
- [ ] Add sample DICOM files to test bundle
- [ ] Create TestFixtures utility
- [ ] Configure code coverage reporting
- [ ] Write first smoke test

**Acceptance Criteria**:
```swift
func testProjectSetup() {
    XCTAssertNotNil(Bundle.main)
}
```

---

#### Story 1.5: CI/CD Pipeline (4 hours)
**Assignee**: Lead iOS Engineer
**Points**: 2

**Tasks**:
- [ ] Create `.github/workflows/ci.yml`
- [ ] Configure build job:
  ```yaml
  - Run unit tests
  - Generate code coverage
  - Archive app
  ```
- [ ] Set up Xcode Cloud (or GitHub Actions)
- [ ] Configure test execution on commit
- [ ] Add status badge to README

**Acceptance Criteria**:
- CI runs on every push
- Tests pass in CI environment

---

### Epic 2: DICOM Parser & Data Model (136 hours)

#### Story 2.1: DICOM Tag Parser - Basic Structure (12 hours)
**Assignee**: Backend Engineer
**Points**: 5

**Tasks**:
- [ ] Create `DICOMTag` enum with common tags:
  ```swift
  enum DICOMTag: UInt32 {
      case patientName = 0x00100010
      case studyInstanceUID = 0x0020000D
      case rows = 0x00280010
      case columns = 0x00280011
      // ... 50+ common tags
  }
  ```
- [ ] Create `DICOMDataset` class to store tag/value pairs
- [ ] Implement VR (Value Representation) enum
- [ ] Create `DICOMParser` protocol
- [ ] Write unit tests for tag definitions

**Acceptance Criteria**:
```swift
let tag = DICOMTag.patientName
XCTAssertEqual(tag.rawValue, 0x00100010)
```

---

#### Story 2.2: Implicit VR Little Endian Parser (16 hours)
**Assignee**: Backend Engineer
**Points**: 8

**Tasks**:
- [ ] Implement `readTag()` - read 4 bytes (group, element)
- [ ] Implement `readVL()` - read value length (4 bytes)
- [ ] Implement `readValue()` - read value bytes
- [ ] Handle different VRs:
  - String types (PN, LO, SH, CS)
  - Numeric types (US, UL, SS, SL)
  - Date/Time (DA, TM, DT)
- [ ] Parse DICOM preamble (128 bytes + "DICM")
- [ ] Handle byte order (little endian)
- [ ] Write parser tests with sample DICOM file

**Acceptance Criteria**:
```swift
let parser = DICOMParser()
let dataset = try parser.parse(url: testDICOMFile)
XCTAssertEqual(dataset.string(for: .patientName), "Doe^John")
```

---

#### Story 2.3: Explicit VR Little Endian Parser (12 hours)
**Assignee**: Backend Engineer
**Points**: 5

**Tasks**:
- [ ] Read VR (2 bytes) after tag
- [ ] Handle short form VL (2 bytes) for most VRs
- [ ] Handle long form VL (4 bytes) for OB, OW, SQ, UN
- [ ] Parse transfer syntax UID from meta header
- [ ] Detect transfer syntax automatically
- [ ] Write tests for explicit VR

**Acceptance Criteria**:
```swift
// Should handle both transfer syntaxes
let implicitFile = "implicit-vr.dcm"
let explicitFile = "explicit-vr.dcm"
XCTAssertNoThrow(try parser.parse(url: implicitFile))
XCTAssertNoThrow(try parser.parse(url: explicitFile))
```

---

#### Story 2.4: Pixel Data Extraction (16 hours)
**Assignee**: Backend Engineer
**Points**: 8

**Tasks**:
- [ ] Parse pixel data tag (0x7FE0, 0x0010)
- [ ] Handle uncompressed pixel data
- [ ] Extract rows, columns, bits allocated
- [ ] Extract samples per pixel (grayscale vs RGB)
- [ ] Extract pixel spacing
- [ ] Handle different pixel representations (unsigned/signed)
- [ ] Apply rescale slope and intercept (CT Hounsfield units)
- [ ] Write pixel data to `Data` structure
- [ ] Test with various CT/MRI samples

**Acceptance Criteria**:
```swift
let dataset = try parser.parse(url: ctScanFile)
let pixelData = dataset.pixelData
XCTAssertEqual(dataset.rows, 512)
XCTAssertEqual(dataset.columns, 512)
XCTAssertEqual(pixelData.count, 512 * 512 * 2) // 16-bit
```

---

#### Story 2.5: Multi-Frame Image Support (12 hours)
**Assignee**: Backend Engineer
**Points**: 5

**Tasks**:
- [ ] Parse Number of Frames tag
- [ ] Extract individual frames from pixel data
- [ ] Handle frame-specific metadata
- [ ] Support per-frame functional groups (enhanced DICOM)
- [ ] Write tests for multi-frame MR

**Acceptance Criteria**:
```swift
let dataset = try parser.parse(url: multiFrameMRI)
XCTAssertEqual(dataset.numberOfFrames, 20)
```

---

#### Story 2.6: JPEG Compression Support (Basic) (20 hours)
**Assignee**: Backend Engineer
**Points**: 8

**Tasks**:
- [ ] Detect JPEG transfer syntax
- [ ] Extract JPEG bitstream
- [ ] Decompress using Foundation/Core Graphics:
  ```swift
  let image = UIImage(data: jpegData)
  let cgImage = image?.cgImage
  // Extract pixel values
  ```
- [ ] Handle JPEG baseline
- [ ] Handle JPEG lossless (if time permits)
- [ ] Test with JPEG-compressed DICOM files

**Acceptance Criteria**:
```swift
let dataset = try parser.parse(url: jpegCompressedFile)
XCTAssertNotNil(dataset.pixelData)
// Decompressed correctly
```

---

#### Story 2.7: Domain Models (8 hours)
**Assignee**: Backend Engineer
**Points**: 3

**Tasks**:
- [ ] Create `Patient` struct
- [ ] Create `Study` struct
- [ ] Create `Series` struct
- [ ] Create `ImageInstance` struct
- [ ] Create `VolumeData` struct
- [ ] Create `PersonName` struct with formatting
- [ ] Add Codable conformance
- [ ] Write unit tests for models

**Acceptance Criteria**:
```swift
let patient = Patient(
    id: UUID(),
    patientID: "12345",
    name: PersonName(familyName: "Doe", givenName: "John"),
    birthDate: Date(),
    sex: .male
)
XCTAssertEqual(patient.name.formatted, "John Doe")
```

---

#### Story 2.8: Core Data Repositories (16 hours)
**Assignee**: Backend Engineer
**Points**: 8

**Tasks**:
- [ ] Create `StudyRepository` protocol
- [ ] Implement `CoreDataStudyRepository`
- [ ] Implement CRUD operations:
  - `saveStudy(_:)`
  - `fetchStudy(uid:)`
  - `fetchAllStudies()`
  - `deleteStudy(uid:)`
- [ ] Create mapping functions (Domain ↔ Entity)
- [ ] Handle Core Data async operations
- [ ] Write repository tests (in-memory store)

**Acceptance Criteria**:
```swift
let repo = CoreDataStudyRepository()
try await repo.saveStudy(testStudy)
let retrieved = try await repo.fetchStudy(uid: testStudy.studyInstanceUID)
XCTAssertEqual(retrieved?.patientName, "Doe^John")
```

---

#### Story 2.9: Integration Tests (12 hours)
**Assignee**: Backend Engineer
**Points**: 5

**Tasks**:
- [ ] Test end-to-end DICOM loading workflow:
  1. Parse DICOM file
  2. Create domain models
  3. Save to Core Data
  4. Retrieve from Core Data
- [ ] Test with multiple modalities (CT, MR, XR)
- [ ] Test with various file sizes (small, medium, large)
- [ ] Test error cases (corrupted files, unsupported formats)
- [ ] Measure performance (parsing time)

**Acceptance Criteria**:
```swift
func testCompleteWorkflow() async throws {
    // Parse
    let dataset = try parser.parse(url: testFile)
    let study = mapToStudy(dataset)

    // Save
    try await repository.saveStudy(study)

    // Retrieve
    let retrieved = try await repository.fetchStudy(uid: study.studyInstanceUID)
    XCTAssertNotNil(retrieved)
}
```

---

#### Story 2.10: Documentation & Code Review (12 hours)
**Assignee**: Both Engineers
**Points**: 5

**Tasks**:
- [ ] Write DocC comments for all public APIs
- [ ] Create usage examples in documentation
- [ ] Write DICOM parser README
- [ ] Code review and refactoring
- [ ] Address technical debt
- [ ] Update architecture docs if needed

---

## Definition of Done

### Story Level:
- [ ] Code written and reviewed
- [ ] Unit tests written (70%+ coverage for logic)
- [ ] Integration tests for workflows
- [ ] Documentation updated
- [ ] No critical bugs
- [ ] Passes CI/CD pipeline

### Sprint Level:
- [ ] All stories completed or moved to backlog
- [ ] Sprint demo completed
- [ ] Retrospective conducted
- [ ] Next sprint planned

---

## Sprint Demo (End of Week 2)

**Audience**: Team + Clinical Advisor

**Demo Script**:
1. Show project structure and architecture
2. Load a sample DICOM CT file
3. Display parsed metadata (patient name, study date, etc.)
4. Show extracted pixel data dimensions
5. Show Core Data storage (saved study appears in database)
6. Show unit test results and coverage

**Demo Data**:
- Sample chest CT (512×512×200 slices)
- Sample brain MR (256×256×150 slices)
- Multi-frame cardiac MR

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| DICOM spec complexity | High | Focus on common use cases first, defer rare formats |
| Performance issues with large files | Medium | Profile early, optimize hot paths |
| Vision Pro simulator limitations | Medium | Use iPad simulator for initial UI work |
| JPEG decompression challenges | Medium | Use native APIs (Core Graphics) |

---

## Daily Standup Format

**When**: 10:00 AM daily (15 minutes)

**Questions**:
1. What did I complete yesterday?
2. What will I work on today?
3. Any blockers?

**Focus**: Keep it short, move detailed discussions offline

---

## Sprint Ceremonies

### Sprint Planning (Day 1)
- Review sprint goal
- Break down stories into tasks
- Estimate and commit to backlog

### Daily Standup (Every day)
- 15-minute sync

### Sprint Review/Demo (Last day)
- Demo completed work
- Get feedback

### Sprint Retrospective (Last day)
- What went well?
- What could improve?
- Action items for next sprint

---

## Technical Decisions

### DICOM Library Choice
**Decision**: Build custom parser
**Rationale**:
- Full control over performance
- No C++ bridging complexity (dcmtk)
- Learning opportunity
- Can optimize for visionOS

**Alternative Considered**: dcmtk (C++ library)
**Risk**: More development time, but cleaner Swift API

---

### Core Data vs Realm
**Decision**: Core Data
**Rationale**:
- Native to Apple platforms
- Great Xcode integration
- Battle-tested
- No third-party dependencies

---

## Success Metrics

### Sprint 1 Success Criteria:
- [ ] Parse 100% of test DICOM files
- [ ] Extract metadata correctly (verified against reference)
- [ ] Extract pixel data completely
- [ ] Core Data schema functional
- [ ] 70%+ unit test coverage
- [ ] All CI checks passing
- [ ] Demo completed successfully

---

## Next Sprint Preview (Sprint 2)

**Focus**: Volume Reconstruction & Metal Rendering

**Stories**:
- Epic 3: Volume Reconstruction (1 week)
- Epic 4: Metal Rendering (start, 1 week)

---

**Document Control**

- **Sprint Master**: Lead iOS Engineer
- **Product Owner**: Product Manager
- **Created**: 2025-11-24
- **Sprint Dates**: TBD

