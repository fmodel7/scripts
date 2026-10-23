# Technical and operational manual — Configure NTP PDC 1.0.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · fmodel@fmodel.com.br · October 23, 2026

[Start](../README.en-US.md) · [Português](MANUAL.pt-BR.md) · [Review](REVIEW.en-US.md) · [Acceptance](ACCEPTANCE.en-US.md)

This manual describes the delivered implementation, engineering choices and observed limits. Microsoft references support the architecture; this is not a Microsoft product, endorsement or certification. No real PDC was configured during development.

## 1. Purpose, architecture and boundaries

The tool configures approved manual NTP sources on the **PDC Emulator of the forest-root AD DS domain**. A child-domain PDC is a different target. Sources may be suitable internal appliances or authorized external services; external to the AD time hierarchy does not necessarily mean public Internet.

Microsoft distinguishes the forest-root PDC from other hierarchy members. This implementation deliberately targets that role, without configuring all DCs, transferring FSMO, granting privileges or changing policies. [Architecture reference](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings).

Implemented flow:

```text
Check Windows/elevation -> capture context/settings -> resolve requested peers
    -> Audit: reports only
    -> Apply: target/policy checks -> ShouldProcess -> machine lock
       -> recheck -> snapshot + registry export -> persist report
       -> recheck again -> durable intent -> changes
       -> service + resync -> verify settings/status -> final reports
```

It does not scan the forest, install software, change time zones, run Set-Date, edit firewall/hypervisor/VM integration or change phase-correction limits. It does not register/unregister W32Time. It is not a continuous monitor or an automatic FSMO-transfer follow-up mechanism.

## 2. Files, dependencies and privileges

| File | Purpose |
|---|---|
| Configure-NTP-PDC.ps1 | Parameters, ShouldProcess approval and exit codes. |
| src/NtpPdc.Core.ps1 | Guards, native execution, backup, application, verification and reports. |
| tests/Test-Core.ps1 | Parser, normalization, evidence, persistence and optional Windows read-only smoke tests. |
| tests/Test-Workflow.ps1 | Eighteen workflows with synthetic adapters. |
| tests/Test-EntryPoint.ps1 | Three actual entry-point processes with replaced dependencies. |
| tests/Mock-Adapters.ps1 | Test helper, not an operational tool. |
| examples/Report-SYNTHETIC.*.html | Fictional report previews; not real DC evidence. |
| docs/EVIDENCE.json | Version, source hashes, environments and validation boundaries. |
| MANIFEST-SHA256.txt | Distributed-file hashes; not a digital signature. |

The operational entry requires 64-bit Windows and an elevated session, including for its local w32tm diagnostics. Apply requires Windows Server 2016 or later, identified as a DC and the forest-root PDC. Windows PowerShell 5.1 and PowerShell 7 are tested. RSAT's ActiveDirectory module is not required: the DC path explicitly loads System.DirectoryServices and uses Windows/.NET APIs.

No credential/key parameters are accepted. The current token and computer domain context are used. Elevation and working directory access are prerequisites; the script does not add groups or bypass ACLs. Microsoft 365 Global Administrator is unrelated to these local/AD operations.

DNS, AD and W32Time must function sufficiently for the selected workflow. If clock problems prevent directory discovery, Apply is blocked. Emergency recovery then requires a separately verified AD procedure; there is no switch to assume an unconfirmed PDC role.

## 3. All parameters

| Parameter | Default/range | Effect |
|---|---|---|
| NtpServers | Empty array; 0–10 input entries | Approved names/IPs without flags, URLs or spaces. Apply requires at least one. |
| Apply | false | Explicitly enables the change path after guards and approval. |
| ReliabilityMode | Automatic; Automatic/Always | Requests AnnounceFlags 10 or 5. |
| OutputPath | Empty -> LocalApplicationData/FMODEL/NtpPdc | Local report/backup root; relative paths follow the PowerShell location; UNC and drives identified as network storage are rejected. |
| ProbePeers | false | Three-sample stripchart for each requested peer; requires NtpServers. |
| NativeTimeoutSeconds | 20; 5–120 | Wait limit per native process. |
| VerificationTimeoutSeconds | 120; 10–600 | Stopwatch-based polling window, not a global timeout. |
| VerificationIntervalSeconds | 5; 1–30 | Delay between evidence attempts. |
| MaxSyncAgeSeconds | 300; 30–86400 | Maximum recognized last-good-sync age; does not configure W32Time's own thresholds. |
| WhatIf | false; common parameter | Previews Apply after preflight; permits reads/reports, not W32Time changes. |
| Confirm | PowerShell preference; High impact | Approval for the change set. Confirm:false removes only that prompt. |

There are nine explicit entry parameters; WhatIf/Confirm come from SupportsShouldProcess. Other platform common parameters, such as Verbose/ErrorAction, are not additional application modes. Checked operations use stopping error behavior internally.

## 4. Audit, plan, preview and apply

From an elevated PowerShell in the complete tool directory:

```powershell
.\Configure-NTP-PDC.ps1
```

Planning with **reserved example names**, which must be replaced with approved real sources:

```powershell
$peers = @('ntp1.example.net', 'ntp2.example.net', 'ntp3.example.net')
.\Configure-NTP-PDC.ps1 -NtpServers $peers
.\Configure-NTP-PDC.ps1 -NtpServers $peers -Apply -WhatIf
```

The first peer-based command remains Audit: it resolves requested names and records the plan, without applying it. Example.net names are not operational servers. The README also retains the original four Brazilian names as unvalidated examples, not defaults or Microsoft recommendations.

After selecting actual sources and reviewing the plan:

```powershell
.\Configure-NTP-PDC.ps1 -NtpServers $peers -Apply
```

When using a separate Windows PowerShell 5.1 process, -Command can build an array inside the expression. The legacy host's -File handling has limitations for array/explicit-switch argument passing; the interactive examples avoid depending on those conversions.

In VSCode, open the tool folder and an elevated terminal using the intended PowerShell version. Do not dot-source the entry or test mocks. PSScriptRoot locates the companion source independently of the caller's initial working directory.

WhatIf is not zero I/O. Reports are written, local registry/service and AD are read, DNS resolution occurs for supplied peers, and ProbePeers generates NTP diagnostic traffic when requested. It does not change settings, restart/start the service, force resync or export the .reg backup. An invalid target remains invalid during preview.

## 5. Target identification and race boundaries

1. Check Windows, 64-bit process and elevated token.
2. Read Win32_ComputerSystem and Win32_OperatingSystem: membership, DomainRole, product type, build, manufacturer and model.
3. For a domain-joined DC, use GetComputerDomain rather than the operator's current logon domain. Compare CIM and directory domain names.
4. Obtain Forest.RootDomain and its PdcRoleOwner. Compare complete FQDNs case-insensitively with appropriate trailing-dot normalization; no interpolated host-name regex.
5. Require the computer domain to equal the forest root and the computer to equal that root's PDC.
6. Recheck after approval, again after backup before changes, and check role/policy after application.

AD and registry operations are not a distributed transaction. FSMO/GPO changes may still occur between reads. Role validation uses the directory view obtained at that time, not consensus across every DC. A final role/policy change prevents promotion to AppliedVerified.

Apply uses Global\FMODEL.ConfigureNtpPdc, a machine-local named mutex. Another configuration run holding it blocks application. It does not lock out GPO, unrelated software or administrators using other tools.

## 6. Policies and service state

An existing HKLM\SOFTWARE\Policies\Microsoft\W32Time branch blocks Apply **even when empty**. This is the project's conservative guard, not proof of a particular effective GPO. It does not enumerate all RSOP/MDM state, run gpupdate or delete policy.

Review gpresult/RSOP and the managing policy. Change the actual policy with the correct forest-root scope when appropriate; do not delete the key just to satisfy this script. Other agents or policy mechanisms may still change settings afterward.

An absent/disabled W32Time service or missing required registry key blocks Apply. StartMode is unchanged. If the service is stopped but not disabled, the approved workflow starts it after backup and before configuration, then restarts it after provider changes. An already-running service is restarted once after configuration. Running is awaited for up to 30 seconds; dependent services are not force-stopped.

## 7. Peer normalization, DNS and flags

DNS names are lowercased/IDNA-normalized and trailing dots removed. Valid IPv4/IPv6 addresses are accepted, including private addresses for approved appliances. Loopback, unspecified and multicast/broadcast addresses are rejected; IPv4-mapped IPv6 is normalized before checks. User-supplied flags, URLs, whitespace, quotes, line breaks and IPv6 zone IDs are not accepted.

Duplicate normalized names are removed case-insensitively. Ten is the input/distinct-peer limit enforced by binding and planning. Repetition does not create redundancy. **Every** requested peer must resolve/validate. A requested name or resulting address matching this machine is rejected to avoid a direct synchronization loop. Other upstream-chain loops are not discovered.

The code does not verify provider ownership, licensing, physical independence, hardware reference quality or cryptographic signatures. Different names can represent the same address/clock. DNS can change after preflight, and conservative source matching may reject a legitimate later rotation.

| Distinct peer count | Constructed flags |
|---|---|
| 1 | First ,0x8; warning about fewer than three names. |
| 2 | First ,0x8; second ,0xA = client plus fallback-only. |
| 3–10 | All ,0x8; no forced fixed polling. |

Peer flags and AnnounceFlags are different settings even when numbers coincide. In the peer field 0x8 is client mode; 0x2 adds fallback-only. This implementation does not use SpecialPollInterval, append 0x1 or change MinPollInterval/MaxPollInterval. [Option reference](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings).

## 8. Announcement, providers and correction limits

The plan requests Type=NTP and manual peers through w32tm. It enables NtpClient and NtpServer, then sets DWORD AnnounceFlags:

- Automatic: 10/0xA, automatic announcement/reliability. The project default avoids unconditional promotion of an unsynchronized source.
- Always: 5/0x5, always announcing/reliable; an explicit operator choice, not proof of time quality.

Microsoft documents circumstances favoring 0xA over 0x5. This engineering default is not a universal recipe for every time topology. Historical special-poll guidance and adaptive client-mode configuration apply to different contexts. [Official announcement discussion](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/configure-authoritative-time-server).

MaxPosPhaseCorrection and MaxNegPhaseCorrection are captured but **not changed**. Review their suitability, especially for a large initial offset. The script does not remove limits to force correction and does not independently measure offset before application. It cannot promise gradual adjustment instead of a clock step; effective Windows behavior and policy govern that.

## 9. Exact change order and backup

Before the first W32Time mutation:

1. Approval, machine lock and refreshed target/policy/settings.
2. Write before-settings.json using refreshed state.
3. reg.exe export of HKLM\SYSTEM\CurrentControlSet\Services\W32Time to w32time-before.reg.
4. Require no timeout, zero exit and a nonempty file.
5. Persist JSON/HTML with BackupSaved state.
6. Recheck target/policy and compare five relevant local values for changes during persistence.

Then, with intent flushed before each operation:

- Start W32Time if needed.
- w32tm /config /manualpeerlist:<list> /syncfromflags:manual /update.
- Write DWORD AnnounceFlags and both provider Enabled values.
- w32tm /config /update.
- Restart W32Time and wait for Running.
- w32tm /resync /rediscover exactly once.

Fixed SystemDirectory executables are launched without a shell. A manual peer list, including its spaces, is one argument. The wrapper rejects embedded quotes/line breaks; it is not a general user-provided command executor.

The export backs up configuration, not AD, VM or clock state. File checks are not a full restore test. Never automatically import the complete branch into another computer or after a role/policy change.

## 10. Verification criteria and meaning

ConfigurationVerified requires the five requested local values, an equivalent peer list independent of order/case, Running service and the final role/policy recheck. This is not independent verification of every effective RSOP setting.

Time evidence simultaneously requires:

- /query /source and /query /status /verbose with zero exits and no timeout.
- A single-line source matching a requested name or pre-resolved address; a native ,0x... suffix is removed when present.
- Recognized leap indicator 0, 1 or 2; 3 is not synchronization confirmation.
- Recognized stratum 1 through 15.
- Recognized last-good-sync age between zero and MaxSyncAgeSeconds.

The parser explicitly recognizes EN-US/PT-BR labels tested with synthetic text. Unknown languages, changed output and duplicate labels do not become success. A differently localized Windows system may be synchronized but receive AppliedNeedsReview because its evidence cannot be interpreted. Inspect the raw output in that case.

Age is service-reported relative time; no regional date parsing is needed. A recent successful sample may predate this run while remaining inside the age window. It does not prove that this particular resync caused a new packet. Source, status and settings are separate reads, not an atomic snapshot.

AppliedVerified means only that these conditions were observed. It does not independently measure absolute accuracy, real offset, every client in the forest, upstream trust, spoofing resistance or NTP/NTS authentication. There is no malware detection or VirusTotal integration in this tool.

## 11. Timeouts, failures and exit codes

Each native process has a timeout. Standard streams are read asynchronously to avoid pipe-buffer deadlocks. On timeout the client is killed when possible; the Windows service **may already have processed the request**. Config/resync mutations are not automatically retried.

Polling uses Stopwatch so correcting system time does not corrupt the wait window. The deadline is checked between attempts; in-flight reads may exceed it. DNS, AD discovery, human approval, CIM and service waiting have their own behavior. NativeTimeoutSeconds is not a whole-script deadline.

| State | Exit | Meaning |
|---|---|---|
| AuditCompleted | 0 | Audit completed, no application; not health certification. |
| WhatIf / Declined | 0 | No W32Time mutation in this workflow. |
| AppliedVerified | 0 | Implemented criteria observed, with section 10 limits. |
| AppliedNeedsReview | 2 | Changes occurred with incomplete/negative verification. |
| Blocked | 1 | No W32Time mutation started; reports/backup may exist. |
| FailedAfterMutationPossible | 1 | Alteration attempted; possible partial state requires investigation. |

Platform, elevation, parameter-binding or early-directory errors can exit 1 without a report. A final report-write failure propagates an error; inspect the backup/journal already created. Audit persistence failure cannot undo prior Windows operations.

Check LASTEXITCODE immediately after the process/script ends. Zero in Audit/WhatIf does not mean configuration was applied or that NTP is healthy.

## 12. Artifacts, fields and confidentiality

Each Run-<UTC>-<suffix> is unique. UTC can change during correction; do not reconstruct an incident using timestamps alone. Journal line order and phases are additional evidence.

| Artifact | Contents/availability |
|---|---|
| Report.pt-BR.html / Report.en-US.html | Readable summary, plan, state and warnings; no external resources/JavaScript. |
| report.json | SchemaVersion, Version, Operator, OperatorSid, RunId, timestamps, Mode, State, RunFolder, Context, Plan, Policy, Before/After, ResolvedPeers, Before/AfterDiagnostics, ConfigurationVerified, Verification, ProbeResults, MutationAttempted, Error, Warnings. |
| before-settings.json | Eight selected values, registry path/name/kind/existence, service state/start mode. |
| w32time-before.reg | Pre-change full W32Time branch export, only after approved Apply. |
| diagnostics-before-*.txt | Raw source/status/configuration/peers output. |
| diagnostics-after-*.txt | Post-operation reads when reached. |
| config-command.txt / resync-command.txt | Corresponding native output when reached. |
| actions.jsonl | UTC, Action and INTENT/COMPLETED Phase for each initiated operation. |

Context includes FQDN, domain/root/PDC, OS/build, DomainRole, membership, manufacturer/model, VM hint and local addresses. Plan contains Servers, PeerList, ReliabilityMode, AnnounceFlags, Type and both provider enable values. ResolvedPeers records names/IPs and resolution UTC. Native records include Executable, Arguments, ExitCode, TimedOut, Output and ObservedUtc.

Verification includes Evidence, Attempts, ElapsedSeconds and final source/status native results. Evidence contains source/match, numeric recognition, leap, stratum, last-good-sync age, limit and scope note. Before/After include Values, Registry, ServiceState and ServiceStartMode. Registry distinguishes a missing key from a missing value and records ValueKind; absence is not zero.

The journal uses Flush(true) before an operation. INTENT without COMPLETED does not prove that nothing changed. It is not immutable storage, a signature or a transaction. JSON/HTML use temporary-file replacement per file, not an all-artifact transaction. Dynamic HTML text is encoded and a restrictive CSP is set.

Normal directory ACLs are inherited; no new encryption, retention, email, telemetry or GitHub upload is implemented. Reports can expose account/SID and internal topology. The repository's ignore patterns help but do not prevent forced commits or remove history.

Use explicit UTF-8 when reading JSON, including on Windows PowerShell 5.1:

```powershell
Get-Content -LiteralPath 'C:\YOUR-RUN-FOLDER\report.json' -Raw -Encoding UTF8 | ConvertFrom-Json
```

## 13. Network diagnosis and virtualization

To request a non-applying probe, using actual approved peers:

```powershell
.\Configure-NTP-PDC.ps1 -NtpServers $peers -ProbePeers
```

ProbePeers uses three stripchart samples at a one-second period. It does not derive an automatic healthy result solely from an exit code; inspect the output. stripchart uses an ephemeral UDP source port, whereas the W32Time client uses UDP source 123. A successful probe therefore does not prove the same firewall/NAT path. Test-NetConnection -Port 123 is TCP, not proof of NTP. [Tools and ports](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings).

Virtualization detection is heuristic. VMICTimeProvider.Enabled is recorded when present; host settings and VMware Tools are not queried. Integration Services, vmictimesync, provider registry and cloud settings are not changed. Microsoft guidance depends on platform/scenario; review host/domain loops and the DC's architecture before changing integration. [Virtual DC time](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service) · [Hyper-V integration](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-integration-services) · [Azure AD DC scenario](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/external-ntpsource-configuration).

## 14. Other DCs, members and role transfer

Apply does not target other DCs/members. For a machine that should return to the domain hierarchy, an administrator can evaluate separately:

```powershell
# REAL CHANGE: only on the correct target and under the environment policy.
w32tm /config /syncfromflags:DOMHIER /update
Restart-Service -Name W32Time
w32tm /resync /rediscover
```

Do not run this on the current root PDC intended to use its approved manual sources. This script does not discover or remotely execute that block. For FSMO transfer, review both old/new PDCs, policy scope and startup behavior. A previous run does not adapt automatically to later transfers.

## 15. Recovery and investigation

1. Preserve the run folder, code version and Windows time-service logs. Identify the last INTENT/COMPLETED.
2. Reconfirm the forest-root PDC and managing policy.
3. Read current source/configuration/status; do not repeat config/resync blindly after a timeout.
4. Compare before-settings.json with current state. Restore only appropriate values for that same target/scenario, preserving kinds and original absences when necessary.
5. Treat importing the full .reg as an impactful administrative operation, not an automatically recommended recovery step. It can overwrite legitimate subsequent changes and does not restore the clock.
6. Revalidate service, settings, time evidence and consumers under the organization's procedure.

There is no -Restore, AD rollback, VM restore or reverse clock adjustment. Partial changes can require manual intervention. Do not use Set-Date indiscriminately to return to a previous timestamp.

## 16. Frequently asked questions

- **Why is being a PDC insufficient?** Child domains have PDCs too; this recipe targets the forest root.
- **Why remove fixed IP comments from the original?** An old DNS mapping is not a guaranteed current address; peers are explicit inputs.
- **Why no automatic public peers?** Source approval belongs to the environment owner.
- **Does AppliedVerified guarantee accuracy?** No; only the implemented conditions were observed.
- **Is resync exit zero enough?** No. Settings and time evidence are still checked.
- **Correct source but AppliedNeedsReview?** Check language, age, stratum/leap, query failures and setting/policy divergence.
- **Can I run it on a workstation?** Audit may read local state when supported; Apply is blocked.
- **Does it need the AD PowerShell module?** No RSAT ActiveDirectory module; it needs Windows/.NET directory APIs and working AD access.
- **Does it disable VM integration?** No. It reports hints and leaves platform changes to the administrator.
- **Does it change time zone/daylight saving?** No. Time synchronization and time-zone display are separate concerns.
- **What if W32Time is disabled?** Apply blocks rather than modifying startup policy.
- **Can it undo changes?** Not automatically; registry backup does not reverse clock/app effects.
- **Is this an official Microsoft script?** No. It is FMODEL code informed by official references.
- **Does default Audit contact Internet?** It launches no own external NTP probe without peers/ProbePeers; AD reads may occur. Existing service activity continues independently.
- **Can I publish a real report?** Review authorization/redaction: it may expose topology, account and SID. Supplied examples are fictional.

## 17. Validation and production acceptance

Evidence includes core-function tests, 18 mocked workflows and three isolated actual entry processes with fake dependencies. CI runs Windows PowerShell 5.1, PowerShell 7 on Windows and Linux mocks. Windows tests also read real local registry/CIM state, check the DirectoryServices type and invoke native w32tm help, without a domain bind or external NTP.

No real PDC, production LDAP, registry/service/clock changes, enterprise GPO, accuracy, firewall, public peer or VM restore/migration was validated. No coverage percentage, compliance assessment or guaranteed effectiveness is claimed. Follow [environment acceptance](ACCEPTANCE.en-US.md) before operational adoption.

## 18. Traceability and references

Reviewed source: `f680c67aa3ebd9d11950ef28431da9a27f8ef58b`. Hashes and environment: [EVIDENCE.json](EVIDENCE.json); [CI run](https://github.com/fmodel7/scripts/actions/runs/40010481878). Original review: [REVIEW.en-US.md](REVIEW.en-US.md). A file manifest identifies bytes, not the author's identity.

Microsoft references consulted October 23, 2026:

- [W32Time tools/settings](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings)
- [How the service works](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/how-the-windows-time-service-works)
- [Authoritative time server / KB 816042](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/configure-authoritative-time-server)
- [Time service and virtual scenarios](https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service)
- [Hyper-V Integration Services](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-integration-services)
- [Azure AD DC time](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/external-ntpsource-configuration)

[NTP.br](https://ntp.br/guia/windows/) is an additional provider reference, not a universal endorsement of the original peers. References explain technologies/scenarios; exact behavior and safeguards in this manual describe the delivered FMODEL implementation.

[Function map / Mapa de funções](FUNCTIONS.en-US.md)
