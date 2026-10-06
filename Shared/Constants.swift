// Shared/Constants.swift
// Compile into both the container app target and the token extension target.
// Replace every "com.yourcompany" with your real reverse-DNS bundle ID prefix.

import Foundation

public enum CorpTokenConstants {

    // MARK: - Bundle IDs

    /// Container app — matches the Xcode target's bundle identifier
    public static let appBundleID = "com.yourcompany.CorpToken"

    /// Token extension — must be a child of appBundleID
    public static let extensionBundleID = "com.yourcompany.CorpToken.TokenExtension"

    // MARK: - Keychain

    /// Shared keychain access group for the app + extension.
    ///
    /// IMPORTANT: `$(AppIdentifierPrefix)` is expanded by Xcode in .entitlements files
    /// at build time, but is NOT expanded in Swift source code — this string is used
    /// as-is in keychain API calls at runtime. Before shipping, replace the prefix with
    /// your actual Team ID (find it at developer.apple.com → Membership):
    ///   e.g.  "A1B2C3D4E5.com.yourcompany.CorpToken.shared"
    ///
    /// A debug-build assertion below will fire immediately if the placeholder is present,
    /// so misconfiguration is caught during development rather than silently at runtime.
    public static let keychainAccessGroup: String = {
        let group = "$(AppIdentifierPrefix)com.yourcompany.CorpToken.shared"
        // precondition (not assert) survives -O Release builds; only -Ounchecked skips it.
        precondition(
            !group.hasPrefix("$(AppIdentifierPrefix)"),
            "Replace '$(AppIdentifierPrefix)' with your Team ID in Constants.swift"
        )
        return group
    }()

    /// Application tag that identifies the SE private key in the keychain.
    public static let privateKeyTag = "com.yourcompany.CorpToken.employee.privatekey"

    /// Human-readable label on the certificate keychain item.
    public static let certificateLabel = "CorpToken Employee Certificate"

    // MARK: - Token Configuration

    /// Must match the com.apple.ctk.class-id value in the extension's Info.plist.
    public static let tokenClassID = "com.yourcompany.CorpToken.token"

    /// Instance ID passed to TKToken.init — use one per macOS user account.
    public static let tokenInstanceID = "employee"

    /// Opaque object ID linking the key item to the certificate item inside a token session.
    public static let keyObjectID = "employee-signing-key"

    // MARK: - App Group

    /// Shared UserDefaults/file container between the app and extension.
    /// Add this to both targets' entitlements and to your App Group in the Developer Portal.
    public static let appGroupID = "group.com.yourcompany.CorpToken"

    // MARK: - Debug Helpers

    /// Adds the keychain access group to a query dictionary only in Release builds.
    /// In DEBUG builds the key is omitted so the app uses its per-app default keychain —
    /// works with any personal Apple ID and no Keychain Sharing capability needed.
    public static func applyAccessGroup(to query: inout [String: Any]) {
        #if !DEBUG
        query[kSecAttrAccessGroup as String] = keychainAccessGroup
        #endif
    }

    // MARK: - UserDefaults Keys

    public static let enrollmentStateKey = "enrollmentState"
    /// Date the employee last completed enrollment. Written by the app on success.
    /// Not read by the app UI — available for MDM compliance scripts or analytics
    /// tools that inspect the shared app group container.
    public static let enrollmentDateKey  = "enrollmentDate"
    public static let certExpiryKey      = "certExpiry"
}

// MARK: - Enrollment State

/// Persisted in the shared UserDefaults (app group) so both processes can read it.
public enum EnrollmentState: String, Codable {
    case notEnrolled  // No key or cert — prompt user to enroll
    case pendingCert  // SE key generated, waiting for CA to issue the cert
    case enrolled     // Key + cert present, token is active
    case expired      // Certificate validity period has passed
    case revoked      // Certificate was revoked by the CA
}
