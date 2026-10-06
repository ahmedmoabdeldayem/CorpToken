// CorpTokenExtension/TokenSession.swift
//
// Handles cryptographic operations for a single client session.
//
// Touch ID / passcode is NOT prompted explicitly here — it is enforced by the
// Secure Enclave access control set during key generation. When SecKeyCreateSignature
// is called, the SE blocks until the user authenticates or cancels. The OS owns the
// biometric UI; the extension simply calls the Security framework API.

import CryptoTokenKit
import Security
import os
import Shared

private let log = Logger(subsystem: CorpTokenConstants.extensionBundleID, category: "TokenSession")

// MARK: - Errors

enum TokenSessionError: LocalizedError {
    case keyUnavailable
    case unsupportedAlgorithm(TKTokenKeyAlgorithm)
    case signingFailed(CFError)
    case keyExchangeFailed(CFError)
    case malformedPublicKey

    var errorDescription: String? {
        switch self {
        case .keyUnavailable:
            return "SE key unavailable — Touch ID may have changed; re-enrollment required"
        case .unsupportedAlgorithm(let alg):
            return "Unsupported algorithm '\(alg.algorithmDebugString)'. Only ECDSA P-256 X9.62 (DER) variants are supported."
        case .signingFailed(let e):
            return "Signing failed: \(e.localizedDescription)"
        case .keyExchangeFailed(let e):
            return "Key exchange failed: \(e.localizedDescription)"
        case .malformedPublicKey:
            return "Peer public key data could not be parsed"
        }
    }
}

// MARK: - Session

class CorpTokenSession: TKTokenSession, TKTokenSessionDelegate {

    override init(token: TKToken) {
        super.init(token: token)
        self.delegate = self
    }

    // MARK: Signing

    /// Signs data with the employee's SE P-256 private key.
    /// The SE will present a Touch ID / passcode prompt via the OS-owned UI.
    func tokenSession(
        _ session: TKTokenSession,
        sign dataToSign: Data,
        keyObjectID: TKToken.ObjectID,
        algorithm: TKTokenKeyAlgorithm
    ) throws -> Data {
        log.debug("Sign request received")

        let privateKey = try fetchPrivateKey()
        let secAlg     = try resolvedSigningAlgorithm(for: algorithm)

        var cfError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            secAlg,
            dataToSign as CFData,
            &cfError
        ) else {
            let err = cfError?.takeRetainedValue()
                ?? NSError(domain: NSOSStatusErrorDomain, code: -1) as CFError
            log.error("Signing failed: \(err.localizedDescription, privacy: .public)")
            throw TokenSessionError.signingFailed(err)
        }

        log.info("Signing succeeded")
        return signature as Data
    }

    // MARK: Key Exchange (ECDH for TLS)

    /// Derives a shared ECDH secret using the SE key and the server's ephemeral public key.
    /// Called during TLS handshake for ECDHE cipher suites.
    func tokenSession(
        _ session: TKTokenSession,
        performKeyExchange otherPartyPublicKeyData: Data,
        keyObjectID: TKToken.ObjectID,
        algorithm: TKTokenKeyAlgorithm,
        parameters: TKTokenKeyExchangeParameters
    ) throws -> Data {
        log.debug("Key exchange request received")

        let privateKey = try fetchPrivateKey()

        let pubKeyAttributes: [String: Any] = [
            kSecAttrKeyType as String:       kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String:      kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]
        var importError: Unmanaged<CFError>?
        guard let peerPublicKey = SecKeyCreateWithData(
            otherPartyPublicKeyData as CFData,
            pubKeyAttributes as CFDictionary,
            &importError
        ) else {
            log.error("Failed to parse peer public key")
            throw TokenSessionError.malformedPublicKey
        }

        var exchangeParams: [String: Any] = [:]
        if parameters.requestedSize > 0 {
            exchangeParams[SecKeyKeyExchangeParameter.requestedSize.rawValue as String]
                = parameters.requestedSize
        }

        var cfError: Unmanaged<CFError>?
        guard let sharedSecret = SecKeyCopyKeyExchangeResult(
            privateKey,
            .ecdhKeyExchangeStandard,
            peerPublicKey,
            exchangeParams as CFDictionary,
            &cfError
        ) else {
            let err = cfError?.takeRetainedValue()
                ?? NSError(domain: NSOSStatusErrorDomain, code: -1) as CFError
            log.error("Key exchange failed: \(err.localizedDescription, privacy: .public)")
            throw TokenSessionError.keyExchangeFailed(err)
        }

        log.info("Key exchange succeeded")
        return sharedSecret as Data
    }

    // MARK: Private Helpers

    private func fetchPrivateKey() throws -> SecKey {
        do {
            return try SecureEnclaveManager.shared.retrievePrivateKey()
        } catch {
            log.error("Key fetch failed: \(error.localizedDescription, privacy: .public)")
            throw TokenSessionError.keyUnavailable
        }
    }

    /// Maps TKTokenKeyAlgorithm identifiers to SecKeyAlgorithm constants.
    private func resolvedSigningAlgorithm(
        for algorithm: TKTokenKeyAlgorithm
    ) throws -> SecKeyAlgorithm {
        if algorithm.isAlgorithm(.ecdsaSignatureMessageX962SHA256) { return .ecdsaSignatureMessageX962SHA256 }
        if algorithm.isAlgorithm(.ecdsaSignatureMessageX962SHA384) { return .ecdsaSignatureMessageX962SHA384 }
        if algorithm.isAlgorithm(.ecdsaSignatureMessageX962SHA512) { return .ecdsaSignatureMessageX962SHA512 }
        if algorithm.isAlgorithm(.ecdsaSignatureDigestX962SHA256)  { return .ecdsaSignatureDigestX962SHA256  }
        if algorithm.isAlgorithm(.ecdsaSignatureDigestX962SHA384)  { return .ecdsaSignatureDigestX962SHA384  }
        if algorithm.isAlgorithm(.ecdsaSignatureDigestX962SHA512)  { return .ecdsaSignatureDigestX962SHA512  }
        throw TokenSessionError.unsupportedAlgorithm(algorithm)
    }
}

// MARK: - TKTokenKeyAlgorithm Logging

extension TKTokenKeyAlgorithm {
    // Private KVC introspection used for logging only — not a public API and may
    // return nil on future OS versions. Never use for algorithm dispatch.
    var algorithmDebugString: String {
        (value(forKeyPath: "algorithm") as? String) ?? "<unknown>"
    }
}
