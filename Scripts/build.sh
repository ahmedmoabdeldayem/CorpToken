#!/bin/bash
# =============================================================================
#  CorpToken — Build Script
#  Builds the Swift package and optionally runs tests.
#
#  Usage:
#    bash Scripts/build.sh           — build only
#    bash Scripts/build.sh test      — build + run tests (requires Xcode.app)
#    bash Scripts/build.sh clean     — clean build folder first
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

MODE="${1:-build}"

echo ""
echo -e "${BOLD}CorpToken Build Script${NC}"
echo -e "Working directory: $REPO"
echo ""

if [ "$MODE" = "clean" ]; then
    echo -e "${YELLOW}Cleaning build artefacts...${NC}"
    rm -rf .build
    echo -e "${GREEN}Clean complete.${NC}"
    echo ""
    MODE="build"
fi

echo -e "${BOLD}Building...${NC}"
swift build 2>&1
echo ""
echo -e "${GREEN}✓ Build complete.${NC}"

if [ "$MODE" = "test" ]; then
    echo ""
    echo -e "${BOLD}Running tests...${NC}"

    if [ ! -d "/Applications/Xcode.app" ] && ! xctool --version &>/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Xcode.app not found — XCTest may not be available.${NC}"
        echo -e "${YELLOW}Install Xcode from the App Store and re-run.${NC}"
        echo ""
    fi

    swift test --parallel 2>&1
    echo ""
    echo -e "${GREEN}✓ Tests complete.${NC}"
fi

echo ""
