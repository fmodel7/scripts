# Complete manual — FMODEL Windows Time 2.0.0

FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO  
F. Model · fmodel@fmodel.com.br · Revision assistance: Akira (ChatGPT)  
Edition: November 13, 2026 · [Português](MANUAL.pt-BR.md) · [Home](../README.en-US.md)

## 1. Purpose and architecture

Two independent scripts configure Windows Time (W32Time). Configure-NTP-PDC.ps1 sets approved manual NTP sources on the PDC Emulator of the forest root domain. Configure-Time-DOMHIER.ps1 selects the AD hierarchy on other domain-joined servers, including DCs and child-domain PDCs. A child-domain PDC is not the forest-root PDC.

DOMHIER is the w32tm argument that selects the domain hierarchy; Type=NT5DS is its corresponding registry mode. It does not mean every machine directly contacts the forest-root PDC. AD selects sources according to domain roles and topology.

The PDC script includes a.st1.ntp.br, c.st1.ntp.br, d.st1.ntp.br and e.st1.ntp.br from the author's original script. These are requested defaults, not mandatory Microsoft sources or a certification. Current availability, usage terms, latency, geographic suitability and source independence were not verified. Approved internal sources or geographically appropriate providers may be preferable outside Brazil.

## 2. Choose the file

- Current forest-root PDC: Configure-NTP-PDC.ps1.
- Other DC, child-domain PDC or member server: Configure-Time-DOMHIER.ps1.
- Windows 10/11 workstation or Linux: offline tests only; operational scripts target Windows Server 2016+.
- Workgroup, inaccessible AD or unverified PDC role: application is blocked, without a force option.

Each PS1 contains its full implementation. No src directory, ActiveDirectory/RSAT module, module installation, embedded credentials or API key is required. The tests directory is for development only. The duplicated implementation permits single-file distribution; tests ensure both embedded engines remain identical.

## 3. Requirements and permissions

Windows Server 2016 or later, a 64-bit process, Windows PowerShell 5.1 or PowerShell 7, elevation and a functioning AD domain are required. W32Time and its standard registry keys must exist. The service cannot be disabled; its startup type is not changed.

The current token is used. No password is requested and no privileges are granted. Microsoft 365 roles are unrelated. The operator needs elevated administration of the local server and working AD/registry/service reads. Run locally on the target; there is no remote execution parameter or server enumeration.

On the PDC, every source must resolve through DNS. W32Time must reach approved sources over the network, normally UDP 123; DNS resolution does not test that path. Consider W32Time's source UDP port 123 and return-path rules. Corporate policy, GPO and the approved time architecture take precedence over lab examples.

## 4. Download without Git

Open the GitHub folder, select Windows-Time-v2.0.0.zip and click Download raw file. Extract All. Alternatively, use Code → Download ZIP at fmodel7/scripts, extract the repository and open scripts/configure-ntp-pdc.

Do not run inside the ZIP preview. Either PS1 can be distributed alone, but the package also includes manuals. Verify the source and compare SHA256 values with MANIFEST-SHA256.txt. The manifest detects differences; it is not a digital signature or independent authenticity guarantee. Editing the NTP list legitimately changes the file hash.

## 5. PowerShell and VSCode

Open the extracted folder in Explorer, select the address bar, type powershell and press Enter. Application requires elevation: open PowerShell as Administrator and use Set-Location with the actual extracted path. Do not append the folder name again if already inside it.

```powershell
Get-Location
Get-ChildItem
```

For VSCode, launch as Administrator, use File → Open Folder and select the extracted folder. Trust code only after reviewing its source. Open Terminal → New Terminal with a PowerShell profile. The Microsoft PowerShell extension helps editing but is not required to execute. The terminal inherits VSCode's elevation. Do not dot-source the script or execute only a selection; invoke the file by name. Preserve UTF-8 with BOM when editing for Windows PowerShell 5.1.

## 6. Test without changing time

From the tool folder, using a normal PowerShell session:

```powershell
powershell.exe -NoProfile -File .\tests\Test-WindowsTime.ps1
```

Or, with PowerShell 7 installed:

```powershell
pwsh -NoProfile -File .\tests\Test-WindowsTime.ps1
```

The suite parses ASTs and loads only functions, never operational entry points. AD, DNS, registry writes, service control and W32Time commands are replaced by synthetic adapters. Harmless child PowerShell processes also test actual stdout, nonzero exit and the real 30-second timeout. The suite therefore takes more than 30 seconds. Temporary report/journal files are created and removed. No domain or elevation is required; no real PDC or clock is changed.

## 7. Simulate on the target

On the forest-root PDC, in an elevated session:

```powershell
.\Configure-NTP-PDC.ps1 -WhatIf
```

On other servers:

```powershell
.\Configure-Time-DOMHIER.ps1 -WhatIf
```

WhatIf performs preflight CIM/AD/registry/service reads and PDC peer DNS resolution. It does not prove UDP/NTP connectivity, future write permissions, backup or restart success. It creates no run folder, report or backup; it does not change W32Time or request resynchronization. Invalid targets remain blocked in WhatIf.

## 8. Apply

After reviewing the target and approved change window, run only the corresponding file:

```powershell
.\Configure-NTP-PDC.ps1
```

```powershell
.\Configure-Time-DOMHIER.ps1
```

No parameters means application after confirmation, unlike version 1.0.0, which audited by default. This edition has no -Apply or -NtpServers parameter. Read the confirmation before answering Yes. Refusal or WhatIf returns NotApplied and exit code 0, meaning no application, not healthy time.

For previously approved automation, -Confirm:$false suppresses only the PowerShell question. It bypasses no target, policy or backup check and is not the beginner path. This is a local configuration tool, not a scheduled task. W32Time may adjust the system clock after configuration.

## 9. Edit NTP sources

At the top of Configure-NTP-PDC.ps1, edit only the NtpServers array to approved hostnames:

```powershell
$NtpServers = @(
    'a.st1.ntp.br'
    'c.st1.ntp.br'
    'd.st1.ntp.br'
    'e.st1.ntp.br'
)
```

Supply 1–10 ASCII DNS hostnames; international names must use punycode. Do not supply literal IPs, URLs, ports, flags or commands. The implementation trims outer whitespace, normalizes case and deduplicates. It rejects self hostnames/addresses, loopback, unspecified addresses and detected multicast/broadcast addresses. Every source must resolve.

One source uses 0x8 (NTP client); two use 0x8 and 0xA (second is fallback-only); three or more all use 0x8. Polling remains adaptive without a fixed SpecialPollInterval. Three or more suitable sources are generally preferable, but count does not establish independence, trust or accuracy. NTS authentication is not implemented.

## 10. Options and constants

There are no custom parameters. WhatIf and Confirm come from SupportsShouldProcess with High impact. Common parameters such as Verbose and ErrorAction belong to PowerShell; internal verified operations use Stop behavior. One confirmation covers the change set.

Internal constants: version 2.0.0; 30-second timeout per native process; up to 30 seconds waiting for service Running; local mutex Global\FMODEL.WindowsTime.Setup; output LocalApplicationData/FMODEL/WindowsTime/Run-UTC-GUID. These are not a global timeout: AD, CIM, DNS, confirmation, service control and disk operations may take longer. There are no automatic retries, schedules, remote lists, passwords or force mode.

## 11. Target and policy validation

Get-TimeContext verifies Windows/64-bit execution, an elevated token, domain membership, server product and minimum build. CIM supplies local facts. System.DirectoryServices uses GetComputerDomain().Forest.RootDomain.PdcRoleOwner, so the forest comes from the computer's domain rather than the interactive user's domain. The local FQDN is compared exactly, without regex or short-name-only matching.

PDC requires a DC matching the forest-root role owner. DOMHIER blocks that target and accepts other domain servers. Any HKLM:\SOFTWARE\Policies\Microsoft\W32Time key, including an empty key, blocks application as a conservative project decision. This does not discover every policy mechanism; a GPO can arrive later. Do not delete the key to evade the guard. Coordinate policy management with the domain team.

After confirmation, the process obtains local exclusion, refreshes context, exports a backup and captures diagnostics. Before the first mutation it rechecks role/policy and five selected registry settings. After application it rechecks target and configuration. These controls reduce races but do not form an AD/registry transaction: FSMO, GPO and administrators may still change state between checks. The mutex does not block external tools or other computers.

## 12. Changes performed

First, reg.exe exports the entire HKLM\SYSTEM\CurrentControlSet\Services\W32Time branch. Exit zero and a nonempty file are required. BackupSaved HTML/JSON is persisted before W32Time changes. Before each mutation stage, an INTENT record is written with Flush(true); COMPLETED follows only after the stage returns without an error. INTENT without COMPLETED means started or unknown, not proof that nothing changed.

If stopped, W32Time is started after backup. Both modes set NtpClient.Enabled=1 and AnnounceFlags=10 (0xA, automatic advertisement). PDC also sets NtpServer.Enabled=1. These are DWORD values. DOMHIER preserves NtpServer.Enabled; it does not automatically turn a member into an NTP server. Service startup type is preserved.

PDC runs w32tm /config /manualpeerlist:"list" /syncfromflags:manual /update. DOMHIER runs w32tm /config /syncfromflags:domhier /update. Old manual entries can remain in NtpServer after DOMHIER; Type=NT5DS selects the hierarchy, and the script does not use those entries for manual synchronization.

The service is then restarted without -Force and awaited until Running. One w32tm /resync /rediscover request follows, with configuration, source, status /verbose and peers queries. There is no domain-wide /monitor, unconditional /reliable:yes or /unregister. Firewall, timezone, phase correction limits, hypervisor integration, ACLs and GPO are not changed.

## 13. Native processes and errors

Executables come from Environment.SystemDirectory with UseShellExecute=false. Every argument is quoted; quotes, newlines, NUL and a trailing backslash are rejected. stdout/stderr are read asynchronously. Nonzero exit or timeout raises an error. On timeout the process is terminated on a best-effort basis; an operation already submitted to the service may have happened.

There is no automatic retry or rollback. Failure before W32Time stages is Blocked; failure after crossing the mutation boundary is FailedAfterMutationPossible. This is conservative: journal failure can happen before an actual change. Failure writing the final report also exits 1; an earlier report, backup and journal may be the only available evidence.

## 14. Results and exit codes

| Result | Exit | Meaning |
|---|---|---|
| NotApplied | 0 | WhatIf or declined confirmation; no run folder. |
| Configured | 0 | Expected local configuration, service Running, resync request accepted and all four native diagnostic queries returned successfully. |
| ConfiguredNeedsReview | 2 | Configuration/diagnostics did not meet every check, or resync failed/remained unknown. Application occurred. |
| Blocked | 1 | No W32Time mutation stage started; backup/report may exist. |
| FailedAfterMutationPossible | 1 | Partial changes are possible; investigate before repeating. |

BackupSaved is an intermediate persisted state, not final success. Early platform, AD, permission or binding failures may exit 1 without a report. The entry exits its process; run as a file, never by dot-sourcing. When launched as a child process, inspect LASTEXITCODE in the calling shell.

Configured does not parse localized labels, leap indicator, stratum, offset or synchronization age. It does not certify time health, source authentication, accuracy, a fresh synchronization or forest-wide propagation. This simplification is deliberate; live acceptance uses diagnostics and lab observations. A successful /resync exit is request acceptance, not an accuracy measurement.

## 15. Reports and data protection

After approval and run-folder creation, output goes to LocalApplicationData of the elevated executing account, which may differ from the account opening Explorer:

- Report.html: browser-readable PT-BR/EN-US summary and expandable technical details.
- report.json: before/after context, operator/SID, plan, backup, state and raw diagnostics.
- W32Time-before.reg: prior configuration export on the approved path only.
- actions.jsonl: per-stage intent/completion records when application starts.

The HTML is offline with no JavaScript or remote assets and encodes inserted data. HTML/JSON writes overwrite files and are not an atomic transaction; interruption or full disk can leave incomplete files. The journal is separate. Open the path printed in the console; the tool does not automatically launch an elevated browser.

Files can contain internal domains, hosts, IPs, policies and identity. They inherit local ACLs without added hardening, encryption or automatic expiry. No telemetry or uploads occur. Do not publish live reports or registry backups. Each approved run creates a new folder; define retention/access under organizational policy.

## 16. Operational checks and questions

```powershell
w32tm /query /configuration
w32tm /query /source
w32tm /query /status /verbose
w32tm /query /peers
```

On the PDC, check Type=NTP and the approved peers. On DOMHIER servers, check Type=NT5DS. Review the expected source, recent last successful sync, a leap indicator without an unsynchronized warning, usable stratum and Windows Time event logs. Labels vary by OS language. CMOS/local clock, VM IC Time Synchronization Provider or missing data requires investigation within the approved architecture. Absence of Local CMOS Clock does not establish success.

Can all DCs use DOMHIER? Other DCs can, but the forest-root PDC needs an approved source outside the AD time hierarchy. That can be an internal NTP appliance, not necessarily the public Internet.

Can this affect authentication? Only W32Time is restarted, but clock changes can affect Kerberos, certificates, logs and applications. Coordinate a change window and AD acceptance; zero impact is not guaranteed.

Must host synchronization be disabled in every VM? No. The decision depends on server role, platform, provider and vendor/Microsoft guidance. Manufacturer/model are recorded, but VM integration is not changed and no universal virtualization policy is applied.

Should the PDC's IP be hardcoded on members? DOMHIER does not require that and preserves hierarchy discovery. FSMO transfer must include a procedure to configure the new forest-root PDC; these scripts do not continuously migrate configuration.

## 17. Troubleshooting and recovery

ExecutionPolicy blocks: inspect Get-ExecutionPolicy -List and corporate policy. For a downloaded file you have reviewed, Unblock-File -LiteralPath .\Configure-NTP-PDC.ps1 or the DOMHIER equivalent removes the Internet-origin mark; it does not override required signing or GPO. Do not globally switch to Unrestricted or disable protections as an automatic workaround.

Wrong target: use the reported forest-root PDC or the appropriate DOMHIER server. AD/DNS failure: investigate discovery, DNS and authentication; no unverified role is forced. Policy exists: manage W32Time through correctly scoped GPO. Disabled service: confirm the intended configuration with its owner rather than indiscriminately changing startup type.

Resync has no time data or source is unexpected: inspect DNS, UDP 123 path, approved sources, W32Time events, VM provider and phase correction limits. A stripchart can assist diagnostics but uses an ephemeral source port and does not prove the service's UDP path. Ping alone cannot prove NTP reachability. There is no automatic resync loop.

Partial failure: retain the run folder, backup and journal, inspect the current state and coordinate approved recovery. The backup exports the entire branch and can contain additional provider values. Do not blindly import it. An approved reg.exe import requires review of policy/ACLs/values, service activation and revalidation; it cannot automatically restore service state, FSMO, GPO or prior clock time. There is no universally safe rollback command. Before repeating, identify completed stages and whether PDC ownership changed.

## 18. Migration, testing and acceptance

2.0.0 replaces the modular 1.0.0 tool in the same folder. Old -Apply, -NtpServers, -OutputPath, -ProbePeers and src/NtpPdc.Core.ps1 instructions no longer apply. Each new PS1 is sufficient on its own. Report states changed; automation interpreting AppliedVerified must be updated. WhatIf is now the non-applying path. The previous content remains in Git history and is linked in CHANGELOG.

Tests cover parsing, requirements, identical embedded engines, roles, policy, service, peer normalization/flags, rejected addresses, state races, mandatory backup, confirmation, journal, HTML, local verification, native errors and actual child-process timeout. Nineteen simulations are not a real AD lab. See TESTING.en-US.md and EVIDENCE.json for exact results and limits; version 1.0.0 counts are not reused.

Authorized acceptance: identify current roles; preserve settings/logs and a suitable recovery point; review peers/GPO; run WhatIf on the root PDC and a member; confirm cross-target blocking; apply to the lab root PDC during an approved window; inspect current evidence/events; apply DOMHIER to a lab member; check NT5DS and source; observe stability before wider GPO deployment. Replan after FSMO transfer. No development test configured a real PDC.

## 19. References

These sources inform architecture and implementation decisions; the project is not Microsoft certified or endorsed.

- Windows Time tools and settings: https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings
- Authoritative time server and AnnounceFlags: https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/configure-authoritative-time-server
- Time hierarchy: https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/how-the-windows-time-service-works
- Hyper-V integration services: https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-integration-services
- Azure external time sources: https://learn.microsoft.com/en-us/azure/virtual-machines/windows/external-ntpsource-configuration
- ntp.br provider guide: https://ntp.br/guia/windows/
