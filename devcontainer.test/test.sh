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
echo "Layer 2 Microsoft Business Applications Bench Test Suite"
echo "=========================================="
echo

echo "Core (base-inherited):"
check "git" "git --version"
check "jq" "jq --version"
check "yq" "yq --version"
check "node" "node --version"
check "npm" "npm --version"
check "uv" "uv --version"
check "python3" "python3 --version"

echo
echo "Core (installed by this layer):"
check "httpie (http)" "http --version"
check "miller (mlr)" "mlr --version"
check "just" "just --version"
check "csvkit (csvstat)" "csvstat --version"
check "sops" "sops --version"
check "age" "age --version"
check "doppler" "doppler --version"
check "dotnet" "dotnet --version"

echo
echo "Auth and Dynamics 365 / Power Platform:"
check "Azure CLI (az)" "az version"
check "Power Platform CLI (pac)" "pac help"
check "M365 Power Platform commands" "m365 pp --help"
check "M365 Power Apps commands" "m365 pa --help"
check "M365 Power Automate commands" "m365 flow --help"

echo
echo "Business Central:"
check ".NET SDK 8" "dotnet --list-sdks | grep -q '^8\\.'"
check ".NET SDK 10" "dotnet --list-sdks | grep -q '^10\\.'"
check "AL Development Tools (al)" "al --version"
check "AL:Go project template" "dotnet new list algo | grep -q 'AL:Go'"

echo
echo "Compat (PowerShell 7 + modules):"
check "PowerShell 7 (pwsh)" "pwsh --version"
mod "Microsoft.Graph"
mod "Microsoft.Entra"
mod "ExchangeOnlineManagement"
mod "MicrosoftTeams"
mod "PnP.PowerShell"

echo
echo "M365 CLIs:"
check "CLI for Microsoft 365 (m365)" "m365 --version"
check "Microsoft Teams CLI (teams)" "teams --version"
check "Microsoft Graph CLI (mgc)" "mgc --version"

echo
echo "=========================================="
echo -e "Passed: ${GREEN}${PASS_COUNT}${NC}   Failed: ${RED}${FAIL_COUNT}${NC}"
echo "=========================================="

[ "$FAIL_COUNT" -eq 0 ]
