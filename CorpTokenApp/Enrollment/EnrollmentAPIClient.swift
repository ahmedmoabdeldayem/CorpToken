// CorpTokenApp/Enrollment/EnrollmentAPIClient.swift
//
// Full enrollment backend client.
//
// ═══════════════════════════════════════════════════════════════════
//  REST CONTRACT  (implement this on your enrollment backend)
//
//  All requests:  Content-Type: application/json
//                 Authorization: Bearer <access_token>
//
//  POST /oauth/device/authorize          — start device flow
//    Body (form-encoded): client_id, scope
//    Response: { device_code, user_code, verification_uri,
//                verification_uri_complete?, expires_in, interval? }
//
//  POST /oauth/token                     — poll for token
//    Body (form-encoded): grant_type=urn:ietf:params:oauth:grant-type:device_code,
//                         client_id, device_code
//    Response 200: { access_token, token_type, expires_in }
//    Response 400: { error: "authorization_pending"|"slow_down"|
//                           "access_denied"|"expired_token",
//                   error_description? }
//
//  POST /v1/enrollments                  — submit enrollment
//    Body: { employee_id: String,
//            public_key: "<base64 X9.63 P-256 public key>",
//            platform: "macos",
//            device_serial: String }
//    Response 200: { enrollment_id: String, status: "pending" }
//
//  GET /v1/enrollments/{enrollment_id}   — poll for certificate
//    Response 200: { enrollment_id, status }
//    status values:
//      "pending"    — CA not yet processed
//      "processing" — CA is processing
//      "issued"     — certificate ready; one of certificate_der or certificate_pem present
//      "rejected"   — CA declined; rejection_reason may be set
//    On "issued":  { ..., certificate_der: "<base64 DER>" }
//                  OR { ..., certificate_pem: "<PEM string>" }
//    On "rejected": { ..., rejection_reason?: String }
// ═══════════════════════════════════════════════════════════════════

import AppKit      // NSWorkspace
import Foundation
import Security
import os.log
import Shared

private let log = Logger(subsystem: CorpTokenConstants.appBundleID, category: "EnrollmentAPI")

// MARK: - Public API

enum EnrollmentAPI {

    /// Authenticates the employee via OAuth2 device flow, submits the SE public key
    /// to the enrollment backend, and polls until the CA issues a DER certificate.
    ///
    /// - Parameters:
    ///   - employeeID:    Directory ID or UPN (e.g. "jdoe" or "jdoe@corp.example.com")
    ///   - publicKeyData: X9.63-encoded P-256 public key from SecureEnclaveManager
    ///   - progress:      Optional UI callback (called on the calling actor's context)
    /// - Returns: DER-encoded X.509 certificate
    static func requestCertificate(
        employeeID: String,
        publicKeyData: Data,
        progress: ((EnrollmentProgress) -> Void)? = nil
    ) async throws -> Data {
        let client = EnrollmentHTTPClient(config: .shared)
        return try await client.requestCertificate(
            employeeID: employeeID,
            publicKeyData: publicKeyData,
            progress: progress
        )
    }
}

// MARK: - Progress

enum EnrollmentProgress {
    case awaitingBrowserAuth(verificationURL: URL, userCode: String)
    case submittingRequest
    case waitingForCertificate(attempt: Int, max: Int)
}

// MARK: - HTTP Client

final class EnrollmentHTTPClient {

    private let config: EnrollmentConfig
    private let session: URLSession

    /// RFC 3986 unreserved characters — safe for form-encoded key and value fields.
    /// Encodes &, =, +, %, and all other special chars that would break form encoding.
    private static let formAllowed = CharacterSet.alphanumerics
        .union(.init(charactersIn: "-._~"))

    init(config: EnrollmentConfig) {
        self.config = config
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest  = config.requestTimeout
        cfg.timeoutIntervalForResource = config.requestTimeout
            * Double(config.maxPollAttempts)
        cfg.httpAdditionalHeaders = [
            "Accept":       "application/json",
            "Content-Type": "application/json",
            "User-Agent":   "CorpToken/1.0 macOS/\(ProcessInfo.processInfo.operatingSystemVersionString)"
        ]
        self.session = URLSession(configuration: cfg)
    }

    // MARK: Certificate Request

    func requestCertificate(
        employeeID: String,
        publicKeyData: Data,
        progress: ((EnrollmentProgress) -> Void)?
    ) async throws -> Data {
        // Invalidate the session when this function exits (success or failure)
        // so the connection pool and internal resources are cleaned up promptly.
        defer { session.finishTasksAndInvalidate() }

        let token = try await obtainAccessToken(progress: progress)

        progress?(.submittingRequest)

        let enrollmentID = try await submitEnrollment(
            employeeID: employeeID,
            publicKeyData: publicKeyData,
            accessToken: token
        )

        log.info("Enrollment submitted, id: \(enrollmentID, privacy: .public)")

        return try await pollForCertificate(
            enrollmentID: enrollmentID,
            accessToken: token,
            progress: progress
        )
    }

    // MARK: OAuth2 Device Authorization

    private func obtainAccessToken(
        progress: ((EnrollmentProgress) -> Void)?
    ) async throws -> String {
        if let cached = TokenCache.load() {
            log.debug("Using cached access token")
            return cached
        }

        log.info("Starting OAuth2 device authorization flow")

        let deviceCodeResponse = try await requestDeviceCode()

        guard let verificationURL = URL(
            string: deviceCodeResponse.verificationURIComplete
                ?? deviceCodeResponse.verificationURI
        ), verificationURL.scheme == "https" else {
            throw EnrollmentError.malformedResponse("verificationURI — must be an https URL")
        }

        progress?(.awaitingBrowserAuth(
            verificationURL: verificationURL,
            userCode: deviceCodeResponse.userCode
        ))

        // Open the verification URL so the employee can authenticate in the browser.
        // NSWorkspace.open is safe to call from any thread on macOS 13+.
        await MainActor.run { _ = NSWorkspace.shared.open(verificationURL) }

        let accessToken = try await pollForAccessToken(
            deviceCode: deviceCodeResponse.deviceCode,
            interval:   TimeInterval(deviceCodeResponse.interval ?? 5),
            expiresAt:  Date().addingTimeInterval(TimeInterval(deviceCodeResponse.expiresIn))
        )
        // TokenCache.save is called inside tryExchangeDeviceCode with the token's own
        // expiresIn. Do NOT save again here with deviceCodeResponse.expiresIn — that
        // would overwrite the correct token TTL with the much shorter device-code TTL.
        return accessToken
    }

    private func requestDeviceCode() async throws -> DeviceCodeResponse {
        let url = config.baseURL.appending(path: "/oauth/device/authorize")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "client_id": config.oauthClientID,
            "scope":     config.oauthScope
        ])
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "device authorization")
        return try decode(DeviceCodeResponse.self, from: data)
    }

    private func pollForAccessToken(
        deviceCode: String,
        interval: TimeInterval,
        expiresAt: Date
    ) async throws -> String {
        var currentInterval = max(interval, 5)

        while Date() < expiresAt {
            // Attempt first, sleep after — avoids burning the first polling interval
            // when the user completes browser auth immediately.
            do {
                return try await tryExchangeDeviceCode(deviceCode: deviceCode)
            } catch let error as OAuthPollingError {
                switch error {
                case .authorizationPending:
                    break  // fall through to sleep
                case .slowDown:
                    currentInterval += 5   // RFC 8628 §3.5: additive backoff
                case .accessDenied:  throw EnrollmentError.authorizationDenied
                case .expiredToken:  throw EnrollmentError.deviceCodeExpired
                }
            }
            try await Task.sleep(nanoseconds: UInt64(currentInterval * 1_000_000_000))
        }

        throw EnrollmentError.deviceCodeExpired
    }

    private func tryExchangeDeviceCode(deviceCode: String) async throws -> String {
        let url = config.baseURL.appending(path: "/oauth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "grant_type":  "urn:ietf:params:oauth:grant-type:device_code",
            "client_id":   config.oauthClientID,
            "device_code": deviceCode
        ])

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnrollmentError.invalidResponse("token exchange response type")
        }

        // OAuth spec: the server returns HTTP 400 with a JSON error body for
        // polling-state errors (authorization_pending, slow_down, etc.) —
        // these are NOT HTTP failures but part of the normal polling protocol.
        if httpResponse.statusCode == 400 {
            let errorBody = try decode(OAuthErrorResponse.self, from: data)
            switch errorBody.error {
            case "authorization_pending": throw OAuthPollingError.authorizationPending
            case "slow_down":             throw OAuthPollingError.slowDown
            case "access_denied":         throw OAuthPollingError.accessDenied
            case "expired_token":         throw OAuthPollingError.expiredToken
            default:
                throw EnrollmentError.serverError(
                    httpResponse.statusCode,
                    errorBody.errorDescription ?? errorBody.error
                )
            }
        }

        try validateHTTPResponse(response, data: data, context: "token exchange")
        let tokenResponse = try decode(TokenResponse.self, from: data)

        TokenCache.save(
            tokenResponse.accessToken,
            expiresIn: TimeInterval(tokenResponse.expiresIn ?? 3600)
        )
        return tokenResponse.accessToken
    }

    // MARK: Certificate Request and Polling

    private func submitEnrollment(
        employeeID: String,
        publicKeyData: Data,
        accessToken: String
    ) async throws -> String {
        let url = config.baseURL.appending(path: "/v1/enrollments")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.iso8601.encode(EnrollmentRequest(
            employeeID:   employeeID,
            publicKeyB64: publicKeyData.base64EncodedString(),
            platform:     "macos",
            deviceSerial: deviceSerialNumber() ?? "unknown"
        ))

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response, data: data, context: "enrollment submission")
        return try decode(EnrollmentResponse.self, from: data).enrollmentID
    }

    private func pollForCertificate(
        enrollmentID: String,
        accessToken: String,
        progress: ((EnrollmentProgress) -> Void)?
    ) async throws -> Data {
        let url = try certStatusURL(for: enrollmentID)

        // Pre-compute to avoid repeated floating-point multiply in the hot loop.
        let sleepNanoseconds = UInt64(config.pollInterval * 1_000_000_000)

        for attempt in 1...config.maxPollAttempts {
            progress?(.waitingForCertificate(attempt: attempt, max: config.maxPollAttempts))

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await session.data(for: request)
            try validateHTTPResponse(response, data: data, context: "certificate poll")

            let result = try decode(EnrollmentResponse.self, from: data)

            switch result.status {
            case "issued":
                let certDER = try extractCertificate(from: result)
                log.info("Certificate issued for enrollment: \(enrollmentID, privacy: .public)")
                return certDER
            case "rejected":
                throw EnrollmentError.enrollmentRejected(
                    result.rejectionReason ?? "No reason provided"
                )
            case "pending", "processing":
                try await Task.sleep(nanoseconds: sleepNanoseconds)
            default:
                throw EnrollmentError.unexpectedStatus(result.status)
            }
        }

        throw EnrollmentError.timeout(enrollmentID)
    }

    private func extractCertificate(from response: EnrollmentResponse) throws -> Data {
        if let b64 = response.certificateDerB64,
           let der = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) {
            return der
        }
        if let pem = response.certificatePEM {
            return try CertificateParser.derFromPEM(pem)
        }
        throw EnrollmentError.noCertificateInResponse
    }

    // MARK: Private Utilities

    private func validateHTTPResponse(
        _ response: URLResponse,
        data: Data,
        context: String
    ) throws {
        guard let http = response as? HTTPURLResponse else {
            throw EnrollmentError.invalidResponse(context)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decode(APIErrorResponse.self, from: data))?.message
                ?? String(data: data, encoding: .utf8).map { String($0.prefix(200)) }
                ?? "no response body"
            throw EnrollmentError.serverError(http.statusCode, message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder.iso8601.decode(type, from: data)
        } catch {
            log.error("JSON decode failed for \(type): \(error.localizedDescription, privacy: .public)")
            throw EnrollmentError.malformedResponse(String(describing: type))
        }
    }

    /// Validates enrollmentID and returns the certificate-status URL.
    /// Rejects IDs containing characters outside [A-Za-z0-9_-] to prevent
    /// path traversal via server-controlled data (e.g. "../../admin").
    private func certStatusURL(for enrollmentID: String) throws -> URL {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        guard !enrollmentID.isEmpty,
              enrollmentID.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw EnrollmentError.malformedResponse(
                "enrollment_id contains invalid characters: \(enrollmentID)"
            )
        }
        return config.baseURL.appending(path: "/v1/enrollments/\(enrollmentID)")
    }

    /// Builds an application/x-www-form-urlencoded body.
    /// Uses RFC 3986 unreserved characters so &, =, +, and % are all percent-encoded,
    /// preventing parameter injection from MDM-delivered config values.
    private func formEncoded(_ params: [String: String]) -> Data {
        let encoded = params
            .map { k, v -> String in
                let ek = k.addingPercentEncoding(withAllowedCharacters: Self.formAllowed) ?? k
                let ev = v.addingPercentEncoding(withAllowedCharacters: Self.formAllowed) ?? v
                return "\(ek)=\(ev)"
            }
            .joined(separator: "&")
        return Data(encoded.utf8)
    }

    /// Returns the Mac's hardware serial number.
    /// Sent to the backend for audit logging only — never used as a security control.
    private func deviceSerialNumber() -> String? {
        var size = 0
        sysctlbyname("hw.serialnumber", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var result = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.serialnumber", &result, &size, nil, 0)
        return String(cString: result)
    }
}

// MARK: - Token Cache

/// Caches the OAuth access token in the app-private keychain (NOT the shared access group).
/// The token is stored with its expiry time; load() returns nil for expired tokens.
private enum TokenCache {

    private static let service = "com.yourcompany.CorpToken.oauth-token"
    private static let account = "access-token"

    private struct CachedToken: Codable {
        let accessToken: String
        let expiresAt:   Date
    }

    /// Saves the access token with a 60-second expiry buffer so stale tokens
    /// aren't sent to the backend.
    static func save(_ token: String, expiresIn: TimeInterval) {
        clear()
        let cached = CachedToken(
            accessToken: token,
            expiresAt:   Date().addingTimeInterval(expiresIn - 60)
        )
        guard let data = try? JSONEncoder.iso8601.encode(cached) else { return }

        let query: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    service,
            kSecAttrAccount as String:    account,
            kSecValueData as String:      data,
            // Not synced to iCloud; token is valid only on this device while unlocked.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Cache write failed (e.g. keychain locked during screen-saver). The token
            // is not cached; the next enrollment call will trigger a full browser re-auth.
            log.fault("TokenCache: SecItemAdd failed OSStatus \(status) — token not cached")
        }
    }

    /// Returns the cached token, or nil if absent or expired.
    /// Proactively removes an expired token from the keychain.
    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String:      kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data   = item as? Data,
              let cached = try? JSONDecoder.iso8601.decode(CachedToken.self, from: data)
        else { return nil }

        guard Date() < cached.expiresAt else {
            clear()  // Proactively purge the expired entry
            return nil
        }
        return cached.accessToken
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum EnrollmentError: LocalizedError {
    case authorizationDenied
    case deviceCodeExpired
    case serverError(Int, String)
    case invalidResponse(String)
    case malformedResponse(String)
    case enrollmentRejected(String)
    case unexpectedStatus(String)
    case noCertificateInResponse
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Authorization was denied. Contact IT if this is unexpected."
        case .deviceCodeExpired:
            return "The login link expired. Please try enrolling again."
        case .serverError(let code, let msg):
            return "Server error \(code): \(msg)"
        case .invalidResponse(let ctx):
            return "Invalid server response: \(ctx)"
        case .malformedResponse(let type):
            return "Server response could not be decoded (\(type))"
        case .enrollmentRejected(let reason):
            return "Enrollment rejected: \(reason)"
        case .unexpectedStatus(let status):
            return "Unexpected enrollment status '\(status)' from server"
        case .noCertificateInResponse:
            return "Server reported 'issued' but did not include the certificate"
        case .timeout(let id):
            return "Certificate not issued within the time limit (enrollment: \(id))"
        }
    }
}

private enum OAuthPollingError: Error {
    case authorizationPending
    case slowDown
    case accessDenied
    case expiredToken
}

// MARK: - JSON Models

private struct DeviceCodeResponse: Decodable {
    let deviceCode:              String
    let userCode:                String
    let verificationURI:         String
    let verificationURIComplete: String?
    let expiresIn:               Int
    let interval:                Int?

    enum CodingKeys: String, CodingKey {
        case deviceCode              = "device_code"
        case userCode                = "user_code"
        case verificationURI         = "verification_uri"
        case verificationURIComplete = "verification_uri_complete"
        case expiresIn               = "expires_in"
        case interval
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn:   Int?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn   = "expires_in"
    }
}

private struct OAuthErrorResponse: Decodable {
    let error:            String
    let errorDescription: String?
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

private struct EnrollmentRequest: Encodable {
    let employeeID:   String
    let publicKeyB64: String
    let platform:     String
    let deviceSerial: String
    enum CodingKeys: String, CodingKey {
        case employeeID   = "employee_id"
        case publicKeyB64 = "public_key"
        case platform
        case deviceSerial = "device_serial"
    }
}

/// Response model for both POST /v1/enrollments and GET /v1/enrollments/{id}.
///
/// POST response: only `enrollmentID` and `status` are required.
/// GET response on `status == "issued"`: exactly one of `certificateDerB64` (base64 DER)
///   or `certificatePEM` must be present.
/// GET response on `status == "rejected"`: `rejectionReason` should be set.
/// GET response on `status == "pending"` or `"processing"`: certificate fields may be absent.
struct EnrollmentResponse: Decodable {
    let enrollmentID:      String
    let status:            String
    let certificateDerB64: String?
    let certificatePEM:    String?
    let rejectionReason:   String?

    enum CodingKeys: String, CodingKey {
        case enrollmentID      = "enrollment_id"
        case status
        case certificateDerB64 = "certificate_der"
        case certificatePEM    = "certificate_pem"
        case rejectionReason   = "rejection_reason"
    }
}

private struct APIErrorResponse: Decodable {
    let message: String
}

// MARK: - Coder Singletons

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
