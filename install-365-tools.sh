#!/bin/bash
# Layer 2 Microsoft 365 Admin Tools Installation Script
# Full set — everything baked into the Docker image.
# Used directly by Dockerfile.layer2.
#
# NOTE: git, jq, yq, make, node/npm/npx, uv/uvx, python3/pip, az CLI
#       are inherited from Layer 0/1b and do NOT need to be reinstalled here.
# NOTE: ALTool identity unknown — add manually once identified.

set -e

ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"

# Robust download with resume and retries (mirrors cloudBench pattern)
download() {
    local url="$1"
    local output="$2"
    local temp_output
    local attempt
    local max_attempts="${DOWNLOAD_ATTEMPTS:-10}"

    temp_output="$(mktemp)"
    for attempt in $(seq 1 "$max_attempts"); do
        if curl --fail --location --show-error --continue-at - \
            --retry 3 --retry-delay 5 --retry-all-errors \
            --connect-timeout 30 --speed-limit 1024 --speed-time 120 \
            "$url" -o "$temp_output"; then
            mv "$temp_output" "$output"
            return 0
        fi
        if [ "$attempt" -eq "$max_attempts" ]; then
            rm -f "$temp_output"
            echo "ERROR: download failed after $max_attempts attempts: $url" >&2
            return 1
        fi
        echo "Download failed; retrying ${attempt}/${max_attempts}..."
        sleep 5
    done
}

echo "=========================================="
echo "Installing Layer 2 Microsoft 365 Admin Tools"
echo "=========================================="

# ----------------------------------------
# CORE: httpie, miller
# (curl/jq/yq/git/make/node/uv inherited from base layers)
# ----------------------------------------
echo "Installing httpie, miller..."
apt-get update && apt-get install -y --no-install-recommends \
    httpie \
    miller \
    && rm -rf /var/lib/apt/lists/*
http --version
mlr --version

# ----------------------------------------
# CORE: just (command runner)
# ----------------------------------------
echo "Installing just..."
JUST_VERSION="$(curl -s https://api.github.com/repos/casey/just/releases/latest | grep '"tag_name"' | sed -E 's/.*"([0-9][^"]+)".*/\1/' | head -1)"
[ -z "$JUST_VERSION" ] && JUST_VERSION="1.36.0"
case "$ARCH" in
    arm64) JUST_ARCH="aarch64-unknown-linux-musl" ;;
    *)     JUST_ARCH="x86_64-unknown-linux-musl" ;;
esac
download "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-${JUST_ARCH}.tar.gz" /tmp/just.tar.gz
tar -xzf /tmp/just.tar.gz -C /usr/local/bin just
rm /tmp/just.tar.gz
chmod +x /usr/local/bin/just
just --version

# ----------------------------------------
# CORE: CSV tools (csvkit via pip; miller via apt above)
# ----------------------------------------
echo "Installing csvkit..."
pip3 install --break-system-packages csvkit 2>/dev/null \
    || pip3 install csvkit \
    || echo "WARNING: csvkit install failed"
command -v csvstat >/dev/null 2>&1 && csvstat --version || true

# ----------------------------------------
# CORE: Secrets management — sops, age, doppler
# ----------------------------------------
echo "Installing sops..."
SOPS_VERSION="$(curl -s https://api.github.com/repos/getsops/sops/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)"
[ -z "$SOPS_VERSION" ] && SOPS_VERSION="3.9.4"
download "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" \
    /usr/local/bin/sops
chmod +x /usr/local/bin/sops
sops --version

echo "Installing age..."
AGE_VERSION="$(curl -s https://api.github.com/repos/FiloSottile/age/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)"
[ -z "$AGE_VERSION" ] && AGE_VERSION="1.2.0"
download "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" \
    /tmp/age.tar.gz
tar -xzf /tmp/age.tar.gz -C /usr/local/bin --strip-components=1 age/age age/age-keygen
rm /tmp/age.tar.gz
chmod +x /usr/local/bin/age /usr/local/bin/age-keygen
age --version

echo "Installing doppler (secret CLI)..."
curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
    'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' \
    | gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" \
    | tee /etc/apt/sources.list.d/doppler-cli.list
apt-get update && apt-get install -y doppler && rm -rf /var/lib/apt/lists/*
doppler --version

# ----------------------------------------
# COMPAT: PowerShell 7 (foundation for PS admin modules)
# ----------------------------------------
if ! command -v pwsh >/dev/null 2>&1; then
    echo "Installing PowerShell 7..."
    . /etc/os-release
    download "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" \
        /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    rm -f /tmp/packages-microsoft-prod.deb
    apt-get -o Acquire::Retries=5 update && apt-get -o Acquire::Retries=5 install -y powershell && rm -rf /var/lib/apt/lists/*
fi
pwsh --version

# ----------------------------------------
# DYNAMICS: Power Platform CLI + Business Central AL tooling
# Current PAC releases require .NET 10 while stable AL tools target .NET 8.
# The helper installs both SDKs, system-wide pac and al commands, and the
# Business Central AL:Go templates.
# ----------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/install-business-apps-tools.sh"

# ----------------------------------------
# COMPAT: PowerShell admin modules
# ----------------------------------------
echo "Installing PowerShell admin modules (Microsoft.Graph is large)..."
pwsh -NoLogo -NoProfile -Command '
  $ErrorActionPreference = "Stop"
  try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted } catch {}
  $mods = @(
    "Microsoft.Graph",
    "Microsoft.Entra",
    "ExchangeOnlineManagement",
    "MicrosoftTeams",
    "PnP.PowerShell"
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
# M365: CLI for Microsoft 365 (m365)
# ----------------------------------------
echo "Installing CLI for Microsoft 365 (m365)..."
npm install -g @pnp/cli-microsoft365 || echo "WARNING: m365 CLI install failed (install manually: npm i -g @pnp/cli-microsoft365)"
command -v m365 >/dev/null 2>&1 && m365 --version || true

# ----------------------------------------
# M365: Microsoft Teams CLI
# ----------------------------------------
echo "Installing Microsoft Teams CLI (@microsoft/teams.cli@preview)..."
npm install -g @microsoft/teams.cli@preview || echo "WARNING: Teams CLI install failed (install manually: npm i -g @microsoft/teams.cli@preview)"
command -v teams >/dev/null 2>&1 && teams --version || true

# ----------------------------------------
# M365: Microsoft Graph CLI (mgc)
# ----------------------------------------
echo "Installing Microsoft Graph CLI (mgc)..."
case "$ARCH" in
    amd64) MGC_ARCH="linux-x64" ;;
    arm64) MGC_ARCH="linux-arm64" ;;
    *)     MGC_ARCH="linux-x64" ;;
esac
MGC_VERSION="$(curl -s https://api.github.com/repos/microsoftgraph/msgraph-cli/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/' | head -1)"
[ -z "$MGC_VERSION" ] && MGC_VERSION="1.10.0"
if download "https://github.com/microsoftgraph/msgraph-cli/releases/download/v${MGC_VERSION}/msgraph-cli-${MGC_ARCH}-${MGC_VERSION}.tar.gz" /tmp/mgc.tar.gz; then
    tar -xzf /tmp/mgc.tar.gz -C /usr/local/bin mgc 2>/dev/null || tar -xzf /tmp/mgc.tar.gz -C /usr/local/bin
    rm -f /tmp/mgc.tar.gz
    chmod +x /usr/local/bin/mgc 2>/dev/null || true
    /usr/local/bin/mgc --version || true
else
    echo "WARNING: mgc download failed (check github.com/microsoftgraph/msgraph-cli/releases)"
fi

# ----------------------------------------
# AUTH: Azure CLI (az) — verify/install if missing
# (already in Layer 1b; install only if absent)
# ----------------------------------------
if ! command -v az >/dev/null 2>&1; then
    echo "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash || echo "WARNING: Azure CLI install failed"
fi
command -v az >/dev/null 2>&1 && az version || true

echo ""
echo "=========================================="
echo "✓ Layer 2 Microsoft 365 Admin Tools Complete"
echo "=========================================="
echo "Core (installed here):"
echo "  httpie, just, sops, age, doppler, dotnet SDKs 8/10, csvkit, miller (mlr)"
echo "Core (inherited from base layers):"
echo "  git, jq, yq, make, node/npm/npx, uv/uvx (MCP runtime), python3/pip"
echo "Auth:    az CLI, pac (Power Platform CLI)"
echo "Compat:  pwsh 7, Microsoft.Graph, Microsoft.Entra,"
echo "         ExchangeOnlineManagement, MicrosoftTeams, PnP.PowerShell"
echo "M365:    m365 CLI, teams CLI, mgc (Graph CLI)"
echo "D365:    pac; m365 pp/pa/flow command groups"
echo "MSBC:    al CLI/compiler/MCP, AL:Go project templates"
