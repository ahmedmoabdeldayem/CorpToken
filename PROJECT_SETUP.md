# Xcode Project Setup

Step-by-step guide to create the Xcode project from the files in this repo.

---

## 1. Create the Project

1. Open Xcode → File → New → Project
2. Choose **macOS → App**
3. Set:
   - Product Name: `CorpToken`
   - Bundle Identifier: `com.yourcompany.CorpToken`
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: **macOS 14.0**
4. Save to this folder (replace the generated source files with the ones in `CorpTokenApp/`)

---

## 2. Add the Token Extension Target

1. File → New → Target
2. Choose **macOS → Token Extension**
3. Set:
   - Product Name: `CorpTokenExtension`
   - Bundle Identifier: `com.yourcompany.CorpToken.TokenExtension`
   - Minimum Deployment: **macOS 14.0**
4. Xcode will generate stub files — **delete them** and add the files from `CorpTokenExtension/`

---

## 3. Add Source Files to Targets

### Shared files (add to BOTH targets)
- `Shared/Constants.swift`
- `Shared/SecureEnclaveManager.swift`
- `Shared/CredentialStore.swift`
- `Shared/CertificateParser.swift`

In Xcode: select each file → File Inspector → Target Membership → check both targets.

### App-only files
- Everything under `CorpTokenApp/` → `CorpToken` target only

### Extension-only files
- Everything under `CorpTokenExtension/` → `CorpTokenExtension` target only

---

## 4. Configure Entitlements

The repo ships with separate Debug and Release entitlements for each target. Debug entitlements omit shared keychain and app group capabilities so the app runs under any personal Apple ID (no paid account needed during development).

### CorpToken app
1. Click the `CorpToken` target → Signing & Capabilities
2. Enable **Automatic Signing** (or set certificate + provisioning profile manually)
3. Under build settings, set entitlements file per configuration:
   - **Debug**: `Configuration/CorpTokenApp-Debug.entitlements`
   - **Release**: `Configuration/CorpTokenApp.entitlements`
4. For Release, add capabilities:
   - **Keychain Sharing** → add group: `com.yourcompany.CorpToken.shared`
   - **App Groups** → add group: `group.com.yourcompany.CorpToken`

### CorpTokenExtension
1. Click the `CorpTokenExtension` target → Signing & Capabilities
2. Set entitlements files:
   - **Debug**: `Configuration/CorpTokenExtension-Debug.entitlements`
   - **Release**: `Configuration/CorpTokenExtension.entitlements`
3. For Release, add the same **Keychain Sharing** and **App Groups** capabilities

### Debug entitlements and the Xcode debugger

Both `*-Debug.entitlements` files include `com.apple.security.get-task-allow = true`. This is required for the Xcode debugger to attach to the process. Without it you will see:

```
unable to obtain a task name port right for pid <N>: (os/kern) failure (0x5)
```

Never include `get-task-allow` in Release builds — it is already absent from the release entitlements files.

---

## 5. Configure the Extension Info.plist

Open `CorpTokenExtension/Info.plist` and verify:

```
NSExtension
  NSExtensionPointIdentifier     = com.apple.ctk-tokens
  NSExtensionPrincipalClass      = $(PRODUCT_MODULE_NAME).CorpTokenDriver
  NSExtensionAttributes
    com.apple.ctk.class-id       = com.yourcompany.CorpToken.token
```

The `com.apple.ctk.class-id` must match `CorpTokenConstants.tokenClassID` exactly.

The version keys use build setting variables:

```xml
<key>CFBundleShortVersionString</key>
<string>$(MARKETING_VERSION)</string>
<key>CFBundleVersion</key>
<string>$(CURRENT_PROJECT_VERSION)</string>
<key>LSMinimumSystemVersion</key>
<string>$(MACOSX_DEPLOYMENT_TARGET)</string>
```

These resolve from the project-level build settings (see Section 9).

---

## 6. Embed the Extension in the App

1. Click the `CorpToken` app target → General → Frameworks, Libraries, and Embedded Content
2. Click **+** → Add `CorpTokenExtension.appex`
3. Set Embed: **Embed Without Signing** (Xcode re-signs it during build)

---

## 7. Add Test Targets

1. File → New → Target → **Unit Testing Bundle** → name it `SharedTests`
2. Add `Tests/SharedTests/*.swift` to this target
3. Add another bundle for `ExtensionTests` and `AppTests` if desired
4. Add the relevant `Shared/` files to test targets as needed

---

## 8. Developer Portal Configuration

Before building with Release signing, configure in the Apple Developer Portal:

1. **App ID** for `com.yourcompany.CorpToken`:
   - Enable Keychain Sharing
   - Enable App Groups

2. **App ID** for `com.yourcompany.CorpToken.TokenExtension`:
   - Enable Keychain Sharing (same group)
   - Enable App Groups (same group)

3. **Keychain Access Group**: `com.yourcompany.CorpToken.shared`

4. **App Group**: `group.com.yourcompany.CorpToken`

5. Generate provisioning profiles for both App IDs

---

## 9. Version Numbers

Version numbers are set once at the **project level** so both the app and the extension always stay in sync. The extension's `Info.plist` uses `$(CURRENT_PROJECT_VERSION)` and `$(MARKETING_VERSION)` which resolve from these settings.

In the project's build settings (both Debug and Release configurations):

| Setting | Value |
|---|---|
| `CURRENT_PROJECT_VERSION` | `1` (bump for each build/release) |
| `MARKETING_VERSION` | `1.0` (user-visible version) |

To update the version: change these two values in the project-level build settings. Do not set them separately per target — that is what caused the extension/app bundle version mismatch warning.

---

## 10. Find & Replace

Replace all placeholder values in one pass:

| Find | Replace with |
|---|---|
| `com.yourcompany` | Your reverse-DNS bundle ID prefix |
| `$(AppIdentifierPrefix)` in `Constants.swift` | Your Team ID (found at developer.apple.com → Membership) |
| `CorpToken` (display name) | Your app name |

Run from the repo root to find all affected files:
```bash
grep -r "com.yourcompany\|AppIdentifierPrefix" . \
  --include="*.swift" --include="*.plist" --include="*.entitlements" -l
```

---

## 11. Build & Test

```bash
# Build both targets
xcodebuild -scheme CorpToken -configuration Debug build

# Run unit tests
xcodebuild test -scheme CorpToken -destination 'platform=macOS'
```

To test the token extension manually:
1. Build and run the CorpToken app
2. Click **Use Test Certificate** in the debug banner at the bottom of the enrollment screen
3. The app transitions to Token Active — the test cert is now in the keychain
4. Open **Keychain Access** → look for "CorpToken Employee Certificate"
5. For full end-to-end token testing (TLS client auth, macOS login), build with Release signing and a real enrollment backend

---

## Entitlement Notes

### `com.apple.security.smartcard`
- Available with any Apple Developer account
- Required for the token extension
- Sufficient for smart card-style virtual tokens

### `com.apple.token` (if needed)
- Required for fully virtual tokens with no physical hardware association
- Requires Apple approval: https://developer.apple.com/contact/request/system-software
- File as "Request for CryptoTokenKit Entitlement"
- Start with `com.apple.security.smartcard` first — it works for most use cases
