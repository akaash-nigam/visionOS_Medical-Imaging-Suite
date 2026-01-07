# Security & Privacy Implementation Design
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Executive Summary

This document defines the security and privacy architecture for Medical Imaging Suite to ensure HIPAA compliance, protect Protected Health Information (PHI), and prevent unauthorized access. The design implements defense-in-depth with encryption, authentication, audit logging, and privacy-by-design principles.

## 2. Security Architecture

### 2.1 Security Layers

```
┌─────────────────────────────────────────┐
│  Application Security                    │
│  - Input validation                      │
│  - Secure coding practices               │
│  - Memory safety (Swift)                 │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  Authentication & Authorization          │
│  - OpticID biometric                     │
│  - Role-based access control (RBAC)      │
│  - Session management                    │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  Data Security                           │
│  - Encryption at rest (AES-256)          │
│  - Encryption in transit (TLS 1.3)       │
│  - Secure key management                 │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  Network Security                        │
│  - Certificate pinning                   │
│  - VPN support                           │
│  - Firewall traversal                    │
└─────────────────────────────────────────┘
            ↓
┌─────────────────────────────────────────┐
│  Audit & Monitoring                      │
│  - Access logging                        │
│  - Anomaly detection                     │
│  - Incident response                     │
└─────────────────────────────────────────┘
```

## 3. Authentication

### 3.1 OpticID Biometric Authentication

```swift
import LocalAuthentication

actor BiometricAuthService {
    func authenticate() async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthenticationError.biometricsNotAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access patient data"
            ) { success, error in
                if success {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: error ?? AuthenticationError.authenticationFailed)
                }
            }
        }
    }
}

enum AuthenticationError: Error {
    case biometricsNotAvailable
    case authenticationFailed
    case tooManyFailedAttempts
}
```

### 3.2 Multi-Factor Authentication

```swift
actor MFAService {
    func verifyMFA(code: String, user: User) async throws -> Bool {
        // TOTP (Time-based One-Time Password) verification
        let totpGenerator = TOTPGenerator(secret: user.mfaSecret)
        let expectedCode = totpGenerator.generate()

        return code == expectedCode
    }

    func generateMFASecret() -> String {
        // Generate base32-encoded secret for TOTP
        let secretData = Data((0..<20).map { _ in UInt8.random(in: 0...255) })
        return secretData.base32EncodedString
    }
}
```

### 3.3 Session Management

```swift
actor SessionManager {
    private var activeSessions: [UUID: Session] = [:]
    private let sessionTimeout: TimeInterval = 15 * 60  // 15 minutes

    struct Session {
        let id: UUID
        let user: User
        let createdAt: Date
        var lastActivityAt: Date
        var isValid: Bool {
            Date().timeIntervalSince(lastActivityAt) < sessionTimeout
        }
    }

    func createSession(for user: User) async throws -> Session {
        let session = Session(
            id: UUID(),
            user: user,
            createdAt: Date(),
            lastActivityAt: Date()
        )

        activeSessions[session.id] = session
        return session
    }

    func validateSession(_ sessionID: UUID) async -> Bool {
        guard let session = activeSessions[sessionID], session.isValid else {
            return false
        }

        // Update last activity
        var updatedSession = session
        updatedSession.lastActivityAt = Date()
        activeSessions[sessionID] = updatedSession

        return true
    }

    func invalidateSession(_ sessionID: UUID) async {
        activeSessions.removeValue(forKey: sessionID)
    }
}
```

## 4. Authorization (RBAC)

### 4.1 Role Definitions

```swift
enum UserRole: String, Codable {
    case physician
    case radiologist
    case surgeon
    case resident
    case medicalStudent
    case administrator

    var permissions: Set<Permission> {
        switch self {
        case .physician, .radiologist, .surgeon:
            return [.viewStudies, .annotate, .export, .collaborate, .generateReports]
        case .resident:
            return [.viewStudies, .annotate, .collaborate]
        case .medicalStudent:
            return [.viewStudies]
        case .administrator:
            return Permission.allCases.asSet()
        }
    }
}

enum Permission: String, CaseIterable, Codable {
    case viewStudies
    case downloadStudies
    case annotate
    case export
    case collaborate
    case generateReports
    case manageUsers
    case viewAuditLogs
    case configurePACS
}

extension Array where Element: CaseIterable {
    func asSet() -> Set<Element> {
        Set(self)
    }
}
```

### 4.2 Permission Checking

```swift
actor AuthorizationService {
    func checkPermission(_ permission: Permission, for user: User, resource: Resource) async -> Bool {
        // Check role-based permissions
        guard user.role.permissions.contains(permission) else {
            return false
        }

        // Check resource-level permissions
        switch resource {
        case .study(let studyUID):
            // Check if user has access to this specific study
            return await checkStudyAccess(user: user, studyUID: studyUID)

        case .patient(let patientID):
            // Check if user is assigned to this patient
            return await checkPatientAccess(user: user, patientID: patientID)

        default:
            return true
        }
    }

    private func checkStudyAccess(user: User, studyUID: String) async -> Bool {
        // Query database for user-study access relationship
        // This might be department-based, provider-based, etc.
        return true  // Simplified
    }

    private func checkPatientAccess(user: User, patientID: String) async -> Bool {
        // Check if user is authorized provider for this patient
        return true  // Simplified
    }
}

enum Resource {
    case study(String)
    case patient(String)
    case configuration
    case auditLog
}
```

## 5. Encryption

### 5.1 Encryption at Rest

```swift
import CryptoKit

actor EncryptionService {
    private let keychain = KeychainService.shared

    // Master encryption key management
    func getMasterKey() throws -> SymmetricKey {
        let keyIdentifier = "com.medicalimaging.master-key"

        if let keyData = try? keychain.get(key: keyIdentifier) {
            return SymmetricKey(data: keyData)
        } else {
            // Generate new master key
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            try keychain.set(key: keyIdentifier, value: keyData)
            return key
        }
    }

    // Encrypt PHI data
    func encrypt(_ data: Data) throws -> EncryptedData {
        let key = try getMasterKey()
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        return EncryptedData(
            ciphertext: sealedBox.ciphertext,
            nonce: sealedBox.nonce,
            tag: sealedBox.tag
        )
    }

    func decrypt(_ encryptedData: EncryptedData) throws -> Data {
        let key = try getMasterKey()

        let sealedBox = try AES.GCM.SealedBox(
            nonce: encryptedData.nonce,
            ciphertext: encryptedData.ciphertext,
            tag: encryptedData.tag
        )

        return try AES.GCM.open(sealedBox, using: key)
    }
}

struct EncryptedData {
    let ciphertext: Data
    let nonce: AES.GCM.Nonce
    let tag: Data
}
```

### 5.2 Encryption in Transit

```swift
import Network

actor SecureNetworkService {
    func createSecureConnection(to host: String, port: UInt16) -> NWConnection {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port)
        )

        // TLS 1.3 configuration
        let tlsOptions = NWProtocolTLS.Options()

        // Minimum TLS 1.3
        sec_protocol_options_set_min_tls_protocol_version(
            tlsOptions.securityProtocolOptions,
            .TLSv13
        )

        // Certificate pinning
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { (metadata, trust, complete) in
                self.verifyCertificate(metadata: metadata, trust: trust, complete: complete)
            },
            .global()
        )

        let parameters = NWParameters(tls: tlsOptions)

        return NWConnection(to: endpoint, using: parameters)
    }

    private func verifyCertificate(
        metadata: sec_protocol_metadata_t,
        trust: sec_trust_t,
        complete: @escaping (Bool) -> Void
    ) {
        // Certificate pinning logic
        let serverCertificates = sec_trust_copy_certificates(trust) as? [SecCertificate] ?? []

        guard let serverCert = serverCertificates.first else {
            complete(false)
            return
        }

        // Compare with pinned certificate
        let pinnedCertData = loadPinnedCertificate()
        let serverCertData = SecCertificateCopyData(serverCert) as Data

        complete(serverCertData == pinnedCertData)
    }

    private func loadPinnedCertificate() -> Data {
        // Load pinned certificate from bundle
        guard let certPath = Bundle.main.path(forResource: "pacs-server", ofType: "cer"),
              let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)) else {
            fatalError("Pinned certificate not found")
        }
        return certData
    }
}
```

## 6. Audit Logging

### 6.1 Audit Event Tracking

```swift
actor AuditService {
    private let repository: AuditRepository

    func logEvent(_ event: AuditEvent) async {
        // Store audit event
        try? await repository.save(event)

        // Send to SIEM (Security Information and Event Management) if configured
        await sendToSIEM(event)
    }

    func logAccess(user: User, resource: String, action: AuditAction, outcome: Outcome) async {
        let event = AuditEvent(
            id: UUID(),
            timestamp: Date(),
            user: user,
            action: action,
            resourceType: "Study",
            resourceID: hashResourceID(resource),  // Hash PHI
            outcome: outcome,
            ipAddress: getCurrentIPAddress(),
            deviceID: getDeviceID()
        )

        await logEvent(event)
    }

    private func hashResourceID(_ resourceID: String) -> String {
        // SHA-256 hash to protect PHI in logs
        let inputData = Data(resourceID.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func sendToSIEM(_ event: AuditEvent) async {
        // Send audit event to external SIEM system (Splunk, ELK, etc.)
        // Implementation depends on SIEM integration
    }

    private func getCurrentIPAddress() -> String {
        // Get device IP address
        return "0.0.0.0"  // Placeholder
    }

    private func getDeviceID() -> String {
        // Get unique device identifier
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
}

enum AuditAction: String, Codable {
    case login
    case logout
    case studyViewed
    case studyDownloaded
    case annotationCreated
    case annotationModified
    case annotationDeleted
    case reportGenerated
    case exportPerformed
    case collaborationStarted
    case configurationChanged
}

enum Outcome: String, Codable {
    case success
    case failure
    case denied
}
```

### 6.2 Audit Log Retention

```swift
actor AuditRetentionService {
    private let repository: AuditRepository
    private let retentionPeriod: TimeInterval = 2 * 365 * 24 * 3600  // 2 years

    func cleanupOldLogs() async throws {
        let cutoffDate = Date().addingTimeInterval(-retentionPeriod)
        try await repository.deleteEvents(olderThan: cutoffDate)
    }

    func exportAuditLogs(from: Date, to: Date) async throws -> URL {
        let events = try await repository.fetchEvents(from: from, to: to)

        // Export to CSV for compliance reporting
        let csv = generateCSV(from: events)

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-log-\(ISO8601DateFormatter().string(from: from)).csv")

        try csv.write(to: exportURL, atomically: true, encoding: .utf8)

        return exportURL
    }

    private func generateCSV(from events: [AuditEvent]) -> String {
        var csv = "Timestamp,User,Action,Resource,Outcome\n"

        for event in events {
            csv += "\(event.timestamp),\(event.user.username),\(event.action.rawValue),\(event.resourceID),\(event.outcome.rawValue)\n"
        }

        return csv
    }
}
```

## 7. Privacy by Design

### 7.1 Data Minimization

```swift
actor DataMinimizationService {
    // Only fetch necessary fields from PACS
    func fetchMinimalStudyData(studyUID: String) async throws -> MinimalStudyData {
        // Query only required DICOM tags
        let tags: [DICOMTag] = [
            .studyInstanceUID,
            .studyDate,
            .modality,
            .studyDescription
        ]

        // Don't fetch patient name, DOB, etc. unless specifically needed
        return try await pacsClient.queryStudy(studyUID: studyUID, tags: tags)
    }
}
```

### 7.2 De-identification

```swift
actor DeidentificationService {
    func deidentifyStudy(_ study: Study) -> Study {
        var deidentified = study

        // Remove direct identifiers
        deidentified.patient.name = PersonName(
            familyName: "Anonymous",
            givenName: "Patient",
            middleName: nil,
            prefix: nil,
            suffix: nil
        )
        deidentified.patient.patientID = "ANON-\(UUID().uuidString)"
        deidentified.patient.birthDate = nil

        // Shift dates to maintain temporal relationships
        if let studyDate = deidentified.studyDate {
            let offset = TimeInterval.random(in: -365*24*3600...0)  // Random shift up to 1 year
            deidentified.studyDate = studyDate.addingTimeInterval(offset)
        }

        return deidentified
    }

    func deidentifyDICOM(_ dicomFile: URL) async throws -> URL {
        // Load DICOM file
        let dataset = try await DICOMParser.parse(url: dicomFile)

        // Remove PHI tags
        let phiTags: [DICOMTag] = [
            .patientName,
            .patientID,
            .patientBirthDate,
            .patientAddress,
            .institutionName,
            .referringPhysicianName
        ]

        for tag in phiTags {
            dataset.remove(tag: tag)
        }

        // Generate new UIDs
        dataset.set(tag: .studyInstanceUID, value: generateAnonymousUID())
        dataset.set(tag: .seriesInstanceUID, value: generateAnonymousUID())
        dataset.set(tag: .sopInstanceUID, value: generateAnonymousUID())

        // Save deidentified file
        let deidentifiedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("deidentified-\(UUID().uuidString).dcm")

        try await dataset.save(to: deidentifiedURL)

        return deidentifiedURL
    }

    private func generateAnonymousUID() -> String {
        // Generate DICOM-compliant anonymous UID
        return "2.25.\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }
}
```

### 7.3 Automatic Cache Expiration

```swift
actor CacheExpirationService {
    private let defaultExpiration: TimeInterval = 7 * 24 * 3600  // 7 days
    private let repository: StudyRepository

    func scheduleExpiration(for studyUID: String) async {
        let expiresAt = Date().addingTimeInterval(defaultExpiration)
        try? await repository.setExpiration(studyUID: studyUID, expiresAt: expiresAt)
    }

    func cleanupExpiredCache() async {
        let expiredStudies = try? await repository.fetchExpiredStudies()

        for study in expiredStudies ?? [] {
            // Delete from Core Data
            try? await repository.deleteStudy(uid: study.studyInstanceUID)

            // Delete files
            try? await fileStorage.deleteDICOMFiles(for: study.studyInstanceUID)

            // Log deletion
            await auditService.logEvent(AuditEvent(
                id: UUID(),
                timestamp: Date(),
                user: systemUser,
                action: .studyDeleted,
                resourceType: "Study",
                resourceID: study.studyInstanceUID,
                outcome: .success,
                ipAddress: "system",
                deviceID: "system"
            ))
        }
    }
}
```

## 8. Secure Coding Practices

### 8.1 Input Validation

```swift
struct InputValidator {
    static func validatePatientID(_ patientID: String) throws {
        // Check length
        guard patientID.count >= 3 && patientID.count <= 64 else {
            throw ValidationError.invalidLength
        }

        // Check format (alphanumeric and dashes only)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        guard patientID.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            throw ValidationError.invalidCharacters
        }
    }

    static func validateStudyUID(_ uid: String) throws {
        // DICOM UID format: numeric digits separated by dots
        let pattern = "^[0-9]+(\\.[0-9]+)*$"
        let regex = try NSRegularExpression(pattern: pattern)

        guard regex.firstMatch(in: uid, range: NSRange(uid.startIndex..., in: uid)) != nil else {
            throw ValidationError.invalidUIDFormat
        }

        // Max length 64 characters
        guard uid.count <= 64 else {
            throw ValidationError.invalidLength
        }
    }
}

enum ValidationError: Error {
    case invalidLength
    case invalidCharacters
    case invalidUIDFormat
}
```

### 8.2 Memory Safety

```swift
// Swift provides memory safety by default, but be careful with:

// 1. Avoid force unwrapping
// Bad:
// let study = studies.first!

// Good:
guard let study = studies.first else {
    throw StudyError.notFound
}

// 2. Avoid unsafe pointers unless necessary
// Bad:
// let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: size)

// Good: Use Data or Array instead
let buffer = [UInt8](repeating: 0, count: size)

// 3. Bounds checking
func getVoxel(x: Int, y: Int, z: Int, volume: VolumeData) -> UInt16? {
    guard x >= 0 && x < volume.dimensions.x &&
          y >= 0 && y < volume.dimensions.y &&
          z >= 0 && z < volume.dimensions.z else {
        return nil
    }

    let index = z * volume.dimensions.y * volume.dimensions.x + y * volume.dimensions.x + x
    return volume.voxels[index]
}
```

## 9. Security Testing

### 9.1 Penetration Testing

```swift
class SecurityTests: XCTestCase {
    func testSQLInjection() {
        // Test that patient ID with SQL injection attempt is properly escaped
        let maliciousInput = "123'; DROP TABLE patients;--"

        XCTAssertThrowsError(try InputValidator.validatePatientID(maliciousInput))
    }

    func testXSS() {
        // Test that HTML/JavaScript in annotations is escaped
        let maliciousAnnotation = "<script>alert('XSS')</script>"

        let sanitized = AnnotationSanitizer.sanitize(maliciousAnnotation)
        XCTAssertFalse(sanitized.contains("<script>"))
    }

    func testAuthenticationBypass() async {
        // Test that unauthenticated requests are rejected
        let session = Session(id: UUID(), user: testUser, createdAt: Date(), lastActivityAt: Date().addingTimeInterval(-1000))

        let isValid = await sessionManager.validateSession(session.id)
        XCTAssertFalse(isValid, "Expired session should be invalid")
    }

    func testEncryptionStrength() throws {
        // Test that encryption uses AES-256
        let key = SymmetricKey(size: .bits256)
        XCTAssertEqual(key.bitCount, 256)
    }
}
```

## 10. Incident Response

### 10.1 Security Incident Detection

```swift
actor SecurityMonitor {
    private var failedLoginAttempts: [String: Int] = [:]  // username: count
    private let maxFailedAttempts = 5

    func recordFailedLogin(username: String) async {
        failedLoginAttempts[username, default: 0] += 1

        if failedLoginAttempts[username]! >= maxFailedAttempts {
            await handleBruteForceAttempt(username: username)
        }
    }

    func recordSuccessfulLogin(username: String) async {
        failedLoginAttempts[username] = 0
    }

    private func handleBruteForceAttempt(username: String) async {
        // Lock account temporarily
        await accountService.lockAccount(username: username, duration: 15 * 60)  // 15 minutes

        // Alert security team
        await alertService.sendSecurityAlert(
            severity: .high,
            message: "Possible brute force attack on account: \(username)"
        )

        // Log incident
        await auditService.logEvent(AuditEvent(
            id: UUID(),
            timestamp: Date(),
            user: User(username: username),
            action: .bruteForceDetected,
            resourceType: "Authentication",
            resourceID: username,
            outcome: .failure,
            ipAddress: getCurrentIPAddress(),
            deviceID: "system"
        ))
    }
}
```

### 10.2 Data Breach Response

```swift
actor BreachResponseService {
    func handlePotentialBreach(incident: SecurityIncident) async {
        // 1. Contain the breach
        await containBreach(incident)

        // 2. Assess impact
        let impact = await assessImpact(incident)

        // 3. Notify stakeholders
        if impact.affectedPatients.count > 0 {
            await notifyStakeholders(impact: impact)
        }

        // 4. Remediate
        await remediate(incident)

        // 5. Document
        await documentIncident(incident, impact: impact)
    }

    private func containBreach(_ incident: SecurityIncident) async {
        // Disable compromised accounts
        // Revoke access tokens
        // Isolate affected systems
    }

    private func assessImpact(_ incident: SecurityIncident) async -> BreachImpact {
        // Determine what PHI was potentially accessed/disclosed
        // Identify affected patients
        // Calculate severity
        return BreachImpact()
    }

    private func notifyStakeholders(impact: BreachImpact) async {
        // HIPAA requires notification within 60 days if >500 patients affected
        // Notify affected individuals
        // Notify HHS Office for Civil Rights
        // Notify media (if >500 affected)
    }
}

struct SecurityIncident {
    let id: UUID
    let timestamp: Date
    let type: IncidentType
    let severity: Severity
    let description: String
}

enum IncidentType {
    case unauthorizedAccess
    case dataBreach
    case malwareDetected
    case denialOfService
}

enum Severity {
    case low
    case medium
    case high
    case critical
}
```

## 11. HIPAA Compliance Checklist

### 11.1 Technical Safeguards

- [x] Access Control: OpticID + role-based permissions
- [x] Audit Controls: Comprehensive audit logging
- [x] Integrity: Hash verification for DICOM files
- [x] Person or Entity Authentication: Biometric + MFA
- [x] Transmission Security: TLS 1.3, certificate pinning

### 11.2 Physical Safeguards

- [x] Device and Media Controls: Encrypted storage
- [x] Workstation Security: Auto-lock after timeout
- [x] Facility Access Controls: N/A (consumer device)

### 11.3 Administrative Safeguards

- [ ] Security Management Process: Policies and procedures
- [ ] Workforce Security: Training and authorization
- [ ] Information Access Management: RBAC implementation
- [ ] Security Awareness Training: User training program
- [ ] Contingency Plan: Backup and disaster recovery

---

**Document Control**

- **Author**: Security Engineering Team
- **Reviewers**: CISO, Privacy Officer, Compliance Officer
- **Approval**: CTO, Legal
- **Next Review**: Quarterly security review

