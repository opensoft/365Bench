# 365Bench — Microsoft 365 Administration

A `sysBenches` Layer 2 bench for administering the **Microsoft 365 business stack** —
focused on **user/tenant administration** (Entra ID, Exchange Online, Teams,
SharePoint/OneDrive). This bench is intentionally **not** for Azure infrastructure
or AKS work — use `cloudBench` for that.

## Quick Start

### Build the Image
```bash
./build-layer.sh
```
Builds `m365-bench:latest` (Layer 2) on top of `sys-bench-base:latest` (Layer 1b),
then ensures the per-user Layer 3 image via `scripts/ensure-layer3.sh`. If you only
need to rebuild the shared Layer 2 image, run `./build-layer2.sh`.

> ⚠️ The build installs the **Microsoft.Graph** PowerShell SDK (large) plus several
> other modules, so the first build is heavy and network-intensive.

### Create a Workspace
```bash
cp -r devcontainer.example workspaces/my-project
cd workspaces/my-project
code .   # Open in VS Code and "Reopen in Container"
```

## What's Included (Layer 2)

All tooling is **cross-platform** (Linux + PowerShell 7), since this is a Linux container.
The full set is baked into the image via `install-365-tools.sh`.

### Core — inherited from base layers (Layer 0/1b)
- **git**, **curl**, **jq**, **yq**, **make** — standard utilities
- **Node.js / npm / npx** — runtime for npm-based M365 CLIs
- **uv / uvx** — Python manager; provides MCP server runtime
- **python3 / pip** — scripting and pip-based tools

### Core — installed by this layer
- **httpie** (`http`) — human-friendly HTTP client
- **just** — command runner (Justfile support)
- **sops** + **age** — secret encryption at rest
- **doppler** — secret CLI for runtime secret injection
- **.NET SDK 8** (`dotnet`) — required for `pac`
- **csvkit** (`csvstat`, `csvcut`, etc.) — CSV processing
- **miller** (`mlr`) — CSV / JSON / NDJSON stream processor

### Optional Auth Layer
- **Azure CLI** (`az`) — Entra ID / `az ad` operations (inherited from Layer 1b)
- **Power Platform CLI** (`pac`) — Power Apps / Power Automate admin

### Optional Compatibility Layer (PowerShell)
- **PowerShell 7** (`pwsh`) — runtime for all Microsoft admin modules
- **Microsoft.Graph** — users, groups, licensing, devices, directory (core)
- **Microsoft.Entra** — Entra ID (Azure AD) administration
- **ExchangeOnlineManagement** — Exchange Online + Security & Compliance
- **MicrosoftTeams** — Teams administration (PowerShell)
- **PnP.PowerShell** — SharePoint Online / OneDrive administration

### M365 CLIs
- **CLI for Microsoft 365** (`m365`) — cross-platform M365 admin/scripting
- **Microsoft Teams CLI** (`teams`) — Teams Toolkit CLI (preview)
- **Microsoft Graph CLI** (`mgc`) — cross-platform Microsoft Graph access

## Authentication
Sign in interactively per tool (device-code / browser):
```bash
Connect-MgGraph                      # Microsoft Graph PowerShell
Connect-ExchangeOnline               # Exchange Online
Connect-MicrosoftTeams               # Teams
Connect-PnPOnline -Url <site> -Interactive
m365 login                           # CLI for Microsoft 365
mgc login                            # Microsoft Graph CLI
az login                             # Azure CLI (Entra)
```
The container mounts your host home directory, so tokens persist between sessions.

## Not Included (and why)
These are **Windows-only** and cannot run in a Linux container:
- **MSOnline** and **AzureAD** — legacy and deprecated; superseded by `Microsoft.Graph` / `Microsoft.Entra`.
- **SharePoint Online Management Shell** (`Microsoft.Online.SharePoint.PowerShell`) — use **PnP.PowerShell** instead.

## Architecture
```
Layer 0: workbench-base:latest   — Ubuntu, system tools, AI CLIs
Layer 1b: sys-bench-base:latest  — sys/ops base
Layer 2: m365-bench:latest       — M365 admin tools (this bench, user-agnostic)
Layer 3: m365-bench:<user>       — per-user image (ensure-layer3.sh)
```

## Testing
```bash
cd devcontainer.test
docker compose up -d
docker compose exec test /test/test.sh
docker compose down
```
Asserts `pwsh`, each PowerShell module, and `m365`/`mgc`/`az` are present.
