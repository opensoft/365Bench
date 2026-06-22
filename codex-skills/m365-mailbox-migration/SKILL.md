---
name: m365-mailbox-migration
description: Prepare, validate, and guide Microsoft 365 Exchange Online mailbox migrations between tenants. Use when Codex is asked to plan or run tenant-to-tenant mailbox moves, cross-tenant mailbox migration readiness, source mailbox attribute export, target MailUser creation, migration endpoint checks, migration batch creation, licensing/prerequisite checks, or post-migration Exchange Online cleanup.
---

# M365 Mailbox Migration

## Operating Rules

- Treat Microsoft 365 tenant migration as high-risk production work. Do not run destructive commands, delete objects, license/unlicense users, change domains, or start migration batches without explicit user approval.
- Prefer dry-run/readiness checks first. Confirm source tenant, target tenant, domains, user scope, and rollback expectations before write operations.
- Use current Microsoft Learn guidance for volatile requirements, licensing, cmdlet names, and preview features before giving final procedural advice.
- Keep secrets, tenant IDs, app IDs, certificates, and exported CSVs out of chat unless the user explicitly asks to inspect sanitized examples.

## Workflow

1. Scope the move: source tenant, target tenant, mailbox count, domains, hybrid/cloud-only status, archive/litigation hold needs, and cutover window.
2. Verify prerequisites: ExchangeOnlineManagement module, administrator roles, accepted domains, cross-tenant access/trust setup, licenses, migration endpoint, and user object strategy.
3. Export source mailbox attributes: `ExchangeGuid`, `ArchiveGuid`, `LegacyExchangeDN`, primary SMTP, aliases, X500 addresses, archive state, hold state, and target UPN/SMTP mapping.
4. Prepare target users as MailUsers. The target recipient must not already have a mismatched mailbox/ExchangeGuid. Stamp the source GUIDs and X500 addresses before migration readiness tests.
5. Validate every target user with `Test-MigrationServerAvailability` or the current Microsoft-recommended readiness/orchestrator checks.
6. Create and monitor migration batches from the target tenant only after readiness succeeds.
7. Run post-migration checks: mailbox access, mail flow, aliases, archives, permissions, forwarding, mobile/client behavior, and cleanup timing.

## Bench Context

In `365Bench`, expect Linux plus PowerShell 7 with `ExchangeOnlineManagement`, `Microsoft.Graph`, `Microsoft.Entra`, CSV tooling, and Microsoft CLIs. Prefer cross-platform PowerShell and Graph/Entra tooling. Avoid legacy Windows-only modules such as `MSOnline` and `AzureAD`.

If working with `/home/brett/projects/365-Cross-Tenant-Migration`, use those scripts as migration-prep helpers:

- `CrossTenantMigration-Report.ps1` exports source attributes.
- `DestinationUserCreation.ps1` creates and stamps target MailUsers.
- `FinalChecks.ps1` runs migration endpoint availability checks.

Modernize or parameterize those scripts before use in a real tenant; they currently include hard-coded paths, placeholder destination SMTP values, and a hard-coded password.

## Detailed Reference

Read `references/runbook.md` when the user wants concrete commands, a runbook, script changes, readiness troubleshooting, or end-to-end migration sequencing.
