# AI/ML Pipeline Design Document
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Executive Summary

This document defines the AI/ML pipeline for Medical Imaging Suite, covering model selection, on-device inference with Core ML, pre/post-processing, and FDA regulatory considerations for AI-assisted medical imaging analysis.

## 2. AI Capabilities

| Capability | Use Case | Model Type | FDA Status |
|------------|----------|------------|------------|
| **Lesion Detection** | Lung nodules, liver lesions | Object Detection | Class II (510(k) required) |
| **Organ Segmentation** | Liver, kidneys, heart, brain | Semantic Segmentation | Class II |
| **Quantification** | Tumor volume, ejection fraction | Regression | Class II |
| **Image Enhancement** | Noise reduction, upscaling | Image-to-Image | Class I (exempt) |

## 3. Core ML Integration

### 3.1 Model Loading

```swift
actor AIMLService {
    private var loadedModels: [String: MLModel] = [:]

    func loadModel(name: String) async throws -> MLModel {
        if let cached = loadedModels[name] {
            return cached
        }

        let modelURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc")!
        let model = try await MLModel.load(contentsOf: modelURL)

        loadedModels[name] = model
        return model
    }
}
```

### 3.2 Inference Pipeline

```swift
protocol AIModel {
    associatedtype Input
    associatedtype Output

    func predict(_ input: Input) async throws -> Output
}

actor LungNoduleDetector: AIModel {
    private let model: MLModel
    private let preprocessor: ImagePreprocessor
    private let postprocessor: DetectionPostprocessor

    typealias Input = VolumeData
    typealias Output = [Detection]

    func predict(_ input: VolumeData) async throws -> [Detection] {
        // 1. Preprocess
        let preprocessed = try await preprocessor.preprocess(input)

        // 2. Inference
        let mlInput = try MLMultiArray(preprocessed)
        let prediction = try await model.prediction(from: LungNoduleDetectorInput(volume: mlInput))

        // 3. Postprocess
        let detections = try await postprocessor.process(prediction)

        return detections
    }
}

struct Detection {
    let boundingBox: BoundingBox3D
    let confidence: Float
    let classLabel: String
}

struct BoundingBox3D {
    let center: SIMD3<Float>
    let size: SIMD3<Float>
}
```

## 4. Preprocessing

### 4.1 Volume Normalization

```swift
struct ImagePreprocessor {
    func preprocess(_ volume: VolumeData) async throws -> NormalizedVolume {
        // 1. Resample to model's expected resolution (e.g., 1mm isotropic)
        let resampled = await resample(volume, to: SIMD3<Float>(1, 1, 1))

        // 2. Windowing (for CT)
        let windowed = applyWindowing(resampled, center: 40, width: 400)

        // 3. Normalize intensity to [0, 1]
        let normalized = normalize(windowed)

        // 4. Crop/pad to fixed size
        let fixed = cropOrPad(normalized, to: SIMD3<Int>(512, 512, 512))

        return fixed
    }

    private func resample(_ volume: VolumeData, to spacing: SIMD3<Float>) async -> VolumeData {
        // Trilinear interpolation to resample volume
        let newDimensions = SIMD3<Int>(
            Int(Float(volume.dimensions.x) * volume.spacing.x / spacing.x),
            Int(Float(volume.dimensions.y) * volume.spacing.y / spacing.y),
            Int(Float(volume.dimensions.z) * volume.spacing.z / spacing.z)
        )

        var newVoxels = [Float](repeating: 0, count: newDimensions.x * newDimensions.y * newDimensions.z)

        for z in 0..<newDimensions.z {
            for y in 0..<newDimensions.y {
                for x in 0..<newDimensions.x {
                    // Calculate corresponding position in original volume
                    let origX = Float(x) * spacing.x / volume.spacing.x
                    let origY = Float(y) * spacing.y / volume.spacing.y
                    let origZ = Float(z) * spacing.z / volume.spacing.z

                    // Trilinear interpolation
                    let value = trilinearInterpolate(volume, x: origX, y: origY, z: origZ)
                    newVoxels[z * newDimensions.y * newDimensions.x + y * newDimensions.x + x] = value
                }
            }
        }

        return VolumeData(
            id: volume.id,
            series: volume.series,
            dimensions: newDimensions,
            spacing: spacing,
            dataType: .float32,
            cacheURL: nil,
            windowCenter: volume.windowCenter,
            windowWidth: volume.windowWidth
        )
    }

    private func normalize(_ volume: VolumeData) -> VolumeData {
        // Normalize to [0, 1]
        // Find min/max
        // Scale: (value - min) / (max - min)
        return volume
    }
}
```

## 5. Postprocessing

### 5.1 Non-Maximum Suppression

```swift
struct DetectionPostprocessor {
    func process(_ prediction: MLFeatureProvider) async throws -> [Detection] {
        // Extract bounding boxes, confidences, class labels from model output
        let boxes = extractBoundingBoxes(prediction)
        let confidences = extractConfidences(prediction)
        let labels = extractLabels(prediction)

        // Filter by confidence threshold
        let filtered = zip(boxes, confidences).enumerated().filter { _, (box, conf) in
            conf > 0.5  // Threshold
        }

        // Non-maximum suppression to remove duplicates
        let nms = nonMaximumSuppression(filtered.map { ($0.element.0, $0.element.1) })

        return nms.map { box, conf in
            Detection(boundingBox: box, confidence: conf, classLabel: "Nodule")
        }
    }

    private func nonMaximumSuppression(_ detections: [(BoundingBox3D, Float)], iouThreshold: Float = 0.3) -> [(BoundingBox3D, Float)] {
        var remaining = detections.sorted { $0.1 > $1.1 }  // Sort by confidence
        var kept: [(BoundingBox3D, Float)] = []

        while !remaining.isEmpty {
            let best = remaining.removeFirst()
            kept.append(best)

            // Remove overlapping boxes
            remaining = remaining.filter { box in
                iou(best.0, box.0) < iouThreshold
            }
        }

        return kept
    }

    private func iou(_ box1: BoundingBox3D, _ box2: BoundingBox3D) -> Float {
        // Calculate 3D Intersection over Union
        let intersection = calculateIntersectionVolume(box1, box2)
        let union = calculateVolume(box1) + calculateVolume(box2) - intersection
        return intersection / union
    }

    private func calculateVolume(_ box: BoundingBox3D) -> Float {
        return box.size.x * box.size.y * box.size.z
    }

    private func calculateIntersectionVolume(_ box1: BoundingBox3D, _ box2: BoundingBox3D) -> Float {
        // Calculate intersection volume
        return 0  // Simplified
    }
}
```

## 6. Organ Segmentation

### 6.1 Semantic Segmentation Model

```swift
actor OrganSegmenter: AIModel {
    private let model: MLModel

    typealias Input = VolumeData
    typealias Output = SegmentationMask

    func predict(_ input: VolumeData) async throws -> SegmentationMask {
        // Preprocess
        let preprocessed = try await preprocessor.preprocess(input)

        // Inference: produces probability map for each class
        let mlInput = try MLMultiArray(preprocessed)
        let prediction = try await model.prediction(from: OrganSegmenterInput(volume: mlInput))

        // Postprocess: convert probabilities to discrete labels
        let segmentation = await generateSegmentationMask(prediction)

        return segmentation
    }

    private func generateSegmentationMask(_ prediction: MLFeatureProvider) async -> SegmentationMask {
        // Extract probability maps (C × D × H × W)
        // Argmax to get class label for each voxel
        // Return binary mask for each organ
        return SegmentationMask(
            dimensions: SIMD3(512, 512, 512),
            voxelData: Data(),
            label: "Liver"
        )
    }
}
```

## 7. Quantification

### 7.1 Volume Calculation

```swift
struct VolumeQuantifier {
    func calculateVolume(segmentation: SegmentationMask, spacing: SIMD3<Float>) -> Float {
        // Count positive voxels
        let voxelCount = segmentation.voxelData.filter { $0 == 1 }.count

        // Voxel volume (mm³)
        let voxelVolume = spacing.x * spacing.y * spacing.z

        // Total volume (cm³)
        return Float(voxelCount) * voxelVolume / 1000.0
    }
}
```

### 7.2 RECIST Measurements

```swift
struct RECISTMeasurer {
    func measureLesion(_ segmentation: SegmentationMask) -> RECISTMeasurement {
        // Find longest diameter in axial plane
        let longestDiameter = findLongestDiameter(segmentation)

        // Find perpendicular short axis
        let shortAxis = findPerpendicularAxis(segmentation, to: longestDiameter)

        return RECISTMeasurement(
            longestDiameter: longestDiameter.length,
            shortAxis: shortAxis.length
        )
    }

    private func findLongestDiameter(_ mask: SegmentationMask) -> Line3D {
        // Iterate through all voxel pairs on lesion boundary
        // Find maximum Euclidean distance
        return Line3D(start: .zero, end: .zero)
    }
}

struct RECISTMeasurement {
    let longestDiameter: Float  // mm
    let shortAxis: Float        // mm
}

struct Line3D {
    let start: SIMD3<Float>
    let end: SIMD3<Float>

    var length: Float {
        distance(start, end)
    }
}
```

## 8. Model Performance Monitoring

### 8.1 Inference Metrics

```swift
actor ModelPerformanceMonitor {
    private var inferenceTimes: [String: [TimeInterval]] = [:]

    func recordInference(modelName: String, duration: TimeInterval) {
        inferenceTimes[modelName, default: []].append(duration)
    }

    func getAverageInferenceTime(modelName: String) -> TimeInterval? {
        guard let times = inferenceTimes[modelName], !times.isEmpty else {
            return nil
        }

        return times.reduce(0, +) / Double(times.count)
    }

    func generateReport() -> PerformanceReport {
        var report = PerformanceReport()

        for (model, times) in inferenceTimes {
            let avg = times.reduce(0, +) / Double(times.count)
            let max = times.max() ?? 0
            let min = times.min() ?? 0

            report.models[model] = ModelMetrics(
                averageTime: avg,
                maxTime: max,
                minTime: min,
                sampleCount: times.count
            )
        }

        return report
    }
}

struct PerformanceReport {
    var models: [String: ModelMetrics] = [:]
}

struct ModelMetrics {
    let averageTime: TimeInterval
    let maxTime: TimeInterval
    let minTime: TimeInterval
    let sampleCount: Int
}
```

## 9. FDA Compliance

### 9.1 Model Validation

```swift
actor ModelValidator {
    func validateModel(name: String, testDataset: [TestCase]) async throws -> ValidationReport {
        var truePositives = 0
        var falsePositives = 0
        var trueNegatives = 0
        var falseNegatives = 0

        for testCase in testDataset {
            let prediction = try await runInference(testCase.input)
            let groundTruth = testCase.groundTruth

            // Compare prediction with ground truth
            if prediction.isPositive && groundTruth.isPositive {
                truePositives += 1
            } else if prediction.isPositive && !groundTruth.isPositive {
                falsePositives += 1
            } else if !prediction.isPositive && !groundTruth.isPositive {
                trueNegatives += 1
            } else {
                falseNegatives += 1
            }
        }

        let sensitivity = Float(truePositives) / Float(truePositives + falseNegatives)
        let specificity = Float(trueNegatives) / Float(trueNegatives + falsePositives)
        let accuracy = Float(truePositives + trueNegatives) / Float(testDataset.count)

        return ValidationReport(
            modelName: name,
            sensitivity: sensitivity,
            specificity: specificity,
            accuracy: accuracy,
            sampleCount: testDataset.count
        )
    }
}

struct ValidationReport {
    let modelName: String
    let sensitivity: Float  // True positive rate
    let specificity: Float  // True negative rate
    let accuracy: Float
    let sampleCount: Int

    var isFDACompliant: Bool {
        // FDA typically requires sensitivity > 0.90 for CAD systems
        return sensitivity > 0.90 && specificity > 0.85
    }
}
```

### 9.2 Model Versioning

```swift
struct ModelManifest: Codable {
    let models: [ModelInfo]
}

struct ModelInfo: Codable {
    let name: String
    let version: String
    let fdaClearanceNumber: String?
    let trainingDataSize: Int
    let validationMetrics: ValidationMetrics
    let lastUpdated: Date
}

struct ValidationMetrics: Codable {
    let sensitivity: Float
    let specificity: Float
    let auc: Float  // Area under ROC curve
}
```

## 10. User Interface for AI Results

### 10.1 AI Confidence Visualization

```swift
struct AIDetectionView: View {
    let detections: [Detection]

    var body: some View {
        ForEach(detections) { detection in
            DetectionOverlay(detection: detection)
                .overlay(alignment: .topTrailing) {
                    ConfidenceBadge(confidence: detection.confidence)
                }
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Float

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption)
            .padding(4)
            .background(confidenceColor)
            .cornerRadius(4)
    }

    var confidenceColor: Color {
        if confidence > 0.9 {
            return .green
        } else if confidence > 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
}
```

---

**Document Control**

- **Author**: ML Engineering Team
- **Reviewers**: Clinical AI Specialist, Regulatory Affairs
- **Approval**: VP of Engineering
- **Next Review**: After FDA pre-submission meeting

