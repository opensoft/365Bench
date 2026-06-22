# Microsoft 365 Cross-Tenant Mailbox Migration Runbook

## First Checks

- Confirm whether the mailbox source and target are Exchange Online. If mailboxes are still on-premises, identify the hybrid path before using cloud-to-cloud migration steps.
- Confirm the target object model: cloud-only MailUsers, synchronized MailUsers, or Microsoft cross-tenant identity mapping/orchestrator.
- Verify the migration is Exchange mailbox migration only unless the user explicitly includes OneDrive, Teams, SharePoint, devices, or identity migration.
- Browse current Microsoft Learn pages before finalizing guidance because licensing, CTIM/orchestrator, and preview behavior can change.

Useful Microsoft Learn entry points:

- Cross-tenant mailbox migration: `https://learn.microsoft.com/en-us/microsoft-365/migration/cross-tenant-mailbox-migration`
- Cross-tenant identity mapping: `https://learn.microsoft.com/en-us/microsoft-365/migration/cross-tenant-identity-mapping`
- Migration Orchestrator user prep: `https://learn.microsoft.com/en-us/microsoft-365/migration/migration-orchestrator-4-user-prep`
- Exchange migration batch overview: `https://learn.microsoft.com/en-us/exchange/mailbox-migration/mailbox-migration`

## Required Data

Collect or produce a CSV with one row per mailbox. Recommended columns:

- `SourceUPN`
- `SourcePrimarySmtp`
- `TargetUPN`
- `TargetPrimarySmtp`
- `DisplayName`
- `ExchangeGuid`
- `ArchiveGuid`
- `LegacyExchangeDN`
- `AdditionalX500`
- `Aliases`
- `ArchiveEnabled`
- `LitigationHoldEnabled`
- `MigrationEndpoint`

For source export, use `Get-Mailbox` from the source tenant and include `EmailAddresses` values beginning with `X500:`. Preserve the original `LegacyExchangeDN` as an `x500:` proxy on the target.

## Target MailUser Rules

- The target object must be a MailUser suitable for cross-tenant migration, not an already-provisioned mailbox with a mismatched `ExchangeGuid`.
- If a target cloud object was previously licensed for Exchange and has stale mailbox info, current Microsoft guidance may require cleanup such as `Set-User <identity> -PermanentlyClearPreviousMailboxInfo`; verify current docs before running it.
- Stamp the source `ExchangeGuid`; stamp `ArchiveGuid` only when source archive migration applies.
- Add `x500:` + source `LegacyExchangeDN` and all additional X500 proxies to preserve replyability.
- Avoid hard-coded temporary passwords in reusable scripts. Prefer secure generated credentials or an account creation process approved by the tenant owner.

## Command Pattern

Connect explicitly and label sessions in notes:

```powershell
Connect-ExchangeOnline -UserPrincipalName admin@source.example
Connect-ExchangeOnline -UserPrincipalName admin@target.example
```

Export attributes in source:

```powershell
$users = Import-Csv .\users.csv
$users | ForEach-Object {
  $mbx = Get-Mailbox -Identity $_.SourceUPN
  [pscustomobject]@{
    SourceUPN = $_.SourceUPN
    SourcePrimarySmtp = $mbx.PrimarySmtpAddress
    TargetUPN = $_.TargetUPN
    TargetPrimarySmtp = $_.TargetPrimarySmtp
    DisplayName = $mbx.DisplayName
    ExchangeGuid = $mbx.ExchangeGuid
    ArchiveGuid = $mbx.ArchiveGuid
    LegacyExchangeDN = $mbx.LegacyExchangeDN
    AdditionalX500 = (($mbx.EmailAddresses | Where-Object { $_ -match '^X500:' }) -join ';')
  }
} | Export-Csv .\migration-attributes.csv -NoTypeInformation -Encoding UTF8
```

Prepare target MailUsers only after confirming the correct tenant session:

```powershell
$rows = Import-Csv .\migration-attributes.csv
$rows | ForEach-Object {
  $legacy = "x500:$($_.LegacyExchangeDN)"
  $x500 = @($legacy) + (($_.AdditionalX500 -split ';') | Where-Object { $_ })
  Set-MailUser -Identity $_.TargetUPN `
    -ExchangeGuid $_.ExchangeGuid `
    -EmailAddresses @{ add = $x500 }
}
```

If creating MailUsers with `New-MailUser`, parameterize the password, target routing, UPN, and primary SMTP. Do not reuse the sample password from legacy scripts.

Validate readiness:

```powershell
$endpoint = "CrossTenantEndpointName"
Import-Csv .\migration-attributes.csv | ForEach-Object {
  Test-MigrationServerAvailability -Endpoint $endpoint -TestMailbox $_.TargetPrimarySmtp |
    Format-List Result,Message
}
```

Start migration batches only after all scoped users pass readiness and the user confirms timing.

## Script Improvement Checklist

When editing migration scripts:

- Add parameters for input CSV, output CSV, destination domain, endpoint name, and dry-run mode.
- Add `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`.
- Use `-WhatIf` where supported and add explicit `-Confirm:$false` only when the user approves automation.
- Cache `Get-Mailbox` results per user instead of calling it repeatedly.
- Emit machine-readable logs and a final summary CSV with success/failure per user.
- Validate required CSV headers before tenant writes.
- Handle empty archive GUIDs and empty X500 lists.
- Never embed tenant passwords or secrets.

## Troubleshooting Cues

- `ExchangeGuid` mismatch: inspect whether the target object was ever mailbox-enabled; verify cleanup guidance before clearing previous mailbox data.
- Missing X500/legacy DN: old replies may NDR after migration; add source legacy DN as `x500:` and include all X500 proxies.
- Endpoint test fails for all users: inspect trust/organization relationship, endpoint config, app permissions, licensing, and tenant pairing.
- Endpoint test fails for one user: inspect target MailUser recipient type, GUIDs, archive GUID, primary SMTP mapping, and source mailbox state.
- Archive errors: confirm archive is enabled/supported and `ArchiveGuid` handling matches the migration plan.
