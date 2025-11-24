# UI/UX Design Document for visionOS
## Medical Imaging Suite

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Executive Summary

This document defines the user interface and interaction design for Medical Imaging Suite on Apple Vision Pro, leveraging spatial computing paradigms,natural gestures, eye tracking, and visionOS design patterns to create an intuitive medical imaging experience.

## 2. visionOS Design Principles

### 2.1 Spatial Design

- **Life-Size Scale**: Medical scans displayed at actual anatomical dimensions (1:1 scale)
- **Depth and Layering**: Use z-axis to organize UI elements (foreground tools, middleground scan, background context)
- **Physical Space Integration**: Anchor volumes to real-world surfaces (table, wall)
- **Comfort Zones**: Place interactive elements within comfortable reach (40-100cm from user)

### 2.2 Interaction Paradigms

- **Direct Manipulation**: Touch volumes directly with hands
- **Eye + Pinch**: Look at object, pinch to select
- **Voice Commands**: "Show bone window", "Measure distance"
- **Controller Support**: Optional for precision tasks

## 3. Window Types

### 3.1 Volumetric Windows (3D Content)

```swift
struct VolumeView: View {
    var body: some View {
        RealityView { content in
            // 3D medical scan
            let volumeEntity = createVolumeEntity()
            content.add(volumeEntity)
        }
        .frame(depth: 0.5, alignment: .center)  // 0.5m depth
    }
}
```

**Use Cases**:
- Primary 3D scan visualization
- Multi-planar reconstruction views
- Surgical planning workspace

### 3.2 Standard Windows (2D Content)

```swift
struct WorklistWindow: View {
    var body: some View {
        NavigationSplitView {
            List(studies) { study in
                StudyRow(study: study)
            }
        } detail: {
            StudyDetailView()
        }
    }
}
```

**Use Cases**:
- Patient worklist
- Study browser
- Settings and configuration
- Report viewing

### 3.3 Ornaments (Floating Controls)

```swift
struct VolumeControlOrnament: View {
    var body: some View {
        HStack {
            Button("Bone") { applyBoneWindow() }
            Button("Soft Tissue") { applySoftTissueWindow() }
            Slider(value: $opacity, in: 0...1)
        }
        .padding()
        .glassBackgroundEffect()
    }
}

// Attach to volume
VolumeView()
    .ornament(attachmentAnchor: .scene(.bottom)) {
        VolumeControlOrnament()
    }
```

**Use Cases**:
- Windowing controls
- Tool palette
- Measurement readouts

## 4. Spatial Layouts

### 4.1 Reading Room Layout

```
User's Perspective:

                    [Windowing Controls]
                           ↓
    [Worklist]     [3D Scan - Center]     [Tools Panel]
    (Left side)     (1m in front)         (Right side)

                    [Slice Navigator]
                           ↑
                      [Timeline]
```

### 4.2 Surgical Planning Layout

```
                    [Implant Library]
                           ↑
    [Measurements]  [Life-Size Anatomy]   [Annotations]
    (Left float)    (Center, anchored)    (Right float)

                    [Drawing Tools]
                           ↓
```

### 4.3 Collaboration Layout

```
    [Participant 1]    [Shared Scan]     [Participant 2]
    (Avatar)           (Center)          (Avatar)

                    [Collaboration Controls]
```

## 5. Gesture Interactions

### 5.1 Navigation Gestures

| Gesture | Action |
|---------|--------|
| **Look + Tap** | Select object/button |
| **Pinch + Drag** | Rotate volume |
| **Two-hand Pinch + Spread** | Scale volume |
| **Swipe Up/Down** | Navigate slices |
| **Double Tap** | Reset view |

### 5.2 Annotation Gestures

| Gesture | Action |
|---------|--------|
| **Index Finger Extended + Pinch** | Draw freehand line |
| **Two Fingers Point + Pinch** | Measure distance |
| **Circle Gesture** | Create region of interest |
| **Voice: "Add Note"** | Create text annotation |

### 5.3 Windowing Gestures

| Gesture | Action |
|---------|--------|
| **Vertical Drag** | Adjust window level (brightness) |
| **Horizontal Drag** | Adjust window width (contrast) |
| **Twist (Two Hands)** | Rotate view |

## 6. Component Library

### 6.1 Study Row

```swift
struct StudyRow: View {
    let study: Study

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            AsyncImage(url: study.thumbnailURL) { image in
                image.resizable()
                     .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 80, height: 80)
            .cornerRadius(8)

            // Study Info
            VStack(alignment: .leading, spacing: 4) {
                Text(study.patient.name.formatted)
                    .font(.headline)

                Text(study.studyDescription ?? "No Description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Label(study.studyDate?.formatted(date: .abbreviated, time: .omitted) ?? "", systemImage: "calendar")
                    Label("\(study.modalities.map { $0.rawValue }.joined(separator: ", "))", systemImage: "camera")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Quick Actions
            Button {
                loadStudy(study)
            } label: {
                Image(systemName: "cube.transparent")
            }
        }
        .padding()
    }
}
```

### 6.2 Windowing Control

```swift
struct WindowingControl: View {
    @Binding var windowCenter: Float
    @Binding var windowWidth: Float

    var body: some View {
        VStack(spacing: 16) {
            Text("Windowing")
                .font(.headline)

            // Preset buttons
            HStack {
                Button("Bone") {
                    windowCenter = 300
                    windowWidth = 2000
                }
                Button("Soft Tissue") {
                    windowCenter = 40
                    windowWidth = 400
                }
                Button("Lung") {
                    windowCenter = -600
                    windowWidth = 1500
                }
            }
            .buttonStyle(.bordered)

            // Manual controls
            VStack {
                HStack {
                    Text("Level:")
                    Slider(value: $windowCenter, in: -1000...3000)
                    Text("\(Int(windowCenter)) HU")
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)
                }

                HStack {
                    Text("Width:")
                    Slider(value: $windowWidth, in: 1...4000)
                    Text("\(Int(windowWidth)) HU")
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)
                }
            }
        }
        .padding()
        .frame(width: 350)
        .glassBackgroundEffect()
    }
}
```

### 6.3 Annotation Tool Palette

```swift
struct AnnotationToolPalette: View {
    @Binding var activeTool: AnnotationTool?

    var body: some View {
        VStack(spacing: 12) {
            Text("Tools")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                ToolButton(tool: .freehand, icon: "pencil", isActive: activeTool == .freehand) {
                    activeTool = .freehand
                }

                ToolButton(tool: .line, icon: "line.diagonal", isActive: activeTool == .line) {
                    activeTool = .line
                }

                ToolButton(tool: .arrow, icon: "arrow.right", isActive: activeTool == .arrow) {
                    activeTool = .arrow
                }

                ToolButton(tool: .circle, icon: "circle", isActive: activeTool == .circle) {
                    activeTool = .circle
                }

                ToolButton(tool: .text, icon: "text.cursor", isActive: activeTool == .text) {
                    activeTool = .text
                }

                ToolButton(tool: .measure, icon: "ruler", isActive: activeTool == .measure) {
                    activeTool = .measure
                }
            }
        }
        .padding()
        .frame(width: 200)
        .glassBackgroundEffect()
    }
}

struct ToolButton: View {
    let tool: AnnotationTool
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(tool.name)
                    .font(.caption)
            }
            .frame(width: 60, height: 60)
            .background(isActive ? Color.blue.opacity(0.3) : Color.clear)
            .cornerRadius(8)
        }
    }
}

enum AnnotationTool {
    case freehand, line, arrow, circle, text, measure

    var name: String {
        switch self {
        case .freehand: return "Draw"
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .circle: return "ROI"
        case .text: return "Text"
        case .measure: return "Measure"
        }
    }
}
```

## 7. Eye Tracking Integration

### 7.1 Gaze-Based Selection

```swift
import RealityKit

class GazeInteractionSystem: System {
    static let query = EntityQuery(where: .has(GazeInteractableComponent.self))

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            if isUserLookingAt(entity) {
                entity.components[GazeInteractableComponent.self]?.isGazedAt = true
                // Highlight entity
                highlightEntity(entity)
            } else {
                entity.components[GazeInteractableComponent.self]?.isGazedAt = false
                unhighlightEntity(entity)
            }
        }
    }

    private func isUserLookingAt(_ entity: Entity) -> Bool {
        // Ray cast from eye position
        // Check intersection with entity bounds
        return false  // Simplified
    }
}

struct GazeInteractableComponent: Component {
    var isGazedAt: Bool = false
}
```

### 7.2 Attention-Based UI

```swift
// Show/hide UI based on where user is looking

struct AdaptiveUI: View {
    @State private var isLookingAtControls = false

    var body: some View {
        ZStack {
            // Main 3D content
            VolumeView()

            // Controls (fade in when gazed at)
            if isLookingAtControls {
                VolumeControlOrnament()
                    .transition(.opacity)
            }
        }
        .onGazeChange { gazeLocation in
            // Detect if gaze is near control area
            isLookingAtControls = isGazeNearControls(gazeLocation)
        }
    }
}
```

## 8. Accessibility

### 8.1 VoiceOver Support

```swift
struct AccessibleVolumeView: View {
    var body: some View {
        RealityView { content in
            let volume = createVolumeEntity()
            content.add(volume)
        }
        .accessibilityLabel("CT scan of chest, 512 slices")
        .accessibilityHint("Pinch and drag to rotate, spread to zoom")
        .accessibilityAddTraits(.isImage)
    }
}
```

### 8.2 High Contrast Mode

```swift
struct ThemedButton: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor

    var body: some View {
        Button("Annotate") {
            // Action
        }
        .foregroundColor(differentiateWithoutColor ? .primary : .blue)
        .overlay(
            differentiateWithoutColor ?
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary, lineWidth: 2) : nil
        )
    }
}
```

### 8.3 Reduced Motion

```swift
struct AnimatedTransition: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VolumeView()
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
    }
}
```

## 9. Dark Mode & Theming

### 9.1 Color Palette

```swift
extension Color {
    static let medicalBlue = Color(red: 0.12, green: 0.53, blue: 0.90)  // #1E88E5
    static let anatomyBone = Color(red: 0.88, green: 0.88, blue: 0.88)  // #E0E0E0
    static let anatomySoftTissue = Color(red: 1.0, green: 0.60, blue: 0.0)  // #FF9800
    static let anatomyVessel = Color(red: 0.96, green: 0.26, blue: 0.21)  // #F44336
    static let anatomyTumor = Color(red: 0.61, green: 0.15, blue: 0.69)  // #9C27B0
    static let annotationGreen = Color(red: 0.30, green: 0.69, blue: 0.31)  // #4CAF50
}
```

### 9.2 Adaptive UI

```swift
struct AdaptiveBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark ?
                  Color(white: 0.15) :
                  Color(white: 0.95))
    }
}
```

## 10. Performance Optimizations

### 10.1 Lazy Loading

```swift
struct StudyListView: View {
    @State private var studies: [Study] = []

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(studies) { study in
                    StudyRow(study: study)
                        .onAppear {
                            if study == studies.last {
                                loadMoreStudies()
                            }
                        }
                }
            }
        }
    }

    func loadMoreStudies() {
        // Load next page
    }
}
```

### 10.2 View Caching

```swift
struct CachedVolumeView: View {
    let volumeID: String

    @State private var cachedEntity: Entity?

    var body: some View {
        RealityView { content in
            if let cached = cachedEntity {
                content.add(cached)
            } else {
                let entity = await createVolumeEntity()
                cachedEntity = entity
                content.add(entity)
            }
        }
    }
}
```

## 11. Onboarding & Tutorial

### 11.1 First-Time User Experience

```swift
struct OnboardingFlow: View {
    @State private var currentStep = 0

    var body: some View {
        TabView(selection: $currentStep) {
            OnboardingStep(
                title: "Welcome to Medical Imaging Suite",
                description: "View patient scans at life-size in your space",
                animation: "welcome"
            ).tag(0)

            OnboardingStep(
                title: "Rotate and Scale",
                description: "Pinch and drag to rotate. Use two hands to scale.",
                animation: "gestures"
            ).tag(1)

            OnboardingStep(
                title: "Annotate in 3D",
                description: "Draw directly on anatomy with your finger",
                animation: "annotate"
            ).tag(2)

            OnboardingStep(
                title: "Collaborate Remotely",
                description: "Invite specialists to review scans together",
                animation: "collaborate"
            ).tag(3)
        }
        .tabViewStyle(.page)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack {
                Button("Skip") { completeOnboarding() }
                Spacer()
                Button(currentStep == 3 ? "Get Started" : "Next") {
                    if currentStep < 3 {
                        currentStep += 1
                    } else {
                        completeOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
```

---

**Document Control**

- **Author**: UI/UX Design Team
- **Reviewers**: Product Manager, Clinical Advisory Board
- **Approval**: Head of Design
- **Next Review**: After user testing sessions

