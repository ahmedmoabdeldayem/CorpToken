# CorpToken — User Guide

**CorpToken** is a security app for your work Mac. It replaces physical smart cards and hardware security keys by storing your employee identity directly inside your Mac's built-in security chip (the Secure Enclave). Once enrolled, it lets you log in to work systems, access internal websites, and connect to the VPN — all with just a Touch ID tap.

---

## Table of Contents

1. [What Does CorpToken Do?](#1-what-does-corptoken-do)
2. [System Requirements](#2-system-requirements)
3. [Installing CorpToken](#3-installing-corptoken)
4. [Enrolling Your Mac](#4-enrolling-your-mac)
5. [Daily Use](#5-daily-use)
6. [Troubleshooting](#6-troubleshooting)
7. [Unenrolling Your Mac](#7-unenrolling-your-mac)
8. [For IT Administrators](#8-for-it-administrators)
9. [Frequently Asked Questions](#9-frequently-asked-questions)
10. [Glossary](#10-glossary)

---

## 1. What Does CorpToken Do?

Think of CorpToken as a digital employee badge that lives inside your Mac.

When you try to access a protected work resource — like a VPN, an internal website that requires a certificate, or a Mac that's locked to your account — the system asks "who are you?" CorpToken answers that question on your behalf, silently, using a certificate issued by your company. You just confirm with **Touch ID**.

**Key facts:**
- Your private key is created inside the Mac's hardware security chip and **never leaves it**, not even to IT.
- Even your IT team cannot copy or extract your key.
- If your Mac is lost or stolen, the key cannot be used without your fingerprint or Mac password.
- One enrollment per Mac. If you get a new Mac, you enroll again.

---

## 2. System Requirements

Before installing CorpToken, confirm your Mac meets these requirements.

### Required

| Requirement | How to check | Minimum |
|---|---|---|
| **macOS version** | Apple menu → About This Mac | **macOS 14 Sonoma** or later |
| **Mac chip** | Apple menu → About This Mac → chip row | **Apple Silicon** (M1/M2/M3/M4) or **Intel with T2 security chip** |
| **Touch ID** | System Settings → Touch ID & Password | Must be set up with at least one fingerprint |
| **Internet connection** | — | Required during enrollment only |
| **Employee ID** | Provided by HR or IT | Your company directory ID or email |

### How to check your chip

1. Click the **Apple menu** (top-left corner)
2. Click **About This Mac**
3. Look for the **Chip** or **Processor** row:
   - ✅ "Apple M1", "Apple M2", "Apple M3", "Apple M4" → You have Apple Silicon (supported)
   - ✅ "Intel Core … (T2)" → You have a T2 chip (supported)
   - ❌ "Intel Core" with no T2 mention → **Not supported.** Contact IT for an alternative.

### How to check your macOS version

Same screen — look for **macOS** in the version line.
- ✅ macOS 14 Sonoma, 15 Sequoia → Supported
- ❌ macOS 13 Ventura or earlier → Update first (System Settings → General → Software Update)

---

## 3. Installing CorpToken

> **Your IT team will typically distribute CorpToken via your company's device management system (MDM).** If so, the app will appear in Self Service or be installed automatically — skip to Section 4.

If you received a `.dmg` or `.pkg` file directly:

1. Double-click the installer file
2. Drag **CorpToken** to your Applications folder
3. Open CorpToken from Applications or Spotlight (`⌘ Space`, type "CorpToken")
4. macOS may ask you to confirm you trust the developer — click **Open**

---

## 4. Enrolling Your Mac

Enrollment is a one-time process that links your employee identity to this Mac. It takes about 2–5 minutes.

### Step-by-step

**Step 1 — Open CorpToken**
Find it in your Applications folder or use Spotlight (`⌘ Space`, type "CorpToken").

**Step 2 — The enrollment screen**
You will see a form with a single field: **Employee ID**.

Enter your company Employee ID. This is usually one of:
- Your work email address (`jdoe@company.com`)
- Your username from your company directory (`jdoe`)
- Your badge number

If you are unsure which to use, ask your IT helpdesk.

**Step 3 — Click "Enroll with Touch ID"**
The app will first generate your private key inside the Mac's security chip. You may see a Touch ID prompt at this stage — place your finger to authorise the key creation.

**Step 4 — Browser login (if required)**
A browser window will open automatically, showing a login page for your company's identity system (Okta, Azure AD, Google Workspace, etc.). Log in with your usual company credentials.

After logging in, return to the CorpToken app. You will see a code displayed — this may already have been entered automatically. If not, type it into the browser window.

**Step 5 — Wait for your certificate**
The screen will show a progress counter. Your company's certificate authority is generating your employee certificate. This usually takes 10–60 seconds. Do not close the app.

**Step 6 — Enrollment complete**
The app will switch to the **Token Active** screen, showing:
- Your name (from your certificate)
- Certificate expiry date
- A green "Token Active" badge

You are now enrolled. The token works in the background — you do not need to keep CorpToken open.

### Enrollment checklist

- [ ] macOS 14 Sonoma or later
- [ ] Apple Silicon or T2 chip
- [ ] Touch ID set up with at least one fingerprint
- [ ] Internet connected
- [ ] Employee ID ready
- [ ] Company SSO credentials ready (for browser login step)

---

## 5. Daily Use

Once enrolled, CorpToken works automatically. You do not need to open the app each day.

### Using with Safari (internal websites)

When you visit an internal website that requires your employee certificate:

1. Safari shows a dialog: **"A website wants to use a certificate to identify you"** — or similar
2. Select your **CorpToken** certificate (it will show your name)
3. Touch ID prompt appears — place your finger
4. You are authenticated

### Using with VPN

Your VPN client will request your certificate automatically when connecting. Depending on your VPN software, you will either:
- See a Touch ID prompt directly, or
- Be asked to select a certificate — choose the one labelled with your name from **CorpToken**

### Using for macOS login (if enabled by IT)

If your IT team has configured smart card login for your Mac:
1. The login screen shows a PIN field instead of a password
2. Touch your finger to Touch ID
3. You are logged in

### Menu bar icon

CorpToken adds a small icon to your menu bar (top-right of screen) — a person with a key. Click it to quickly check your enrollment status without opening the full app.

**Status icons:**

| Icon | Meaning |
|---|---|
| ✅ Green shield | Token active — everything is working |
| 🕐 Clock | Enrollment pending — waiting for certificate |
| ⚠️ Orange shield | Certificate expiring soon (within 30 days) |
| ❌ Red shield | Certificate expired or revoked — action needed |

---

## 6. Troubleshooting

### "Secure Enclave not available" during enrollment

**Cause:** Your Mac does not have a T2 chip or Apple Silicon.
**Fix:** Contact IT — they may have an alternative authentication method for your model.

### Touch ID prompt says "Not Set Up"

**Cause:** No fingerprints enrolled on this Mac.
**Fix:**
1. System Settings → Touch ID & Password
2. Click the **+** button to add a fingerprint
3. Then try enrolling again in CorpToken

### "Authorization was denied" during browser login

**Cause:** Your IT team has not approved your account for certificate enrollment, or you are not in the right security group.
**Fix:** Contact your IT helpdesk and ask them to add you to the CorpToken enrollment group.

### "Enrollment rejected" after browser login

**Cause:** The certificate authority declined the request. This can happen if the device is not MDM-enrolled or your account has a policy restriction.
**Fix:** Contact IT helpdesk with your Employee ID and the rejection reason shown on screen.

### Certificate expired — "Token Active" not shown

**Cause:** Employee certificates have a validity period (usually 1 year). After expiry, the token stops working.
**Fix:**
1. Open CorpToken
2. You will see an "Expired" screen
3. Click **Re-Enroll** and repeat the enrollment steps

If you set up notifications, you will receive an alert 14 days before expiry.

### Touch ID works but signing fails with "Key unavailable"

**Cause:** The Mac's enrolled fingerprints changed since enrollment (e.g., all fingerprints were deleted and re-added). The Secure Enclave's biometry-linked key is no longer accessible via Touch ID. Your Mac password will still work as a fallback — use that to confirm.
**Fix:** Unenroll and re-enroll (Section 7 → Section 4).

### The token appears in Keychain Access but TLS/VPN doesn't use it

**Cause:** The application may not be looking for a token-backed certificate, or the certificate might not have the right Extended Key Usage flags.
**Fix:** Contact IT to verify the certificate was issued with the correct profile.

### CorpToken shows "Not Enrolled" after updating macOS

**Cause:** Rare, but a major macOS update can occasionally clear the App Group UserDefaults that CorpToken uses to cache enrollment state.
**Fix:** Open CorpToken — it will re-read the keychain and show the correct status. If genuinely unenrolled, repeat enrollment.

### Enrollment completes but the screen doesn't change

**Cause:** Can happen if an earlier failed enrollment attempt left a partial entry in the keychain.
**Fix:** CorpToken handles this automatically — duplicate keychain entries are silently accepted rather than treated as an error. If the screen still doesn't transition to Token Active, unenroll via the app menu and re-enroll.

---

## 7. Unenrolling Your Mac

Unenrolling removes your private key and certificate from this Mac. You will need to re-enroll to use the token again.

**When to unenroll:**
- You are returning or decommissioning this Mac
- IT requests it (e.g., before a device wipe)
- You need to re-enroll with a fresh certificate

**Steps:**
1. Open CorpToken
2. On the **Token Active** screen, scroll to the bottom
3. Click **Remove This Device's Token**
4. Confirm the dialog — "Remove"

The private key and certificate are permanently deleted. This action cannot be undone.

> **Leaving the company?** Unenrolling removes your key from the device but does not revoke the certificate at your company's certificate authority. Contact IT so they can revoke the certificate.

---

## 8. For IT Administrators

This section covers deploying and managing CorpToken at scale.

### Prerequisites for deployment

| Item | Details |
|---|---|
| **Apple Developer Account** | Paid membership required for entitlements |
| **Certificate Authority** | Must support SCEP or a REST API for certificate issuance |
| **MDM platform** | Jamf, Kandji, Mosyle, or any SCEP-capable MDM |
| **OAuth 2.0 server** | Okta, Azure AD, Google, or any RFC 8628-compliant server (for in-app enrollment flow) |
| **macOS 14+** | On all managed devices |

### Deployment option A — MDM SCEP (recommended, zero-touch)

The MDM pushes a SCEP profile that automatically generates a key pair and requests a certificate from your CA. No user interaction is needed beyond approving the MDM enrolment.

1. Customise `MDM/SCEP_Profile_Template.mobileconfig` with your SCEP server URL, CA fingerprint, and subject fields.
2. Push the profile to device groups via your MDM.
3. Push the CorpToken `.app` (or `.pkg`) as a managed install.
4. The app automatically detects the MDM-issued certificate on first launch.

> **Note:** MDM SCEP certificates are stored in the regular keychain, not the Secure Enclave. For SE-backed keys, use Option B.

### Deployment option B — In-app enrollment (Secure Enclave-backed)

1. Deploy the CorpToken `.app` to devices.
2. Configure your enrollment backend URL and OAuth client ID via a Custom Settings MDM profile (see configuration keys below).
3. Employees open CorpToken, enter their Employee ID, and complete browser-based SSO authentication.
4. Your enrollment backend receives the SE public key, forwards it to your CA, and returns the signed certificate.

### MDM configuration keys

Push these via a **Custom Settings** profile with `PayloadDomain = com.yourcompany.CorpToken`:

| Key | Type | Description | Default |
|---|---|---|---|
| `EnrollmentBaseURL` | String | Base URL of your enrollment REST API (must be `https://`) | `https://enroll.corp.yourcompany.com` |
| `EnrollmentOAuthClientID` | String | OAuth 2.0 client ID for the device flow | `corptoken-macos` |
| `EnrollmentOAuthScope` | String | OAuth scope for certificate issuance | `enrollment:write` |
| `EnrollmentRequestTimeout` | Number | HTTP request timeout in seconds | `30` |
| `EnrollmentPollInterval` | Number | Seconds between certificate status polls | `4` |
| `EnrollmentMaxPollAttempts` | Number | Maximum poll attempts (~total wait time) | `30` |

If `EnrollmentBaseURL` is missing, invalid, or not `https://`, the app logs a critical error and falls back to the compiled-in default. A bad MDM push will never crash the app on launch.

### Enrollment backend contract

Your backend must implement these endpoints (details in `EnrollmentAPIClient.swift`):

```
POST /oauth/device/authorize     — OAuth2 device authorization
POST /oauth/token                — OAuth2 token exchange
POST /v1/enrollments             — Submit enrollment (public key + employee ID)
GET  /v1/enrollments/{id}        — Poll for issued certificate
```

The issued certificate must be returned as base64-encoded DER in the `certificate_der` field, or as a PEM string in `certificate_pem`.

### Certificate requirements

The employee certificate must have:
- **Subject CN**: Employee display name (for UI display)
- **Subject email**: Employee email (for TLS client auth matching)
- **Extended Key Usage**: `1.3.6.1.5.5.7.3.2` (TLS client authentication)
- **Extended Key Usage**: `1.3.6.1.4.1.311.20.2.2` (Smart card logon — required for macOS login)
- **Key type**: P-256 EC (Secure Enclave only supports P-256)
- **Keychain label**: Must be set to `"CorpToken Employee Certificate"` (for automatic detection)

### Certificate revocation

CorpToken does not perform OCSP or CRL checks locally. Revocation must be enforced at the service layer (VPN gateway, web server, identity provider). When revoking a certificate:

1. Revoke at your CA
2. Optionally push an MDM command to wipe the CorpToken app data, which triggers the employee to re-enroll

### macOS smart card login setup

To use CorpToken for macOS login (replace password with Touch ID + certificate):

1. Push `com.apple.security.smartcard` configuration profile with:
   - `checkCertificateTrust = 2` (require valid trust chain)
   - `oneCardPerUser = true`
   - `UserPairing` mapping the certificate UPN/email to the macOS account username
2. The certificate's Subject Alternative Name must include either:
   - `ntPrincipalName` matching the Active Directory UPN, or
   - `rfc822Name` matching the user's email in the local user record

### Building from source

```bash
# 1. Clone the repository
git clone https://github.com/ahmedmoabdeldayem/CorpToken
cd CorpToken

# 2. Run the setup script (installs prerequisites)
chmod +x Scripts/setup.command
./Scripts/setup.command

# 3. Open Xcode and follow PROJECT_SETUP.md to configure targets,
#    entitlements, and provisioning profiles

# 4. Build and archive via Xcode for distribution
```

---

## 9. Frequently Asked Questions

**Q: Does CorpToken work if I have Face ID?**
A: CorpToken is a macOS app. Macs use Touch ID, not Face ID. If your Mac has Touch ID (on the keyboard or the Touch Bar), CorpToken supports it.

**Q: Can IT see my private key?**
A: No. The private key is generated inside the Secure Enclave hardware chip and never leaves it. CorpToken only exports the corresponding public key to IT's certificate authority. The key itself is mathematically unextractable.

**Q: What if I forget my Mac password?**
A: Touch ID is the primary method, and your Mac password is the fallback. If you forget your Mac password, contact IT to reset it through standard Mac account recovery procedures. Once the password is reset, Touch ID and CorpToken will work normally again.

**Q: Can I use CorpToken on multiple Macs?**
A: Yes — enroll each Mac separately. Each device gets its own key pair and certificate.

**Q: What happens when I get a new Mac?**
A: Enroll it. Your old Mac's key and certificate remain active until the certificate expires or you unenroll that Mac. If you have already handed back the old Mac, contact IT to revoke that certificate.

**Q: Does CorpToken store my password anywhere?**
A: No. CorpToken only stores your employee certificate (public information) in the keychain, and the private key in the Secure Enclave. No passwords are stored.

**Q: Will adding a new fingerprint break my token?**
A: No. Adding a new fingerprint while your existing ones remain enrolled will not break the token. The token only breaks if ALL fingerprints are deleted and replaced. Even then, your Mac password works as a fallback, and re-enrollment takes less than 5 minutes.

**Q: How do I know CorpToken is working right now?**
A: Look at the menu bar icon (person with a key symbol). A green shield means active. Or open CorpToken — the main screen shows "Token Active" in green when everything is working.

**Q: My certificate shows it expires in 30 days. What do I do?**
A: Open CorpToken. If your company has set up automatic renewal, nothing is needed — you'll see a "Renewing" status. If not, you'll see a countdown and a Renew button. Click it to start the re-enrollment process (same as initial enrollment but faster since you're already authenticated).

---

## 10. Glossary

| Term | Plain English |
|---|---|
| **Certificate** | A digital document issued by your company that proves who you are, like a digital passport |
| **Certificate Authority (CA)** | The system at your company that issues and manages certificates |
| **Enrollment** | The one-time process of linking your employee identity to this Mac |
| **Keychain** | macOS's built-in password and certificate manager |
| **MDM** | Mobile Device Management — the system IT uses to configure and manage company Macs |
| **PKCS#11 / Smart card** | Standards for hardware security tokens; CorpToken implements these so apps treat it like a physical card |
| **Private key** | The secret half of your certificate — like the physical key to a lock. Never leaves your Mac. |
| **Public key** | The shareable half — like the lock itself. Used to verify your identity |
| **SCEP** | Simple Certificate Enrollment Protocol — an automated way for MDM to request certificates |
| **Secure Enclave** | A dedicated security chip built into Apple Silicon and T2 Macs that stores keys in isolated hardware |
| **TLS client authentication** | When a website asks your Mac to prove its identity (not just yours) using a certificate |
| **Touch ID** | Apple's fingerprint reader, used by CorpToken to authorise signing operations |
| **Token** | In this context, your enrollment on this Mac — the combination of your certificate and private key |
| **VPN** | Virtual Private Network — a secure tunnel to your company's network |

---

*For help, contact your IT helpdesk or open a ticket referencing "CorpToken".*
