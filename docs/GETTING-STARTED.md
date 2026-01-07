# Getting Started Guide
## Medical Imaging Suite - Developer Onboarding

**Last Updated**: 2025-11-24

---

## Prerequisites

### Required Software
- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.2 or later
- **visionOS SDK**: Included with Xcode 15.2+
- **Git**: For version control
- **Swift**: 6.0+ (included with Xcode)

### Recommended Tools
- **SF Symbols**: For UI icons
- **RealityKit Composer**: For 3D asset creation
- **Instruments**: For profiling
- **Create ML**: For AI model training

### Hardware
- **Apple Vision Pro**: For device testing (optional for initial development)
- **Mac**: M1/M2/M3 or Intel with 16GB+ RAM recommended
- **Storage**: 50GB+ free space for Xcode and simulators

---

## Development Environment Setup

### Step 1: Clone Repository

```bash
git clone https://github.com/akaash-nigam/visionOS_Medical-Imaging-Suite.git
cd visionOS_Medical-Imaging-Suite
```

### Step 2: Install Xcode

1. Download Xcode 15.2+ from App Store
2. Install Command Line Tools:
   ```bash
   xcode-select --install
   ```
3. Accept license:
   ```bash
   sudo xcodebuild -license accept
   ```

### Step 3: Install Vision Pro Simulator

1. Open Xcode
2. Go to **Xcode → Settings → Platforms**
3. Click **+** and select **visionOS**
4. Download and install

### Step 4: Verify Setup

```bash
# Check Xcode version
xcodebuild -version
# Should show: Xcode 15.2 or later

# List available simulators
xcrun simctl list devices visionOS
# Should show: Apple Vision Pro simulator
```

---

## Project Structure

```
visionOS_Medical-Imaging-Suite/
├── README.md                      # Project overview
├── PRD.md                         # Product requirements
├── docs/                          # Design documentation
│   ├── 01-system-architecture.md
│   ├── 02-rendering-architecture.md
│   ├── 03-data-model-storage.md
│   ├── 04-pacs-ehr-integration.md
│   ├── 05-security-privacy.md
│   ├── 06-ui-ux-design.md
│   ├── 07-collaboration-architecture.md
│   ├── 08-ai-ml-pipeline.md
│   ├── 09-testing-strategy.md
│   ├── 10-api-design.md
│   ├── PROJECT-ROADMAP.md         # Epics and timeline
│   ├── SPRINT-01-PLAN.md          # First sprint plan
│   └── GETTING-STARTED.md         # This file
├── MedicalImagingSuite/           # Main app (to be created)
│   ├── App/
│   ├── Presentation/
│   ├── Application/
│   ├── CoreServices/
│   ├── Models/
│   └── Resources/
├── MedicalImagingSuiteTests/      # Test target (to be created)
└── TestData/                      # Sample DICOM files (to be added)
```

---

## Creating the Xcode Project (Sprint 1, Story 1.1)

### Step 1: Create New Project

1. Open Xcode
2. Click **File → New → Project**
3. Select **visionOS → App**
4. Configure project:
   - **Product Name**: MedicalImagingSuite
   - **Team**: Your development team
   - **Organization Identifier**: com.medicalimaging
   - **Bundle Identifier**: com.medicalimaging.suite
   - **Interface**: SwiftUI
   - **Language**: Swift
5. Save in repository root

### Step 2: Configure Project Settings

1. Select project in navigator
2. Set **iOS Deployment Target**: visionOS 2.0
3. Enable **Swift Strict Concurrency**: Yes
4. Set **Swift Language Version**: Swift 6

### Step 3: Test Run

1. Select **Apple Vision Pro** simulator
2. Click **Run** (⌘R)
3. App should launch showing "Hello World"

---

## Acquiring Test Data

### DICOM Sample Files

You'll need sample DICOM files for testing. Here are safe sources:

#### Option 1: Public Medical Datasets
- **The Cancer Imaging Archive (TCIA)**: https://www.cancerimagingarchive.net/
  - Free, de-identified medical images
  - Various modalities (CT, MR, PET)
  - Download sample datasets

#### Option 2: DICOM Sample Files Repository
- **dcm4che samples**: https://github.com/dcm4che/dcm4che/tree/master/dcm4che-test/src/test/data
  - Small test files
  - Various transfer syntaxes

#### Option 3: Generate Synthetic DICOM
```swift
// Use our synthetic generator (to be created in testing)
let generator = SyntheticDICOMGenerator()
let syntheticCT = generator.generateCTScan(dimensions: SIMD3(512, 512, 200))
```

### Organizing Test Data

```bash
# Create test data directory
mkdir TestData
cd TestData

# Organize by modality
mkdir CT MR XR

# Example: Download and organize
# Place CT scans in TestData/CT/
# Place MR scans in TestData/MR/
```

---

## Running Tests

### Unit Tests

```bash
# Command line
xcodebuild test \
  -scheme MedicalImagingSuite \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro'

# Or use Xcode:
# ⌘U (Run tests)
```

### Code Coverage

1. **Xcode → Product → Scheme → Edit Scheme**
2. Select **Test** tab
3. Check **Code Coverage**
4. Run tests (⌘U)
5. View coverage: **Report Navigator → Coverage**

---

## Git Workflow

### Branch Strategy

```
main                  # Production-ready code
  ├── develop         # Integration branch
  │   ├── feature/dicom-parser
  │   ├── feature/metal-rendering
  │   └── feature/ui-components
```

### Creating a Feature Branch

```bash
# Update develop
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/dicom-parser

# Make changes...
git add .
git commit -m "Implement DICOM tag parser"

# Push to remote
git push -u origin feature/dicom-parser

# Create pull request on GitHub
```

### Commit Message Format

```
<type>: <short description>

<optional detailed description>

<optional footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding tests
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `chore`: Build/tooling changes

**Example**:
```
feat: Implement DICOM implicit VR parser

- Add DICOMTag enum with common tags
- Implement readTag() and readValue() methods
- Support string and numeric value representations
- Add unit tests for parser

Closes #12
```

---

## Code Style Guidelines

### Swift Style

Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

**Key Points**:
```swift
// Naming
- Classes/Structs: PascalCase
- Functions/Variables: camelCase
- Constants: camelCase (not SCREAMING_SNAKE_CASE)

// Example:
class DICOMParser {
    func parseTag(from data: Data) -> DICOMTag { }

    private let transferSyntax: String
    private static let defaultBufferSize = 4096
}

// Prefer clarity over brevity
✅ func convertToHounsfieldUnits(_ value: Int16) -> Float
❌ func cvtHU(_ v: Int16) -> Float

// Use meaningful variable names
✅ let patientName = dataset.string(for: .patientName)
❌ let pn = dataset.string(for: .patientName)

// Avoid force unwrapping
❌ let value = dictionary[key]!
✅ guard let value = dictionary[key] else { return }
```

### SwiftUI Style

```swift
// Decompose large views
struct StudyListView: View {
    var body: some View {
        List {
            ForEach(studies) { study in
                StudyRow(study: study)  // Extract to separate view
            }
        }
    }
}

// Use @ViewBuilder for complex layouts
@ViewBuilder
func makeHeader() -> some View {
    if showTitle {
        Text("Medical Imaging Suite")
    }
}
```

### Documentation

Use DocC-style comments:

```swift
/// Parses a DICOM file and extracts metadata and pixel data.
///
/// This method reads the DICOM preamble, file meta information, and dataset.
/// It supports Implicit VR Little Endian and Explicit VR Little Endian transfer syntaxes.
///
/// - Parameter url: The URL of the DICOM file to parse.
/// - Returns: A `DICOMDataset` containing all parsed tags and values.
/// - Throws: ``DICOMError/invalidFormat`` if the file is not a valid DICOM file.
///
/// ## Example
/// ```swift
/// let parser = DICOMParser()
/// let dataset = try parser.parse(url: fileURL)
/// print(dataset.patientName)
/// ```
public func parse(url: URL) throws -> DICOMDataset {
    // Implementation
}
```

---

## Debugging Tips

### Common Issues

#### Issue: "No such module 'RealityKit'"
**Solution**: Ensure deployment target is visionOS 2.0+

#### Issue: Simulator not available
**Solution**: Download visionOS runtime in Xcode settings

#### Issue: Metal shader compilation error
**Solution**: Check shader syntax, use Metal debugger

### Debugging Tools

#### Xcode Debugger
- Set breakpoints: Click line number gutter
- Print to console: `print()` or `dump()`
- LLDB commands: `po variable`

#### Instruments
```bash
# Profile app
Product → Profile (⌘I)

# Select instrument:
- Time Profiler: CPU performance
- Allocations: Memory usage
- Leaks: Memory leaks
```

#### Metal Debugger
1. Run app
2. Click **Debug Navigator** (⌘7)
3. Click **Capture GPU Frame**
4. Inspect shader calls

---

## Learning Resources

### visionOS Development
- [Apple visionOS Documentation](https://developer.apple.com/visionos/)
- [Develop your first immersive app (WWDC)](https://developer.apple.com/videos/)
- [RealityKit Documentation](https://developer.apple.com/documentation/realitykit/)

### Medical Imaging
- [DICOM Standard](https://www.dicomstandard.org/)
- [dcm4che DICOM Toolkit](https://github.com/dcm4che/dcm4che)
- [Medical Image Computing (Book)](https://www.springer.com/gp/book/9783319964522)

### Metal & Graphics
- [Metal Programming Guide](https://developer.apple.com/metal/)
- [Metal Shading Language Specification](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf)
- [Ray Casting Tutorial](https://en.wikipedia.org/wiki/Volume_ray_casting)

---

## FAQ

### Q: Do I need a Vision Pro device to develop?
**A**: No, you can use the simulator for most development. Device is needed for final testing and performance validation.

### Q: Can I test on iPad/iPhone first?
**A**: Yes, you can create an iPad target for initial 2D UI development, but spatial features require visionOS.

### Q: How do I get sample DICOM files?
**A**: See "Acquiring Test Data" section above. Use public datasets or synthetic data.

### Q: What if I'm new to medical imaging?
**A**: Start with the PRD and design docs. Focus on DICOM basics first. Consult with clinical advisor for domain questions.

### Q: How do I contribute?
**A**:
1. Pick a task from Sprint backlog
2. Create feature branch
3. Implement and test
4. Submit pull request
5. Address code review feedback

---

## Next Steps

1. ✅ Read this guide
2. ⬜ Set up development environment
3. ⬜ Read PROJECT-ROADMAP.md for project overview
4. ⬜ Read SPRINT-01-PLAN.md for immediate tasks
5. ⬜ Review relevant design docs (01-10)
6. ⬜ Acquire sample DICOM files
7. ⬜ Create Xcode project (Sprint 1, Story 1.1)
8. ⬜ Join daily standup
9. ⬜ Pick first task and start coding!

---

## Support

### Technical Questions
- Check design docs first
- Ask in team chat
- Consult with Lead Engineer

### Clinical/Domain Questions
- Refer to PRD
- Consult with Clinical Advisor
- Review DICOM standard

### Process Questions
- Check PROJECT-ROADMAP.md
- Ask Product Manager
- Review sprint plan

---

**Welcome to the team! Let's build something amazing. 🚀**

