// Tests/SharedTests/SecureEnclaveManagerTests.swift
//
// Unit tests for SecureEnclaveManager.
//
// NOTE: Tests that call generateKeyPair() and retrievePrivateKey() require
// a physical Mac with a T2 chip or Apple Silicon. They will be skipped
// automatically on simulator targets or machines without SE.

import XCTest
@testable import Shared   // Adjust module name to match your Xcode target

final class SecureEnclaveManagerTests: XCTestCase {

    private let se = SecureEnclaveManager.shared

    // MARK: - Availability

    func testAvailabilityReportedCorrectly() {
        // Should return true on T2/Apple Silicon, false otherwise
        // Either value is valid — we just ensure it doesn't crash
        _ = se.isAvailable
    }

    // MARK: - Key Lifecycle

    func testGenerateAndRetrieve() throws {
        try XCTSkipUnless(se.isAvailable, "Secure Enclave not available")

        // Clean slate
        try? se.deleteKeyPair()
        XCTAssertFalse(se.hasKeyPair())

        // Generate
        let privateKey = try se.generateKeyPair()
        XCTAssertNotNil(privateKey)
        XCTAssertTrue(se.hasKeyPair())

        // Retrieve
        let retrieved = try se.retrievePrivateKey()
        XCTAssertNotNil(retrieved)

        // Clean up
        try se.deleteKeyPair()
        XCTAssertFalse(se.hasKeyPair())
    }

    func testPublicKeyDataIsNonEmpty() throws {
        try XCTSkipUnless(se.isAvailable, "Secure Enclave not available")

        try se.generateKeyPair()
        defer { try? se.deleteKeyPair() }

        let pubKeyData = try se.publicKeyData()
        // X9.63 uncompressed P-256 public key is 65 bytes (04 || x || y)
        XCTAssertEqual(pubKeyData.count, 65)
        XCTAssertEqual(pubKeyData.first, 0x04, "Public key should be uncompressed (starts with 0x04)")
    }

    func testRetrieveThrowsWhenNoKeyExists() throws {
        try XCTSkipUnless(se.isAvailable, "Secure Enclave not available")

        try? se.deleteKeyPair()

        XCTAssertThrowsError(try se.retrievePrivateKey()) { error in
            XCTAssertEqual(error as? SecureEnclaveError, .keyNotFound)
        }
    }

    func testGenerateReplacesExistingKey() throws {
        try XCTSkipUnless(se.isAvailable, "Secure Enclave not available")

        try se.generateKeyPair()
        let pubKey1 = try se.publicKeyData()

        try se.generateKeyPair()
        let pubKey2 = try se.publicKeyData()

        // New key pair should have a different public key
        XCTAssertNotEqual(pubKey1, pubKey2)

        try se.deleteKeyPair()
    }
}

// MARK: - SecureEnclaveError Equatable

extension SecureEnclaveError: Equatable {
    public static func == (lhs: SecureEnclaveError, rhs: SecureEnclaveError) -> Bool {
        switch (lhs, rhs) {
        case (.unavailable, .unavailable),
             (.keyNotFound, .keyNotFound),
             (.publicKeyExportFailed, .publicKeyExportFailed):
            return true
        default:
            return false
        }
    }
}
