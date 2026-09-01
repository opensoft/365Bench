#!/bin/bash
# Cross-platform Dynamics 365 / Power Platform / Business Central tools.
# Called by the full and minimal 365Bench installers.

set -euo pipefail

DOTNET_TOOL_DIR="${DOTNET_TOOL_DIR:-/opt/microsoft/dotnet-tools}"
DOTNET_SHARED_HOME="${DOTNET_CLI_HOME:-/opt/microsoft/dotnet-cli-home}"

echo "Installing .NET SDKs 8 and 10 (required by AL and PAC)..."
if ! dotnet --list-sdks 2>/dev/null | grep -q '^8\.' \
    || ! dotnet --list-sdks 2>/dev/null | grep -q '^10\.'; then
    if ! grep -Rqs 'packages\.microsoft\.com' /etc/apt/sources.list.d 2>/dev/null \
        && ! grep -qs 'packages\.microsoft\.com' /etc/apt/sources.list 2>/dev/null; then
        . /etc/os-release
        microsoft_feed="$(mktemp)"
        curl --proto '=https' --proto-redir '=https' --tlsv1.2 \
            --fail --silent --show-error --location --retry 3 \
            "https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb" \
            --output "$microsoft_feed"
        dpkg -i "$microsoft_feed"
        rm -f "$microsoft_feed"
    fi
    apt-get -o Acquire::Retries=5 update
    apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
        dotnet-sdk-8.0 \
        dotnet-sdk-10.0
    rm -rf /var/lib/apt/lists/*
fi
dotnet --list-sdks

mkdir -p "$DOTNET_TOOL_DIR" "$DOTNET_SHARED_HOME"
export DOTNET_CLI_HOME="$DOTNET_SHARED_HOME"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

echo "Installing Power Platform CLI (pac)..."
if [[ -x "$DOTNET_TOOL_DIR/pac" ]]; then
    dotnet tool update \
        --tool-path "$DOTNET_TOOL_DIR" \
        Microsoft.PowerApps.CLI.Tool
else
    dotnet tool install \
        --tool-path "$DOTNET_TOOL_DIR" \
        Microsoft.PowerApps.CLI.Tool
fi
ln -sf "$DOTNET_TOOL_DIR/pac" /usr/local/bin/pac
pac help >/dev/null

echo "Installing Business Central AL Development Tools (al)..."
if [[ -x "$DOTNET_TOOL_DIR/al" ]]; then
    dotnet tool update \
        --tool-path "$DOTNET_TOOL_DIR" \
        Microsoft.Dynamics.BusinessCentral.Development.Tools
else
    dotnet tool install \
        --tool-path "$DOTNET_TOOL_DIR" \
        Microsoft.Dynamics.BusinessCentral.Development.Tools
fi
ln -sf "$DOTNET_TOOL_DIR/al" /usr/local/bin/al
al --version

echo "Installing Business Central AL project templates..."
dotnet new install Microsoft.Dynamics.BusinessCentral.Development.Tools
dotnet new list algo | grep -q 'AL:Go'

# The image is single-user at runtime, but its username is added in Layer 3.
# Keep the shared template cache writable so that any Layer 3 user can refresh
# the templates without falling back to a root-only cache.
chmod -R a+rwX "$DOTNET_SHARED_HOME"

echo "Dynamics 365 / Business Central tools installed:"
echo "  pac (Power Platform CLI), al (Business Central AL CLI), AL:Go templates"
