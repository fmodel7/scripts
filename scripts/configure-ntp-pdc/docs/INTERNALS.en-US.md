# Internal reference — 2.0.0

Both PS1 files embed the same functions; they are not a public API or module. Entry points exit their process; do not dot-source them. AST extraction is used only by tests.

## Get-TimeNativePath

Selects a SystemDirectory binary without PATH lookup. [PDC source](../Configure-NTP-PDC.ps1#L36).

## Invoke-TimeNative

Runs without a shell, captures stdout/stderr, requires exit zero and enforces a 30 s timeout. [PDC source](../Configure-NTP-PDC.ps1#L41).

## Get-TimeSettings

Reads Type, NtpServer, AnnounceFlags and two provider Enabled values. [PDC source](../Configure-NTP-PDC.ps1#L74).

## Get-TimeContext

Checks runtime/token/server and captures computer domain, root PDC, policy, service, identity, IPs and settings. [PDC source](../Configure-NTP-PDC.ps1#L85).

## Assert-TimeTarget

Blocks policy, disabled service and a role incompatible with PDC/DOMHIER. [PDC source](../Configure-NTP-PDC.ps1#L119).

## Resolve-TimeAddresses

.NET DNS adapter; does not prove NTP reachability or trust. [PDC source](../Configure-NTP-PDC.ps1#L130).

## Get-TimePeerList

Normalizes/validates 1–10 names, resolves and rejects invalid addresses, then builds 0x8/0xA flags. [PDC source](../Configure-NTP-PDC.ps1#L135).

## New-TimeRunFolder

Creates a UTC/GUID run folder in LocalApplicationData with inherited ACLs. [PDC source](../Configure-NTP-PDC.ps1#L166).

## Write-TimeJournal

Appends JSONL with FileStream and calls Flush(true). [PDC source](../Configure-NTP-PDC.ps1#L174).

## Invoke-TimeMutation

Writes INTENT, executes a stage and writes COMPLETED only without an error. [PDC source](../Configure-NTP-PDC.ps1#L182).

## Backup-TimeRegistry

Exports the W32Time branch, requiring native success and a nonempty file. [PDC source](../Configure-NTP-PDC.ps1#L189).

## Set-TimeRegistry

Enables the client, sets automatic advertisement and enables the server only in PDC mode. [PDC source](../Configure-NTP-PDC.ps1#L197).

## Set-TimeService

Starts/restarts without Force and waits up to 30 s for Running. [PDC source](../Configure-NTP-PDC.ps1#L207).

## Get-TimeDiagnostics

Queries configuration/source/status verbose/peers and records individual errors. [PDC source](../Configure-NTP-PDC.ps1#L214).

## Test-TimeConfiguration

Checks Running, DWORDs, Type and manual peers for PDC; does not assess time health. [PDC source](../Configure-NTP-PDC.ps1#L226).

## Write-TimeReport

Writes technical JSON and bilingual offline encoded HTML without JavaScript. [PDC source](../Configure-NTP-PDC.ps1#L236).

## Invoke-TimeSetup

Coordinates preflight, confirmation, mutex, backup, revalidation, mutations and final result. [PDC source](../Configure-NTP-PDC.ps1#L268).

Actual AD/service/registry operations and the UDP path require lab acceptance.
