// Shared/CredentialStore.swift
// Compile into both the container app target and the token extension target.
//
// Manages the employee X.509 certificate in the shared keychain access group.
// The token extension reads the certificate from here to populate TKTokenKeychainContents.
//
// Identity formation: the system automatically links the certificate to the SE private key
// when both share the same access group AND the certificate's public key matches the SE key.
// Ensure the CSR sent to your CA was built from SecureEnclaveManager.publicKeyData().

import Foundation
import Security

// MARK: - Error

public enum CredentialStoreError: LocalizedError {
    case certificateNotFound
    case certificateDecodeFailed
    case certificateStoreFailed(OSStatus)
    case identityNotFound

    public var errorDescription: String? {
        switch self {
        case .certificateNotFound:
            return "Employee certificate not found — enrollment may be incomplete"
        case .certificateDecodeFailed:
            return "Certificate data is not valid DER-encoded X.509"
        case .certificateStoreFailed(let status):
            return "Keychain write failed (OSStatus \(status))"
        case .identityNotFound:
            return "No identity (cert + private key) found — key and cert must share the same public key"
        }
    }
}

// MARK: - Store

public final class CredentialStore {

    public static let shared = CredentialStore()
    private init() {}

    // Opened once at init; same suite for the lifetime of the process.
    private let sharedDefaults = UserDefaults(suiteName: CorpTokenConstants.appGroupID)

    // MARK: Certificate — Write

    /// Stores a DER-encoded certificate in the shared keychain.
    ///
    /// Call after receiving the signed certificate from your CA. The system will
    /// automatically form a SecIdentity by linking this cert to the SE private key
    /// that shares its public key in the same access group.
    public func storeCertificate(_ derData: Data) throws {
        guard let certificate = SecCertificateCreateWithData(nil, derData as CFData) else {
            throw CredentialStoreError.certificateDecodeFailed
        }

        try? removeCertificate()

        var query: [String: Any] = [
            kSecClass as String:    kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: CorpTokenConstants.certificateLabel
        ]
        CorpTokenConstants.applyAccessGroup(to: &query)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw CredentialStoreError.certificateStoreFailed(status)
        }

        if let expiry = expiryDate(from: certificate) {
            sharedDefaults?.set(expiry, forKey: CorpTokenConstants.certExpiryKey)
        }
    }

    // MARK: Certificate — Read

    public func retrieveCertificate() throws -> SecCertificate {
        var query: [String: Any] = [
            kSecClass as String:      kSecClassCertificate,
            kSecAttrLabel as String:  CorpTokenConstants.certificateLabel,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnRef as String:  true
        ]
        CorpTokenConstants.applyAccessGroup(to: &query)

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let ref = item,
              CFGetTypeID(ref) == SecCertificateGetTypeID() else {
            throw CredentialStoreError.certificateNotFound
        }

        return ref as! SecCertificate
    }

    /// Returns raw DER bytes. TKTokenKeychainCertificate requires this format.
    public func retrieveCertificateData() throws -> Data {
        SecCertificateCopyData(try retrieveCertificate()) as Data
    }

    // MARK: Identity — Read

    /// Returns the SecIdentity (cert + private key pair) from the keychain.
    public func retrieveIdentity() throws -> SecIdentity {
        var query: [String: Any] = [
            kSecClass as String:      kSecClassIdentity,
            kSecAttrLabel as String:  CorpTokenConstants.certificateLabel,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnRef as String:  true
        ]
        CorpTokenConstants.applyAccessGroup(to: &query)

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let ref = item,
              CFGetTypeID(ref) == SecIdentityGetTypeID() else {
            throw CredentialStoreError.identityNotFound
        }

        return ref as! SecIdentity
    }

    // MARK: Certificate — Delete

    /// Removes the employee certificate from the shared keychain.
    /// Silently succeeds if no certificate is present (idempotent).
    /// Also clears the cached expiry date from shared UserDefaults.
    public func removeCertificate() throws {
        var query: [String: Any] = [
            kSecClass as String:    kSecClassCertificate,
            kSecAttrLabel as String: CorpTokenConstants.certificateLabel
        ]
        CorpTokenConstants.applyAccessGroup(to: &query)
        SecItemDelete(query as CFDictionary)
        sharedDefaults?.removeObject(forKey: CorpTokenConstants.certExpiryKey)
    }

    // MARK: Convenience

    public func hasCertificate() -> Bool {
        (try? retrieveCertificate()) != nil
    }

    public func subjectSummary() -> String? {
        guard let cert = try? retrieveCertificate() else { return nil }
        return SecCertificateCopySubjectSummary(cert) as String?
    }

    public func expiryDate() -> Date? {
        guard let cert = try? retrieveCertificate() else { return nil }
        return expiryDate(from: cert)
    }

    // MARK: Private

    private func expiryDate(from cert: SecCertificate) -> Date? {
        guard let values = SecCertificateCopyValues(
            cert,
            [kSecOIDX509V1ValidityNotAfter] as CFArray,
            nil
        ) as? [String: Any],
        let entry = values[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
        let date  = entry[kSecPropertyKeyValue as String] as? Date
        else { return nil }
        return date
    }
}
