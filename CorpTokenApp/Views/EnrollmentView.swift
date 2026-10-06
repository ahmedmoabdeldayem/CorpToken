// CorpTokenApp/Views/EnrollmentView.swift
// Step-by-step enrollment wizard: employee enters their ID, the app generates
// the SE key and calls the enrollment backend.

import AppKit
import SwiftUI

struct EnrollmentView: View {

    @ObservedObject var vm: EnrollmentViewModel
    @State private var employeeID = ""
    @FocusState private var idFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 52))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                Text("Enroll Your Employee Token")
                    .font(.title2.bold())

                Text("Your private key will be generated in the Secure Enclave\nand never leave this device.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .padding(.vertical, 32)

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 16) {
                Text("Employee ID")
                    .font(.headline)

                TextField("e.g. jdoe or jdoe@corp.example.com", text: $employeeID)
                    .textFieldStyle(.roundedBorder)
                    .focused($idFieldFocused)
                    .onSubmit { startEnrollment() }
                    .disabled(vm.isLoading)

                // Requirements checklist
                VStack(alignment: .leading, spacing: 6) {
                    RequirementRow(
                        label: "Secure Enclave available",
                        met: vm.seAvailable
                    )
                    RequirementRow(
                        label: "Employee ID entered",
                        met: !employeeID.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)

            // Error banner
            if let error = vm.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(12)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 32)
            }

            Spacer()

            Divider()

            // OAuth browser-auth step
            if let url = vm.pendingAuthURL, let code = vm.pendingUserCode {
                BrowserAuthBannerView(url: url, userCode: code)
                    .padding(.horizontal, 32)
            }

            // Certificate poll progress
            if vm.isLoading && vm.pollAttempt > 0 {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for certificate (\(vm.pollAttempt)/\(vm.maxPollAttempts))…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            Divider()

            // Action
            HStack {
                Spacer()
                if vm.isLoading && vm.pendingAuthURL == nil && vm.pollAttempt == 0 {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Generating key…")
                            .foregroundStyle(.secondary)
                    }
                } else if !vm.isLoading {
                    Button("Enroll with Touch ID", action: startEnrollment)
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            employeeID.trimmingCharacters(in: .whitespaces).isEmpty ||
                            !vm.seAvailable
                        )
                        .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(20)
        }
        .onAppear { idFieldFocused = true }
    }

    private func startEnrollment() {
        let id = employeeID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }
        Task { await vm.enroll(employeeID: id) }
    }
}

// MARK: - Debug Banner (Debug builds only)

#if DEBUG
struct DebugEnrollmentBanner: View {
    @ObservedObject var vm: EnrollmentViewModel

    var body: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "ant.fill").foregroundStyle(.orange)
                Text("DEBUG BUILD").font(.caption.bold()).foregroundStyle(.orange)
            }
            Text("Skip the backend and use a pre-baked test certificate.\nNo Secure Enclave or Touch ID required.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                Task { await vm.debugEnroll() }
            } label: {
                Label("Use Test Certificate", systemImage: "checkmark.seal.fill")
                    .font(.callout.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(vm.isLoading)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .background(.orange.opacity(0.05))
    }
}
#endif

// MARK: - Browser Auth Banner

private struct BrowserAuthBannerView: View {
    let url: URL
    let userCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Browser Login Required", systemImage: "safari")
                .font(.headline)

            Text("A browser window has been opened. Log in with your corporate SSO, then enter the code below.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Text(userCode)
                    .font(.system(.title2, design: .monospaced).bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Button("Open Browser Again") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.link)
            }
        }
        .padding(14)
        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.blue.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Requirement Row

private struct RequirementRow: View {
    let label: String
    let met: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : .secondary)
            Text(label)
        }
    }
}
