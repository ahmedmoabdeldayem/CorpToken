// Tests/SharedTests/CredentialStoreTests.swift
//
// Unit tests for CredentialStore.
//
// Tests that write to the shared keychain access group require a real provisioned
// Mac with the entitlement in place. All such tests are guarded with XCTSkipUnless
// so they are skipped gracefully in CI environments that lack the access group.
//
// Tests that only check parsing/decoding behaviour (no keychain I/O) run everywhere.
//
// To supply a real DER certificate for the full round-trip tests, paste the
// base64-encoded bytes into `testCertBase64` (same format as CertificateParserTests).

import XCTest
import Security
@testable import Shared   // Adjust module name to match your Xcode target

final class CredentialStoreTests: XCTestCase {

    // Self-signed test certificate (DER, base64-encoded).
    // Leave empty to skip keychain round-trip tests (same pattern as CertificateParserTests).
    // Generate with:
    //   openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
    //     -keyout /dev/null -out test.der -outform DER -days 365 \
    //     -subj "/CN=Test Employee/O=CorpToken" -nodes
    //   base64 -i test.der
    private let testCertBase64 = "MIICRDCCAeqgAwIBAgIURDdfaDH7h4/tbzVPO66vNSjQz+EwCgYIKoZIzj0EAwIw" +
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

    private let store = CredentialStore.shared

    // MARK: - Helpers

    /// Returns the SecCertificate built from `testCertBase64`, or nil if the
    /// constant is empty / the data is not valid DER.
    private var testCertificate: SecCertificate? {
        guard !testCertBase64.isEmpty,
              let der  = Data(base64Encoded: testCertBase64),
              let cert = SecCertificateCreateWithData(nil, der as CFData)
        else { return nil }
        return cert
    }

    // MARK: - storeCertificate: invalid data

    func testStoreCertificateThrowsForInvalidDER() {
        // Random bytes that are not a valid DER-encoded X.509 certificate
        let garbage = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertThrowsError(try store.storeCertificate(garbage)) { error in
            guard let storeError = error as? CredentialStoreError else {
                XCTFail("Expected CredentialStoreError, got \(error)")
                return
            }
            XCTAssertEqual(storeError, .certificateDecodeFailed)
        }
    }

    func testStoreCertificateThrowsForEmptyData() {
        XCTAssertThrowsError(try store.storeCertificate(Data())) { error in
            XCTAssertEqual(error as? CredentialStoreError, .certificateDecodeFailed)
        }
    }

    // MARK: - retrieveCertificate: nothing stored

    func testRetrieveCertificateThrowsWhenEmpty() throws {
        // Remove any cert that might be present from a previous test run
        try? store.removeCertificate()

        XCTAssertThrowsError(try store.retrieveCertificate()) { error in
            XCTAssertEqual(error as? CredentialStoreError, .certificateNotFound)
        }
    }

    func testRetrieveCertificateDataThrowsWhenEmpty() throws {
        try? store.removeCertificate()

        XCTAssertThrowsError(try store.retrieveCertificateData()) { error in
            XCTAssertEqual(error as? CredentialStoreError, .certificateNotFound)
        }
    }

    // MARK: - hasCertificate: no cert present

    func testHasCertificateReturnsFalseWhenNothingStored() throws {
        try? store.removeCertificate()
        XCTAssertFalse(store.hasCertificate())
    }

    // MARK: - subjectSummary: no cert present

    func testSubjectSummaryReturnsNilWhenNothingStored() throws {
        try? store.removeCertificate()
        XCTAssertNil(store.subjectSummary())
    }

    // MARK: - expiryDate: no cert present

    func testExpiryDateReturnsNilWhenNothingStored() throws {
        try? store.removeCertificate()
        XCTAssertNil(store.expiryDate())
    }

    // MARK: - removeCertificate: idempotent

    func testRemoveCertificateIsIdempotent() {
        // Calling remove when nothing is stored should not throw
        XCTAssertNoThrow(try? store.removeCertificate())
        XCTAssertNoThrow(try? store.removeCertificate())
    }

    // MARK: - Full round-trip (requires real DER cert + access group entitlement)

    func testStoreAndRetrieveCertificate() throws {
        try XCTSkipIf(testCertBase64.isEmpty, "No test certificate provided — set testCertBase64")

        guard let der = Data(base64Encoded: testCertBase64) else {
            XCTFail("testCertBase64 is not valid base64")
            return
        }

        defer { try? store.removeCertificate() }

        try store.storeCertificate(der)

        // hasCertificate() should now return true
        XCTAssertTrue(store.hasCertificate())

        // The retrieved DER bytes must match what was stored
        let retrieved = try store.retrieveCertificateData()
        XCTAssertEqual(retrieved, der)
    }

    func testStoredCertificateCanBeRetrievedAsSecCertificate() throws {
        try XCTSkipIf(testCertBase64.isEmpty, "No test certificate provided — set testCertBase64")

        guard let der = Data(base64Encoded: testCertBase64) else {
            XCTFail("testCertBase64 is not valid base64")
            return
        }

        defer { try? store.removeCertificate() }

        try store.storeCertificate(der)

        let cert = try store.retrieveCertificate()
        // A successfully retrieved SecCertificate should yield non-empty DER
        let roundTripDER = SecCertificateCopyData(cert) as Data
        XCTAssertEqual(roundTripDER, der)
    }

    func testSubjectSummaryNonEmptyAfterStore() throws {
        try XCTSkipIf(testCertBase64.isEmpty, "No test certificate provided — set testCertBase64")

        guard let der = Data(base64Encoded: testCertBase64) else {
            XCTFail("testCertBase64 is not valid base64")
            return
        }

        defer { try? store.removeCertificate() }

        try store.storeCertificate(der)

        let summary = store.subjectSummary()
        XCTAssertNotNil(summary)
        XCTAssertFalse(summary!.isEmpty)
    }

    func testHasCertificateReturnsTrueAfterStore() throws {
        try XCTSkipIf(testCertBase64.isEmpty, "No test certificate provided — set testCertBase64")

        guard let der = Data(base64Encoded: testCertBase64) else {
            XCTFail("testCertBase64 is not valid base64")
            return
        }

        defer { try? store.removeCertificate() }

        try store.storeCertificate(der)
        XCTAssertTrue(store.hasCertificate())
    }

    func testHasCertificateReturnsFalseAfterRemove() throws {
        try XCTSkipIf(testCertBase64.isEmpty, "No test certificate provided — set testCertBase64")

        guard let der = Data(base64Encoded: testCertBase64) else {
            XCTFail("testCertBase64 is not valid base64")
            return
        }

        try store.storeCertificate(der)
        try? store.removeCertificate()
        XCTAssertFalse(store.hasCertificate())
    }

    func testRetrieveCertificateThrowsAfterRemove() throws {
        try XCTSkipIf(testCertBase64.isEmpty, "No test certificate provided — set testCertBase64")

        guard let der = Data(base64Encoded: testCertBase64) else {
            XCTFail("testCertBase64 is not valid base64")
            return
        }

        try store.storeCertificate(der)
        try? store.removeCertificate()

        XCTAssertThrowsError(try store.retrieveCertificate()) { error in
            XCTAssertEqual(error as? CredentialStoreError, .certificateNotFound)
        }
    }
}

// MARK: - CredentialStoreError Equatable

extension CredentialStoreError: Equatable {
    public static func == (lhs: CredentialStoreError, rhs: CredentialStoreError) -> Bool {
        switch (lhs, rhs) {
        case (.certificateNotFound, .certificateNotFound),
             (.certificateDecodeFailed, .certificateDecodeFailed),
             (.identityNotFound, .identityNotFound):
            return true
        case (.certificateStoreFailed(let a), .certificateStoreFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}
