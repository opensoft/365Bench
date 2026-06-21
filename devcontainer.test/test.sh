#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

check() {
    local name="$1"
    local command="$2"

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name"
        ((PASS_COUNT++))
    else
        echo -e "${RED}✗${NC} $name"
        ((FAIL_COUNT++))
    fi
}

mod() {
    local m="$1"
    check "PS module: $m" "pwsh -NoLogo -NoProfile -Command \"if (Get-Module -ListAvailable -Name '$m') { exit 0 } else { exit 1 }\""
}

echo "=========================================="
echo "Layer 2 Microsoft 365 Bench Test Suite"
echo "=========================================="
echo

echo "Foundation:"
check "PowerShell 7 (pwsh)" "pwsh --version"
check "Node.js" "node --version"

echo
echo "PowerShell admin modules:"
mod "Microsoft.Graph"
mod "Microsoft.Entra"
mod "ExchangeOnlineManagement"
mod "MicrosoftTeams"
mod "PnP.PowerShell"

echo
echo "CLIs:"
check "CLI for Microsoft 365 (m365)" "m365 --version"
check "Microsoft Graph CLI (mgc)" "mgc --version"
check "Azure CLI (az)" "az version"

echo
echo "=========================================="
echo -e "Passed: ${GREEN}${PASS_COUNT}${NC}   Failed: ${RED}${FAIL_COUNT}${NC}"
echo "=========================================="

[ "$FAIL_COUNT" -eq 0 ]
