# PACS/EHR Integration Specification
## Medical Imaging Suite for visionOS

**Version**: 1.0
**Last Updated**: 2025-11-24
**Status**: Draft

---

## 1. Executive Summary

This document specifies the integration architecture for Medical Imaging Suite with hospital Picture Archiving and Communication Systems (PACS) and Electronic Health Records (EHR). The design supports DICOM networking (DIMSE and DICOMweb), HL7 FHIR for clinical data, and vendor-specific APIs for major PACS/EHR systems.

## 2. Integration Overview

### 2.1 Supported Standards

| Standard | Purpose | Implementation Priority |
|----------|---------|----------------------|
| **DICOM DIMSE** | Image query/retrieve (C-FIND, C-MOVE) | High (Phase 1) |
| **DICOMweb** | RESTful image access (WADO, QIDO, STOW) | High (Phase 1) |
| **HL7 FHIR R4** | Clinical data (Patient, ImagingStudy, DiagnosticReport) | Medium (Phase 2) |
| **IHE Profiles** | XDS-I (document sharing) | Low (Phase 3) |

### 2.2 Supported PACS Vendors

- GE Healthcare: Centricity PACS
- Philips: IntelliSpace PACS
- Siemens Healthineers: syngo.via
- Fujifilm: Synapse PACS
- Sectra: PACS IDS7
- Generic: Any DICOM-compliant PACS

### 2.3 Supported EHR Vendors

- Epic Systems (Epic App Orchard integration)
- Cerner (HealtheIntent APIs)
- Allscripts
- MEDITECH
- Generic FHIR-compliant EHR

## 3. DICOM DIMSE Protocol

### 3.1 DICOM Service Classes

The application implements the following DICOM Service Class User (SCU) roles:

| Service | SOP Class UID | Purpose |
|---------|---------------|---------|
| **C-ECHO** | 1.2.840.10008.1.1 | Verify connection |
| **C-FIND** | 1.2.840.10008.5.1.4.1.2.2.1 (Study Root) | Query studies |
| **C-MOVE** | 1.2.840.10008.5.1.4.1.2.2.2 (Study Root) | Retrieve images |
| **C-STORE** | 1.2.840.10008.5.1.4.1.1.88.33 (DICOM SR) | Store annotations |

### 3.2 DIMSE Client Implementation

```swift
import Network

protocol DIMSEClient {
    func connect(to server: PACSServer) async throws
    func disconnect() async
    func echo() async throws
    func find(query: DICOMQuery) async throws -> [DICOMQueryResult]
    func move(studyUID: String, to destinationAET: String) async throws
    func store(dataset: DICOMDataset) async throws
}

actor DIMSEClientImpl: DIMSEClient {
    private var connection: NWConnection?
    private let server: PACSServer
    private let localAET: String = "VISION_PRO"
    private let maxPDUSize: Int = 65536

    func connect(to server: PACSServer) async throws {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(server.hostname),
            port: NWEndpoint.Port(integerLiteral: UInt16(server.port))
        )

        connection = NWConnection(to: endpoint, using: .tcp)
        connection?.start(queue: .global())

        // Wait for connection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
        }

        // Send association request
        try await sendAssociationRequest()
    }

    func echo() async throws {
        let command = DICOMCommand.cEcho()
        try await sendCommand(command)
        let response = try await receiveResponse()

        guard response.status == .success else {
            throw DICOMError.echoFailed
        }
    }

    func find(query: DICOMQuery) async throws -> [DICOMQueryResult] {
        let command = DICOMCommand.cFind(queryLevel: .study)
        let dataset = encodeFindQuery(query)

        try await sendCommand(command, dataset: dataset)

        var results: [DICOMQueryResult] = []

        while true {
            let response = try await receiveResponse()

            if response.status == .success {
                break  // No more results
            } else if response.status == .pending {
                if let dataset = response.dataset {
                    results.append(parseFindResult(dataset))
                }
            } else {
                throw DICOMError.findFailed(status: response.status)
            }
        }

        return results
    }

    func move(studyUID: String, to destinationAET: String) async throws {
        let command = DICOMCommand.cMove(
            queryLevel: .study,
            moveDestination: destinationAET
        )

        let dataset = DICOMDataset()
        dataset.set(tag: .studyInstanceUID, value: studyUID)

        try await sendCommand(command, dataset: dataset)

        // Wait for move to complete
        while true {
            let response = try await receiveResponse()

            if response.status == .success {
                break
            } else if response.status == .pending {
                // Move in progress, update progress
                continue
            } else {
                throw DICOMError.moveFailed(status: response.status)
            }
        }
    }

    // Association management
    private func sendAssociationRequest() async throws {
        var pdu = AssociationRequestPDU()
        pdu.calledAET = server.aet.padding(toLength: 16, withPad: " ", startingAt: 0)
        pdu.callingAET = localAET.padding(toLength: 16, withPad: " ", startingAt: 0)
        pdu.maxPDULength = UInt32(maxPDUSize)

        // Add presentation contexts
        pdu.addPresentationContext(
            id: 1,
            abstractSyntax: "1.2.840.10008.1.1",  // Verification SOP
            transferSyntaxes: ["1.2.840.10008.1.2"]  // Implicit VR Little Endian
        )

        pdu.addPresentationContext(
            id: 3,
            abstractSyntax: "1.2.840.10008.5.1.4.1.2.2.1",  // Study Root Query/Retrieve
            transferSyntaxes: ["1.2.840.10008.1.2"]
        )

        let data = pdu.encode()
        try await send(data)

        // Receive association accept/reject
        let response = try await receive()
        let responsePDU = try AssociationPDU.decode(response)

        guard responsePDU is AssociationAcceptPDU else {
            throw DICOMError.associationRejected
        }
    }

    private func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection?.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection?.receive(minimumIncompleteLength: 1, maximumLength: maxPDUSize) { data, _, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: DICOMError.connectionClosed)
                }
            }
        }
    }
}

struct PACSServer: Codable {
    let id: UUID
    let name: String
    let hostname: String
    let port: Int
    let aet: String          // Application Entity Title
    let protocol: PACSProtocol
}

enum PACSProtocol: String, Codable {
    case dimse
    case dicomweb
}

enum DICOMError: Error {
    case associationRejected
    case connectionClosed
    case echoFailed
    case findFailed(status: DICOMStatus)
    case moveFailed(status: DICOMStatus)
}
```

### 3.3 DICOM Query Model

```swift
struct DICOMQuery {
    var patientID: String?
    var patientName: String?
    var studyDate: DateRange?
    var studyDescription: String?
    var modality: Modality?
    var accessionNumber: String?
}

struct DateRange {
    let start: Date?
    let end: Date?

    var dicomFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"

        let startStr = start.map { formatter.string(from: $0) } ?? ""
        let endStr = end.map { formatter.string(from: $0) } ?? ""

        return "\(startStr)-\(endStr)"
    }
}

struct DICOMQueryResult {
    let studyInstanceUID: String
    let patientID: String
    let patientName: String
    let studyDate: Date?
    let studyDescription: String?
    let modalities: [Modality]
    let numberOfSeries: Int
    let numberOfInstances: Int
}
```

## 4. DICOMweb Protocol

### 4.1 DICOMweb Services

| Service | HTTP Method | Purpose |
|---------|-------------|---------|
| **QIDO-RS** | GET | Query for studies, series, instances |
| **WADO-RS** | GET | Retrieve instances, metadata, rendered images |
| **STOW-RS** | POST | Store instances (annotations) |

### 4.2 DICOMweb Client Implementation

```swift
import Foundation

protocol DICOMwebClient {
    func queryStudies(filters: [String: String]) async throws -> [DICOMQueryResult]
    func retrieveStudy(studyUID: String) async throws -> Data
    func retrieveMetadata(studyUID: String) async throws -> DICOMMetadata
    func storeInstance(_ data: Data) async throws
}

actor DICOMwebClientImpl: DICOMwebClient {
    private let baseURL: URL
    private let session: URLSession
    private let authProvider: AuthenticationProvider

    init(baseURL: URL, authProvider: AuthenticationProvider) {
        self.baseURL = baseURL
        self.authProvider = authProvider

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }

    func queryStudies(filters: [String: String]) async throws -> [DICOMQueryResult] {
        // QIDO-RS: GET {baseURL}/studies?{filters}
        var components = URLComponents(url: baseURL.appendingPathComponent("studies"), resolvingAgainstBaseURL: true)!
        components.queryItems = filters.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/dicom+json", forHTTPHeaderField: "Accept")

        // Add authentication
        request = try await authProvider.authenticate(request: request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DICOMwebError.queryFailed
        }

        // Parse JSON response
        let results = try JSONDecoder().decode([DICOMJSONStudy].self, from: data)
        return results.map { mapToQueryResult($0) }
    }

    func retrieveStudy(studyUID: String) async throws -> Data {
        // WADO-RS: GET {baseURL}/studies/{studyUID}
        let url = baseURL
            .appendingPathComponent("studies")
            .appendingPathComponent(studyUID)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("multipart/related; type=application/dicom", forHTTPHeaderField: "Accept")
        request = try await authProvider.authenticate(request: request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DICOMwebError.retrieveFailed
        }

        return data
    }

    func retrieveMetadata(studyUID: String) async throws -> DICOMMetadata {
        // WADO-RS: GET {baseURL}/studies/{studyUID}/metadata
        let url = baseURL
            .appendingPathComponent("studies")
            .appendingPathComponent(studyUID)
            .appendingPathComponent("metadata")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/dicom+json", forHTTPHeaderField: "Accept")
        request = try await authProvider.authenticate(request: request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DICOMwebError.metadataFailed
        }

        return try JSONDecoder().decode(DICOMMetadata.self, from: data)
    }

    func storeInstance(_ data: Data) async throws {
        // STOW-RS: POST {baseURL}/studies
        let url = baseURL.appendingPathComponent("studies")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/dicom", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dicom+json", forHTTPHeaderField: "Accept")
        request.httpBody = data
        request = try await authProvider.authenticate(request: request)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DICOMwebError.storeFailed
        }
    }
}

enum DICOMwebError: Error {
    case queryFailed
    case retrieveFailed
    case metadataFailed
    case storeFailed
}
```

## 5. HL7 FHIR Integration

### 5.1 FHIR Resources

```swift
protocol FHIRClient {
    func fetchPatient(id: String) async throws -> FHIRPatient
    func fetchImagingStudy(id: String) async throws -> FHIRImagingStudy
    func createDiagnosticReport(_ report: FHIRDiagnosticReport) async throws -> String
}

struct FHIRPatient: Codable {
    let id: String
    let identifier: [FHIRIdentifier]
    let name: [FHIRHumanName]
    let gender: String?
    let birthDate: String?  // YYYY-MM-DD
}

struct FHIRIdentifier: Codable {
    let system: String?
    let value: String
}

struct FHIRHumanName: Codable {
    let family: String?
    let given: [String]?
    let prefix: [String]?
    let suffix: [String]?
}

struct FHIRImagingStudy: Codable {
    let id: String
    let identifier: [FHIRIdentifier]
    let status: String
    let subject: FHIRReference
    let started: String?  // ISO 8601 datetime
    let numberOfSeries: Int?
    let numberOfInstances: Int?
    let series: [FHIRImagingStudySeries]?
}

struct FHIRImagingStudySeries: Codable {
    let uid: String
    let number: Int?
    let modality: FHIRCoding
    let description: String?
    let numberOfInstances: Int?
    let instance: [FHIRImagingStudyInstance]?
}

struct FHIRImagingStudyInstance: Codable {
    let uid: String
    let number: Int?
    let sopClass: FHIRCoding
}

struct FHIRCoding: Codable {
    let system: String?
    let code: String
    let display: String?
}

struct FHIRReference: Codable {
    let reference: String  // e.g., "Patient/123"
    let display: String?
}

struct FHIRDiagnosticReport: Codable {
    let status: String
    let code: FHIRCodeableConcept
    let subject: FHIRReference
    let effectiveDateTime: String
    let issued: String
    let result: [FHIRReference]?
    let conclusion: String?
    let conclusionCode: [FHIRCodeableConcept]?
}

struct FHIRCodeableConcept: Codable {
    let coding: [FHIRCoding]
    let text: String?
}
```

### 5.2 FHIR Client Implementation

```swift
actor FHIRClientImpl: FHIRClient {
    private let baseURL: URL
    private let session: URLSession
    private let authProvider: AuthenticationProvider

    func fetchPatient(id: String) async throws -> FHIRPatient {
        let url = baseURL.appendingPathComponent("Patient").appendingPathComponent(id)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        request = try await authProvider.authenticate(request: request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FHIRError.fetchFailed
        }

        return try JSONDecoder().decode(FHIRPatient.self, from: data)
    }

    func fetchImagingStudy(id: String) async throws -> FHIRImagingStudy {
        let url = baseURL.appendingPathComponent("ImagingStudy").appendingPathComponent(id)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        request = try await authProvider.authenticate(request: request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FHIRError.fetchFailed
        }

        return try JSONDecoder().decode(FHIRImagingStudy.self, from: data)
    }

    func createDiagnosticReport(_ report: FHIRDiagnosticReport) async throws -> String {
        let url = baseURL.appendingPathComponent("DiagnosticReport")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/fhir+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(report)
        request = try await authProvider.authenticate(request: request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FHIRError.createFailed
        }

        let created = try JSONDecoder().decode(FHIRDiagnosticReport.self, from: data)
        return created.id ?? ""
    }
}

enum FHIRError: Error {
    case fetchFailed
    case createFailed
}
```

## 6. Authentication

### 6.1 OAuth 2.0 Flow (Epic, Cerner)

```swift
protocol AuthenticationProvider {
    func authenticate(request: URLRequest) async throws -> URLRequest
    func refreshToken() async throws
}

actor OAuth2Provider: AuthenticationProvider {
    private var accessToken: String?
    private var refreshToken: String?
    private var expiresAt: Date?

    private let clientID: String
    private let clientSecret: String
    private let authorizationEndpoint: URL
    private let tokenEndpoint: URL

    func authenticate(request: URLRequest) async throws -> URLRequest {
        // Check if token is expired
        if let expiresAt = expiresAt, Date() >= expiresAt {
            try await refreshToken()
        }

        // If no token, perform full OAuth flow
        if accessToken == nil {
            try await performAuthorizationCodeFlow()
        }

        var authenticatedRequest = request
        authenticatedRequest.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }

    func refreshToken() async throws {
        guard let refreshToken = refreshToken else {
            throw AuthError.noRefreshToken
        }

        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret
        ]

        request.httpBody = body.percentEncoded()

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.refreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(OAuth2TokenResponse.self, from: data)
        updateTokens(tokenResponse)
    }

    private func performAuthorizationCodeFlow() async throws {
        // 1. Launch browser for user to authorize
        // 2. Receive authorization code via redirect URL
        // 3. Exchange code for tokens
        // (Implementation depends on platform-specific browser launching)
    }

    private func updateTokens(_ response: OAuth2TokenResponse) {
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
        self.expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
    }
}

struct OAuth2TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

enum AuthError: Error {
    case noRefreshToken
    case refreshFailed
    case authorizationFailed
}
```

## 7. Vendor-Specific Integrations

### 7.1 Epic Integration

```swift
actor EpicPACSClient {
    private let fhirClient: FHIRClient
    private let appOrchardCredentials: EpicCredentials

    struct EpicCredentials {
        let clientID: String
        let clientSecret: String
        let baseURL: URL
    }

    func queryWorklist() async throws -> [WorklistItem] {
        // Epic uses FHIR ImagingStudy for worklist
        let url = fhirClient.baseURL.appendingPathComponent("ImagingStudy")

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "status", value: "available"),
            URLQueryItem(name: "_sort", value: "-started")
        ]

        // Fetch and parse
        // ...
    }
}
```

### 7.2 GE Centricity Integration

```swift
actor GECentricityClient {
    private let dicomwebClient: DICOMwebClient

    // GE Centricity supports DICOMweb with custom authentication
    func connect() async throws {
        // GE-specific authentication header
        // X-Api-Key: {apiKey}
    }
}
```

## 8. Integration Testing

### 8.1 Mock PACS Server

```swift
actor MockPACSServer {
    private var studies: [DICOMStudy] = []

    func addStudy(_ study: DICOMStudy) {
        studies.append(study)
    }

    func handleCFind(query: DICOMQuery) -> [DICOMQueryResult] {
        studies.filter { study in
            if let patientID = query.patientID, study.patient.patientID != patientID {
                return false
            }
            // Additional filtering...
            return true
        }.map { mapToQueryResult($0) }
    }
}
```

---

**Document Control**

- **Author**: Integration Engineering Team
- **Reviewers**: Solutions Architect, Hospital IT Partner
- **Approval**: CTO
- **Next Review**: After vendor partnership discussions

