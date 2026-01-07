//
//  BiometricAuthService.swift
//  MedicalImagingSuite
//
//  OpticID biometric authentication for visionOS
//

import Foundation
import LocalAuthentication

// MARK: - Auth Result

enum AuthResult {
    case success
    case failure(AuthError)
    case cancelled
}

enum AuthError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case systemError(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric credentials are enrolled. Please enroll OpticID in Settings"
        case .lockout:
            return "Too many failed attempts. Please try again later"
        case .systemError(let error):
            return "Authentication failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Biometric Auth Service

/// Handles biometric authentication using OpticID
@MainActor
final class BiometricAuthService: ObservableObject {

    @Published var isAuthenticated: Bool = false
    @Published var lastAuthDate: Date?

    private let context = LAContext()
    private let sessionTimeout: TimeInterval = 15 * 60  // 15 minutes

    // MARK: - Availability

    /// Check if biometric authentication is available
    func isBiometricAvailable() -> Bool {
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if let error = error {
            print("⚠️ Biometric unavailable: \(error.localizedDescription)")
        }

        return available
    }

    /// Get biometric type name
    func biometricType() -> String {
        guard isBiometricAvailable() else { return "None" }

        switch context.biometryType {
        case .opticID:
            return "OpticID"
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Authentication

    /// Authenticate user with biometrics
    func authenticate(reason: String = "Authenticate to access medical imaging data") async -> AuthResult {
        // Check availability
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                return .failure(mapError(error))
            }
            return .failure(.notAvailable)
        }

        // Perform authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                isAuthenticated = true
                lastAuthDate = Date()
                print("✅ Authentication successful")
                return .success
            } else {
                return .failure(.systemError(NSError(domain: "Auth", code: -1)))
            }

        } catch let authError as LAError {
            if authError.code == .userCancel {
                return .cancelled
            }
            return .failure(mapError(authError))
        } catch {
            return .failure(.systemError(error))
        }
    }

    /// Check if session is still valid
    func isSessionValid() -> Bool {
        guard let lastAuth = lastAuthDate else { return false }

        let elapsed = Date().timeIntervalSince(lastAuth)
        return elapsed < sessionTimeout
    }

    /// Logout and clear authentication
    func logout() {
        isAuthenticated = false
        lastAuthDate = nil
        print("👋 User logged out")
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> AuthError {
        guard let laError = error as? LAError else {
            return .systemError(error)
        }

        switch laError.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockout
        default:
            return .systemError(error)
        }
    }
}

// MARK: - Session Manager

/// Manages authentication sessions and timeouts
@MainActor
final class SessionManager: ObservableObject {

    @Published var isSessionActive: Bool = false
    @Published var sessionStartTime: Date?

    private let timeout: TimeInterval
    private var timeoutTimer: Timer?

    init(timeoutMinutes: Int = 15) {
        self.timeout = TimeInterval(timeoutMinutes * 60)
    }

    // MARK: - Session Control

    func startSession() {
        isSessionActive = true
        sessionStartTime = Date()

        // Start timeout timer
        scheduleTimeout()

        print("✅ Session started")
    }

    func endSession() {
        isSessionActive = false
        sessionStartTime = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil

        print("👋 Session ended")
    }

    func refreshSession() {
        guard isSessionActive else { return }

        sessionStartTime = Date()
        scheduleTimeout()

        print("🔄 Session refreshed")
    }

    private func scheduleTimeout() {
        timeoutTimer?.invalidate()

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.handleTimeout()
        }
    }

    private func handleTimeout() {
        print("⏱️ Session timed out")
        endSession()
    }

    // MARK: - Session Info

    var remainingTime: TimeInterval? {
        guard let start = sessionStartTime, isSessionActive else { return nil }

        let elapsed = Date().timeIntervalSince(start)
        return max(0, timeout - elapsed)
    }

    var remainingTimeFormatted: String? {
        guard let remaining = remainingTime else { return nil }

        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Audit Logger

/// Logs security-relevant events
actor AuditLogger {

    private let fileURL: URL

    init() throws {
        let documentsDir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        self.fileURL = documentsDir.appendingPathComponent("audit.log")

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    // MARK: - Logging

    func log(event: AuditEvent) {
        let entry = formatEntry(event)

        // Append to file
        if let data = (entry + "\n").data(using: .utf8),
           let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try? fileHandle.close()
        }

        print("📝 Audit: \(event.description)")
    }

    private func formatEntry(_ event: AuditEvent) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return "[\(timestamp)] \(event.type.rawValue): \(event.description) | User: \(event.userId ?? "unknown") | IP: \(event.ipAddress ?? "N/A")"
    }

    // MARK: - Reading

    func recentEvents(count: Int = 100) async -> [String] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: "\n")
        return Array(lines.suffix(count))
    }

    func clearLog() async throws {
        try Data().write(to: fileURL)
        print("🗑️ Audit log cleared")
    }
}

// MARK: - Audit Event

struct AuditEvent {
    enum EventType: String {
        case login = "LOGIN"
        case logout = "LOGOUT"
        case authFailure = "AUTH_FAILURE"
        case sessionTimeout = "SESSION_TIMEOUT"
        case dataAccess = "DATA_ACCESS"
        case dataModification = "DATA_MODIFICATION"
        case studyImport = "STUDY_IMPORT"
        case studyDelete = "STUDY_DELETE"
        case configChange = "CONFIG_CHANGE"
    }

    let type: EventType
    let description: String
    let userId: String?
    let ipAddress: String?

    init(type: EventType, description: String, userId: String? = nil, ipAddress: String? = nil) {
        self.type = type
        self.description = description
        self.userId = userId
        self.ipAddress = ipAddress
    }
}
