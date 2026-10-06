// CorpTokenExtension/Token.swift
//
// Represents one employee's credential set exposed to the macOS keychain.
// Reads the certificate and SE key from the shared access group and populates
// TKTokenKeychainContents so the OS presents them to Safari, macOS login, VPN, etc.
//
// Object ID rules (CORRECT-1):
//   certObjectID — identifies the certificate item in the token
//   keyObjectID  — identifies the private key item; the key is LINKED to the cert
//                  via TKTokenKeychainKey(certificate:objectID:), not via a shared ID.
//   Using the same objectID for both crashes the CTK daemon with "duplicate objectID."

import CryptoTokenKit
import Foundation
import os
import Shared

private let log = Logger(subsystem: CorpTokenConstants.extensionBundleID, category: "Token")

// MARK: - Token

class CorpToken: TKToken, TKTokenDelegate {

    /// Identifies the private key item within the token session.
    /// Must match the objectID used in TokenSession signing/exchange calls.
    static let keyObjectID  = Data(CorpTokenConstants.keyObjectID.utf8)

    /// Identifies the certificate item. Distinct from keyObjectID — CTK requires
    /// unique objectIDs across all items in a single token instance.
    static let certObjectID = Data("employee-cert".utf8)

    override init(tokenDriver: TKTokenDriver, instanceID: String) {
        super.init(tokenDriver: tokenDriver, instanceID: instanceID)
        self.delegate = self
        populateKeychainContents()
    }

    // MARK: Keychain Population

    private func populateKeychainContents() {
        guard CredentialStore.shared.hasCertificate(),
              SecureEnclaveManager.shared.hasKeyPair() else {
            // Not enrolled yet — token is intentionally empty.
            // The extension process is relaunched by the CTK daemon after enrollment
            // completes and storeCertificate() is called in the container app.
            log.notice("Token created with empty contents — employee not enrolled or key missing")
            return
        }

        do {
            let certDER = try CredentialStore.shared.retrieveCertificateData()

            guard let secCert = SecCertificateCreateWithData(nil, certDER as CFData) else {
                log.error("Failed to create SecCertificate from stored DER data")
                return
            }

            guard let certItem = TKTokenKeychainCertificate(
                certificate: secCert,
                objectID: CorpToken.certObjectID   // cert gets its own unique ID
            ) else {
                log.error("Failed to create TKTokenKeychainCertificate")
                return
            }
            certItem.label = CorpTokenConstants.certificateLabel

            guard let keyItem = TKTokenKeychainKey(
                certificate: secCert,              // link key to cert via the SecCertificate
                objectID: CorpToken.keyObjectID    // key gets a distinct ID used in TokenSession
            ) else {
                log.error("Failed to create TKTokenKeychainKey")
                return
            }
            keyItem.label       = "Employee Signing Key"
            keyItem.canSign     = true
            keyItem.canDecrypt  = false
            // Enables ECDH key-exchange operations used in TLS ECDHE cipher suites
            // (handled by TokenSession.tokenSession(_:performKeyExchange:...))
            keyItem.canPerformKeyExchange = true
            // suitableForLogin covers both TLS client auth and macOS login/screen lock
            keyItem.isSuitableForLogin = true

            // Signals that user presence (Touch ID / passcode) is required before use.
            // The actual authentication is enforced by the SE access control at signing time.
            keyItem.constraints = [NSNumber(value: TKTokenOperation.signData.rawValue): NSNumber(value: true)]

            keychainContents?.fill(with: [certItem, keyItem])
            log.info("Token keychain populated: \(CredentialStore.shared.subjectSummary() ?? "unknown", privacy: .public)")

        } catch {
            log.error("Token keychain population failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: TKTokenDelegate

    /// Creates a session for the requested cryptographic operation.
    /// Touch ID / passcode is enforced by the SE access control inside the session,
    /// not here — this method returns a session unconditionally.
    func createSession(_ token: TKToken) throws -> TKTokenSession {
        log.debug("Creating session")
        return CorpTokenSession(token: self)
    }
}
