# Product Requirements Document: Medical Imaging Suite

## Executive Summary

Medical Imaging Suite transforms medical image review and surgical planning for Apple Vision Pro by enabling physicians to view patient scans at life-size scale in their physical space, compare multiple imaging modalities side-by-side, draw surgical plans directly on 3D anatomical models, and collaborate with specialists globally in a shared spatial environment.

## Product Vision

Revolutionize medical imaging workflows by leveraging spatial computing to provide surgeons, radiologists, and specialists with an intuitive, immersive platform for diagnosis, surgical planning, and collaborative consultation that improves patient outcomes and reduces time to treatment.

## Target Users

### Primary Users
- Orthopedic surgeons (pre-operative planning)
- Neurosurgeons (tumor resection, spine surgery)
- Radiologists (diagnostic image review)
- Cardiothoracic surgeons (cardiac and vascular planning)
- Interventional radiologists (procedure planning)
- Plastic and reconstructive surgeons

### Secondary Users
- Medical students and residents (education)
- Referring physicians (consultation)
- Medical device representatives (implant planning)
- Patient educators (explaining procedures)

## Market Opportunity

- Global medical imaging software market: $4.1B by 2028
- 3D medical imaging market: $11.2B by 2030 (CAGR 8.3%)
- Average hospital spends $500K-$2M/year on imaging software
- 50+ DICOM images viewed per radiologist per day
- Surgical planning software adoption: 35% of hospitals (growing 12% YoY)
- Telemedicine consultations: Growing 40% annually

## Core Features

### 1. Life-Size Scan Visualization

**Description**: CT, MRI, and X-ray scans displayed at actual anatomical scale floating in the user's physical space

**User Stories**:
- As a surgeon, I want to view patient anatomy at life-size so I can better plan surgical approach
- As a radiologist, I want to walk around a 3D scan to examine it from all angles
- As an orthopedic surgeon, I want to overlay a patient's scan on the actual patient for reference during surgery

**Acceptance Criteria**:
- Support for DICOM format (CT, MRI, PET, X-ray, ultrasound)
- 1:1 scale rendering (scan dimensions match actual anatomy)
- Adjustable opacity for soft tissue vs. bone visualization
- Windowing controls (Hounsfield units for CT)
- Segmentation of anatomical structures (automatic and manual)
- Region of interest (ROI) measurements
- 3D volume rendering from 2D slices
- Slice-by-slice navigation with gesture

**Technical Requirements**:
- DICOM parser (supports DICOM 3.0 standard)
- 3D reconstruction algorithms (marching cubes, ray casting)
- RealityKit for spatial rendering
- Metal shaders for volume rendering
- Support for 512×512 to 1024×1024 slice resolution
- Render 500+ slices in < 5 seconds
- 60fps minimum frame rate

**Visualization Modes**:
```
Rendering Types:
1. Volume Rendering: Full 3D semi-transparent view
2. Maximum Intensity Projection (MIP): Brightest voxels
3. Surface Rendering: Segmented structures
4. Multi-Planar Reconstruction (MPR): Axial, sagittal, coronal slices
5. Hybrid: Bone surface + soft tissue transparency

Windowing Presets (CT):
- Bone: Window 2000 HU, Level 300 HU
- Soft Tissue: Window 400 HU, Level 40 HU
- Lung: Window 1500 HU, Level -600 HU
- Brain: Window 80 HU, Level 40 HU
```

### 2. Side-by-Side Scan Comparison

**Description**: Display multiple scans simultaneously in spatial arrangement for temporal comparison or multi-modality fusion

**User Stories**:
- As a radiologist, I want to compare pre and post-treatment scans to assess progression
- As a neurosurgeon, I want to view MRI and CT scans together for comprehensive planning
- As an oncologist, I want to compare PET and CT scans for tumor staging

**Acceptance Criteria**:
- Display up to 4 scans simultaneously
- Synchronized rotation and zoom across all scans
- Registration tools for aligning different modality scans
- Linked crosshairs showing corresponding anatomical locations
- Difference highlighting (e.g., tumor growth over time)
- Timeline view for longitudinal studies
- Automatic patient matching and chronological ordering

**Technical Requirements**:
- Image registration algorithms (rigid, affine, deformable)
- Real-time synchronization of viewpoints
- Fusion rendering for overlaying modalities
- Support for different coordinate systems (LPS, RAS)
- Memory management for multiple large datasets (up to 4GB total)

**Comparison Modes**:
```
1. Side-by-Side: Independent scans in spatial array
2. Overlay: Blend two scans with adjustable transparency
3. Fusion: Color-coded overlay (e.g., PET heatmap on CT)
4. Difference Map: Highlight changes between timepoints
5. Synchronized MPR: Corresponding slices across modalities
```

### 3. Surgical Planning Tools

**Description**: Draw, measure, and annotate directly on 3D anatomical models to plan surgical approach

**User Stories**:
- As a surgeon, I want to draw the incision path directly on the patient anatomy
- As an orthopedic surgeon, I want to measure bone dimensions for implant sizing
- As a neurosurgeon, I want to plan the safest trajectory to reach a deep tumor

**Acceptance Criteria**:
- 3D drawing tools: pen, highlighter, arrow, text annotation
- Measurement tools: linear, angular, volumetric
- Segmentation tools: select anatomical structures (tumor, organ, vessel)
- Implant placement: Load 3D models of surgical implants and position them
- Resection planning: Mark tissue to be removed
- Save and export surgical plans (PDF, 3D models)
- Integration with surgical navigation systems

**Technical Requirements**:
- 3D mesh editing and annotation
- Precise hand tracking for drawing (sub-millimeter accuracy)
- 3D model import (STL, OBJ formats) for implants
- Boolean operations for virtual resection
- Export to DICOM, STL, PDF
- Integration APIs for surgical navigation systems (Brainlab, Medtronic)

**Planning Tools**:
```
Drawing Tools:
- Freehand Pen: Draw paths and markings
- Straight Line: Measure distances
- Angle Tool: Measure joint angles
- Protractor: Surgical approach angles
- Volume Selector: Tumor volume calculation

Implant Library:
- Orthopedic: Hip stems, knee components, plates, screws
- Spine: Pedicle screws, cages, rods
- Cranial: Plates, mesh
- Custom: Import patient-specific implants

Measurements:
- Linear: mm precision
- Volumetric: cm³ for tumors, organs
- Angular: Degrees for joint alignment
- Density: Hounsfield units sampling
```

### 4. Global Collaboration

**Description**: Multi-user spatial sessions where specialists from different locations review scans together

**User Stories**:
- As a surgeon, I want to consult with a specialist across the country on a complex case
- As a radiologist, I want to present interesting cases to my tumor board
- As a medical student, I want to join attending physicians during case review for learning

**Acceptance Criteria**:
- Up to 8 simultaneous participants
- Participants see shared 3D scan in synchronized space
- Each user's pointer/annotations visible to all
- Spatial audio: voices positioned at avatar locations
- Screen sharing for participants without Vision Pro
- Recording capability for teaching files
- HIPAA-compliant encrypted transmission
- Session invitations via secure link

**Technical Requirements**:
- SharePlay or custom WebRTC implementation
- End-to-end encryption (AES-256)
- Real-time state synchronization (< 150ms latency)
- Adaptive quality based on bandwidth
- HIPAA compliance certification
- Session recording with patient consent management

**Collaboration Features**:
```
Roles:
- Host: Primary physician, full controls
- Co-Host: Consulting specialist, annotation privileges
- Observer: Medical student, view-only

Tools:
- Laser Pointer: Point at anatomical features
- Shared Annotations: All users see markings
- Private Notes: Personal observations
- Snapshot: Capture current view for report
- Voice Notes: Attach audio commentary

Session Management:
- Schedule: Calendar integration
- Invite: Secure link generation
- Record: MP4 video + 3D state file
- Export: Generate consultation report
```

### 5. Patient Data Integration

**Description**: Seamless integration with hospital PACS and EHR systems for retrieving patient imaging and clinical data

**User Stories**:
- As a radiologist, I want to pull patient scans directly from PACS without manual downloads
- As a surgeon, I want to view patient history and lab results alongside imaging
- As a physician, I want my annotations saved back to the patient record

**Acceptance Criteria**:
- DICOM PACS integration (query and retrieve)
- HL7 FHIR integration for clinical data
- Worklist display: pending studies to review
- Prior study comparison: automatic retrieval of previous exams
- Radiologist reporting: dictation and structured reporting
- Bidirectional sync: annotations saved to PACS
- Support for major PACS vendors (GE, Philips, Siemens, Fuji)

**Technical Requirements**:
- DICOM DIMSE protocol (C-FIND, C-MOVE, C-STORE)
- DICOMweb support (WADO, QIDO, STOW)
- HL7 FHIR API client
- OAuth 2.0 for EHR authentication
- On-device encryption for cached patient data
- HIPAA compliance for data handling

**Integration Architecture**:
```
Data Flow:
1. User authenticates with hospital system
2. App queries PACS worklist
3. User selects patient study
4. DICOM images retrieved and cached locally
5. 3D reconstruction performed on device
6. User reviews and annotates
7. Annotations sent back to PACS as DICOM SR
8. Report generated and saved to EHR

Supported Systems:
- PACS: GE Centricity, Philips IntelliSpace, Siemens syngo
- EHR: Epic, Cerner, Allscripts
- VNA: Vendor-neutral archives
- Cloud PACS: Ambra, Nuance PowerShare
```

### 6. AI-Assisted Analysis

**Description**: Machine learning models for automated detection, segmentation, and quantification

**User Stories**:
- As a radiologist, I want AI to pre-identify suspicious lesions for faster review
- As a surgeon, I want automatic segmentation of tumors and critical structures
- As a cardiologist, I want automated ejection fraction calculation from cardiac MRI

**Acceptance Criteria**:
- Automated lesion detection (lung nodules, liver lesions, brain tumors)
- Organ segmentation (liver, kidneys, heart, brain)
- Quantitative measurements (tumor volume, ejection fraction, stenosis)
- AI confidence scores displayed
- Radiologist override and correction capability
- FDA-cleared algorithms where required
- On-device processing (privacy-preserving)

**Technical Requirements**:
- Core ML models for on-device inference
- Support for ONNX model import
- GPU acceleration via Metal
- Real-time inference (< 10 seconds per scan)
- Model versioning and update mechanism
- FDA 510(k) clearance for diagnostic models

**AI Capabilities**:
```
Detection Models:
- Lung: Nodule detection, classification (benign/malignant probability)
- Brain: Hemorrhage, stroke, tumor detection
- Chest: Pneumonia, pneumothorax, fractures
- Abdomen: Liver lesions, kidney stones

Segmentation Models:
- Organs: Liver, kidneys, spleen, pancreas, heart
- Vessels: Aorta, coronary arteries, intracranial vessels
- Pathology: Tumors, edema, infarcts

Quantification:
- Cardiology: Ejection fraction, wall motion, valve area
- Oncology: Tumor volume, RECIST measurements
- Neurology: Brain volume, lesion load
- Orthopedics: Bone mineral density, fracture gap
```

## User Experience

### Onboarding Flow
1. User downloads Medical Imaging Suite
2. Hospital IT configures PACS/EHR integration
3. Physician logs in with hospital credentials
4. Interactive tutorial: scan visualization, gestures, tools
5. HIPAA training acknowledgment
6. Ready to review first patient

### Primary User Flow: Radiologist Reading Study

1. Open app, view worklist from PACS
2. Select patient study to review
3. Scans load and reconstruct in 3D
4. Walk around scan, examine from multiple angles
5. Adjust windowing to view different tissues
6. AI highlights potential findings
7. Measure suspicious lesion
8. Annotate with voice dictation
9. Compare with prior study (loads automatically)
10. Generate structured report
11. Sign and send to EHR
12. Next study

### Primary User Flow: Surgeon Planning Operation

1. Open app, load patient's pre-op CT
2. View anatomy at life-size scale
3. Segment tumor and critical structures (AI-assisted)
4. Load implant 3D models
5. Position implant on anatomy
6. Measure and verify sizing
7. Draw planned incision path
8. Mark critical structures to avoid
9. Invite specialist for second opinion
10. Collaborate in real-time discussion
11. Finalize plan, export to PDF
12. Share with surgical team

### Gesture Controls

```
Navigation:
- Pinch + Drag: Rotate scan
- Two-hand Pinch-Zoom: Scale scan
- Look + Tap: Select anatomical structure
- Swipe: Navigate through slices

Tools:
- Draw: Index finger extended, pinch to draw
- Measure: Two-finger points, measure distance
- Annotate: Voice command "Add note"
- Segment: Circle structure with finger

Windowing:
- Vertical Drag: Adjust window level
- Horizontal Drag: Adjust window width
- Two-finger Twist: Rotate view
```

## Design Specifications

### Visual Design

**Color Palette**:
- Medical Blue: #1E88E5
- Bone: #E0E0E0 (gray-white)
- Soft Tissue: #FF9800 (amber)
- Vessels: #F44336 (red)
- Tumor: #9C27B0 (purple)
- Annotations: #4CAF50 (green)
- Background: Neutral gray #424242

**Typography**:
- UI Font: SF Pro (clear, clinical)
- Monospace: SF Mono (measurements, patient ID)
- Sizes: 14-20pt for readability
- High contrast for operating room lighting

### Spatial Layout

**Default Workspace**:
- Center: Primary 3D scan (life-size)
- Left: Patient info panel, prior studies
- Right: Measurement tools, annotations list
- Top: Windowing controls, rendering mode
- Bottom: Timeline, slice navigator

**Specialized Layouts**:
- **Reading Room**: Worklist + current study
- **Surgical Planning**: Scan + implant library + tools
- **Teaching**: Scan + annotation panel + video feed
- **Consultation**: Dual scans + collaboration panel

### Information Hierarchy
1. Patient anatomy (scan) - largest, central
2. Critical measurements and AI findings
3. Patient demographics and study info
4. Tool palettes and controls
5. Worklist and administrative functions

## Technical Architecture

### Platform
- Apple Vision Pro (visionOS 2.0+)
- Swift 6.0+
- SwiftUI + RealityKit + Metal

### System Requirements
- visionOS 2.0 or later
- 16GB RAM minimum (medical imaging is memory-intensive)
- 256GB storage for local scan caching
- Hospital network access for PACS integration
- HIPAA-compliant deployment environment

### Key Technologies
- **RealityKit**: 3D rendering engine
- **Metal**: GPU-accelerated volume rendering
- **Core ML**: AI model inference
- **DICOM Toolkit**: dcmtk or custom parser
- **Spatial Audio**: Collaboration voice positioning
- **SharePlay**: Multi-user sessions (if HIPAA-compliant)

### Data Architecture

```
Local Storage:
- Patient Cache: Encrypted SQLite + file storage
- DICOM Files: Encrypted on-device storage
- Annotations: Core Data (synced to PACS)
- AI Models: Core ML models (300MB-2GB)

Network:
- PACS: DICOM DIMSE or DICOMweb
- EHR: HL7 FHIR REST API
- Collaboration: WebRTC peer-to-peer (encrypted)

Security:
- Encryption at Rest: AES-256
- Encryption in Transit: TLS 1.3
- Authentication: OAuth 2.0 + SAML
- Audit Logging: All patient data access logged
```

### Performance Targets
- Time to load 512-slice CT: < 10 seconds
- 3D reconstruction time: < 15 seconds
- Frame rate: 60fps minimum (90fps target)
- Collaboration latency: < 150ms
- AI inference time: < 10 seconds per scan
- Memory usage: < 8GB for typical studies

## Regulatory & Compliance

### FDA Regulations

**Software as Medical Device (SaMD)**:
- **Class I (General Wellness)**: Viewing and sharing scans
  - 510(k) exempt

- **Class II (Moderate Risk)**: Measurement, surgical planning, AI-assisted detection
  - Requires FDA 510(k) clearance
  - Predicate devices: OsiriX, Vitrea, syngo.via

- **Class III (High Risk)**: Automated diagnosis
  - Not planned for initial release

**Strategy**: Launch with Class I features, pursue 510(k) for advanced features in Phase 2

### HIPAA Compliance

**Required Controls**:
- Access control: Role-based, unique user IDs
- Audit controls: Log all patient data access
- Integrity controls: Prevent unauthorized alterations
- Transmission security: TLS 1.3 encryption
- Business Associate Agreements (BAA) with cloud providers

**Privacy Measures**:
- Minimum necessary: Only retrieve relevant patient data
- De-identification: Support for anonymization (for teaching)
- Patient consent: For recordings and sharing
- Breach notification: Automated detection and reporting

### International Standards
- **DICOM 3.0**: Full conformance
- **HL7 FHIR R4**: Patient, Imaging Study, Diagnostic Report
- **IHE Profiles**: XDS-I (Cross-Enterprise Document Sharing)
- **CE Mark**: For European Union distribution (MDR compliance)

## Security & Privacy

### Security Architecture
- **Zero-Trust Model**: All data assumed sensitive
- **Device Security**: OpticID biometric authentication
- **Network Security**: VPN required for hospital connection
- **Data Security**: End-to-end encryption
- **Application Security**: Code signing, anti-tampering

### Privacy by Design
- **Data Minimization**: Only request necessary scans
- **On-Device Processing**: AI runs locally, not cloud
- **Automatic Purging**: Delete patient data after session (configurable)
- **No Analytics**: No usage data containing PHI sent to developers
- **Patient Rights**: Support for access, correction, deletion requests

### Audit Trail
```
Logged Events:
- User login/logout
- Patient record access
- DICOM retrieve operations
- Annotations created/modified
- Reports generated
- Sharing/collaboration sessions
- AI model usage
- Export operations

Log Fields:
- Timestamp (synchronized)
- User ID
- Patient ID (hashed in logs)
- Action type
- Result (success/failure)
- Source IP address
```

## Monetization Strategy

### Pricing Models

**Option 1: Enterprise Licensing (Recommended)**
- **Per-Seat Annual License**: $5,000/year per physician
  - PACS/EHR integration
  - AI-assisted analysis
  - Collaboration features (up to 8 users)
  - Training and support
  - Regulatory compliance updates

- **Department License**: $50,000/year for up to 15 users
  - All features
  - Custom integrations
  - Dedicated support
  - On-site training

- **Hospital Enterprise**: $200,000/year unlimited users
  - All features
  - White-label option
  - On-premise deployment option
  - Priority feature development

**Option 2: Usage-Based**
- $50 per study reviewed
- Volume discounts for high-usage departments

**Additional Revenue Streams**:
1. Professional services: Integration, training, customization
2. AI model licensing: Hospital-specific fine-tuned models
3. Cloud PACS storage: For hospitals without infrastructure
4. Continuing Medical Education (CME) courses

### Target Revenue
- Year 1: $2M (40 enterprise seats @ $5K each)
- Year 2: $10M (8 departments @ $50K + 120 seats)
- Year 3: $30M (5 hospital enterprises + growth)

## Success Metrics

### Primary KPIs
- **User Adoption**: 500 active physicians within 12 months
- **Customer Retention**: > 90% annual renewal rate
- **Clinical Impact**: 20% reduction in surgical planning time (measured)
- **Revenue**: $2M ARR by end of Year 1

### Secondary KPIs
- **Diagnostic Accuracy**: 95%+ AI sensitivity for lesion detection
- **User Satisfaction**: NPS > 60
- **System Uptime**: 99.9% availability
- **Support Tickets**: < 5 per user per year
- **Training Time**: Physicians proficient within 2 hours

### Clinical Outcomes (Long-term)
- Surgical complication reduction
- Improved diagnostic concordance
- Reduced time to treatment
- Increased patient satisfaction
- Publications in medical literature

## Launch Strategy

### Phase 1: Alpha Testing (Months 1-3)
- Partner with 2 academic medical centers
- 10 surgeon/radiologist users
- Core features: Scan viewing, measurements, basic tools
- DICOM integration only (no AI)
- Gather extensive clinical feedback

### Phase 2: Beta Testing (Months 4-6)
- Expand to 5 hospitals, 50 users
- Add: AI segmentation, collaboration
- Begin FDA 510(k) submission process
- Clinical validation studies
- Iterate based on feedback

### Phase 3: Limited Release (Months 7-9)
- FDA 510(k) clearance obtained
- Launch to 10 paying customers
- Full feature set
- Marketing to specialty conferences
- Case studies and publications

### Phase 4: General Availability (Months 10-12)
- Public launch
- Sales team expansion
- Marketing campaign
- International expansion planning (CE Mark)

## Marketing Strategy

### Target Channels
- **Medical Conferences**: RSNA, AAOS, AANS, ACC
  - Booth with live demos
  - Speaking sessions and workshops
  - CME-accredited courses

- **Publications**:
  - Peer-reviewed journals: Journal of Surgical Planning, Radiology
  - Trade publications: Healthcare IT News, Diagnostic Imaging
  - Case studies demonstrating clinical outcomes

- **KOL Partnerships**:
  - Partner with respected surgeons and radiologists
  - Advisory board of medical thought leaders
  - Published testimonials and case series

- **Hospital IT**:
  - Webinars for CIOs and IT directors
  - Integration partner ecosystem
  - Proof-of-concept programs

### Launch Campaign
- "Surgery in a New Dimension" tagline
- Video: Surgeon planning complex spinal fusion in 3D
- ROI calculator: Time savings, reduced complications
- Free 30-day pilot program for departments

## Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| FDA clearance delayed/denied | Critical | Medium | Early engagement with FDA, experienced regulatory consultant |
| HIPAA breach | Critical | Low | Rigorous security audit, penetration testing, insurance |
| Hospital IT integration challenges | High | High | Dedicate integration team, support major PACS vendors |
| Physician adoption resistance | High | Medium | KOL champions, comprehensive training, ROI demonstration |
| Performance issues with large datasets | Medium | Medium | Optimize rendering, progressive loading, LOD techniques |
| Competition from established vendors | Medium | High | Focus on spatial UX differentiation, speed to market |
| Vision Pro hardware limitations | High | Low | Efficient algorithms, hardware requirement documentation |
| Clinical validation failures | High | Low | Partner with academic institutions, rigorous study design |

## Competitive Analysis

### Existing Solutions
- **OsiriX / Horos**: Free/paid Mac DICOM viewer, 2D/3D, mature
- **3D Slicer**: Free, open-source, powerful but complex
- **Vitrea (Vital Images)**: Enterprise 3D workstation, expensive
- **syngo.via (Siemens)**: Integrated with Siemens scanners
- **Aquarius (TeraRecon)**: Cloud-based advanced visualization

**Our Advantages**:
- Only spatial computing solution
- Natural gesture interface (faster than mouse/keyboard)
- Life-size visualization (better spatial understanding)
- Immersive collaboration (remote specialists feel present)
- Modern UX (existing tools outdated)

### Potential Competitors
- **Microsoft HoloLens**: Used in some surgical applications
  - Smaller field of view, less comfortable for long sessions
- **Magic Leap**: Medical partnerships announced
  - Limited traction, uncertain future
- **Meta Quest Pro**: Lower cost but not medical-grade
  - Comfort and precision limitations

## Open Questions

1. Should we pursue FDA clearance before launch or start with visualization-only?
2. What is optimal scan caching duration (privacy vs. performance)?
3. Should we support VR headsets (Quest) for broader market or Vision Pro only?
4. How do we handle liability for surgical planning features?
5. Should we build proprietary PACS or integrate only?
6. What level of AI automation is clinically safe and legally defensible?
7. International expansion: Which markets first (EU, APAC)?

## Success Criteria

Medical Imaging Suite will be considered successful if:
- FDA 510(k) clearance obtained within 12 months
- 20+ hospital customers within 18 months
- $10M+ ARR within 24 months
- Published in peer-reviewed medical journal
- Demonstrated clinical benefit (reduced surgical time or improved outcomes)
- 90%+ customer retention rate
- Featured at RSNA (major radiology conference)

## Appendix

### Clinical Use Cases

**Case 1: Complex Spine Surgery**
- Patient: 62-year-old with spinal tumor
- Challenge: Tumor involves multiple vertebrae, near spinal cord
- Solution: Surgeon views CT/MRI at life-size, segments tumor, plans approach avoiding cord, positions pedicle screws virtually
- Outcome: 30% reduction in OR time, successful resection

**Case 2: Liver Tumor Resection**
- Patient: 58-year-old with hepatocellular carcinoma
- Challenge: Plan resection preserving adequate liver volume
- Solution: AI segments liver, tumor, vessels; surgeon plans resection planes; volumetric analysis confirms adequate remnant
- Outcome: Confident surgical plan, reduced blood loss

**Case 3: Pediatric Cardiac Surgery**
- Patient: 2-year-old with congenital heart defect
- Challenge: Complex anatomy, small structures
- Solution: Cardiologist and surgeon collaborate remotely on 3D cardiac CT, plan repair approach
- Outcome: Successful multidisciplinary planning, family education improved

### Technical Deep Dive: Volume Rendering

```
Ray Casting Algorithm:
1. For each pixel in viewport:
   a. Cast ray from eye through pixel into volume
   b. Sample volume at intervals along ray (step size ~0.5-1mm)
   c. Accumulate color and opacity based on transfer function
   d. Apply lighting (gradient-based shading)
   e. Output final pixel color

Transfer Function:
- Maps Hounsfield units (CT) or signal intensity (MRI) to color/opacity
- Bone: High HU → opaque white
- Soft tissue: Mid HU → semi-transparent amber
- Air/background: Low HU → fully transparent

Optimizations:
- Early ray termination: Stop when accumulated opacity > 0.95
- Empty space skipping: Don't sample air regions
- Octree acceleration structure
- GPU implementation via Metal compute shaders
- Level of detail: Reduce samples for distant/peripheral volumes

Performance:
- Target: 60fps for 512³ volume on Vision Pro M2 chip
- Memory: ~1GB for typical CT scan (512×512×400 slices × 2 bytes/voxel)
```

### DICOM Integration Specifications

```
Supported Transfer Syntaxes:
- Implicit VR Little Endian
- Explicit VR Little Endian
- JPEG Lossless
- JPEG 2000 Lossless
- RLE Lossless

DICOM Services (SCU Role):
- C-ECHO: Verify PACS connection
- C-FIND: Query worklist, studies, series
- C-MOVE: Retrieve images
- C-STORE: Send annotations back

Supported Modalities:
- CT (Computed Tomography)
- MR (Magnetic Resonance)
- PET (Positron Emission Tomography)
- US (Ultrasound)
- XA (X-ray Angiography)
- MG (Mammography)
- CR/DX (Computed/Digital Radiography)

Structured Reports:
- Create DICOM SR for annotations
- Store measurements with spatial coordinates
- Attach to original study for future retrieval
```
