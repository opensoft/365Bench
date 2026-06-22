# 365Bench — Warp Notes

## Purpose
`365Bench` is a `sysBenches` Layer 2 bench for **Microsoft 365 business-stack
administration**, scoped to **user/tenant admin** (Entra ID, Exchange Online,
Teams, SharePoint/OneDrive). It is deliberately separate from `cloudBench`, which
owns Azure infrastructure / AKS.

## Layering
- Layer 1b base: `sys-bench-base:latest`
- Layer 2 image: `m365-bench:latest` (built by `build-layer2.sh` from `Dockerfile.layer2`)
- Layer 3 user image: `m365-bench:<user>` (via `../../scripts/ensure-layer3.sh`, called by `build-layer.sh`)
- Runtime: `.devcontainer/docker-compose.yml` mounts the full host home so per-user
  credentials/tokens persist; `network_mode: host`, `privileged`, docker.sock.

## Image / service naming
- Folder/repo: `365Bench`
- Docker image + compose service + container: `m365-bench`
- Compose project: `sys-benches` (shared across sysBenches)

## Tooling philosophy
Linux-only, cross-platform Microsoft admin tooling:
- PowerShell 7 + `Microsoft.Graph`, `Microsoft.Entra`, `ExchangeOnlineManagement`,
  `MicrosoftTeams`, `PnP.PowerShell`
- CLIs: `m365` (CLI for Microsoft 365), `mgc` (Microsoft Graph CLI), `az` (Entra via `az ad`)
- Windows-only modules (`MSOnline`, `AzureAD`, SharePoint Online Management Shell) are
  intentionally excluded — they cannot run on Linux. Use Graph/Entra/PnP equivalents.

## Codex skill wiring
- Bundled skill: `codex-skills/m365-mailbox-migration`
- Install helper: `./install-codex-skills.sh`
- Installed destination: `${CODEX_HOME:-$HOME/.codex}/skills/m365-mailbox-migration`
- Purpose: guide Exchange Online cross-tenant mailbox migration planning, target
  MailUser preparation, readiness validation, migration batch sequencing, and
  post-migration checks.

## Install scripts
- `install-365-tools-minimal.sh` — core set baked into the image (used by `Dockerfile.layer2`)
- `install-365-tools.sh` — full set = minimal + Power Platform CLI (`pac`) + beta modules

## Repo wiring
Standalone repo `git@github.com:opensoft/365Bench.git`, registered in `workBenches`
as a submodule at `sysBenches/365Bench` (same pattern as `sysBenches/cloudBench`).
When the bench changes: push the bench repo first, then bump the submodule pointer
in `workBenches`.
