// Shared/CertificateParser.swift
// Compile into both targets.
//
// Utilities for PEM ↔ DER conversion, certificate inspection, and
// preparing public key data for CSR generation.
//
// Full PKCS#10 CSR generation (ASN.1 encoding) requires an external package.
// The recommended option is Apple's swift-certificates:
//   https://github.com/apple/swift-certificates
// Add it to your Package.swift or via Xcode → Add Package Dependencies.

import Foundation
import Security

// MARK: - Error

public enum CertificateParserError: LocalizedError {
    case invalidPEM(String)
    case invalidDER

    public var errorDescription: String? {
        switch self {
        case .invalidPEM(let detail): return "Invalid PEM: \(detail)"
        case .invalidDER:             return "Data is not valid DER-encoded X.509"
        }
    }
}

// MARK: - Parser

public enum CertificateParser {

    // MARK: Format Conversion

    /// Strips PEM armor and base64-decodes to DER bytes.
    public static func derFromPEM(_ pem: String) throws -> Data {
        let stripped = pem
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
            .joined()

        guard !stripped.isEmpty else {
            throw CertificateParserError.invalidPEM("no base64 content found")
        }
        guard let der = Data(base64Encoded: stripped, options: .ignoreUnknownCharacters) else {
            throw CertificateParserError.invalidPEM("base64 decoding failed")
        }
        return der
    }

    /// Wraps DER bytes in PEM armor (64-char line length per RFC 7468).
    public static func pemFromDER(_ der: Data) -> String {
        let body = der.base64EncodedString(options: .lineLength64Characters)
        return "-----BEGIN CERTIFICATE-----\n\(body)\n-----END CERTIFICATE-----\n"
    }

    // MARK: Certificate Inspection

    /// Human-readable CN or OU from the Subject field.
    public static func subjectSummary(from cert: SecCertificate) -> String {
        SecCertificateCopySubjectSummary(cert) as String? ?? "Unknown"
    }

    /// Returns true if now falls within [notBefore, notAfter].
    public static func isValid(_ cert: SecCertificate) -> Bool {
        guard let values = SecCertificateCopyValues(
            cert,
            [kSecOIDX509V1ValidityNotBefore, kSecOIDX509V1ValidityNotAfter] as CFArray,
            nil
        ) as? [String: Any] else { return false }

        let now = Date()

        if let entry = values[kSecOIDX509V1ValidityNotBefore as String] as? [String: Any],
           let notBefore = entry[kSecPropertyKeyValue as String] as? Date,
           notBefore > now { return false }

        if let entry = values[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
           let notAfter = entry[kSecPropertyKeyValue as String] as? Date,
           notAfter < now { return false }

        return true
    }

    /// Returns the Not After date, or nil if the certificate values can't be read.
    public static func expiryDate(from cert: SecCertificate) -> Date? {
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

    // MARK: CSR Preparation

    /// Returns the X9.63-encoded public key bytes from the Secure Enclave key.
    ///
    /// Send these bytes (along with employeeID and commonName) to your enrollment
    /// backend. The backend constructs the PKCS#10 CSR, signs it, forwards it to
    /// your CA, and returns the issued DER certificate.
    ///
    /// If you want on-device CSR generation, add the `swift-certificates` package
    /// and implement a `CertificateSigningRequest` using the SE key for the signature.
    public static func publicKeyDataForEnrollment() throws -> Data {
        try SecureEnclaveManager.shared.publicKeyData()
    }
}
