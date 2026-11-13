# Complete manual — FMODEL DHCP Transfer 1.0.0

FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO  
F. Model · fmodel@fmodel.com.br · Revision assistance: Akira (ChatGPT)  
November 13, 2026 · [Português](MANUAL.pt-BR.md) · [Home](../README.en-US.md)

## 1. Purpose and scope

Export-DHCP.ps1 exports DHCPv4/DHCPv6 configuration and, by default, leases to XML. Import-DHCP.ps1 imports XML into the destination after confirmation and backup preparation. Each PS1 is standalone and embeds the same internal worker; no auxiliary FMODEL module is required.

These are export/import tools, not a complete infrastructure migration. They do not install the role, authorize/deauthorize servers in AD, shut down the source, change IP/DNS/bindings/relays, recreate failover or validate client address acquisition. Settings present in XML may be applied by the native cmdlet; the wrapper does not edit/remove XML sections to manufacture compatibility.

## 2. Changes from the submitted files

The importer was inside a block comment; it is now a separate executable script. Export files are no longer forcibly overwritten. ScopeOverwrite is explicit rather than automatic. Restart-Service no longer receives ComputerName: the optional restart happens locally on the chosen destination, without -Force. Verified operations use terminating error handling and distinguish failure before/after an import attempt.

The fixed log is replaced by a unique run folder, HTML/JSON reports and JSONL journal. Import prepares native and XML destination backups and uses a stable input snapshot. A successful cmdlet return is not presented as proof of DHCP client service.

## 3. Requirements and permissions

Real operations require a Windows Server 2016+ target, installed DHCP role/DhcpServer module, DHCPServer service Running and elevated target administration. The worker requires 64-bit Windows PowerShell 5.1. Use powershell.exe, not pwsh.exe. PowerShell 7 is supported for offline tests, not operational execution in this edition.

There is no embedded password or Credential parameter. Local execution uses the current token; remote execution uses existing PowerShell Remoting/WinRM configuration. Actual identity/SID are recorded. Remoting, TrustedHosts, execution policy, firewall and privileges are not configured. DHCP management rights are not automatically AD authorization rights.

The operator must create/read files in the selected directory. The identity used by the backup service/API also needs write access. ACLs are not changed automatically; resolve Access Denied with the responsible team and narrowly scoped permissions, not Everyone Full Control. Allow space for XML, snapshot and multiple backups.

## 4. Download and open

Open DHCP-Transfer-v1.0.0.zip under scripts/dhcp-transfer on GitHub, select Download raw file and Extract All. Alternatively, use Code → Download ZIP from the repository home, extract it and enter scripts/dhcp-transfer. Do not run inside the ZIP preview. Either PS1 works alone, but the package includes manuals and tests.

Open Windows PowerShell as Administrator and use Set-Location with the actual extracted path. In VSCode, run as Administrator, use File → Open Folder and open a terminal with the Windows PowerShell profile. The Microsoft PowerShell extension helps editing but is not required. If PowerShell 7 is the default profile, select Windows PowerShell or launch powershell.exe. Preserve UTF-8 with BOM when editing.

```powershell
Get-Location
Get-ChildItem
$PSVersionTable
```

## 5. Offline student tests

On a regular workstation without a domain, DHCP or elevation:

```powershell
powershell.exe -NoProfile -File .\tests\Test-DhcpTransfer.ps1
```

Replacing powershell.exe with pwsh also works. The suite extracts functions through AST, never operational entry points. It uses synthetic XML/data, a fake DHCP module and substituted adapters. Temporary files are created and removed; no server connection, service change or real DHCP database operation occurs. See TESTING.en-US.md and EVIDENCE.json for results, environments and limits.

## 6. Local versus remote file locations

DhcpServer='.' selects the current computer. A name equal to COMPUTERNAME also takes the local route; other DNS names use Invoke-Command. The current server's FQDN may use WinRM; use dot for local operation. Literal IPs, URIs, computer lists and command characters are not accepted as server names.

**Every path is local to the selected server**, including ExportPath, ImportFile, BackupPath, final XML, hash sidecar, backups and reports. Files are not copied automatically to the administration workstation. For remote operations, a complete worker runs on the target; DHCP cmdlets and optional restart execute locally there. This avoids ambiguity between client paths, server paths and compatibility sessions.

WinRM must already be configured and approved. A Plan session performs preflight and an Apply session runs after approval. No extra credentials or network shares are used by the worker; UNC paths/network drives are rejected. Transfer XML between source and destination through an approved process outside this flow. Accessing a share from WinRM can introduce second-hop restrictions.

## 7. Export: initial path

On the source server, simulate:

```powershell
.\Export-DHCP.ps1 -WhatIf
```

Export after confirmation:

```powershell
.\Export-DHCP.ps1
```

Defaults are C:\DHCP-Backup and a unique DHCP-Export-UTC-ID.xml filename. The console prints Computer, File, SHA256 and RunFolder. Because default names are generated per invocation, simulation and application can show different names. For a known lab filename:

```powershell
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml -WhatIf
.\Export-DHCP.ps1 -FileName DHCP-Lab.xml
```

If that XML or its .sha256 sidecar exists, choose another name. There is no Force override. Export does not shut down the source or prevent new leases after the snapshot; plan cutover under the approved architecture.

## 8. Remote export

From an administration Windows PowerShell session with approved WinRM access:

```powershell
.\Export-DHCP.ps1 -DhcpServer DHCP-SOURCE -ExportPath C:\DHCP-Backup -FileName `
    DHCP-Lab.xml -WhatIf
.\Export-DHCP.ps1 -DhcpServer DHCP-SOURCE -ExportPath C:\DHCP-Backup -FileName DHCP-Lab.xml
```

Replace DHCP-SOURCE with the real name. C:\DHCP-Backup is on DHCP-SOURCE. Transfer XML/hash to a protected destination path using an approved method and confirm the hash through a trusted channel before importing.

## 9. Import: planning and execution

Prepare the destination and source cutover with the network/AD team. This tool requires the destination service Running for its cmdlets, so the environment must be isolated/prepared to avoid unintended simultaneous service or address allocation. This requirement does not replace Microsoft's full migration procedure, which includes additional stop/start and authorization steps.

After placing XML on the destination, simulate locally there:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -WhatIf
```

Import after confirmation, without overwriting existing scopes or automatically restarting:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml
```

**Omitting ScopeOverwrite does not make the operation purely additive:** server-wide settings may still be applied. Existing scopes can be skipped with native warnings; warnings are preserved and result in NeedsReview. Do not assume complete import without inspecting the actual content applied.

## 10. Explicit disruptive options

Only when the approved plan requires replacing existing scopes:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -ScopeOverwrite -WhatIf
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -ScopeOverwrite
```

ScopeOverwrite permits native scope replacement, not a field-by-field merge. RestartService is independent and can temporarily interrupt client service:

```powershell
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -RestartService
```

For remote use, add -DhcpServer DHCP-DESTINATION. Confirmation includes server, file, leases, overwrite and restart. Confirm:$false suppresses only the outer question in previously approved automation and is not the beginner path. The internal Import-DhcpServer Force flag suppresses its native question after outer approval; it does not itself enable ScopeOverwrite.

## 11. Every parameter

### Export-DHCP.ps1

| Parameter | Default | Effect |
|---|---|---|
| DhcpServer | . | Local target or remote DNS name. |
| ExportPath | C:\DHCP-Backup | Target-local directory for XML and run folder. |
| FileName | XML name with UTC and random ID | Simple ASCII leaf name up to 150 characters; existing XML/hash rejected. |
| ConfigurationOnly | false | Omits leases; retains configuration and all IPv4/IPv6 scopes. |

### Import-DHCP.ps1

| Parameter | Default | Effect |
|---|---|---|
| DhcpServer | . | Local target or remote DNS name. |
| ImportFile | Required | XML already present at an absolute target-local path. |
| BackupPath | C:\DHCP-Backup | Base for a unique import folder and backups/logs. |
| ConfigurationOnly | false | Does not import leases; still imports configuration/scopes. |
| ScopeOverwrite | false | Permits replacing existing scopes. |
| RestartService | false | Restarts destination DHCPServer after import returns. |
| ExpectedSha256 | Empty | If supplied, requires 64 hexadecimal digits and matching XML. |

ConfigurationOnly is not the native ServerConfigOnly parameter. This edition has no ScopeId/Prefix filters: operations use the full supported XML content, IPv4 and IPv6. WhatIf/Confirm come from SupportsShouldProcess with High impact. ErrorAction/Verbose are common PowerShell parameters; verified operations use Stop.

## 12. XML, hash and stable input

The streaming XML reader prohibits DTDs and external entity resolution. It requires nonempty, well-formed XML rooted at DHCPServer. This is not official XSD validation or a version-compatibility guarantee: semantic validation remains with the native cmdlet and acceptance process. Untrusted XML should not be imported merely because these checks pass.

SHA256 covers complete file bytes, not normalized XML. ExpectedSha256 can use the export's value verified through a trusted channel:

```powershell
$hash = (Get-FileHash C:\DHCP-Backup\DHCP-Lab.xml -Algorithm SHA256).Hash
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Lab.xml -ExpectedSha256 $hash -WhatIf
```

Hashing a received file only identifies that same file; it does not authenticate its origin. The wrapper does not automatically read the .sha256 sidecar or treat a digital signature as proof of XML origin. After approval, it copies XML to InputSnapshot.xml using CreateNew, compares its hash with the approved plan and holds a read-only handle denying writers during import. The original input is unchanged.

## 13. Backups before import

Within Import-UTC-GUID, it prepares PreImportNative with Backup-DhcpServer and requires at least one positive-size file. It then exports DestinationBefore.xml including leases and checks XML structure. Failure prevents calling Import-DhcpServer. BackupSaved HTML/JSON is persisted before import.

Next it creates ImportCmdletBackup and supplies it to Import-DhcpServer, which also performs its own pre-change backup. Paths are separate to avoid mixing stages. A nonempty set is not proof of restorability; restoration requires lab testing. Space, permissions and backup contents are acceptance requirements.

## 14. Internal flow and concurrency

Plan checks runtime/token, module, service, v4/v6 scopes, failover and paths. Import also reads XML/hash. WhatIf or refusal exits before directories, backups or reports are created. Queries and WinRM still occur; this is not DHCP service simulation or proof of future write permission.

Apply revalidates the selected target/input, obtains local mutex Global\FMODEL.DhcpTransfer and refreshes context. MachineGuid, paths and selected inventory help detect changes. Before attempting import it refreshes context after backups. These checks are not a distributed transaction: GPO, administrators and external tools do not obey the mutex, and settings outside the selected inventory can change undetected. Recorded local identity is not a cryptographic hardware attestation.

Export first writes Export.partial.xml in the run folder. After XML/hash checks, File.Move publishes the final name without overwriting. The sidecar also uses CreateNew. A failure after publication may leave final XML without hash or a complete report; ExportFailed does not mean no file exists. No automatic cleanup deletes evidence.

## 15. Reports, journal and privacy

Each approved execution creates Export-UTC-GUID or Import-UTC-GUID under ExportPath/BackupPath. Console paths refer to the server; access Report.html by an approved method. HTML is offline with no JavaScript/remote assets, encoded data and a PT-BR/EN-US summary. report.json contains state, actual operator/SID, before/after inventory, options, warnings, paths and error.

actions.jsonl records STARTED, INTENT and COMPLETED with Flush(true). INTENT precedes export/backup/import/restart stages. INTENT without COMPLETED means unknown result or failure, not absence of change. HTML/JSON files are overwritten directly without atomic transaction guarantees; disk failure/interruption may leave incomplete files. Final reporting failure exits 1 even after service changes.

XML/backups can expose IPs, MACs, reservations, hostnames and internal architecture. The tool does not encrypt, harden ACLs, upload, email or expire files. ACLs are inherited; apply corporate controls. Never publish real exports, snapshots, backups or reports in Git. The package SHA256 manifest is not script signing or an execution-policy bypass.

## 16. States and exit codes

| State | Exit | Meaning |
|---|---|---|
| NotApplied | 0 | WhatIf or refusal; no run folder. |
| Exported | 0 | Export cmdlet returned, XML passed structural checks and XML/hash were published. |
| ImportedAwaitingValidation | 0 | Import returned and post-inventory was read; validate results/clients. |
| NeedsReview | 2 | Import warnings, such as skipped scopes; review partial/expected results. |
| Blocked | 1 | No Import-DhcpServer attempt began; backups/logs may exist. |
| ExportFailed | 1 | Export/publication failed; partial/final files may exist. |
| FailedAfterImportPossible | 1 | Import was attempted; partial application or later restart/diagnostic failure is possible. |

BackupSaved is intermediate. Platform, binding, preflight, mutex or communication failures may produce no report. If WinRM drops after Apply is sent, the caller can exit 1 without knowing the server's result: inspect server files and DHCP state before retrying. No automatic retry or rollback exists. Run as a file, not by dot-sourcing; inspect LASTEXITCODE in the calling shell when launching a child process.

## 17. Operational validation

After import, inspect reports and DHCP console, v4/v6 scopes, states, ranges, exclusions, reservations, server/scope options, policies and leases. Compare with source inventory/XML without assuming equal counts mean identical data. Verify bindings, AD authorization, dynamic DNS/credentials, relays, firewall and routing. The wrapper does not validate every option, lease, reservation or policy or semantically compare XML against destination.

Test authorized clients/networks/VLANs for correct addresses, gateway, DNS, lease duration, renewal and events. Running service does not prove DHCP delivery. Ensure independent servers do not unintentionally serve the same pool. Source shutdown/deauthorization and destination activation belong to cutover planning, not automatic script behavior.

## 18. Failover and compatibility

Export can make a copy of a failover server but does not migrate its relationship. Import blocks a destination with detected IPv4 failover relationships, without a bypass. Source XML is not certified for failover content/state. Follow Microsoft's dedicated procedure for failover, clusters, split-scope and multi-role deployments.

Review OS versions, updates, UI language, database paths and scenario requirements. Arbitrary bidirectional Windows Server compatibility is not assumed; XML is not repaired by removing unsupported tags. DNS-update credentials, authorization and partner configuration may need separate treatment. Consult migration references before production.

## 19. Errors and recovery

Unsigned script: run Get-ExecutionPolicy -List. MachinePolicy/UserPolicy may require signing; do not indiscriminately switch to Unrestricted/Bypass. When RemoteSigned permits and origin is reviewed, Unblock-File -LiteralPath .\Export-DHCP.ps1 removes the download mark; it does not override AllSigned/GPO. Importer and tests follow the same rule.

Missing DhcpServer module/service: review the target role installation; the tool installs nothing. WinRM unavailable: verify DNS, endpoint, authentication and permissions with the domain team. Remote file missing: paths belong to the server, not the workstation. Backup Access Denied: inspect space, ACLs and service identity without broadly weakening access.

Hash/XML failure: obtain an approved fresh export and investigate transfer/integrity rather than ignoring or blindly editing it. Existing scopes: inspect warnings and decide whether ScopeOverwrite is appropriate in an approved window. Partial failure: retain logs/backups, inspect current state and prepare recovery instead of automatically repeating with overwrite.

Native Restore-DhcpServer recovery or reimporting prior XML requires a separate reviewed procedure, can interrupt service and does not undo external AD/DNS/relay/client effects. There is no universally safe rollback command. Test isolated restoration and record recovery authority.

## 20. Acceptance and references

Before production, use an isolated lab with the same versions/languages. Test local/remote export, transferred-file integrity, import with/without existing scopes, warnings, approved overwrite, backup permissions, session loss and restoration. Record client validation and cutover planning. Development tests did not export/import any real DHCP database or establish a real WinRM session.

Primary references for architecture and parameters; the project is not Microsoft certified or endorsed:

- Export-DhcpServer: https://learn.microsoft.com/en-us/powershell/module/dhcpserver/export-dhcpserver
- Import-DhcpServer: https://learn.microsoft.com/en-us/powershell/module/dhcpserver/import-dhcpserver
- Backup-DhcpServer: https://learn.microsoft.com/en-us/powershell/module/dhcpserver/backup-dhcpserver
- DHCP migration: https://learn.microsoft.com/en-us/windows-server/networking/technologies/dhcp/migrate-dhcp-server
- Existing failover migration: https://learn.microsoft.com/en-us/windows-server/networking/technologies/dhcp/migrate-existing-dhcp-failover

[Individual guides](../README.en-US.md) · [Testing](TESTING.en-US.md) · [Evidence](EVIDENCE.json)
