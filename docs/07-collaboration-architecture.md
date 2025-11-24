# Collaboration Architecture Document
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Executive Summary

This document defines the real-time collaboration architecture for Medical Imaging Suite, enabling multiple physicians to review medical scans together in a shared spatial environment with synchronized views, spatial audio, and collaborative annotations.

## 2. Collaboration Features

| Feature | Description | Priority |
|---------|-------------|----------|
| **Shared Viewing** | All participants see the same 3D scan | High |
| **Synchronized Interaction** | Rotations/zooms synchronized across users | High |
| **Collaborative Annotations** | Real-time annotation sharing | High |
| **Spatial Audio** | Voice positioned at avatar location | Medium |
| **Screen Sharing** | Share to non-VisionPro participants | Medium |
| **Session Recording** | Record for teaching files | Low |

## 3. SharePlay Integration

### 3.1 Group Activity

```swift
import GroupActivities

struct MedicalImagingActivity: GroupActivity {
    let studyInstanceUID: String

    static let activityIdentifier = "com.medicalimaging.viewing-session"

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Medical Imaging Review"
        metadata.type = .generic
        metadata.supportsContinuationOnTV = false
        return metadata
    }
}
```

### 3.2 Collaboration Manager

```swift
import GroupActivities

@MainActor
class CollaborationManager: ObservableObject {
    @Published var activeSession: GroupSession<MedicalImagingActivity>?
    @Published var participants: [Participant] = []
    @Published var isHost: Bool = false

    private var messenger: GroupSessionMessenger?
    private var tasks = Set<Task<Void, Never>>()

    func startSession(for study: Study) async throws {
        let activity = MedicalImagingActivity(studyInstanceUID: study.studyInstanceUID)

        // Prepare to start group activity
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            // User wants to start session
            try await activity.activate()

        case .activationDisabled:
            // SharePlay disabled
            throw CollaborationError.sharePlayDisabled

        case .cancelled:
            // User cancelled
            return

        @unknown default:
            break
        }
    }

    func configureSession(_ session: GroupSession<MedicalImagingActivity>) {
        self.activeSession = session
        self.isHost = session.localParticipant.id == session.activeParticipants.first?.id

        // Create messenger for real-time sync
        messenger = GroupSessionMessenger(session: session)

        // Observe participants
        let participantsTask = Task {
            for await participants in session.$activeParticipants.values {
                self.participants = participants.sorted { $0.id < $1.id }.map { participant in
                    Participant(id: participant.id, displayName: participant.name)
                }
            }
        }

        // Listen for messages
        let messagesTask = Task {
            guard let messenger = messenger else { return }

            for await (message, sender) in messenger.messages(of: SyncMessage.self) {
                await handle(message, from: sender)
            }
        }

        tasks.insert(participantsTask)
        tasks.insert(messagesTask)

        session.join()
    }

    func leaveSession() {
        activeSession?.leave()
        activeSession = nil
        messenger = nil
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    // Send sync messages
    func broadcastVolumeTransform(_ transform: Transform) async {
        guard let messenger = messenger else { return }

        let message = SyncMessage.volumeTransform(
            position: transform.translation,
            rotation: transform.rotation,
            scale: transform.scale
        )

        do {
            try await messenger.send(message)
        } catch {
            print("Failed to send transform: \(error)")
        }
    }

    func broadcastAnnotation(_ annotation: Annotation) async {
        guard let messenger = messenger else { return }

        let message = SyncMessage.annotation(annotation)

        do {
            try await messenger.send(message)
        } catch {
            print("Failed to send annotation: \(error)")
        }
    }

    func broadcastWindowing(center: Float, width: Float) async {
        guard let messenger = messenger else { return }

        let message = SyncMessage.windowing(center: center, width: width)

        do {
            try await messenger.send(message)
        } catch {
            print("Failed to send windowing: \(error)")
        }
    }

    // Handle incoming messages
    private func handle(_ message: SyncMessage, from sender: Participant.ID) async {
        // Ignore messages from self
        guard sender != activeSession?.localParticipant.id else { return }

        switch message {
        case .volumeTransform(let position, let rotation, let scale):
            await applyRemoteTransform(position: position, rotation: rotation, scale: scale)

        case .annotation(let annotation):
            await addRemoteAnnotation(annotation)

        case .windowing(let center, let width):
            await applyRemoteWindowing(center: center, width: width)

        case .laserPointer(let position):
            await showRemoteLaserPointer(position: position, from: sender)
        }
    }

    private func applyRemoteTransform(position: SIMD3<Float>, rotation: simd_quatf, scale: SIMD3<Float>) async {
        // Update volume transform
    }

    private func addRemoteAnnotation(_ annotation: Annotation) async {
        // Add annotation to scene
    }

    private func applyRemoteWindowing(center: Float, width: Float) async {
        // Update windowing
    }

    private func showRemoteLaserPointer(position: SIMD3<Float>, from sender: Participant.ID) async {
        // Show laser pointer from remote participant
    }
}

enum SyncMessage: Codable {
    case volumeTransform(position: SIMD3<Float>, rotation: simd_quatf, scale: SIMD3<Float>)
    case annotation(Annotation)
    case windowing(center: Float, width: Float)
    case laserPointer(position: SIMD3<Float>)
}

struct Participant: Identifiable {
    let id: UUID
    let displayName: String
}

enum CollaborationError: Error {
    case sharePlayDisabled
    case sessionFailed
}
```

## 4. Spatial Audio

### 4.1 Avatar Positioning

```swift
import RealityKit
import Spatial

actor SpatialAudioManager {
    func positionAvatarAudio(for participant: Participant, at position: SIMD3<Float>) {
        // Create spatial audio source at participant's avatar location
        let audioEntity = Entity()
        audioEntity.position = position

        // Add spatial audio component
        var audioComponent = SpatialAudioComponent()
        audioComponent.gain = 1.0
        audioComponent.rolloffFactor = 1.0
        audioEntity.components[SpatialAudioComponent.self] = audioComponent

        // Play participant's voice audio
    }
}
```

## 5. Screen Sharing (for non-VisionPro users)

### 5.1 WebRTC Integration

```swift
import WebRTC

actor ScreenShareService {
    private var peerConnection: RTCPeerConnection?
    private var localVideoTrack: RTCVideoTrack?

    func startScreenShare() async throws {
        // Capture RealityView as video stream
        let capturer = RTCCameraVideoCapturer(delegate: self)

        let videoSource = peerConnectionFactory.videoSource()
        localVideoTrack = peerConnectionFactory.videoTrack(with: videoSource, trackId: "screen-share")

        // Add to peer connection
        peerConnection?.add(localVideoTrack!, streamIds: ["screen-share-stream"])
    }

    func stopScreenShare() {
        localVideoTrack = nil
    }
}
```

## 6. Session Recording

### 6.1 Recording Manager

```swift
actor SessionRecorder {
    private var isRecording = false
    private var videoWriter: AVAssetWriter?

    func startRecording() async throws {
        guard !isRecording else { return }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("session-\(UUID()).mp4")

        videoWriter = try AVAssetWriter(url: outputURL, fileType: .mp4)

        // Configure video input
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1920,
            AVVideoHeightKey: 1080
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriter?.add(videoInput)

        videoWriter?.startWriting()
        videoWriter?.startSession(atSourceTime: .zero)

        isRecording = true
    }

    func stopRecording() async throws -> URL {
        guard isRecording else { throw RecordingError.notRecording }

        await videoWriter?.finishWriting()
        isRecording = false

        guard let outputURL = videoWriter?.outputURL else {
            throw RecordingError.noOutput
        }

        return outputURL
    }
}

enum RecordingError: Error {
    case notRecording
    case noOutput
}
```

## 7. Conflict Resolution

### 7.1 Operational Transform for Annotations

```swift
actor AnnotationSyncEngine {
    private var localVersion = 0
    private var remoteVersion = 0
    private var pendingOperations: [AnnotationOperation] = []

    struct AnnotationOperation {
        let id: UUID
        let type: OperationType
        let annotation: Annotation
        let version: Int

        enum OperationType {
            case create
            case modify
            case delete
        }
    }

    func applyOperation(_ operation: AnnotationOperation) -> AnnotationOperation? {
        // Operational transform logic
        // Resolve conflicts when operations overlap

        if operation.version < remoteVersion {
            // Transform operation to apply to current state
            return transform(operation)
        } else {
            // Apply directly
            return operation
        }
    }

    private func transform(_ operation: AnnotationOperation) -> AnnotationOperation {
        // Transform operation based on pending operations
        // This ensures convergence even with concurrent edits
        return operation
    }
}
```

## 8. Network Optimization

### 8.1 Message Throttling

```swift
actor MessageThrottler {
    private var lastSentTime: [MessageType: Date] = [:]
    private let minInterval: TimeInterval = 0.1  // 100ms

    enum MessageType {
        case transform
        case laserPointer
        case windowing
    }

    func shouldSend(_ type: MessageType) -> Bool {
        let now = Date()

        if let lastSent = lastSentTime[type] {
            let elapsed = now.timeIntervalSince(lastSent)
            if elapsed < minInterval {
                return false
            }
        }

        lastSentTime[type] = now
        return true
    }
}
```

### 8.2 Adaptive Quality

```swift
actor AdaptiveQualityManager {
    private var currentLatency: TimeInterval = 0

    func adjustQuality(latency: TimeInterval) {
        currentLatency = latency

        if latency > 0.3 {
            // High latency: reduce update frequency
            messageThrottler.minInterval = 0.2
        } else if latency < 0.1 {
            // Low latency: increase update frequency
            messageThrottler.minInterval = 0.05
        }
    }
}
```

## 9. Security for Collaboration

### 9.1 End-to-End Encryption

```swift
actor CollaborationEncryption {
    private var sessionKey: SymmetricKey?

    func establishSessionKey(with participant: Participant) async throws {
        // Diffie-Hellman key exchange
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey

        // Exchange public keys via SharePlay
        // Derive shared secret
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: participant.publicKey)

        sessionKey = SharedSecret.symmetricKey(from: sharedSecret)
    }

    func encryptMessage(_ message: SyncMessage) throws -> Data {
        guard let key = sessionKey else {
            throw EncryptionError.noSessionKey
        }

        let encoder = JSONEncoder()
        let messageData = try encoder.encode(message)

        let sealedBox = try AES.GCM.seal(messageData, using: key)
        return sealedBox.combined!
    }

    func decryptMessage(_ data: Data) throws -> SyncMessage {
        guard let key = sessionKey else {
            throw EncryptionError.noSessionKey
        }

        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: key)

        let decoder = JSONDecoder()
        return try decoder.decode(SyncMessage.self, from: decrypted)
    }
}

enum EncryptionError: Error {
    case noSessionKey
}
```

---

**Document Control**

- **Author**: Collaboration Engineering Team
- **Reviewers**: Network Engineer, Security Officer
- **Approval**: CTO
- **Next Review**: After SharePlay integration testing

