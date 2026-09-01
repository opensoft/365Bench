# 365Bench — Microsoft Business Applications

A `sysBenches` Layer 2 bench for administering and developing against the
**Microsoft business applications stack**:

- Microsoft 365: Entra ID, Exchange Online, Teams, SharePoint, and OneDrive
- Dynamics 365 CRM / Dataverse and the wider Power Platform
- Dynamics 365 Business Central online and externally hosted environments

This is a Linux container. It includes the maximum Microsoft-supported
cross-platform toolset, while Windows-only GUI and server utilities are called
out explicitly below. Use `cloudBench` for Azure infrastructure or AKS work.

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

The full set is baked into the image via `install-365-tools.sh` and
`install-business-apps-tools.sh`.

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
- **.NET SDKs 8 and 10** (`dotnet`) — runtimes for stable AL tools, current
  Power Platform CLI, plug-ins, and other business-app projects
- **csvkit** (`csvstat`, `csvcut`, etc.) — CSV processing
- **miller** (`mlr`) — CSV / JSON / NDJSON stream processor

### Authentication
- **Azure CLI** (`az`) — Entra ID / `az ad` operations (inherited from Layer 1b)
- **Power Platform CLI** (`pac`) — environment and Dataverse authentication

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

### Dynamics 365 CRM / Dataverse / Power Platform
- **Power Platform CLI** (`pac`) — environments, solutions, plug-ins, PCF,
  model-driven and canvas apps, connectors, Power Pages, pipelines, packages,
  Dataverse model generation, solution checking, and Power Platform MCP
- **CLI for Microsoft 365 Power Platform groups** — `m365 pp`, `m365 pa`, and
  `m365 flow` for Dataverse, solutions, Power Apps, and Power Automate
- **Power Platform Tools for VS Code**
  (`microsoft-IsvExpTools.powerplatform-vscode`) — official interactive
  environment, solution, package, and portal tooling
- **Node.js/npm and .NET SDKs 8/10** — PCF controls and Dataverse plug-in projects

### Dynamics 365 Business Central
- **AL Development Tools** (`al`) — AL compilation and packaging, multi-project
  workspaces, package inspection, publishing, authentication, and the AL MCP
  server
- **AL:Go template** (`dotnet new algo`) — bootstrap AL/AL-Go projects
- **AL Language extension** (`ms-dynamics-smb.al`) — IntelliSense, compilation,
  publishing, debugging, code analyzers, and agent tools in VS Code
- **HTTPie / REST Client / Azure CLI / PowerShell** — Business Central REST,
  OData, automation, and administration-center APIs
- **GitHub CLI** (`gh`, inherited) — AL-Go for GitHub workflows

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
pac auth create --deviceCode         # Power Platform / Dataverse
al auth login                        # Business Central AL tooling
```
The container mounts your host home directory, so tokens persist between sessions.

## Common Dynamics Workflows

```bash
# Inspect the available CRM / Power Platform commands
pac help
m365 pp --help

# Start a Business Central AL/AL-Go project
dotnet new algo --name MyBusinessCentralExtension

# Inspect the Business Central compiler, workspace, and MCP commands
al --help
```

Publishing, deployment, tenant administration, and data mutation still require
the appropriate tenant roles and an explicitly selected target environment.

## Codex Skills

This bench includes a Codex skill for Microsoft 365 cross-tenant mailbox migration:

- `m365-mailbox-migration` — workflow guidance for Exchange Online tenant-to-tenant
  mailbox moves, source attribute export, target MailUser preparation, endpoint
  readiness checks, migration batch sequencing, and post-migration validation.

Install or refresh the bundled skill into your Codex home:

```bash
./install-codex-skills.sh
```

The skill is stored in `codex-skills/m365-mailbox-migration` so it travels with
`365Bench`, while installation copies it to `${CODEX_HOME:-$HOME/.codex}/skills`
for normal Codex discovery.

## Not Included (and why)

These tools are **Windows-only** and cannot run as supported tools in this
Linux container:

- **XrmToolBox**
- **Plug-in Registration Tool**, **Configuration Migration Tool**, and
  **Package Deployer** GUIs (`pac tool ...` requires the .NET Framework build
  of PAC). The cross-platform `pac plugin`, `pac package`, `pac solution`, and
  Dataverse API workflows remain available.
- **Power Platform administration and checker PowerShell modules** that require
  Windows PowerShell 5.x / .NET Framework. Use `pac`, `m365`, or the supported
  service APIs here.
- **Local Business Central Windows containers**, the Business Central
  Administration Shell, and Windows server tooling. Connect the Linux bench to
  Business Central online sandboxes or an externally reachable server.
- **MSOnline** and **AzureAD** — legacy and deprecated; superseded by `Microsoft.Graph` / `Microsoft.Entra`.
- **SharePoint Online Management Shell** (`Microsoft.Online.SharePoint.PowerShell`) — use **PnP.PowerShell** instead.

## Architecture
```
Layer 0: workbench-base:latest   — Ubuntu, system tools, AI CLIs
Layer 1b: sys-bench-base:latest  — sys/ops base
Layer 2: m365-bench:latest       — Microsoft business-app tools (this bench)
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
