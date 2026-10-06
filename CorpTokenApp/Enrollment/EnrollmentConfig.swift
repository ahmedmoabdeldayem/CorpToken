// CorpTokenApp/Enrollment/EnrollmentConfig.swift
//
// Runtime configuration for the enrollment backend.
//
// Values are read from three sources in priority order (highest first):
//   1. MDM-managed preferences (com.apple.ManagedClient.preferences domain)
//   2. App group UserDefaults  (written by an IT admin tool or first-run setup)
//   3. Compiled-in defaults    (the constants below)
//
// ─────────────────────────────────────────────────────────────────
//  MDM KEY REFERENCE
//  Push a Custom Settings profile with PayloadDomain =
//  "com.yourcompany.CorpToken" and any of these keys:
//
//  Key                        Type      Default
//  ──────────────────────────────────────────────────────
//  EnrollmentBaseURL          String    https://enroll.corp.yourcompany.com
//  EnrollmentOAuthClientID    String    corptoken-macos
//  EnrollmentOAuthScope       String    enrollment:write
//  EnrollmentRequestTimeout   Number    30  (seconds per request)
//  EnrollmentPollInterval     Number    4   (seconds between cert polls)
//  EnrollmentMaxPollAttempts  Number    30  (≈ 2 min total poll window)
//
//  IMPORTANT: EnrollmentBaseURL MUST be an https:// URL.
//  If an invalid or non-https URL is delivered, the compiled-in default is used
//  and a critical log entry is written.
// ─────────────────────────────────────────────────────────────────

import Foundation
import os.log
import Shared

private let configLog = Logger(
    subsystem: CorpTokenConstants.appBundleID,
    category: "EnrollmentConfig"
)

struct EnrollmentConfig {

    // MARK: - Fields

    let baseURL:         URL
    let oauthClientID:   String
    let oauthScope:      String
    let requestTimeout:  TimeInterval
    let pollInterval:    TimeInterval
    let maxPollAttempts: Int

    // MARK: - Compiled-in defaults (also used as fallback when MDM delivers bad values)

    private static let defaultBaseURL     = "https://enroll.corp.yourcompany.com"
    private static let defaultClientID    = "corptoken-macos"
    private static let defaultScope       = "enrollment:write"
    private static let defaultTimeout     = 30.0
    private static let defaultInterval    = 4.0
    private static let defaultMaxAttempts = 30

    // MARK: - Shared Instance

    static let shared: EnrollmentConfig = {
        let managed  = UserDefaults(suiteName: "com.apple.ManagedClient.preferences")
        let appGroup = UserDefaults(suiteName: CorpTokenConstants.appGroupID)

        func string(_ key: String, fallback: String) -> String {
            managed?.string(forKey: key)
                ?? appGroup?.string(forKey: key)
                ?? fallback
        }

        func double(_ key: String, fallback: Double) -> Double {
            if let v = managed?.object(forKey: key) as? Double  { return v }
            if let v = appGroup?.object(forKey: key) as? Double { return v }
            return fallback
        }

        // Uses object(forKey:) instead of integer(forKey:) so that a legitimately
        // configured value of 0 is distinguishable from a missing key (integer(forKey:)
        // returns 0 for both cases, making them indistinguishable).
        func int(_ key: String, fallback: Int) -> Int {
            if let v = managed?.object(forKey: key) as? Int  { return v }
            if let v = appGroup?.object(forKey: key) as? Int { return v }
            return fallback
        }

        let rawURL       = string("EnrollmentBaseURL",         fallback: defaultBaseURL)
        let clientID     = string("EnrollmentOAuthClientID",   fallback: defaultClientID)
        let scope        = string("EnrollmentOAuthScope",       fallback: defaultScope)
        let timeout      = double("EnrollmentRequestTimeout",   fallback: defaultTimeout)
        let interval     = double("EnrollmentPollInterval",     fallback: defaultInterval)
        let maxAttempts  = max(1, int("EnrollmentMaxPollAttempts", fallback: defaultMaxAttempts))

        // Validate URL and enforce HTTPS. Gracefully fall back rather than crashing
        // so that a bad MDM push doesn't permanently break the app on every launch.
        let resolvedURL: URL
        if let url = URL(string: rawURL), url.scheme == "https" {
            resolvedURL = url
        } else {
            configLog.critical(
                "EnrollmentBaseURL '\(rawURL, privacy: .public)' is invalid or not HTTPS — using compiled-in default"
            )
            // Force-unwrap is safe: the literal is a valid https URL in source code.
            resolvedURL = URL(string: defaultBaseURL)!
        }

        return EnrollmentConfig(
            baseURL:         resolvedURL,
            oauthClientID:   clientID,
            oauthScope:      scope,
            requestTimeout:  timeout,
            pollInterval:    interval,
            maxPollAttempts: maxAttempts
        )
    }()
}
