// CorpTokenApp/Views/TokenStatusView.swift
// Shown when the employee is fully enrolled. Displays cert details and
// provides an unenroll action.

import SwiftUI

struct TokenStatusView: View {

    @ObservedObject var vm: EnrollmentViewModel
    @State private var showingUnenrollConfirm = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            HStack(spacing: 14) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Token Active")
                        .font(.title3.bold())
                    if let subject = vm.subjectSummary {
                        Text(subject)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(.green.opacity(0.06))

            Divider()

            // Details
            List {
                Section("Certificate") {
                    if let subject = vm.subjectSummary {
                        DetailRow(label: "Subject", value: subject)
                    }

                    if let expiry = vm.expiryDate {
                        // daysUntilExpiry is pre-computed in the ViewModel (not in body)
                        let daysLeft = vm.daysUntilExpiry ?? 0
                        DetailRow(
                            label: "Expires",
                            value: Self.dateFormatter.string(from: expiry),
                            badge: daysLeft <= 30 ? "\(daysLeft) days left" : nil,
                            badgeColor: daysLeft <= 14 ? .red : .orange
                        )
                    }
                }

                Section("Capabilities") {
                    CapabilityRow(icon: "globe", label: "TLS Client Authentication", active: true)
                    CapabilityRow(icon: "macwindow.badge.plus", label: "macOS Login / Screen Lock", active: true)
                    CapabilityRow(icon: "lock.shield", label: "Touch ID Protected", active: true)
                }

                Section {
                    Button(role: .destructive) {
                        showingUnenrollConfirm = true
                    } label: {
                        Label("Remove This Device's Token", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .listStyle(.inset)
        }
        .confirmationDialog(
            "Remove Employee Token?",
            isPresented: $showingUnenrollConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { vm.unenroll() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The private key and certificate will be deleted from this Mac. You will need to re-enroll to use the token again.")
        }
    }
}

// MARK: - Supporting Views

private struct DetailRow: View {
    let label: String
    let value: String
    var badge: String? = nil
    var badgeColor: Color = .orange

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
            if let badge {
                Text(badge)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(badgeColor)
            }
        }
    }
}

private struct CapabilityRow: View {
    let icon: String
    let label: String
    let active: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(active ? .blue : .secondary)
                .frame(width: 20)
            Text(label)
            Spacer()
            Image(systemName: active ? "checkmark" : "minus")
                .foregroundStyle(active ? .green : .secondary)
        }
    }
}
