#!/bin/bash
# =============================================================================
#  CorpToken — Quick Requirements Checker
#  Prints a pass/fail for each requirement in under 5 seconds.
#  No installations — read-only. Safe to run on any Mac.
#
#  Usage:  bash Scripts/check_requirements.sh
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'
PASS="${GREEN}PASS${NC}"; FAIL="${RED}FAIL${NC}"; WARN="${YELLOW}WARN${NC}"

row() { printf "  %-40s %b\n" "$1" "$2"; }

echo ""
echo -e "${BOLD}CorpToken Requirements Check${NC}"
echo -e "──────────────────────────────────────────────"

# macOS version
VER=$(sw_vers -productVersion); MAJ=$(echo "$VER" | cut -d. -f1)
[ "$MAJ" -ge 13 ] \
  && row "macOS $VER" "$PASS" \
  || row "macOS $VER (need 13+)" "$FAIL"

# Chip
if [[ "$(uname -m)" == "arm64" ]]; then
  row "Apple Silicon (Secure Enclave)" "$PASS"
elif system_profiler SPiBridgeDataType 2>/dev/null | grep -q 'Apple T2'; then
  row "Intel + T2 chip (Secure Enclave)" "$PASS"
else
  row "Secure Enclave hardware" "$FAIL — upgrade Mac"
fi

# Swift
if command -v swift &>/dev/null; then
  SV=$(swift --version 2>&1 | grep -oE 'Swift version [0-9.]+' | head -1)
  row "$SV" "$PASS"
else
  row "Swift compiler" "$FAIL — install Xcode CLT"
fi

# Xcode CLT
xcode-select -p &>/dev/null \
  && row "Xcode Command Line Tools" "$PASS" \
  || row "Xcode Command Line Tools" "$FAIL — run: xcode-select --install"

# Xcode.app
[ -d "/Applications/Xcode.app" ] \
  && row "Xcode.app (for tests)" "$PASS" \
  || row "Xcode.app (for tests)" "$WARN — optional, install from App Store"

# Homebrew
command -v brew &>/dev/null \
  && row "Homebrew" "$PASS" \
  || row "Homebrew" "$WARN — optional"

# Package.swift present
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$REPO/Package.swift" ] \
  && row "Package.swift found" "$PASS" \
  || row "Package.swift" "$FAIL — re-clone repository"

echo -e "──────────────────────────────────────────────"
echo -e "  Run ${BOLD}Scripts/setup.command${NC} to install missing items."
echo ""
