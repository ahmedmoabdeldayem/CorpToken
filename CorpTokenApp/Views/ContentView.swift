// CorpTokenApp/Views/ContentView.swift
// Root view — routes to EnrollmentView or TokenStatusView based on enrollment state.

import SwiftUI

struct ContentView: View {

    @StateObject private var vm = EnrollmentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch vm.enrollmentState {
                case .notEnrolled:
                    EnrollmentView(vm: vm)
                case .pendingCert:
                    PendingCertView(vm: vm)
                case .enrolled:
                    TokenStatusView(vm: vm)
                case .expired, .revoked:
                    ExpiredView(vm: vm)
                }
            }
            #if DEBUG
            if vm.enrollmentState == .notEnrolled {
                DebugEnrollmentBanner(vm: vm)
            }
            #endif
        }
        .onAppear { vm.refreshState() }
    }
}

// MARK: - Pending View

struct PendingCertView: View {
    @ObservedObject var vm: EnrollmentViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("Waiting for Certificate")
                .font(.title2.bold())

            Text("Your enrollment request has been submitted.\nOnce your IT team approves it, re-open this app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Check Again") { vm.refreshState() }
                .buttonStyle(.borderedProminent)

            Button("Cancel Enrollment", role: .destructive) { vm.unenroll() }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Expired / Revoked View

struct ExpiredView: View {
    @ObservedObject var vm: EnrollmentViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            Text(vm.enrollmentState == .expired ? "Certificate Expired" : "Certificate Revoked")
                .font(.title2.bold())

            Text("Your employee token is no longer valid.\nContact IT support to re-enroll.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Re-Enroll") { vm.unenroll() }
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Menu Bar Extra

struct MenuBarView: View {
    @StateObject private var vm = EnrollmentViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(statusText, systemImage: statusIcon)
                .font(.callout)
            if let subject = vm.subjectSummary {
                Text(subject)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            Button("Open CorpToken") { NSApp.activate(ignoringOtherApps: true) }
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(8)
        .onAppear { vm.refreshState() }
    }

    private var statusText: String {
        switch vm.enrollmentState {
        case .enrolled:    return "Token Active"
        case .pendingCert: return "Enrollment Pending"
        case .expired:     return "Certificate Expired"
        case .revoked:     return "Certificate Revoked"
        case .notEnrolled: return "Not Enrolled"
        }
    }

    private var statusIcon: String {
        switch vm.enrollmentState {
        case .enrolled:    return "checkmark.shield.fill"
        case .pendingCert: return "clock.badge"
        case .expired, .revoked: return "xmark.shield.fill"
        case .notEnrolled: return "person.badge.plus"
        }
    }
}
