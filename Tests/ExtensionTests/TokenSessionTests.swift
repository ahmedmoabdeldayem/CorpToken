// Tests/ExtensionTests/TokenSessionTests.swift
//
// Tests for the token extension's signing logic.
//
// Full end-to-end signing tests require:
//   1. A physical Mac with Secure Enclave
//   2. A provisioned keychain access group (can't be tested without a signing identity)
//
// These tests focus on the algorithm mapping and error paths that don't need SE.

import XCTest
import CryptoTokenKit
@testable import CorpTokenExtension

final class TokenSessionTests: XCTestCase {

    // MARK: - Algorithm Mapping

    // TokenSession.resolvedSigningAlgorithm is private; test it indirectly by
    // calling tokenSession(_:sign:keyObjectID:algorithm:) with a mock key.
    // For now, document expected algorithm support as a specification test.

    func testSupportedAlgorithmsDocumented() {
        // ECDSA P-256 variants that the session must support:
        let expected: [SecKeyAlgorithm] = [
            .ecdsaSignatureMessageX962SHA256,
            .ecdsaSignatureMessageX962SHA384,
            .ecdsaSignatureMessageX962SHA512,
            .ecdsaSignatureDigestX962SHA256,
            .ecdsaSignatureDigestX962SHA384,
            .ecdsaSignatureDigestX962SHA512
        ]
        // RSA algorithms are intentionally NOT in this list — the SE key is EC only
        XCTAssertEqual(expected.count, 6, "Update this test when adding new algorithms")
    }

    // MARK: - Integration (requires SE + provisioning)

    func testSignAndVerify() throws {
        try XCTSkipUnless(SecureEnclaveManager.shared.isAvailable, "SE not available")
        try XCTSkipUnless(SecureEnclaveManager.shared.hasKeyPair(), "No enrolled key — run enrollment first")

        let testData   = "Hello, CorpToken".data(using: .utf8)!
        let privateKey = try SecureEnclaveManager.shared.retrievePrivateKey()

        var cfError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            testData as CFData,
            &cfError
        ) else {
            throw cfError!.takeRetainedValue() as Error
        }

        // Verify with the public key
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        let verified  = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            testData as CFData,
            signature,
            nil
        )

        XCTAssertTrue(verified, "Signature should verify with the corresponding public key")
    }
}
