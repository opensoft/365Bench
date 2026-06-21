#!/bin/bash
# Layer 2 Microsoft 365 Admin Tools Installation Script (Full)
# Full set = minimal core + extras (Power Platform CLI, beta PowerShell modules).
# The Dockerfile uses the *minimal* script by default; run this for the full set.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Core set first
bash "$SCRIPT_DIR/install-365-tools-minimal.sh"

echo ""
echo "=========================================="
echo "Installing FULL extras (Power Platform, beta modules)"
echo "=========================================="

# ----------------------------------------
# Power Platform CLI (pac) — .NET global tool (Power Apps / Power Automate admin)
# ----------------------------------------
if command -v dotnet >/dev/null 2>&1; then
    echo "Installing Power Platform CLI (pac)..."
    dotnet tool install --global Microsoft.PowerApps.CLI.Tool || echo "WARNING: pac install failed"
else
    echo "WARNING: dotnet SDK not found; skipping Power Platform CLI (pac)."
    echo "         Install the .NET SDK, then: dotnet tool install --global Microsoft.PowerApps.CLI.Tool"
fi

# ----------------------------------------
# Beta PowerShell modules (preview cmdlets)
# ----------------------------------------
echo "Installing beta PowerShell modules..."
pwsh -NoLogo -NoProfile -Command '
  $ErrorActionPreference = "Continue"
  try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted } catch {}
  foreach ($m in @("Microsoft.Graph.Beta","Microsoft.Entra.Beta")) {
    Write-Host "Installing module: $m ..."
    try { Install-Module -Name $m -Scope AllUsers -Force -AllowClobber -Repository PSGallery }
    catch { Write-Warning "Failed to install $m : $_" }
  }
'

echo ""
echo "✓ Full Microsoft 365 admin toolset installed."
