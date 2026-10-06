// swift-tools-version: 5.9
//
// Package.swift — for `swift build` / `swift test` without an Xcode project.
//
// Production targets (Xcode):
//   • Container app target    — compiles Shared/ + CorpTokenApp/ into one module
//   • Token extension target  — compiles Shared/ + CorpTokenExtension/ into one module
//
// SPM targets (testing only):
//   • Shared             — the four shared utility files
//   • CorpTokenApp       — enrollment logic (excludes the @main SwiftUI entry point)
//   • CorpTokenExtension — token driver/session files
//   • Test targets matching @testable import names used in each test file

import PackageDescription

let package = Package(
    name: "CorpToken",
    platforms: [.macOS(.v13)],

    targets: [

        // ── Shared utilities ───────────────────────────────────────────────
        .target(
            name: "Shared",
            path: "Shared"
        ),

        // ── Container app (enrollment logic + UI) ─────────────────────────
        // CorpTokenApp.swift is excluded because @main cannot appear in a
        // library target; the rest of the app code is fully testable.
        .target(
            name: "CorpTokenApp",
            dependencies: ["Shared"],
            path: "CorpTokenApp",
            exclude: ["App/CorpTokenApp.swift"],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        ),

        // ── Token extension ────────────────────────────────────────────────
        .target(
            name: "CorpTokenExtension",
            dependencies: ["Shared"],
            path: "CorpTokenExtension",
            exclude: ["Info.plist"],
            swiftSettings: [
                .define("SWIFT_PACKAGE")
            ]
        ),

        // ── Test targets ───────────────────────────────────────────────────
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"],
            path: "Tests/SharedTests"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["CorpTokenApp", "Shared"],
            path: "Tests/AppTests"
        ),
        .testTarget(
            name: "ExtensionTests",
            dependencies: ["CorpTokenExtension", "Shared"],
            path: "Tests/ExtensionTests"
        ),
    ]
)
