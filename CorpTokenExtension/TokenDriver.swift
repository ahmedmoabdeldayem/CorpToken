// CorpTokenExtension/TokenDriver.swift
//
// Principal class of the CryptoTokenKit app extension.
// Set NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).CorpTokenDriver in Info.plist.
//
// The CryptoTokenKit daemon (com.apple.CryptoTokenKit.ahp) launches this extension
// process on demand — when any client (Safari, SSH, macOS login) requests a token.
// The container app does NOT need to be running for the extension to work.

import CryptoTokenKit
import Foundation
import os
import Shared

private let log = Logger(subsystem: CorpTokenConstants.extensionBundleID, category: "TokenDriver")

// MARK: - Driver

class CorpTokenDriver: TKTokenDriver, TKTokenDriverDelegate {

    override init() {
        super.init()
        self.delegate = self
        log.info("CorpTokenDriver initialized")
    }

    // MARK: TKTokenDriverDelegate

    /// Called by the system for each token configuration defined in Info.plist.
    /// For our single virtual token, this is called once with instanceID = "employee".
    ///
    /// Throwing here signals that the token is currently unavailable (e.g., SE broken).
    /// The system will retry when the next client requests the token.
    func tokenDriver(
        _ driver: TKTokenDriver,
        tokenFor configuration: TKToken.Configuration
    ) throws -> TKToken {
        log.info("Creating token for instanceID: \(configuration.instanceID, privacy: .public)")
        return CorpToken(tokenDriver: driver, instanceID: configuration.instanceID)
    }
}
