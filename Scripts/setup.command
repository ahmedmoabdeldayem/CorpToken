#!/bin/bash
# =============================================================================
#  CorpToken — Prerequisites Setup Script
#  macOS equivalent of a Windows .bat file
#
#  HOW TO RUN:
#    Double-click this file in Finder  →  Terminal opens and runs it
#    — OR —
#    Open Terminal, drag this file into it, press Enter
#
#  WHAT THIS SCRIPT DOES:
#    1. Checks your macOS version (needs 13 Ventura or later)
#    2. Checks your Mac chip (needs T2 or Apple Silicon)
#    3. Checks if Touch ID is configured
#    4. Installs Xcode Command Line Tools (needed to build CorpToken)
#    5. Installs Homebrew (optional, used for extra tools)
#    6. Verifies the Swift compiler is working
#    7. Builds the CorpToken package to confirm nothing is broken
#    8. Checks if Xcode.app is installed (needed for tests)
#    9. Prints a summary of what passed, what needs attention
# =============================================================================

# ── Colours ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'   # No colour

# ── Symbols ──────────────────────────────────────────────────────────────────
PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"
INFO="${BLUE}ℹ${NC}"

# ── Move to repo root (two levels up from Scripts/) ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# ── Track overall result ─────────────────────────────────────────────────────
ERRORS=0
WARNINGS=0

pass()  { echo -e "  ${PASS}  $1"; }
fail()  { echo -e "  ${FAIL}  $1"; ERRORS=$((ERRORS + 1)); }
warn()  { echo -e "  ${WARN}  $1"; WARNINGS=$((WARNINGS + 1)); }
info()  { echo -e "  ${INFO}  $1"; }
header(){ echo -e "\n${BOLD}── $1 ──────────────────────────────────────────${NC}"; }

# =============================================================================
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          CorpToken Prerequisites Setup            ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
info "Repository: $REPO_ROOT"
info "Date: $(date '+%A, %d %B %Y %H:%M')"

# =============================================================================
header "1 of 8 — macOS Version"

MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="$(echo "$MACOS_VERSION" | cut -d. -f1)"

if [ "$MACOS_MAJOR" -ge 14 ]; then
    pass "macOS $MACOS_VERSION — Sonoma or later (required: 14+)"
else
    fail "macOS $MACOS_VERSION is too old. CorpToken requires macOS 14 Sonoma or later."
    echo -e "     ${DIM}Fix: Apple menu → System Settings → General → Software Update${NC}"
fi

# =============================================================================
header "2 of 8 — Secure Enclave Hardware"

CHIP_INFO="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")"
MODEL_ID="$(sysctl -n hw.model 2>/dev/null || echo "Unknown")"

if [[ "$MODEL_ID" == *"Mac"* ]]; then
    # Apple Silicon check
    if [[ "$CHIP_INFO" == *"Apple"* ]] || [[ "$(uname -m)" == "arm64" ]]; then
        pass "Apple Silicon detected ($CHIP_INFO) — Secure Enclave available"
        SE_AVAILABLE=true
    else
        # Intel — check for T2 chip via system_profiler
        T2_CHECK="$(system_profiler SPiBridgeDataType 2>/dev/null | grep -c 'Apple T2' || echo 0)"
        if [ "$T2_CHECK" -gt 0 ]; then
            pass "Intel Mac with T2 Security Chip detected — Secure Enclave available"
            SE_AVAILABLE=true
        else
            fail "No Secure Enclave found (Intel Mac without T2 chip)."
            echo -e "     ${DIM}CorpToken requires a T2 chip (2018+ Intel Macs) or Apple Silicon.${NC}"
            echo -e "     ${DIM}Contact IT for an alternative authentication method.${NC}"
            SE_AVAILABLE=false
        fi
    fi
else
    warn "Could not determine Mac model. Check manually: Apple menu → About This Mac"
    SE_AVAILABLE=false
fi

# =============================================================================
header "3 of 8 — Touch ID"

TOUCHID_CHECK="$(bioutil -r -s 2>/dev/null | grep -c 'enrolled' || echo 0)"

# bioutil may not be available on all configurations; try an alternative check
if [ "$TOUCHID_CHECK" -gt 0 ] 2>/dev/null; then
    pass "Touch ID fingerprints enrolled"
elif ioreg -c AppleHIDTransport 2>/dev/null | grep -qi "biometric" 2>/dev/null; then
    warn "Touch ID hardware found but could not confirm fingerprints are set up."
    echo -e "     ${DIM}Check: System Settings → Touch ID & Password → verify at least one fingerprint shown${NC}"
else
    warn "Could not check Touch ID status automatically."
    echo -e "     ${DIM}Please verify manually: System Settings → Touch ID & Password${NC}"
fi

# =============================================================================
header "4 of 8 — Xcode Command Line Tools"

if xcode-select -p &>/dev/null && [ -d "$(xcode-select -p)" ]; then
    CLT_PATH="$(xcode-select -p)"
    SWIFT_VERSION="$(swift --version 2>/dev/null | head -1)"
    pass "Xcode Command Line Tools installed at: $CLT_PATH"
    pass "Swift: $SWIFT_VERSION"
else
    warn "Xcode Command Line Tools not found. Installing now..."
    echo ""
    echo -e "  ${YELLOW}A dialog box will appear. Click 'Install' and wait for it to complete.${NC}"
    echo -e "  ${YELLOW}This may take 5–15 minutes depending on your internet speed.${NC}"
    echo ""

    xcode-select --install 2>/dev/null

    echo ""
    echo -e "  ${YELLOW}After the installation completes, re-run this script.${NC}"
    echo -e "  ${DIM}(Close this window and double-click setup.command again)${NC}"
    echo ""
    exit 0
fi

# =============================================================================
header "5 of 8 — Homebrew (Optional)"

if command -v brew &>/dev/null; then
    BREW_VERSION="$(brew --version | head -1)"
    pass "Homebrew already installed: $BREW_VERSION"
else
    warn "Homebrew is not installed."
    echo -e "     ${DIM}Homebrew is optional for CorpToken but useful for other developer tools.${NC}"
    echo ""
    read -r -p "  Would you like to install Homebrew? [y/N] " INSTALL_BREW
    if [[ "$INSTALL_BREW" =~ ^[Yy]$ ]]; then
        echo ""
        info "Installing Homebrew — this may ask for your Mac password..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if command -v brew &>/dev/null; then
            pass "Homebrew installed successfully"
        else
            warn "Homebrew installation may have failed. Check the output above."
        fi
    else
        info "Skipping Homebrew. You can install it later from https://brew.sh"
    fi
fi

# =============================================================================
header "6 of 8 — Swift Compiler"

if command -v swift &>/dev/null; then
    SWIFT_VER="$(swift --version 2>&1 | grep 'Swift version' | head -1)"
    SWIFT_MAJOR="$(swift --version 2>&1 | grep -oE 'Swift version [0-9]+' | grep -oE '[0-9]+')"
    if [ "${SWIFT_MAJOR:-0}" -ge 5 ]; then
        pass "Swift compiler available: $SWIFT_VER"
    else
        warn "Swift version may be too old. Expected Swift 5.9+, got: $SWIFT_VER"
        echo -e "     ${DIM}Update Xcode Command Line Tools: sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install${NC}"
    fi
else
    fail "Swift compiler not found even though CLT appears installed."
    echo -e "     ${DIM}Try: sudo xcode-select --reset${NC}"
fi

# =============================================================================
header "7 of 8 — Building CorpToken Package"

if [ -f "$REPO_ROOT/Package.swift" ]; then
    info "Running swift build... (this may take 30–60 seconds the first time)"
    echo ""

    BUILD_OUTPUT="$(swift build 2>&1)"
    BUILD_EXIT="$?"

    if [ "$BUILD_EXIT" -eq 0 ]; then
        pass "swift build completed — Build complete! 0 errors"
    else
        fail "swift build failed. Output:"
        echo ""
        echo "$BUILD_OUTPUT" | sed 's/^/     /'
        echo ""
        echo -e "     ${DIM}Share the output above with your developer or IT team.${NC}"
    fi
else
    warn "Package.swift not found at $REPO_ROOT. Cannot run build check."
    echo -e "     ${DIM}Expected location: $REPO_ROOT/Package.swift${NC}"
fi

# =============================================================================
header "8 of 8 — Xcode.app (for running tests)"

if [ -d "/Applications/Xcode.app" ]; then
    XCODE_VERSION="$(defaults read /Applications/Xcode.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo 'unknown')"
    XCODE_MIN="15"
    XCODE_MAJOR="$(echo "$XCODE_VERSION" | cut -d. -f1)"
    if [ "${XCODE_MAJOR:-0}" -ge "$XCODE_MIN" ]; then
        pass "Xcode.app $XCODE_VERSION installed — unit tests can be run"
    else
        warn "Xcode.app $XCODE_VERSION is installed but may be outdated. Recommended: Xcode 15 or later."
        echo -e "     ${DIM}Update via App Store → Xcode${NC}"
    fi
else
    warn "Xcode.app not installed. Unit tests cannot be run without it."
    echo -e "     ${DIM}Install from the Mac App Store: https://apps.apple.com/app/xcode/id497799835${NC}"
    echo -e "     ${DIM}Xcode.app is free. It is only required for building the full app and running tests.${NC}"
    echo -e "     ${DIM}swift build works with Command Line Tools alone.${NC}"
fi

# =============================================================================
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                    SUMMARY                       ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}All checks passed! CorpToken is ready.${NC}"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "  ${YELLOW}${BOLD}Setup complete with $WARNINGS warning(s). Review items above.${NC}"
else
    echo -e "  ${RED}${BOLD}$ERRORS error(s) found. CorpToken cannot run until these are resolved.${NC}"
    if [ "$WARNINGS" -gt 0 ]; then
        echo -e "  ${YELLOW}Additionally, $WARNINGS warning(s) — review items above.${NC}"
    fi
fi

echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""

if [ "$SE_AVAILABLE" = false ]; then
    echo -e "  1. ${RED}Your Mac does not have a Secure Enclave.${NC}"
    echo -e "     Contact IT for an alternative authentication method."
    echo ""
else
    echo -e "  1. ${BOLD}Set up an Xcode project${NC} following PROJECT_SETUP.md"
    echo -e "     ${DIM}(Required to build the full macOS app with entitlements)${NC}"
    echo ""
    echo -e "  2. ${BOLD}Configure your bundle ID and enrollment backend${NC}"
    echo -e "     Edit Shared/Constants.swift — replace 'com.yourcompany' with your domain"
    echo -e "     Edit CorpTokenApp/Enrollment/EnrollmentConfig.swift — add your backend URL"
    echo ""
    echo -e "  3. ${BOLD}Set up Apple Developer provisioning${NC}"
    echo -e "     See PROJECT_SETUP.md → Steps 4–8 for entitlements and capabilities"
    echo ""
    echo -e "  4. ${BOLD}Read the user guide${NC}"
    echo -e "     Open USER_GUIDE.md in any text editor or markdown viewer"
    echo ""
    echo -e "  5. ${BOLD}Run tests${NC} (requires Xcode.app)"
    echo -e "     ${DIM}swift test --parallel${NC}"
fi

echo ""
echo -e "${DIM}Script completed at $(date '+%H:%M:%S'). You can close this window.${NC}"
echo ""
