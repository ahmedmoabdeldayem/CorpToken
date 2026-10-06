# CorpToken

A macOS CryptoTokenKit employee authentication token.

Employees enroll once. Their private key is generated in the Secure Enclave (never leaves the chip). The signed certificate from your CA is stored in the shared keychain. From that point on, the token extension exposes the credential to the OS — enabling Touch ID-protected TLS client authentication, macOS login, and VPN authentication automatically.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  CorpToken.app  (container)                             │
│                                                         │
│  EnrollmentView → EnrollmentViewModel                   │
│       │                                                 │
│       ├─ SecureEnclaveManager.generateKeyPair()         │
│       └─ EnrollmentAPIClient.requestCertificate() ──► Your CA │
│                    │                                    │
│            CredentialStore.storeCertificate()           │
│                    │                                    │
│  ┌─────────────────▼──────────────────────────────┐     │
│  │  CorpTokenExtension  (App Extension)           │     │
│  │                                                │     │
│  │  CorpTokenDriver → CorpToken → CorpTokenSession│     │
│  │       reads shared keychain (access group)     │     │
│  └──────────────────────────────────────────────┬─┘     │
└─────────────────────────────────────────────────┼───────┘
                                                  │ exposes via TKTokenKeychainContents
                                                  ▼
                          macOS Keychain / CryptoTokenKit daemon
                                                  │
                         ┌────────────────────────┼──────────────────┐
                         ▼                         ▼                  ▼
                      Safari               macOS Login           VPN / SSH
                   (TLS client auth)     (smart card PIN)      (PKCS#11)
```

---

## Key Design Decisions

| Decision | Choice | Why |
|---|---|---|
| Key storage | Secure Enclave | Key material never leaves the chip |
| Auth gate | Touch ID (biometryCurrentSet) | Invalidated if fingerprints change |
| Cert delivery | MDM SCEP or custom API | MDM = zero-touch; API = SE key support |
| Token type | Virtual (non-smart-card) | No physical hardware required |
| Deployment | One token instance per macOS user | Standard corporate Mac pattern |

---

## Repository Structure

```
CorpToken/
├── Shared/                        Compiled into both app and extension
│   ├── Constants.swift            Bundle IDs, keychain tags, app group
│   ├── SecureEnclaveManager.swift SE key generation and retrieval
│   ├── CredentialStore.swift      Certificate keychain operations
│   └── CertificateParser.swift    PEM↔DER, cert inspection, CSR prep
│
├── CorpTokenApp/                  Container app (enrollment UI)
│   ├── App/
│   │   ├── CorpTokenApp.swift     @main entry point + MenuBarExtra
│   │   └── AppDelegate.swift      Lifecycle, expiry notifications
│   ├── Enrollment/
│   │   ├── EnrollmentAPIClient.swift  OAuth2 device flow + cert request/poll
│   │   └── EnrollmentConfig.swift     MDM-overridable runtime config
│   ├── Views/
│   │   ├── ContentView.swift      Root router
│   │   ├── EnrollmentView.swift   Enrollment wizard
│   │   └── TokenStatusView.swift  Certificate details + unenroll
│   ├── ViewModels/
│   │   └── EnrollmentViewModel.swift  Enrollment orchestration (progress/state)
│   └── Debug/
│       └── DebugEnrollment.swift  Debug-only mock enrollment (no backend/SE)
│
├── CorpTokenExtension/            CryptoTokenKit app extension
│   ├── TokenDriver.swift          TKTokenDriver — principal class
│   ├── Token.swift                TKToken — populates keychain contents
│   ├── TokenSession.swift         TKTokenSession — ECDSA signing + ECDH
│   └── Info.plist                 Extension manifest (com.apple.ctk-tokens)
│
├── Configuration/
│   ├── CorpTokenApp.entitlements             Production entitlements
│   ├── CorpTokenApp-Debug.entitlements       Debug entitlements (no shared keychain)
│   ├── CorpTokenExtension.entitlements
│   └── CorpTokenExtension-Debug.entitlements
│
├── MDM/
│   └── SCEP_Profile_Template.mobileconfig   Push via Jamf/Kandji/Mosyle
│
└── Tests/
    ├── SharedTests/
    │   ├── SecureEnclaveManagerTests.swift
    │   └── CertificateParserTests.swift
    ├── ExtensionTests/
    │   └── TokenSessionTests.swift
    └── AppTests/
        └── EnrollmentAPIClientTests.swift
```

---

## Setup

See [PROJECT_SETUP.md](PROJECT_SETUP.md) for full Xcode project configuration.

### Quick summary

1. Create a new macOS App project in Xcode targeting macOS 14+
2. Add a second target: **Token Extension** (File → New Target → Token Extension)
3. Add the `Shared/` folder to **both** targets
4. Add `CorpTokenApp/` files to the app target only
5. Add `CorpTokenExtension/` files to the extension target only
6. Set the entitlements files in each target's Signing & Capabilities
7. Enable **Keychain Sharing** and **App Groups** capabilities in both targets
   - Keychain group: `com.yourcompany.CorpToken.shared`
   - App group: `group.com.yourcompany.CorpToken`
8. Replace every `com.yourcompany` with your actual bundle ID prefix

---

## Enrollment Flow

### Option A — MDM SCEP (recommended for production)

1. Push `MDM/SCEP_Profile_Template.mobileconfig` via your MDM
2. MDM generates the key + CSR, sends to your SCEP server, stores the cert
3. Open CorpToken — it detects the cert and activates the token

> **Label matching required:** The SCEP profile must store the certificate with
> the label `"CorpToken Employee Certificate"` (matching `CorpTokenConstants.certificateLabel`).
> Set this in the profile's `PayloadDisplayName` or configure your MDM to apply that label.
> Without it, the app will not find the MDM-issued certificate on launch.

**Limitation:** MDM SCEP uses the regular keychain, not the Secure Enclave.
For SE keys, use Option B.

### Option B — In-app enrollment (for Secure Enclave keys)

1. Employee opens CorpToken, enters their Employee ID
2. App generates P-256 key in the Secure Enclave
3. App exports the public key and calls `EnrollmentAPIClient.requestCertificate()`
4. The client performs OAuth2 device flow, POSTs the public key to your backend, and polls until the CA issues the cert
5. App stores the cert; token extension is live immediately

Configure the backend URL and OAuth credentials via MDM or `EnrollmentConfig.swift` defaults.

---

## What You Need to Implement

| File | What to add |
|---|---|
| `Shared/Constants.swift` → `keychainAccessGroup` | Replace `$(AppIdentifierPrefix)` with your Team ID |
| `CorpTokenApp/Enrollment/EnrollmentConfig.swift` → `defaultBaseURL` | Your enrollment backend URL |
| `MDM/SCEP_Profile_Template.mobileconfig` | Your SCEP server URL and CA fingerprint |
| `Configuration/*.entitlements` | Your real bundle ID prefix |

`EnrollmentAPIClient.swift` is fully implemented and handles OAuth2 device flow, certificate request, and polling. Configure it via MDM keys or by editing `EnrollmentConfig.swift` defaults.

---

## Debug / Development

The app ships with a debug-only enrollment path that requires **no backend, no Secure Enclave, and no Apple Developer account**.

In a Debug build, the enrollment screen shows a **"Use Test Certificate"** button at the bottom. Clicking it:

1. Stores a pre-built self-signed test certificate (valid Oct 2026 – Oct 2028) in the default keychain
2. Sets enrollment state to `.enrolled` directly (no SE key is generated)
3. Shows the Token Active screen immediately

This lets you test the full UI state machine and menu bar transitions without any infrastructure.

**What the debug path does NOT cover:**
- SE key generation (no real key is created)
- Shared keychain access group (app ↔ extension)
- Token extension process (CTK daemon)
- TLS client authentication or macOS login

For those, build with Release signing and a real enrollment backend.

### Debug entitlements

The `*-Debug.entitlements` files intentionally omit `keychain-access-groups` and `application-groups` so the app runs under any personal Apple ID. They include `com.apple.security.get-task-allow` to allow the Xcode debugger to attach.

---

## Security Notes

- The SE private key is bound to `biometryCurrentSet` — it is automatically
  invalidated if the user adds or removes a fingerprint. Re-enrollment is required.
- The device passcode is also accepted as a fallback (`.biometryCurrentSet` + `.or` + `.devicePasscode` access control).
- Certificate revocation is not checked by the token extension itself. Implement
  OCSP stapling or CRL checks in your CA and rely on OS-level revocation checking.
- For macOS login (smart card login), an additional MDM profile is needed to map
  the certificate's Subject/UPN to a local account. See Apple's Smart Card documentation.

---

## Requirements

- macOS 14 Sonoma or later
- T2 chip or Apple Silicon (for Secure Enclave enrollment; debug path works on any Mac)
- Apple Developer account (for keychain-sharing entitlements in production)
- Your own certificate authority (ADCS, EJBCA, HashiCorp Vault PKI, or similar)
