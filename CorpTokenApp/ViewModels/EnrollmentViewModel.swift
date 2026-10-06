// CorpTokenApp/ViewModels/EnrollmentViewModel.swift
//
// Drives the enrollment flow:
//   1. Generate SE key pair
//   2. OAuth2 device flow → access token
//   3. POST public key to enrollment backend → enrollment ID
//   4. Poll until CA issues certificate → DER cert
//   5. Store certificate in shared keychain
//   6. Update enrollment state in shared UserDefaults

import Foundation
import Combine
import os.log
import Shared

private let log = Logger(subsystem: CorpTokenConstants.appBundleID, category: "EnrollmentViewModel")

@MainActor
final class EnrollmentViewModel: ObservableObject {

    // MARK: Published State

    @Published var enrollmentState: EnrollmentState = .notEnrolled
    @Published var isLoading        = false
    @Published var errorMessage:   String? = nil
    @Published var subjectSummary: String? = nil
    @Published var expiryDate:     Date?   = nil

    /// Pre-computed expiry countdown so views don't run Calendar math in body.
    @Published var daysUntilExpiry: Int? = nil

    /// True if this Mac has Secure Enclave hardware. Cached at init to avoid
    /// repeated API calls from SwiftUI body.
    @Published var seAvailable: Bool = false

    // OAuth browser-auth step
    @Published var pendingAuthURL:  URL?    = nil
    @Published var pendingUserCode: String? = nil

    // Certificate poll progress
    @Published var pollAttempt:    Int = 0
    @Published var maxPollAttempts: Int = 0

    // MARK: Init

    init() {
        refreshState()
    }

    // MARK: Enrollment

    func enroll(employeeID: String) async {
        guard !isLoading else { return }
        errorMessage    = nil
        pendingAuthURL  = nil
        pendingUserCode = nil
        pollAttempt     = 0
        isLoading       = true

        do {
            log.info("Generating SE key pair")
            try SecureEnclaveManager.shared.generateKeyPair()

            let publicKeyData = try CertificateParser.publicKeyDataForEnrollment()

            log.info("Starting backend enrollment")
            let certDER = try await EnrollmentAPI.requestCertificate(
                employeeID: employeeID,
                publicKeyData: publicKeyData
            ) { [weak self] progress in
                guard let self else { return }
                switch progress {
                case .awaitingBrowserAuth(let url, let code):
                    self.pendingAuthURL  = url
                    self.pendingUserCode = code
                case .submittingRequest:
                    self.pendingAuthURL  = nil
                    self.pendingUserCode = nil
                case .waitingForCertificate(let attempt, let max):
                    self.pollAttempt     = attempt
                    self.maxPollAttempts = max
                }
            }

            try CredentialStore.shared.storeCertificate(certDER)
            persistState(.enrolled)
            refreshState()
            log.info("Enrollment complete")

        } catch {
            log.error("Enrollment failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            try? SecureEnclaveManager.shared.deleteKeyPair()
            try? CredentialStore.shared.removeCertificate()
            persistState(.notEnrolled)
        }

        pendingAuthURL  = nil
        pendingUserCode = nil
        pollAttempt     = 0
        isLoading       = false
    }

    // MARK: Debug Mock Enrollment

#if DEBUG
    /// Stores the bundled test certificate — no backend, no waiting.
    /// Touch ID is still required because a real SE key is generated first.
    func debugEnroll() async {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading    = true
        do {
            try DebugEnrollment.enroll()
            persistState(.enrolled)
            enrollmentState = .enrolled
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
#endif

    // MARK: Unenrollment

    func unenroll() {
        do {
            try SecureEnclaveManager.shared.deleteKeyPair()
            try CredentialStore.shared.removeCertificate()
            persistState(.notEnrolled)
            refreshState()
            log.info("Unenrollment complete")
        } catch {
            log.error("Unenrollment error: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: State Refresh

    /// Recomputes enrollment state from current keychain contents.
    ///
    /// Note: the `.revoked` state is never set by this method — it must be written
    /// externally, e.g. via an MDM command or a background revocation-check service
    /// writing `.revoked` to the shared UserDefaults enrollment state key.
    func refreshState() {
        let hasKey  = SecureEnclaveManager.shared.hasKeyPair()
        let hasCert = CredentialStore.shared.hasCertificate()

        seAvailable = SecureEnclaveManager.shared.isAvailable

        switch (hasKey, hasCert) {
        case (false, false):
            enrollmentState = .notEnrolled

        case (true, false):
            enrollmentState = .pendingCert

        case (false, true):
            // Certificate exists but SE key is gone (e.g. biometry change invalidated it).
            // The token extension will show an empty token despite the cert being present.
            // Treat as not enrolled so the UI prompts re-enrollment.
            enrollmentState = .notEnrolled
            log.warning("Certificate present but SE key missing — re-enrollment required")

        case (true, true):
            enrollmentState = (CredentialStore.shared.expiryDate() ?? .distantFuture) < Date()
                ? .expired
                : .enrolled
        }

        subjectSummary = CredentialStore.shared.subjectSummary()
        expiryDate     = CredentialStore.shared.expiryDate()
        daysUntilExpiry = expiryDate.flatMap {
            Calendar.current.dateComponents([.day], from: Date(), to: $0).day
        }
    }

    // MARK: Private

    private func persistState(_ state: EnrollmentState) {
        let defaults = UserDefaults(suiteName: CorpTokenConstants.appGroupID)
        defaults?.set(state.rawValue, forKey: CorpTokenConstants.enrollmentStateKey)
        if state == .enrolled {
            defaults?.set(Date(), forKey: CorpTokenConstants.enrollmentDateKey)
        }
        // employeeID is NOT persisted to UserDefaults — it is PII and the shared
        // app group container is a plain plist readable by any same-user process.
    }
}
