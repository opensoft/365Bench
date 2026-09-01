#!/bin/bash
# Layer 2 Microsoft 365 Admin Tools Installation Script (Minimal)
# Cross-platform M365 user/tenant admin tooling on top of sys-bench-base (Layer 1b).
# This is the core set baked into the image by Dockerfile.layer2.

set -e

echo "=========================================="
echo "Installing Layer 2 Microsoft 365 Admin Tools"
echo "=========================================="

ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"

# ----------------------------------------
# PowerShell 7 (foundation for all MS admin modules)
# ----------------------------------------
if ! command -v pwsh >/dev/null 2>&1; then
    echo "Installing PowerShell 7..."
    . /etc/os-release
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
        "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" \
        -o /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    rm -f /tmp/packages-microsoft-prod.deb
    apt-get update
    apt-get install -y powershell
    rm -rf /var/lib/apt/lists/*
fi
pwsh --version

# ----------------------------------------
# Node.js LTS (required for CLI for Microsoft 365)
# ----------------------------------------
if ! command -v node >/dev/null 2>&1; then
    echo "Installing Node.js LTS..."
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL \
        https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
    rm -rf /var/lib/apt/lists/*
fi
node --version

# ----------------------------------------
# Dynamics 365 / Power Platform / Business Central essentials
# ----------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/install-business-apps-tools.sh"

# ----------------------------------------
# PowerShell admin modules (cross-platform, AllUsers scope)
#   AllUsers installs under /usr/local/share/powershell/Modules so the Layer 3
#   non-root user can load them (nothing under /root).
# ----------------------------------------
echo "Installing PowerShell admin modules (Microsoft.Graph is large)..."
pwsh -NoLogo -NoProfile -Command '
  $ErrorActionPreference = "Stop"
  try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted } catch {}
  $mods = @(
    "Microsoft.Graph",            # Users, groups, licensing, devices, directory (core)
    "Microsoft.Entra",            # Entra ID (Azure AD) administration
    "ExchangeOnlineManagement",   # Exchange Online + Security & Compliance
    "MicrosoftTeams",             # Teams administration
    "PnP.PowerShell"              # SharePoint Online / OneDrive administration
  )
  $failed = @()
  foreach ($m in $mods) {
    Write-Host "Installing module: $m ..."
    try { Install-Module -Name $m -Scope AllUsers -Force -AllowClobber -Repository PSGallery }
    catch { Write-Warning "Failed to install $m : $_"; $failed += $m }
  }
  if ($failed.Count -gt 0) { Write-Warning ("Modules failed: " + ($failed -join ", ")); exit 1 }
  Write-Host "All PowerShell modules installed."
'

# ----------------------------------------
# CLI for Microsoft 365 (cross-platform, npm)
# ----------------------------------------
echo "Installing CLI for Microsoft 365 (m365)..."
npm install -g --ignore-scripts @pnp/cli-microsoft365 || echo "WARNING: m365 CLI install failed (install manually: npm i -g --ignore-scripts @pnp/cli-microsoft365)"
command -v m365 >/dev/null 2>&1 && m365 --version || true

# ----------------------------------------
# Microsoft Teams CLI (teams, preview npm package)
# ----------------------------------------
echo "Installing Microsoft Teams CLI (@microsoft/teams.cli@preview)..."
npm install -g --ignore-scripts @microsoft/teams.cli@preview || echo "WARNING: Teams CLI install failed (install manually: npm i -g --ignore-scripts @microsoft/teams.cli@preview)"
command -v teams >/dev/null 2>&1 && teams --version || true

# ----------------------------------------
# Microsoft Graph CLI (mgc, cross-platform Go binary) — best effort
# ----------------------------------------
echo "Installing Microsoft Graph CLI (mgc)..."
case "$ARCH" in
    amd64) MGC_ARCH="linux-x64" ;;
    arm64) MGC_ARCH="linux-arm64" ;;
    *)     MGC_ARCH="linux-x64" ;;
esac
MGC_VERSION="$(curl -s https://api.github.com/repos/microsoftgraph/msgraph-cli/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)"
if [ -z "$MGC_VERSION" ]; then MGC_VERSION="1.10.0"; fi
if curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fL \
    "https://github.com/microsoftgraph/msgraph-cli/releases/download/v${MGC_VERSION}/msgraph-cli-${MGC_ARCH}-v${MGC_VERSION}.tar.gz" \
    -o /tmp/mgc.tar.gz; then
    tar -xzf /tmp/mgc.tar.gz -C /usr/local/bin mgc 2>/dev/null || tar -xzf /tmp/mgc.tar.gz -C /usr/local/bin
    rm -f /tmp/mgc.tar.gz
    chmod +x /usr/local/bin/mgc 2>/dev/null || true
    /usr/local/bin/mgc --version || true
else
    echo "WARNING: mgc download failed (check latest asset name at github.com/microsoftgraph/msgraph-cli/releases)"
fi

# ----------------------------------------
# Azure CLI (for `az ad` / Entra operations) — install if missing
# ----------------------------------------
if ! command -v az >/dev/null 2>&1; then
    echo "Installing Azure CLI..."
    curl --proto '=https' --proto-redir '=https' --tlsv1.2 -sL \
        https://aka.ms/InstallAzureCLIDeb | bash || echo "WARNING: Azure CLI install failed"
fi
command -v az >/dev/null 2>&1 && az version || true

echo ""
echo "=========================================="
echo "✓ Layer 2 Microsoft 365 Admin Tools Complete"
echo "=========================================="
echo "Installed: pwsh 7, Node.js, Microsoft.Graph, Microsoft.Entra,"
echo "           ExchangeOnlineManagement, MicrosoftTeams, PnP.PowerShell,"
echo "           m365 CLI, teams CLI, mgc (Graph CLI), az CLI,"
echo "           pac (Power Platform CLI), al (Business Central AL CLI)"
