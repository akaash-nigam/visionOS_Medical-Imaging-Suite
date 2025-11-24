# Project Roadmap & Implementation Plan
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Implementation Ready

---

## 1. Product Phases

### Phase 1: MVP (Minimum Viable Product) - 3 months
**Goal**: Core viewing and annotation capabilities for single-user workflow

**Target Users**: Individual radiologists and surgeons for case review

**Success Criteria**:
- Load and display DICOM CT/MRI scans in 3D
- Basic windowing and volume rendering
- Simple measurements and annotations
- Local file import (no PACS yet)
- 60fps rendering performance

### Phase 2: Hospital Integration - 2 months
**Goal**: Connect to hospital PACS systems for clinical workflow

**Success Criteria**:
- PACS worklist integration (DICOM DIMSE or DICOMweb)
- Query and retrieve studies from PACS
- Save annotations back to PACS as DICOM SR
- Basic authentication and audit logging

### Phase 3: AI-Assisted Analysis - 2 months
**Goal**: AI models for lesion detection and organ segmentation

**Success Criteria**:
- Lung nodule detection
- Basic organ segmentation (liver, kidneys)
- Confidence scores and visualization
- FDA pre-submission package prepared

### Phase 4: Collaboration & Advanced Features - 2 months
**Goal**: Multi-user collaboration and surgical planning

**Success Criteria**:
- SharePlay-based collaboration sessions
- Surgical planning tools (implant placement)
- Session recording
- Multi-study comparison

### Phase 5: FDA Clearance & Commercial Launch - 3 months
**Goal**: FDA 510(k) clearance and commercial availability

**Success Criteria**:
- FDA 510(k) clearance obtained
- Clinical validation studies completed
- 5 beta hospital deployments
- App Store submission approved

---

## 2. MVP Scope Definition

### 2.1 MVP Features (Must Have)

| Feature | Description | Priority |
|---------|-------------|----------|
| **DICOM Import** | Load DICOM files from local storage | P0 |
| **3D Volume Rendering** | Display CT/MRI as 3D volume | P0 |
| **Windowing Controls** | Adjust brightness/contrast (HU) | P0 |
| **MPR Views** | Axial, sagittal, coronal slices | P0 |
| **Basic Measurements** | Linear distance, angles | P0 |
| **Simple Annotations** | Freehand drawing, text labels | P0 |
| **Study Metadata** | Display patient info, study details | P0 |
| **Basic Navigation** | Rotate, zoom, pan with gestures | P0 |
| **Local Storage** | Cache recently viewed studies | P0 |
| **Basic Security** | OpticID authentication | P0 |

### 2.2 MVP Non-Goals (Deferred)

- ❌ PACS integration (Phase 2)
- ❌ AI/ML features (Phase 3)
- ❌ Multi-user collaboration (Phase 4)
- ❌ Cloud sync
- ❌ Multiple modality fusion
- ❌ Surgical implant planning
- ❌ EHR integration

### 2.3 MVP Technical Stack

```swift
// Core Technologies for MVP
- Platform: visionOS 2.0+
- Language: Swift 6.0
- UI: SwiftUI
- 3D: RealityKit + Metal
- Storage: Core Data + FileManager
- DICOM: Custom parser (or dcmtk bridge)
```

---

## 3. Epics Breakdown

### Epic 1: Foundation & Project Setup
**Duration**: 1 week
**Dependencies**: None

#### Stories:
- [ ] Create Xcode project for visionOS
- [ ] Set up project structure (modules, frameworks)
- [ ] Configure Core Data model
- [ ] Set up unit testing infrastructure
- [ ] Configure CI/CD pipeline (Xcode Cloud or GitHub Actions)
- [ ] Add test fixtures (sample DICOM files)

**Deliverable**: Empty app that launches on Vision Pro simulator

---

### Epic 2: DICOM Parser & Data Model
**Duration**: 2 weeks
**Dependencies**: Epic 1

#### Stories:
- [ ] Implement DICOM tag parser (implicit/explicit VR)
- [ ] Support common transfer syntaxes (Implicit LE, Explicit LE)
- [ ] Parse patient/study/series metadata
- [ ] Extract pixel data from DICOM files
- [ ] Handle multi-frame images
- [ ] Support JPEG compression (basic)
- [ ] Create domain models (Patient, Study, Series, Image)
- [ ] Implement Core Data entities and repositories
- [ ] Write unit tests for parser

**Deliverable**: Load DICOM file and extract metadata + pixel data

**Acceptance Criteria**:
```swift
// Should be able to:
let parser = DICOMParser()
let dataset = try parser.parse(url: dicomFileURL)
XCTAssertEqual(dataset.patientName, "Doe^John")
XCTAssertEqual(dataset.rows, 512)
XCTAssertEqual(dataset.pixelData.count, 512 * 512 * 2)
```

---

### Epic 3: Volume Reconstruction & Data Pipeline
**Duration**: 1 week
**Dependencies**: Epic 2

#### Stories:
- [ ] Sort DICOM slices by instance number
- [ ] Verify slice spacing consistency
- [ ] Reconstruct 3D volume from 2D slices
- [ ] Normalize Hounsfield units (rescale slope/intercept)
- [ ] Handle different voxel data types (Int16, UInt8)
- [ ] Implement volume data caching
- [ ] Memory-efficient loading for large datasets

**Deliverable**: Convert DICOM series to 3D VolumeData structure

---

### Epic 4: Metal Rendering Pipeline
**Duration**: 3 weeks
**Dependencies**: Epic 3

#### Stories:
- [ ] Set up Metal device and command queue
- [ ] Upload volume data to GPU texture (MTLTexture)
- [ ] Implement ray casting compute shader
- [ ] Add transfer function (intensity → color/opacity)
- [ ] Implement gradient calculation for lighting
- [ ] Add windowing controls (HU center/width)
- [ ] Optimize with early ray termination
- [ ] Implement empty space skipping
- [ ] Add windowing presets (bone, soft tissue, lung)
- [ ] Profile and optimize for 60fps

**Deliverable**: Metal shader that renders volume at 60fps

**Acceptance Criteria**:
- Render 512×512×400 CT scan at 60fps
- Window level/width adjustments responsive (<100ms)
- Memory usage < 1.5GB for typical scan

---

### Epic 5: RealityKit Integration & Spatial UI
**Duration**: 2 weeks
**Dependencies**: Epic 4

#### Stories:
- [ ] Create VolumeEntity with Metal-rendered texture
- [ ] Display volume in RealityView
- [ ] Implement pinch-to-rotate gesture
- [ ] Implement two-hand scale gesture
- [ ] Position volume at life-size scale (1:1)
- [ ] Add spatial UI windows (controls, patient info)
- [ ] Create ornaments for windowing controls
- [ ] Implement look-and-tap selection
- [ ] Add double-tap to reset view

**Deliverable**: Interactive 3D volume in spatial environment

---

### Epic 6: Multi-Planar Reconstruction (MPR)
**Duration**: 1 week
**Dependencies**: Epic 3

#### Stories:
- [ ] Extract axial slices
- [ ] Extract sagittal slices
- [ ] Extract coronal slices
- [ ] Display slices as 2D planes in 3D space
- [ ] Synchronize slice position across views
- [ ] Add slice navigation (swipe gesture)
- [ ] Implement crosshair linking
- [ ] Toggle MPR view mode

**Deliverable**: Switch between volume and MPR views

---

### Epic 7: Measurement Tools
**Duration**: 1 week
**Dependencies**: Epic 5

#### Stories:
- [ ] Implement linear distance measurement
- [ ] Calculate physical distance (mm) using pixel spacing
- [ ] Implement angle measurement (3 points)
- [ ] Display measurement labels in 3D space
- [ ] Persist measurements to Core Data
- [ ] Show measurement list panel
- [ ] Delete measurements

**Deliverable**: Measure distances and angles on anatomy

**Acceptance Criteria**:
- Measure distance with <1mm accuracy
- Measurements persist across sessions
- Clear visual feedback during measurement

---

### Epic 8: Annotation System
**Duration**: 2 weeks
**Dependencies**: Epic 5

#### Stories:
- [ ] Implement freehand drawing in 3D space
- [ ] Add straight line tool
- [ ] Add arrow annotation
- [ ] Add text annotation (keyboard input)
- [ ] Add circle/ellipse ROI tool
- [ ] Attach annotations to volume entity
- [ ] Persist annotations to Core Data
- [ ] List all annotations (sidebar)
- [ ] Edit/delete annotations
- [ ] Color and style picker

**Deliverable**: Draw and save annotations on scans

---

### Epic 9: File Import & Study Management
**Duration**: 1 week
**Dependencies**: Epic 2, Epic 8

#### Stories:
- [ ] Implement file picker for DICOM import
- [ ] Support single file and folder import
- [ ] Parse multiple series in a study
- [ ] Generate study thumbnails
- [ ] Create study list view (worklist UI)
- [ ] Display patient demographics
- [ ] Show study date, modality, description
- [ ] Search/filter studies
- [ ] Delete studies from cache

**Deliverable**: Import DICOM studies and browse worklist

---

### Epic 10: Local Storage & Caching
**Duration**: 1 week
**Dependencies**: Epic 9

#### Stories:
- [ ] Implement encrypted file storage (AES-256)
- [ ] Store DICOM files in app cache directory
- [ ] Implement LRU cache eviction
- [ ] Set cache expiration (7 days default)
- [ ] Add cache size limit (configurable)
- [ ] Display cache usage in settings
- [ ] Clear cache manually
- [ ] Optimize Core Data queries (indexes)

**Deliverable**: Persistent storage with automatic cleanup

---

### Epic 11: Authentication & Security (MVP)
**Duration**: 1 week
**Dependencies**: Epic 1

#### Stories:
- [ ] Implement OpticID biometric authentication
- [ ] Create login screen
- [ ] Session timeout (15 minutes)
- [ ] Lock app when backgrounded
- [ ] Basic audit logging (Core Data)
- [ ] Keychain integration for master key
- [ ] Encryption service (AES-256-GCM)

**Deliverable**: OpticID-protected app with PHI encryption

---

### Epic 12: Settings & Configuration
**Duration**: 3 days
**Dependencies**: Epic 11

#### Stories:
- [ ] Create settings window
- [ ] Cache retention policy settings
- [ ] Default windowing presets
- [ ] Measurement units (mm vs cm)
- [ ] About screen (version, license)
- [ ] Privacy policy display
- [ ] Reset to defaults

**Deliverable**: User-configurable settings

---

### Epic 13: Testing & Polish (MVP)
**Duration**: 1 week
**Dependencies**: All MVP epics

#### Stories:
- [ ] Comprehensive unit test coverage (>70%)
- [ ] Integration tests for key workflows
- [ ] Performance testing (frame rate, memory)
- [ ] UI/UX polish (animations, feedback)
- [ ] Error handling and user messaging
- [ ] Accessibility testing (VoiceOver)
- [ ] Load testing with large datasets
- [ ] Bug fixes from testing

**Deliverable**: Production-ready MVP

---

## 4. Post-MVP Epics (Phase 2-5)

### Epic 14: PACS Integration (DICOM DIMSE)
**Duration**: 2 weeks
**Dependencies**: MVP complete

#### Stories:
- [ ] Implement DICOM DIMSE client (C-ECHO, C-FIND, C-MOVE)
- [ ] PACS server configuration UI
- [ ] Query worklist from PACS
- [ ] Retrieve studies from PACS
- [ ] Store annotations as DICOM SR
- [ ] Test with major PACS vendors (GE, Philips, Siemens)

---

### Epic 15: DICOMweb Integration
**Duration**: 1 week
**Dependencies**: Epic 14

#### Stories:
- [ ] Implement QIDO-RS (query)
- [ ] Implement WADO-RS (retrieve)
- [ ] Implement STOW-RS (store)
- [ ] OAuth 2.0 authentication
- [ ] Multipart DICOM parsing

---

### Epic 16: HL7 FHIR Integration
**Duration**: 1 week
**Dependencies**: Epic 14

#### Stories:
- [ ] FHIR client implementation
- [ ] Fetch Patient resources
- [ ] Fetch ImagingStudy resources
- [ ] Create DiagnosticReport
- [ ] Epic/Cerner integration testing

---

### Epic 17: AI - Lesion Detection
**Duration**: 2 weeks
**Dependencies**: MVP complete

#### Stories:
- [ ] Train/acquire lung nodule detection model
- [ ] Convert model to Core ML
- [ ] Implement preprocessing pipeline
- [ ] Implement postprocessing (NMS)
- [ ] Visualize detections in 3D
- [ ] Show confidence scores
- [ ] Allow radiologist override
- [ ] Validate on test dataset

---

### Epic 18: AI - Organ Segmentation
**Duration**: 2 weeks
**Dependencies**: Epic 17

#### Stories:
- [ ] Train/acquire organ segmentation model
- [ ] Implement semantic segmentation pipeline
- [ ] Generate 3D meshes from segmentation
- [ ] Color-code organs
- [ ] Toggle organ visibility
- [ ] Calculate organ volumes
- [ ] Export segmentation masks

---

### Epic 19: Collaboration - SharePlay
**Duration**: 2 weeks
**Dependencies**: MVP complete

#### Stories:
- [ ] Implement GroupActivity
- [ ] Set up GroupSession
- [ ] Synchronize volume transforms
- [ ] Synchronize annotations
- [ ] Synchronize windowing
- [ ] Show participant avatars
- [ ] Spatial audio integration
- [ ] Session invitation flow

---

### Epic 20: Collaboration - Screen Share
**Duration**: 1 week
**Dependencies**: Epic 19

#### Stories:
- [ ] WebRTC integration
- [ ] Capture RealityView as video stream
- [ ] Share to web browser (non-VisionPro users)
- [ ] Session recording
- [ ] Export recorded sessions

---

### Epic 21: Surgical Planning Tools
**Duration**: 2 weeks
**Dependencies**: Epic 8, Epic 18

#### Stories:
- [ ] Implant library (STL models)
- [ ] Load and position implants
- [ ] Snap implants to anatomy
- [ ] Measure implant fit
- [ ] Plan resection boundaries
- [ ] Calculate resection volume
- [ ] Export surgical plan (PDF)

---

### Epic 22: Multi-Study Comparison
**Duration**: 1 week
**Dependencies**: MVP complete

#### Stories:
- [ ] Side-by-side layout (2-4 studies)
- [ ] Synchronized rotation/zoom
- [ ] Image registration (rigid/affine)
- [ ] Difference highlighting
- [ ] Timeline view for longitudinal studies

---

### Epic 23: Advanced Rendering
**Duration**: 1 week
**Dependencies**: Epic 4

#### Stories:
- [ ] Surface rendering (marching cubes)
- [ ] Maximum Intensity Projection (MIP)
- [ ] Hybrid rendering (surface + volume)
- [ ] Ambient occlusion
- [ ] Depth of field
- [ ] Quality/performance presets

---

### Epic 24: FDA Validation & Documentation
**Duration**: 4 weeks (parallel with development)
**Dependencies**: Epic 17, Epic 18

#### Stories:
- [ ] Write Software Requirements Specification (SRS)
- [ ] Design History File (DHF)
- [ ] Risk analysis (FMEA)
- [ ] Verification testing (unit/integration)
- [ ] Validation testing (clinical studies)
- [ ] 510(k) submission preparation
- [ ] FDA pre-submission meeting

---

## 5. MVP Implementation Timeline

### Month 1: Foundation & Core Rendering
```
Week 1: Epics 1, 2 (Project setup, DICOM parser)
Week 2: Epic 2, 3 (DICOM parser, Volume reconstruction)
Week 3: Epic 4 (Metal rendering - part 1)
Week 4: Epic 4 (Metal rendering - part 2)
```

### Month 2: Spatial UI & Interaction
```
Week 5: Epic 5 (RealityKit integration)
Week 6: Epic 6, 7 (MPR views, Measurements)
Week 7: Epic 8 (Annotations - part 1)
Week 8: Epic 8 (Annotations - part 2)
```

### Month 3: Study Management & Polish
```
Week 9: Epic 9, 10 (File import, Storage)
Week 10: Epic 11, 12 (Security, Settings)
Week 11: Epic 13 (Testing)
Week 12: Epic 13 (Polish & bug fixes)
```

---

## 6. Team Structure (Recommended)

### For MVP (3 months):
- **1 iOS/visionOS Engineer** (Lead) - RealityKit, SwiftUI
- **1 Graphics Engineer** - Metal shaders, rendering optimization
- **1 Backend Engineer** - DICOM parsing, Core Data, storage
- **1 QA Engineer** (part-time) - Testing, validation
- **1 Product Manager** (part-time) - Requirements, clinical input
- **1 Clinical Advisor** (consulting) - Medical workflow validation

### Total: 4.5 FTE for MVP

---

## 7. Milestones & Demos

### Milestone 1 (Week 4): "First Render"
**Demo**: Load a DICOM CT scan and display as 3D volume with basic windowing

### Milestone 2 (Week 8): "Interactive Review"
**Demo**: Navigate scan, adjust windowing, create measurements and annotations

### Milestone 3 (Week 12): "MVP Complete"
**Demo**: Full study import workflow, persistent storage, secure authentication

### Milestone 4 (Month 5): "Hospital Ready"
**Demo**: Connect to hospital PACS, retrieve studies, save annotations back

### Milestone 5 (Month 7): "AI-Powered"
**Demo**: Automatic lesion detection and organ segmentation

### Milestone 6 (Month 9): "Collaboration"
**Demo**: Multi-user session with synchronized viewing and annotations

### Milestone 7 (Month 12): "FDA Cleared"
**Demo**: Commercial launch with FDA 510(k) clearance

---

## 8. Risk Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Metal rendering performance** | High | Medium | Prototype early (Epic 4), use profiling tools |
| **DICOM parser complexity** | High | Medium | Use existing library (dcmtk) or well-tested code |
| **Vision Pro hardware access** | High | Low | Use simulator for most development, rent device |
| **FDA clearance delays** | Critical | Medium | Start pre-submission process early, hire consultant |
| **PACS integration challenges** | Medium | High | Partner with one hospital IT team for testing |
| **Clinical adoption resistance** | High | Medium | Involve physicians early, focus on UX |

---

## 9. Success Metrics

### MVP Success Criteria:
- [ ] Load and render 512-slice CT in < 10 seconds
- [ ] 60fps rendering performance
- [ ] 5 beta users (physicians) actively testing
- [ ] < 5 critical bugs reported
- [ ] 90% of users can complete key tasks without training
- [ ] NPS score > 50

### Phase 2 (Hospital Integration) Success:
- [ ] Successfully connected to 3 different PACS vendors
- [ ] Retrieve studies in < 30 seconds over hospital network
- [ ] 10 daily active users at beta hospital
- [ ] Annotations successfully saved to PACS

### Phase 3 (AI) Success:
- [ ] Lesion detection sensitivity > 90%
- [ ] Segmentation Dice score > 0.85
- [ ] AI results reviewed by radiologist in < 1 minute
- [ ] FDA pre-submission feedback received

---

## 10. Next Steps

### Immediate Actions (This Week):
1. ✅ Create project roadmap (this document)
2. ⬜ Set up Xcode project for visionOS
3. ⬜ Create project board (GitHub Projects or Jira)
4. ⬜ Add all epics and stories to backlog
5. ⬜ Acquire Vision Pro device or simulator access
6. ⬜ Obtain sample DICOM test files
7. ⬜ Set up development environment

### Sprint 1 (Week 1-2): Epic 1 & 2
**Goal**: Project foundation and DICOM parser

**Sprint Planning**:
- Story pointing and estimation
- Assign stories to developers
- Set up daily standups
- Define sprint demo format

---

**Document Control**

- **Author**: Product & Engineering Team
- **Reviewers**: CTO, Clinical Advisor, Project Manager
- **Approval**: CEO
- **Next Review**: End of each sprint

