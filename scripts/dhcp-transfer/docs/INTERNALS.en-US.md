# Internal functions — DHCP Transfer 1.0.0

The PS1 files are executable entry points, not modules. Do not dot-source. The embedded worker is identical in both files; internal functions are not a public API.

## Invoke-DhcpWorker

Complete target-side worker: preflight, mutex, export/import, backups and reporting. [Source](../Export-DHCP.ps1#L29).

## Get-DhcpContext

Checks Windows Server/PowerShell 5.1/elevation/service, loads DhcpServer and reads local scopes/failover. [Source](../Export-DHCP.ps1#L34).

## Resolve-DhcpPath

Requires an absolute local volume path and rejects UNC/network, wildcards, ADS and existing reparse points. [Source](../Export-DHCP.ps1#L58).

## Test-DhcpFileName

Validates simple ASCII XML leaf names, extension, length and reserved DOS names. [Source](../Export-DHCP.ps1#L79).

## Get-DhcpXmlInfo

Streaming DTD-prohibited read checks root/document and computes bytes/SHA256. Not XSD validation. [Source](../Export-DHCP.ps1#L87).

## Invoke-DhcpExport

Calls local Export-DhcpServer without Force, with explicit Leases and terminating errors/warnings. [Source](../Export-DHCP.ps1#L110).

## Invoke-DhcpBackup

Calls local Backup-DhcpServer with terminating errors/warnings. [Source](../Export-DHCP.ps1#L116).

## Invoke-DhcpImport

Imports snapshot with explicit BackupPath, Leases and ScopeOverwrite; captures warnings. Force suppresses native prompting after outer approval. [Source](../Export-DHCP.ps1#L121).

## Restart-DhcpLocalService

Restarts on target without ComputerName/Force and waits up to 30 s for Running after Restart-Service returns. [Source](../Export-DHCP.ps1#L129).

## Write-DhcpJournal

Appends JSONL through FileStream and Flush(true). [Source](../Export-DHCP.ps1#L134).

## Write-DhcpReport

Writes JSON and bilingual offline HTML with encoded inserted data. [Source](../Export-DHCP.ps1#L142).

## Copy-DhcpSnapshot

Copies a read-open source to a CreateNew destination and calls Flush(true). [Source](../Export-DHCP.ps1#L166).

## Get-DhcpPlan

Checks context/paths, export collisions, destination failover and input XML/hash. [Source](../Export-DHCP.ps1#L175).

## Invoke-DhcpTarget

Selects local execution or Invoke-Command, sending the complete worker/request to target. [Source](../Export-DHCP.ps1#L280).

## Invoke-DhcpTransfer

Validates server/hash, requests Plan, invokes ShouldProcess and sends Apply with the approved plan. [Source](../Export-DHCP.ps1#L289).

Request is an internal object carrying Mode, Stage, paths, options and Plan, not a public service endpoint or test backdoor. Results include Status, ExitCode, Computer, File, SHA256, RunFolder and Error.
