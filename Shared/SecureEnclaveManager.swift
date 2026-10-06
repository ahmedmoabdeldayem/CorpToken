// Shared/SecureEnclaveManager.swift
// Compile into both the container app target and the token extension target.
//
// All employee private keys live in the Secure Enclave (T2 / Apple Silicon).
// Key material never leaves the chip.
//
// Access control: biometryCurrentSet OR devicePasscode.
// • biometryCurrentSet  — key becomes inaccessible via Touch ID if fingerprints change,
//                         preventing an attacker who adds their own fingerprint from using it.
// • devicePasscode      — passcode fallback lets the legitimate employee still use the key
//                         after adding/removing a fingerprint, without re-enrollment.

import Foundation
import Security
import CryptoKit

// MARK: - Error

public enum SecureEnclaveError: LocalizedError {
    case unavailable
    case keyGenerationFailed(CFError)
    case keyNotFound
    case publicKeyExportFailed

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Secure Enclave is not available on this Mac (requires T2 or Apple Silicon)"
        case .keyGenerationFailed(let err):
            return "Key generation failed: \(err.localizedDescription)"
        case .keyNotFound:
            return "No employee private key in keychain — re-enrollment required"
        case .publicKeyExportFailed:
            return "Could not export public key data for CSR"
        }
    }
}

// MARK: - Manager

public final class SecureEnclaveManager {

    public static let shared = SecureEnclaveManager()
    private init() {}

    // Pre-computed once; the same string for the process lifetime.
    private static let tagData = Data(CorpTokenConstants.privateKeyTag.utf8)

    // MARK: Availability

    public var isAvailable: Bool { SecureEnclave.isAvailable }

    // MARK: Key Generation

    /// Generates a new P-256 EC key pair in the Secure Enclave.
    /// Permanently stores the private key (requires Touch ID or passcode to use).
    /// Any existing key is replaced. Call during employee enrollment only.
    @discardableResult
    public func generateKeyPair() throws -> SecKey {
        guard isAvailable else { throw SecureEnclaveError.unavailable }

        try? deleteKeyPair()

        var cfError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet, .or, .devicePasscode],
            &cfError
        ) else {
            throw SecureEnclaveError.keyGenerationFailed(
                cfError?.takeRetainedValue() ??
                NSError(domain: "com.apple.security.SecAccessControl", code: -1) as CFError
            )
        }

        var privateKeyAttrs: [String: Any] = [
            kSecAttrIsPermanent as String:    true,
            kSecAttrApplicationTag as String: Self.tagData,
            kSecAttrAccessControl as String:  access
        ]
        // In Release builds, restrict to the shared access group so the token
        // extension can also access the key. In Debug, use the per-app default.
        CorpTokenConstants.applyAccessGroup(to: &privateKeyAttrs)

        let attributes: [String: Any] = [
            kSecAttrKeyType as String:       kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String:       kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String:   privateKeyAttrs
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw SecureEnclaveError.keyGenerationFailed(
                error?.takeRetainedValue() ??
                NSError(domain: "com.apple.security.SecKey", code: -1) as CFError
            )
        }

        return privateKey
    }

    // MARK: Key Retrieval

    /// Returns an opaque SecKey reference to the SE private key.
    /// Key material never leaves the Secure Enclave chip.
    public func retrievePrivateKey() throws -> SecKey {
        var query: [String: Any] = [
            kSecClass as String:              kSecClassKey,
            kSecAttrKeyType as String:        kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: Self.tagData,
            kSecAttrTokenID as String:        kSecAttrTokenIDSecureEnclave,
            kSecMatchLimit as String:         kSecMatchLimitOne,
            kSecReturnRef as String:          true
        ]
        CorpTokenConstants.applyAccessGroup(to: &query)

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let ref = item,
              CFGetTypeID(ref) == SecKeyGetTypeID() else {
            throw SecureEnclaveError.keyNotFound
        }

        return ref as! SecKey
    }

    /// Returns the X9.63-encoded (04 || x || y) public key bytes.
    /// Send these to your enrollment backend to embed in the CSR.
    public func publicKeyData() throws -> Data {
        let privateKey = try retrievePrivateKey()

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SecureEnclaveError.publicKeyExportFailed
        }

        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw SecureEnclaveError.publicKeyExportFailed
        }

        return data as Data
    }

    // MARK: Deletion

    /// Destroys the SE key pair. Silently succeeds if already absent.
    public func deleteKeyPair() throws {
        var query: [String: Any] = [
            kSecClass as String:              kSecClassKey,
            kSecAttrApplicationTag as String: Self.tagData
        ]
        CorpTokenConstants.applyAccessGroup(to: &query)

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    // MARK: Existence Check

    /// Returns true if the SE private key exists in the keychain.
    /// Does NOT guarantee usability — Touch ID or passcode auth required at signing time.
    public func hasKeyPair() -> Bool {
        (try? retrievePrivateKey()) != nil
    }
}
