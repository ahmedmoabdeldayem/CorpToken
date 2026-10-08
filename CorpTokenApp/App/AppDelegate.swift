// CorpTokenApp/App/AppDelegate.swift
//
// Handles app lifecycle events and certificate expiry reminders.
// Token extensions are App Extensions (not System Extensions), so no explicit
// installation step is required — the extension activates automatically when
// the app is first run and the container app is present.

import AppKit
import UserNotifications
import os.log
import Shared

private let log = Logger(subsystem: CorpTokenConstants.appBundleID, category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestNotificationPermission()
        scheduleExpiryCheckIfNeeded()
        log.info("CorpToken app launched")
    }

    // Don't quit when the main window is closed — menu bar extra stays active
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Certificate Expiry Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Posts a local notification if the employee's certificate expires within 14 days.
    ///
    /// This fires on every app launch while within the 14-day window. The static
    /// identifier "corptoken.expiry" deduplicates pending notifications but NOT
    /// already-delivered ones, so we explicitly remove delivered notifications first
    /// to avoid repeat banners on multiple launches in the same day.
    private func scheduleExpiryCheckIfNeeded() {
        guard let expiry = CredentialStore.shared.expiryDate() else { return }

        let rawDays = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        let daysUntilExpiry = max(0, rawDays)

        guard rawDays <= 14 else { return }

        let center = UNUserNotificationCenter.current()

        // Remove any previously delivered or pending notification with this ID
        // so we don't accumulate duplicate banners across multiple launches.
        center.removeDeliveredNotifications(withIdentifiers: ["corptoken.expiry"])
        center.removePendingNotificationRequests(withIdentifiers: ["corptoken.expiry"])

        let content   = UNMutableNotificationContent()
        content.title = "CorpToken Certificate Expiring"
        content.body  = daysUntilExpiry <= 0
            ? "Your employee certificate has expired. Open CorpToken to re-enroll."
            : "Your employee certificate expires in \(daysUntilExpiry) day(s). Open CorpToken to renew."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "corptoken.expiry",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error { log.error("Notification error: \(error.localizedDescription, privacy: .public)") }
        }
    }
}
