// CorpTokenApp/Debug/DebugEnrollment.swift
// ONLY compiled in Debug builds. Excluded from Release via #if DEBUG.
//
// Lets you test the full UI flow (enrollment → status screen → unenroll)
// without a real enrollment backend, Team ID, or Apple Developer account.
//
// What it tests:
//   ✓ Certificate storage in the default keychain
//   ✓ EnrollmentViewModel state machine (notEnrolled → enrolled → unenrolled)
//   ✓ TokenStatusView display (subject name, expiry date, capability rows)
//   ✓ Menu bar icon state transitions
//   ✓ Unenrollment flow
//
// What it does NOT test (requires real provisioning + backend):
//   ✗ SE key generation (no real key is created — cert stored without a paired key)
//   ✗ Shared keychain access group (app ↔ extension sharing)
//   ✗ TLS client authentication
//   ✗ macOS login via smart card
//   ✗ Token extension process (CTK daemon interaction)

#if DEBUG
import Foundation
import Security
import Shared

// Pre-generated self-signed P-256 test certificate
// Subject: CN=Test Employee, O=TestCorp Inc, email=employee@testcorp.example
// Valid: Oct 2026 → Oct 2028
private let kTestCertDERBase64 =
    "MIICRDCCAeqgAwIBAgIURDdfaDH7h4/tbzVPO66vNSjQz+EwCgYIKoZIzj0EAwIw" +
    "WTEWMBQGA1UEAwwNVGVzdCBFbXBsb3llZTEVMBMGA1UECgwMVGVzdENvcnAgSW5j" +
    "MSgwJgYJKoZIhvcNAQkBFhllbXBsb3llZUB0ZXN0Y29ycC5leGFtcGxlMB4XDTI2" +
    "MTAwMzEyMTYyMloXDTI4MTAwMjEyMTYyMlowWTEWMBQGA1UEAwwNVGVzdCBFbXBs" +
    "b3llZTEVMBMGA1UECgwMVGVzdENvcnAgSW5jMSgwJgYJKoZIhvcNAQkBFhllbXBs" +
    "b3llZUB0ZXN0Y29ycC5leGFtcGxlMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE" +
    "HvLJmjpYDU3N8lQsvtlrvHh5RgOUSzRZa1sqyH365dYFNnNj+XflUBz++Tt8/k/j" +
    "beyC57Z9i8hCun86UVn+iaOBjzCBjDAdBgNVHQ4EFgQUMc6kHUnbXzz/xb4W9EVI" +
    "NQ/0sOswHwYDVR0jBBgwFoAUMc6kHUnbXzz/xb4W9EVINQ/0sOswDwYDVR0TAQH/" +
    "BAUwAwEB/zAkBgNVHREEHTAbgRllbXBsb3llZUB0ZXN0Y29ycC5leGFtcGxlMBMG" +
    "A1UdJQQMMAoGCCsGAQUFBwMCMAoGCCqGSM49BAMCA0gAMEUCIQDe0OYAUuZSDseQ" +
    "FKzmGbessvnLZPxRrMGmAHSUDP/NwQIgGbWKa/L6IKhTRcnZAhG9sTRuW/VarEYo" +
    "QwX/YR5bAEg="

enum DebugEnrollmentError: LocalizedError {
    case testCertDecodeFailed
    var errorDescription: String? {
        switch self {
        case .testCertDecodeFailed: return "[Debug] Failed to decode the bundled test certificate."
        }
    }
}

enum DebugEnrollment {

    /// Mock enrollment — runs in ~1 second with no network, no SE, no Touch ID.
    ///
    /// Stores the bundled test certificate in the default keychain. No SE key
    /// is generated, so `hasKeyPair()` remains false after this call.
    /// `EnrollmentViewModel.debugEnroll()` sets state to `.enrolled` directly
    /// (bypassing `refreshState()` which would revert to `.notEnrolled` without a key).
    ///
    /// After this call, `CredentialStore.shared.hasCertificate()` == true.
    static func enroll() throws {
        guard let der = Data(base64Encoded: kTestCertDERBase64,
                             options: .ignoreUnknownCharacters) else {
            throw DebugEnrollmentError.testCertDecodeFailed
        }
        try CredentialStore.shared.storeCertificate(der)
    }
}
#endif
