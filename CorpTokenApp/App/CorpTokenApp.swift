// CorpTokenApp/App/CorpTokenApp.swift
//
// Entry point for the container app.
//
// The container app has two roles:
//   1. Enrollment UI — guides the employee through SE key generation and
//      certificate delivery (MDM SCEP or manual CSR submission).
//   2. Token status — lets the employee see their cert expiry and unenroll.
//
// The token extension runs independently in a separate process managed by
// the CryptoTokenKit daemon. The app does not need to stay running.

import SwiftUI

@main
struct CorpTokenApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main window — shown when the user opens the app
        WindowGroup {
            ContentView()
                .frame(minWidth: 520, idealWidth: 520, maxWidth: 700,
                       minHeight: 420, idealHeight: 420, maxHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove File → New (single-window app)
            CommandGroup(replacing: .newItem) { }
        }

        // Menu bar extra — optional, remove if you prefer dock-only
        MenuBarExtra("CorpToken", systemImage: "person.badge.key") {
            MenuBarView()
        }
    }
}
