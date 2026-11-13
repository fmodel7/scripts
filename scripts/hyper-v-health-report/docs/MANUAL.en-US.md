# Hyper-V Health Report 1.0.0 — Complete manual

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
Created and maintained by **F. Model** · [fmodel@fmodel.com.br](mailto:fmodel@fmodel.com.br)  
[Português](MANUAL.pt-BR.md) · [Start here](../README.en-US.md)

## 1. Purpose and deliverables

`Export-HyperVHealthReport.ps1` collects inventory and operational evidence from Hyper-V hosts, virtual machines and, when requested, a failover cluster. It helps administrators understand capacity, identify conditions that need investigation and prepare an evidence-based technical review.

Each execution creates a unique directory containing **offline HTML, 54 CSV files, JSON and a SHA256 manifest**. ZIP packaging is optional. The FMODEL HTML includes summary cards, findings and recommendations, collapsible tables, global and per-table search, severity filtering, navigation, CSV links and browser printing. Interface text and new assessment recommendations support PT-BR and EN-US.

This is a read-only point-in-time assessment. It is not continuous monitoring, benchmarking, vulnerability scanning, restore testing or compliance certification. “No findings” describes only the implemented rules that could be applied to the collected evidence. Always review coverage and errors first.

## 2. Changes from the uploaded reference

The reference identifies itself as **Get-HyperVReport.ps1 v1.5, March 5, 2015, by Serhat AKINCI**. It was inspected statically and was not executed for this work. The FMODEL delivery is an independent implementation in one operational PS1; the legacy file is neither bundled nor simply renamed under new credits.

| Area | Current delivery |
|---|---|
| Runtime and queries | Windows PowerShell 5.1 x64; Hyper-V/FailoverClusters cmdlets and CIM; no WMI command-string execution through `Invoke-Expression` |
| Installation/configuration | No automatic feature installation, execution-policy change, firewall/remoting configuration or VM changes |
| Outputs | Normalized HTML/CSV, JSON preserving values before spreadsheet protection, manifest and optional ZIP |
| Failure handling | Per-probe coverage, target-specific errors, explicit caps and completed packets retained after timeout |
| Storage | Bounded VHD parent traversal and cycle detection; file size, virtual capacity and volume free space kept separate |
| Security | Secure Boot, vTPM/shielding, Device Guard, SMB and network configuration as evidence, without enforced changes |
| Learning | Built-in synthetic example, offline tests and one complete manual per language |
| Email | Not included; reports are not automatically transmitted and no SMTP password is requested |

No general reuse license has been selected for this library. Public visibility does not settle third-party code rights. Reference authorship is acknowledged here; the original is not distributed in this package.

## 3. Requirements and compatibility

| Use | Requirements |
|---|---|
| Live collection | 64-bit Windows, **Windows PowerShell 5.1 Desktop**, `powershell.exe`, target connectivity and query permissions |
| Intended targets | Hyper-V on Windows Server 2016, 2019, 2022 and 2025, subject to installed cmdlets/properties; real acceptance testing per version remains required |
| Local host | Hyper-V module already installed on that host; querying the local machine does not require WinRM |
| Remote hosts | Existing WinRM/PowerShell Remoting, DNS, authentication and a compatible Windows PowerShell endpoint; modules execute on the target |
| Cluster | `-ClusterNode` is the name of an **actual member node**, with FailoverClusters available; discovery runs there |
| Example, offline rendering and tests | Windows PowerShell 5.1 or PowerShell 7; offline/example paths also work on Linux |
| HTML | Modern browser; no internet required; local JavaScript powers search and controls |

PowerShell 7 is rejected for live collection in this release rather than assuming implicit compatibility of Windows modules. PowerShell 7 is not required for live operation. Client Windows Hyper-V may lack server/cluster/Replica capabilities and is not accepted as a fully validated operational platform here.

Automated validation uses synthetic providers. No real Hyper-V host, SAN, SOFS, Storage Spaces installation, cluster or guest VM was accessed. Passing automated tests is not production acceptance.

## 4. Accounts and permissions

The current session identity is used by default. No password prompt appears unless you explicitly pass `-Credential (Get-Credential)` for remote queries. Credentials are not written to reports, included in JSON or passed as worker scriptblock input.

| Area | Access dependency |
|---|---|
| Hyper-V inventory | Host management/read rights; Hyper-V Administrators may cover part of the scope |
| Remoting | Access to the Windows-configured WinRM endpoint; Hyper-V Administrators membership alone does not guarantee this |
| CIM, services and registry | Access to the queried providers and registry keys |
| Events | Read access to the selected channels under organizational delegation |
| Cluster | Cluster permissions and connectivity to every discovered node |
| In-use VHD | Query on the owning host; SMB and second-hop access may require appropriate authentication design |
| Reports | Create files in the local output directory |

Start in a lab with an authorized account and delegate the minimum access required by the environment. The script does not create delegation or configure CredSSP/TrustedHosts. `-Credential` does not automatically solve SMB second-hop access. Reference S19 explains that boundary.

An explicit credential cannot be applied to a local background job: start the local session under the intended identity or use an explicit remote target. Recognized local names include `.`, `localhost`, loopback and the short machine name; the same machine's FQDN may follow the remote path.

## 5. Easiest path: download, extract and try the example

1. Use [Download the Hyper-V package](https://github.com/fmodel7/scripts/raw/refs/heads/main/scripts/hyper-v-health-report/HyperV-Health-Report-v1.0.0.zip).
2. In File Explorer, right-click the ZIP and select **Extract All**.
3. Open the extracted directory containing `Export-HyperVHealthReport.ps1` and `README.md`.
4. Copy that directory's path from File Explorer's address bar.
5. Open PowerShell or VSCode's integrated terminal and run the commands below. Paste only the directory path when prompted; do not append the directory name a second time.

```powershell
$folder = Read-Host 'Paste the extracted directory path'
Set-Location -LiteralPath $folder.Trim('"')
Get-ChildItem -LiteralPath .
```

Confirm that the PS1 is listed. After reviewing the source and trusting its origin, unblock only the files you intend to run:

```powershell
Unblock-File -LiteralPath .\Export-HyperVHealthReport.ps1
Unblock-File -LiteralPath .\tests\Test-HyperVHealthReport.ps1
Unblock-File -LiteralPath .\tests\Test-HyperVCollectors.ps1
```

Unblocking removes the downloaded-file marker; it does not create a digital signature. If AllSigned or Group Policy requires signing, use the organization's signing/approval process. Do not change the global policy to Unrestricted or Bypass.

Try the tool without Hyper-V or server access:

```powershell
$result = .\Export-HyperVHealthReport.ps1 -CreateExample -Language en-US
Invoke-Item -LiteralPath $result.Html
```

The browser should show **HV-LAB01**, **HV-LAB02**, **APP-LAB01** and **DB-LAB01**, prominently labeled as synthetic. This command only creates local example files.

## 6. Run offline tests

```powershell
.\tests\Test-HyperVHealthReport.ps1
.\tests\Test-HyperVCollectors.ps1
```

The first validates parsing, assessment rules, serialization, CSV formula protection, HTML escaping, manifests, offline rendering and CLI execution. The second simulates host/cluster queries and owned-job behavior. Successful test runs end with `PASS:`; failures stop with a descriptive message.

These tests do not connect to your Hyper-V infrastructure. They do not replace comparison against Hyper-V Manager and Failover Cluster Manager in a lab.

## 7. Collect the local Hyper-V host

On an authorized lab server, open 64-bit **Windows PowerShell** under the intended account. From a PowerShell 7 terminal, start Windows PowerShell first:

```powershell
powershell.exe -NoProfile
```

Navigate to the script directory as shown in section 5 and verify the runtime:

```powershell
$PSVersionTable.PSVersion
$PSVersionTable.PSEdition
[Environment]::Is64BitProcess
Get-Module -ListAvailable Hyper-V
```

Expect 5.1, Desktop and `True`. Then:

```powershell
$result = .\Export-HyperVHealthReport.ps1 -OutputPath C:\Reports\HyperV -CreateZip
Invoke-Item -LiteralPath $result.Html
```

Without `-ComputerName`, the current computer is the target. A local background job queries that host; no guest agent or guest commands are launched. Read-only collection can still consume CPU, I/O and metadata access resources.

## 8. One or more remote hosts

Replace the sample host names with authorized targets:

```powershell
$result = .\Export-HyperVHealthReport.ps1 -ComputerName HV01 -OutputPath C:\Reports\HyperV

$result = .\Export-HyperVHealthReport.ps1 -ComputerName HV01,HV02 -Language en-US -CreateZip

# A credential prompt appears because this example explicitly requests it.
$credential = Get-Credential
$result = .\Export-HyperVHealthReport.ps1 -ComputerName HV01 -Credential $credential
Invoke-Item -LiteralPath $result.Html
```

No ping result gates collection. DNS, WinRM and authorization are separate dependencies. Hosts are processed sequentially rather than launching hundreds of simultaneous host queries.

## 9. Collect a cluster

Use an **actual member node**, avoiding reliance on a virtual cluster name exposing WinRM:

```powershell
$result = .\Export-HyperVHealthReport.ps1 -ClusterNode HV01 -CreateZip -HostTimeoutSeconds 900
Invoke-Item -LiteralPath $result.Html
```

The script connects to the specified node, reads cluster/nodes/roles/resources/CSV volumes/networks/quorum, then queries each discovered node, including nodes that may be Down. Inaccessible nodes remain explicit. `-ComputerName` and `-ClusterNode` select different parameter sets and cannot be combined.

`-MaxHosts` limits processed nodes. Cluster discovery and every host have separate time budgets. Ownership/VM state may change during Live Migration; this is not a transactional cluster snapshot and cannot guarantee a unique cross-host census across different collection times.

The script does not run Test-Cluster, failover, drain, Live Migration or quorum changes. It does not certify N+1/HA capacity: placement, reserve, compatibility, affinity, NUMA and workload must also be evaluated.

## 10. Run from VSCode

Use **File → Open Folder** to open the tool directory, then **Terminal → New Terminal**. Confirm the terminal is in the directory containing the PS1 with `Get-ChildItem`. If already there, do not run another `cd .\hyper-v-health-report`.

For the example, use section 5 directly. For live collection, run `powershell.exe -NoProfile` in the terminal and follow sections 7–9. The PowerShell extension helps with editing but is not required for terminal execution. Using explicit terminal commands makes runtime and working directory easier to verify than generic Run Code buttons.

## 11. Output structure and sharing

```text
HyperV-Reports/
└── HyperV-YYYYMMDD-HHMMSS-identifier/
    ├── report.html
    ├── report.json
    ├── MANIFEST-SHA256.txt
    └── csv/
        ├── Hosts.csv
        ├── VMs.csv
        ├── Findings.csv
        ├── Coverage.csv
        ├── Errors.csv
        └── ... all 54 datasets
```

`-CreateZip` creates a sibling ZIP file. Every run uses a new directory rather than overwriting earlier reports. `OutputPath` is local to the collector, even for remote targets. UNC paths and paths traversing reparse points/symlinks are rejected. This path validation does not isolate the process against concurrent filesystem changes.

Share the ZIP or complete directory so CSV links continue to work. GitHub's file view is not the browser report: download/extract before viewing. For Server Core, move the package to an authorized workstation with a browser.

Files inherit output-directory permissions; the script does not enforce private ACLs. Choose an appropriate directory. Do not publish real reports in this public repository: host names, addresses, paths, notes and event messages may reveal internal information. Published examples are synthetic.

## 12. Reading the HTML

Start with the summary cards and host summary, then read Findings, Coverage and Errors before taking action. Cards count observed records. Partial collection or migration means they are not guaranteed infrastructure totals.

Each finding includes severity, rule, host, target, evidence, recommendation and `SourceId`; source IDs are mapped later in this manual. Critical prioritizes a significant signal, Warning requires review, and Info provides context. None authorizes automatic destructive action.

Search globally or within a section for a VM, path or event. The severity selector applies only to findings. Sections expand/collapse individually or together; navigation opens the target section. Printing uses the browser and can save a PDF; it does not create a second PDF manual in the repository. Active filters also affect printed visible rows.

By default HTML renders at most **500 rows per dataset**. A section notice identifies truncation. Search covers rendered rows only. CSV and JSON contain all actually exported records, within collection limits; a “full CSV” cannot recover items omitted by timeout, caps or permission failures.

`—` means unknown/not reported, not zero. Some identifiers and property names remain technical for correlation with cmdlets and CSV files. Dataset explanations and units appear later in this manual.

## 13. CSV, Excel, JSON and integrity

CSV files use commas, quoted fields, doubled internal quotes and **UTF-8 with BOM**. If regional Excel settings show one column, use **Data → From Text/CSV**, selecting UTF-8 and comma delimiter. PowerShell examples:

```powershell
$vms = Import-Csv -LiteralPath (Join-Path $result.CsvDirectory 'VMs.csv')
$vms | Select-Object Host,VMName,State,ProcessorCount

$findings = Import-Csv -LiteralPath (Join-Path $result.CsvDirectory 'Findings.csv')
$findings | Where-Object Severity -eq 'Critical'
```

Text beginning with spreadsheet formula characters (`=`, `+`, `-`, `@`, including certain whitespace/control prefixes) receives a leading apostrophe in CSV to reduce formula execution. Typed negative numbers remain numeric. JSON preserves original normalized values before this presentation protection; it is not a dump of complete native objects and contains no credentials.

Calculated dates use ISO8601 UTC; provider date/duration text is preserved when the provider does not expose a typed date. Arrays become `; `-separated values rather than independent rows. Missing properties are JSON null and empty CSV fields. SchemaVersion 1, tool Version 1.0.0, RunId, parameters and timestamps support traceability.

The manifest contains SHA256 for HTML, JSON and CSV files with relative paths. It excludes itself and the external ZIP. Hashes detect changes against a trusted manifest; **they do not authenticate authorship and are not digital signatures**.

## 14. Recreate outputs without reconnecting

```powershell
$file = Read-Host 'Paste the full report.json path'
$newOutput = .\Export-HyperVHealthReport.ps1 -InputJson $file.Trim('"') -Language en-US -CreateZip
Invoke-Item -LiteralPath $newOutput.Html
```

This mode validates and reexports a local JSON report. It does not query servers, reassess rules or change thresholds. The interface language changes; recommendations already stored in JSON retain their original collection language. For all recommendations in another language, collect or create the example in that language initially.

Only completed schema-1 reports from this tool are accepted, in regular local files up to 100 MiB. Nested dataset field values are rejected. The offline reader allows at most 200,000 records per dataset; exceptionally large live reports may require external processing. JSON cannot supply executable query configuration.

## 15. Coverage, failures and timing

| Probe status | Interpretation |
|---|---|
| Collected | Query/projection returned records; not a health verdict |
| Empty | Query completed without records; distinct from failure |
| Failed | Read/projection did not complete normally; inspect Errors |
| Unsupported | Cmdlet unavailable on the target; feature was not assessed |
| NotRequested | Optional feature not selected, such as BPA or cluster discovery in host mode |
| NotApplicable | For example, generation-2 firmware/vTPM on a generation-1 VM, or VHD inspection of a pass-through disk |
| NotEnabled | Replica/resource metering already disabled; the script does not enable it |
| Truncated | More records existed than the configured cap; remaining records were not exported |
| Partial | VHD parent chain stopped because of read failure, cycle or depth cap |
| TimedOut | Host/discovery job exceeded its budget; subsequent probes are unknown |
| Disabled | Event channel disabled; not evidence of no relevant events |

Completed describes completion without the warnings the code identified; CompletedWithIssues includes review findings and/or incomplete coverage; SyntheticExample is demonstration only. Runtime/parameter/JSON/output errors throw and stop execution. CompletedWithIssues is still successful program execution for process-exit purposes: automation must inspect Status, Coverage and Findings rather than only LASTEXITCODE.

Default budget is 600 seconds per worker. Hosts run sequentially; cluster discovery has its own budget, so this is not a global deadline. Remote session options use a 30-second OpenTimeout and 120-second OperationTimeout. An interrupted in-progress probe is lost; completed packets already emitted are retained.

Only the job returned to this invocation is stopped/removed by reference. No global job cleanup affects unrelated work. DurationSeconds measures each probe; event retrieval currently happens before the packet, so Events duration measures projection/publication rather than total native event-query time. Run StartedUtc/EndedUtc delimit collection/assessment before file finalization.

## 16. Capacity interpretation

CPU: configured virtual processors are not consumed CPU. The ratio compares vCPU in running records with host logical processors. There is no universal Microsoft 8:1 sizing rule: the default is a local review trigger that must be adapted to workload. CPUUsage/LoadPercentage are snapshots, not historical utilization, CPU wait or latency guarantees.

Memory: OS TotalVisibleMemorySize/FreePhysicalMemory values are KiB converted to bytes, not a DIMM inventory. Startup, assigned, demanded, minimum and maximum memory are different concepts. Dynamic-memory maxima are not current consumption. Free-memory thresholds request review, not automatic diagnosis.

Disks: FileSizeBytes is Hyper-V's reported file size; VirtualSizeBytes is virtual guest capacity. Neither alone measures physical SAN/S2D/SOFS allocation or guest filesystem free space. ReFS, block cloning, deduplication and thin provisioning affect physical relationships. Guest filesystems are not queried.

StorageCapacity groups only successfully read paths that can be correlated to a host volume. Paths are deduplicated per host; parent disks are included. Summing virtual child and parent capacities does **not** produce unique useful capacity. NominalGrowthBytes = max(0, virtual-size sum − file-size sum) is an observed nominal difference, not a forecast or certified overcommit calculation. SMB/unmatched paths are excluded. Never sum repeated shared CSV/volume observations across hosts as physical cluster storage.

Checkpoints: the default seven-day threshold is an initial FMODEL policy, not a universal Microsoft expiration. Recovery/backup checkpoints, intentional checkpoints and merges may exist. Do not manually delete AVHDX files. The script does not perform unrestricted orphan-disk scans or mount/test/repair VHDs.

Replica: Normal is current engine-reported health, not proof of RPO, secondary-site capacity or recovery success. Backup and Replica solve different problems. No backup, VM export, checkpoint, failover test or restore test is started.

## 17. Security and best-practice review

Compare Secure Boot, vTPM, shielding, state/migration encryption and Device Guard with organizational policy and guest compatibility. The tool does not classify every VM without vTPM as insecure. Generation 1 does not expose the same firmware capabilities as generation 2.

Networking includes vSwitch/SET/VLAN, host and VM adapters, guest-reported IPs, guards and offloads. A reported guest IP does not prove connectivity, DNS or freshness. A Down interface alone is not a fault. Duplicate MACs require identity/isolation review; isolated replicas and separate networks may justify them. Configured RDMA/VMQ/SR-IOV capabilities do not prove active data paths, redundancy or throughput.

SMB data describes local configuration and connections visible under the collection identity. Empty connections do not prove Hyper-V never uses SMB; service and authentication contexts matter. Enabled SMB1 raises a warning. QFE is not a complete patch catalog; the tool does not compare against a baseline, security advisories, supported firmware or vulnerability databases.

BPA is **opt-in** and reads only existing Microsoft/Windows/Hyper-V results. It does not launch a new scan or guarantee freshness; verify result date/scope directly in the organization's BPA tools. FMODEL review rules are not presented as official BPA rules.

HTML encodes collected text and uses a nonce-based CSP for its own styles/scripts. No external libraries or images are loaded. Reports still contain internal information and are not anonymized. No private keys, VM key protectors or disk contents are collected.

## 18. Events and reboot evidence

Default event selection is the last seven days, levels **1 Critical, 2 Error and 3 Warning**, at most 200 records per channel. Channels: System, Application, Microsoft-Windows-Hyper-V-VMMS-Admin, Microsoft-Windows-Hyper-V-Worker-Admin, Microsoft-Windows-Hyper-V-Hypervisor-Admin and Microsoft-Windows-FailoverClustering/Operational. Missing/denied/disabled channels remain explicit. A standalone host may have no cluster channel.

Event counts are not current incident verdicts. Translated event message text is not parsed to guess success. Reduce scope with `-EventDays 1 -MaxEventsPerLog 100`, or use `-SkipEvents`.

Reboot evidence reads registry CBS RebootPending, WindowsUpdate RebootRequired and PendingFileRenameOperations signals. The first two request review when present. File-rename queues are informational only: they can persist and do not independently confirm a current reboot requirement. These keys do not cover every product/installer. S10 documents a separate Windows Update API that the script **does not call**; do not confuse these heuristic signals with that API's official state.

## 19. Troubleshooting

| Symptom | Next step |
|---|---|
| Repeated directory in cd | Check Get-Location/Get-ChildItem; do not enter a directory you are already in |
| Unsigned script blocked | Review origin and unblock the specific file; follow organizational signing if AllSigned/GPO applies |
| Live mode rejected in PS7 | Start powershell.exe -NoProfile and verify 5.1 Desktop x64 |
| Hyper-V module missing | Use the correct host and verify preinstalled module; the program does not install roles/features |
| WinRM/DNS/access denied | Verify target, endpoint and delegated rights; do not broadly relax firewall/TrustedHosts |
| VHD inaccessible | Check owning host, migration, permission and SMB second hop; do not assume missing file |
| No cluster nodes | Use an actual member and verify FailoverClusters/access; inspect Coverage/Errors |
| Empty tables | Distinguish Empty, Unsupported, NotRequested, NotApplicable and Failed |
| Truncation | Intentionally increase caps or reduce scope/period; CSV cannot recover uncollected records |
| Timeout | Start with one host, reduce scope/events or adjust budget after understanding the delay |
| No browser on server | View the complete directory/ZIP on an authorized workstation; common on Server Core |
| Single-column Excel | Import using comma delimiter and UTF-8 |
| Cannot access output folder | Choose a directory with suitable inherited permissions |

## 20. Lab acceptance

First run the example and offline tests. Then collect an authorized noncritical host. Compare VM counts/IDs/states with Hyper-V Manager, and volumes/checkpoints/VLAN/Replica with their corresponding cmdlets. Confirm that only local report files were created and infrastructure configuration remained unchanged.

Next validate one remote host and a small cluster, checking every node's coverage. Include an Off VM, a generation-1 VM if available, disabled resource metering and a delegated account lacking some permissions. Do not deliberately cause production outages or storage exhaustion. Synthetic cycle/depth tests do not instruct you to create invalid real disks.

Validate environment-specific cases: in-use VHD ownership, CSV ownership/migration, authenticated SMB storage, trunk/private VLANs, extended Replica, Linux guests and properties absent from your OS version. Compare CSVs with direct authorized queries. Record version/runtime/targets, expected results and accepted limitations.

## 21. Presentation and questions

Suggested introduction:

“This FMODEL tool collects read-only Hyper-V evidence. It separates hosts, VMs, storage, networking, cluster data and events into exportable datasets. The summary helps prioritize investigation, while coverage identifies successful, failed and limited queries. Recommendations never become automatic remediation. Decisions remain subject to workload requirements, organizational policy and team validation.”

| Question | Study answer |
|---|---|
| Does it change VMs or restart hosts? | No. It writes local reports and manages only its own collection jobs |
| Does it require a guest agent? | It does not install an agent or execute guest commands; some reported IP/state data depends on existing integration information |
| Is an empty field a fault? | Not necessarily: version, applicability, disabled features and failed queries can all explain it |
| Does Collected mean healthy? | No. It describes data retrieval, not availability/security certification |
| Does it verify backup? | No backup-product query or restore is performed; checkpoints and Replica do not prove backup |
| Why Windows PowerShell 5.1? | It is this release's operational runtime for Windows modules; PS7 was validated for offline paths |
| Are these official Microsoft rules? | They are FMODEL review rules informed by Microsoft sources, including local policy thresholds |
| What is the operational impact? | Read queries still consume resources; start in a small authorized lab scope |
| Can it be scheduled? | An approved account can invoke the PS1 from external scheduling; the script creates no scheduled task |
| How do we detect file changes? | Compare SHA256 against a trusted source manifest; this does not replace digital signing |
| Is it fully validated in our infrastructure? | No. Synthetic tests and rendering were checked; real infrastructure acceptance remains separate |

## 22. Internal architecture

The PS1 is standalone: schema, normalization, collection, assessment and HTML functions live in the same file. Normal invocation runs the entrypoint. Dot-sourcing loads functions for inspection/tests without collection, but sets StrictMode and ErrorActionPreference in the importing scope. For normal operation use `&`/`.\`, not dot-sourcing.

Invoke-HvMain selects mode, validates runtime/thresholds and builds targets. Invoke-HvBoundedWorker creates a local or remote job from a fixed internal scriptblock. Invoke-HvWorker runs independent probes and emits normalized packets. Add-HvPacket records rows/coverage/errors. Invoke-HvAssessment applies rules and derives summaries. Write-HvDeliverables writes CSV/JSON/HTML, manifest and optional ZIP.

Computer names are validated cmdlet arguments, not executable code. Scriptblock creation uses the fixed internal function, never a JSON/report field. Native objects remain inside the worker; reports contain selected normalized values. Offline JSON cannot supply executable commands.

When extending the tool, update schemas before adding columns, review 5.1 compatibility, preserve unknown versus zero, add a relevant behavioral test and update both manuals. Synthetic example totals are not operational evidence.


## 23. Complete parameter reference

Modes: Hosts (default), Cluster, Example and Offline. Collection/threshold options do not change JSON rendering. CreateExample uses fixed data without live queries.

| Parameter | Type / range | Default | Effect |
|---|---|---|---|
| `-ComputerName` | string[] | current computer | Explicit hosts; names/IPv4, localhost or ::1. No wildcards. |
| `-ClusterNode` | string | — | Actual cluster member; exclusive mode. |
| `-InputJson` | string | — | Local report for offline rendering; no reassessment. |
| `-CreateExample` | switch | False | Synthetic demonstration without servers. |
| `-Credential` | PSCredential | current identity | Remote host/cluster modes only; not persisted. |
| `-OutputPath` | string | ./HyperV-Reports | Local output root; unique run directory. |
| `-Language` | pt-BR / en-US | pt-BR | New assessment/interface language. |
| `-CreateZip` | switch | False | Compresses the result directory. |
| `-MaxHtmlRows` | int 1–5000 | 500 | Rendered rows per table, not CSV collection cap. |
| `-HostTimeoutSeconds` | int 30–7200 | 600 | Budget per host/discovery job. |
| `-MaxHosts` | int 1–512 | 128 | Maximum processed targets; extras explicitly truncated. |
| `-MaxVMsPerHost` | int 1–20000 | 2000 | VM inventory cap per host; explicit truncation. |
| `-MaxRowsPerProbe` | int 1–50000 | 5000 | Per-probe cap, not whole-run/dataset cap. |
| `-MaxVhdDepth` | int 1–128 | 32 | Maximum disks read in a chain; extra marker records limit. |
| `-EventDays` | int 1–90 | 7 | Recent window per channel, level 1/2/3. |
| `-MaxEventsPerLog` | int 1–5000 | 200 | Exported cap per channel/host; one extra queried to detect truncation. |
| `-SkipEvents` | switch | False | Skips event logs with NotRequested coverage. |
| `-IncludeBpaResults` | switch | False | Reads existing BPA results; does not initiate scan. |
| `-VolumeWarningPercent` | double 1–99 | 15 | Warning below free percentage; local policy. |
| `-VolumeCriticalPercent` | double 0.1–98 | 5 | Critical below, must be below Warning. |
| `-MemoryWarningPercent` | double 1–99 | 10 | Review host free memory below threshold. |
| `-MemoryCriticalPercent` | double 0.1–98 | 5 | Critical below, must be below Warning. |
| `-CheckpointWarningDays` | double 0–3650 | 7 | Warning when age exceeds, not equals. |
| `-VcpuRatioWarning` | double 1–128 | 8 | Info above configured ratio; not contention diagnosis. |

Thresholds use strict comparisons (`<`/`>`); equality does not trigger a rule. `-Verbose` is a common parameter. There is no WhatIf/remediation mode: live collection is read-only. Parameter/runtime/output errors throw; partial data can produce CompletedWithIssues.

## 24. All datasets, sources and fields

Each dataset has a CSV even when empty. Missing properties remain unknown. Machine-readable schema: `../tests/evidence/CSV-SCHEMAS.json`. These are selected contract fields, not every possible Windows object property.

### 24.1. Hosts — `Hosts.csv`

**Source:** `Get-CimInstance: Win32_OperatingSystem / Win32_ComputerSystem`.

One row per host: OS, manufacturer/model, domain, boot, visible memory and processors. CIM KiB memory is converted to bytes; uptime derives from boot.

**Fields in CSV order:**

```text
Host, CollectedUtc, Manufacturer, Model, Domain, OSCaption, OSVersion, Build, LastBootUtc, UptimeHours, MemoryTotalBytes, MemoryFreeBytes, MemoryFreePercent, LogicalProcessors, PhysicalProcessors, HypervisorPresent
```

### 24.2. Host configuration — `HostSettings.csv`

**Source:** `Get-VMHost`.

Default directories, NUMA spanning, Live Migration/authentication/concurrency and MAC range. Migration configuration does not prove a migration will succeed.

**Fields in CSV order:**

```text
Host, VirtualMachinePath, VirtualHardDiskPath, NumaSpanningEnabled, VirtualMachineMigrationEnabled, VirtualMachineMigrationAuthenticationType, VirtualMachineMigrationPerformanceOption, MaximumVirtualMachineMigrations, MaximumStorageMigrations, UseAnyNetworkForMigration, MacAddressMinimum, MacAddressMaximum, EnableEnhancedSessionMode
```

### 24.3. Processors — `Processors.csv`

**Source:** `Get-CimInstance: Win32_Processor`.

One row per reported physical processor. MaxClockSpeed is MHz; LoadPercentage is a provider snapshot, not guaranteed total hypervisor utilization. Virtualization flags may vary while the hypervisor is active.

**Fields in CSV order:**

```text
Host, DeviceID, Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, LoadPercentage, VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions
```

### 24.4. NUMA — `NumaNodes.csv`

**Source:** `Get-VMHostNumaNode`.

NUMA node topology and cmdlet-reported total/available memory in MiB. Does not change NUMA or automatically choose VM topology.

**Fields in CSV order:**

```text
Host, NodeId, ProcessorCount, MemoryTotal, MemoryAvailable
```

### 24.5. Supported VM versions — `SupportedVersions.csv`

**Source:** `Get-VMHostSupportedVersion`.

Host-supported VM configuration versions. VM version differs from Windows version and VM generation; no configuration upgrade is performed.

**Fields in CSV order:**

```text
Host, Name, Version, IsDefault
```

### 24.6. Services — `Services.csv`

**Source:** `Get-CimInstance: Win32_Service`.

Only vmms, vmcompute, ClusSvc, WinRM, VSS, swprv and W32Time when present. Stopped demand-start services are not automatically failures; a specific rule reviews vmms.

**Fields in CSV order:**

```text
Host, Name, State, StartMode, Status
```

### 24.7. QFE updates — `Hotfixes.csv`

**Source:** `Get-CimInstance: Win32_QuickFixEngineering`.

QFE/HotFixID inventory and provider installation date. Not a complete update catalog or CVE audit; InstalledOn may remain provider text.

**Fields in CSV order:**

```text
Host, HotFixID, Description, InstalledOn
```

### 24.8. Reboot signals — `RebootSignals.csv`

**Source:** `Get-Item / Get-ItemProperty: Registry`.

Three host registry signals. Permission failure is not treated as a missing key. PendingFileRenameOperations remains informational.

**Fields in CSV order:**

```text
Host, Signal, Present, Detail
```

### 24.9. Volumes — `Volumes.csv`

**Source:** `Get-Volume`.

Host-visible volumes, including letterless volumes. SizeBytes/FreeBytes map Size/SizeRemaining; FreePercent requires a positive denominator. Free-space rules assess known-size Fixed volumes.

**Fields in CSV order:**

```text
Host, Path, UniqueId, DriveLetter, FileSystemLabel, FileSystemType, HealthStatus, OperationalStatus, DriveType, SizeBytes, FreeBytes, FreePercent
```

### 24.10. Physical disks — `PhysicalDisks.csv`

**Source:** `Get-PhysicalDisk`.

Disks exposed by the Storage subsystem. RAID/SAN may expose abstractions rather than all physical devices. No complete SMART/vendor diagnostic is collected.

**Fields in CSV order:**

```text
Host, FriendlyName, UniqueId, MediaType, BusType, HealthStatus, OperationalStatus, Size, CanPool, Usage
```

### 24.11. Storage pools — `StoragePools.csv`

**Source:** `Get-StoragePool`.

Windows-visible pools, including primordial pools if returned. Size/AllocatedSize are bytes; not a complete SAN inventory or S2D topology.

**Fields in CSV order:**

```text
Host, FriendlyName, UniqueId, IsPrimordial, HealthStatus, OperationalStatus, Size, AllocatedSize
```

### 24.12. Host adapters — `NetworkAdapters.csv`

**Source:** `Get-NetAdapter -IncludeHidden`.

Physical/virtual/hidden adapters, state, MAC, link and available driver data. An unused Down adapter does not automatically raise a finding.

**Fields in CSV order:**

```text
Host, Name, InterfaceDescription, InterfaceIndex, Status, MacAddress, LinkSpeed, DriverInformation, DriverVersion, DriverDate, NdisVersion, Virtual, HardwareInterface
```

### 24.13. Host IP addresses — `NetworkIPs.csv`

**Source:** `Get-NetIPAddress`.

Host adapter addresses and prefixes. Does not resolve DNS, test gateways or automatically classify management versus storage networks.

**Fields in CSV order:**

```text
Host, InterfaceAlias, InterfaceIndex, AddressFamily, IPAddress, PrefixLength, AddressState, PrefixOrigin, SuffixOrigin
```

### 24.14. Virtual switches — `Switches.csv`

**Source:** `Get-VMSwitch`.

Switches and External/Internal/Private type, associated adapters and SET/SR-IOV flags. Availability depends on OS version and hardware.

**Fields in CSV order:**

```text
Host, Name, Id, SwitchType, NetAdapterInterfaceDescription, AllowManagementOS, EmbeddedTeamingEnabled, IovEnabled, IovSupport, BandwidthReservationMode
```

### 24.15. Switch Embedded Teaming — `SwitchTeams.csv`

**Source:** `Get-VMSwitchTeam`.

Queried only for switches with EmbeddedTeamingEnabled=True. Records mode/algorithm; does not test cable failover or provide a full LBFO inventory.

**Fields in CSV order:**

```text
Host, Name, NetAdapterInterfaceDescription, TeamingMode, LoadBalancingAlgorithm
```

### 24.16. Live Migration networks — `MigrationNetworks.csv`

**Source:** `Get-VMMigrationNetwork`.

Allowed Live Migration subnets and priority when available. Does not initiate migration or verify end-to-end authentication.

**Fields in CSV order:**

```text
Host, Subnet, Priority
```

### 24.17. Hyper-V Replica service — `HostReplica.csv`

**Source:** `Get-VMReplicationServer`.

Host Replica receiver configuration, authentication/ports/location. No certificates/private keys or active Replica connectivity tests.

**Fields in CSV order:**

```text
Host, ReplicationEnabled, AllowedAuthenticationType, KerberosAuthenticationPort, CertificateAuthenticationPort, DefaultStorageLocation, ReplicationAllowedFromAnyServer
```

### 24.18. Virtual machines — `VMs.csv`

**Source:** `Get-VM`.

Base inventory per host. VMId identifies the VM; names may repeat. Includes state/version/generation, CPU/memory snapshot, automatic actions, paths and notes. Legacy integration version/state fields may be empty.

**Fields in CSV order:**

```text
Host, VMId, VMName, Generation, Version, State, Status, OperationalStatus, UptimeHours, CPUUsage, ProcessorCount, MemoryAssigned, MemoryDemand, MemoryStatus, DynamicMemoryEnabled, MemoryStartup, AutomaticStartAction, AutomaticStopAction, AutomaticStartDelay, CheckpointType, AutomaticCheckpointsEnabled, ReplicationState, ReplicationHealth, IntegrationServicesState, IntegrationServicesVersion, ResourceMeteringEnabled, IsClustered, ConfigurationLocation, SnapshotFileLocation, SmartPagingFilePath, Notes
```

### 24.19. VM CPU settings — `VMProcessors.csv`

**Source:** `Get-VMProcessor -VM`.

vCPU, limits/reserves/weight, migration compatibility, nested virtualization and NUMA limits. Count is not actual consumption.

**Fields in CSV order:**

```text
Host, VMId, VMName, Count, Reserve, Maximum, RelativeWeight, CompatibilityForMigrationEnabled, CompatibilityForOlderOperatingSystemsEnabled, ExposeVirtualizationExtensions, HwThreadCountPerCore, MaximumCountPerNumaNode, MaximumCountPerNumaSocket, EnableHostResourceProtection
```

### 24.20. VM memory settings — `VMMemory.csv`

**Source:** `Get-VMMemory -VM`.

Startup/Minimum/Maximum are bytes; Buffer is a percentage and Priority is Hyper-V weight. DynamicMemoryEnabled controls applicability of dynamic limits.

**Fields in CSV order:**

```text
Host, VMId, VMName, DynamicMemoryEnabled, Startup, Minimum, Maximum, Buffer, Priority, MaximumAmountPerNumaNode
```

### 24.21. Attached disks — `VMDisks.csv`

**Source:** `Get-VMHardDiskDrive -VM`.

One row per disk attachment: controller/location, Path or pass-through DiskNumber, persistent reservations and available QoS. Empty Path does not imply a missing disk.

**Fields in CSV order:**

```text
Host, VMId, VMName, ControllerType, ControllerNumber, ControllerLocation, Path, DiskNumber, SupportPersistentReservations, MaximumIOPS, MinimumIOPS, QoSPolicyID
```

### 24.22. VHD parent chains — `VHDChains.csv`

**Source:** `Get-VHD -Path, cadeia limitada`.

One row per level from each attached disk. Depth=0 is the queried attachment root. ReadStatus distinguishes Read, Error, DepthLimit and CycleDetected. Does not enumerate every disk on storage.

**Fields in CSV order:**

```text
Host, VMId, VMName, RootPath, Depth, Path, ParentPath, VhdFormat, VhdType, FileSizeBytes, VirtualSizeBytes, MinimumSizeBytes, FragmentationPercentage, LogicalSectorSize, PhysicalSectorSize, BlockSize, Attached, DiskIdentifier, ReadStatus, Error
```

### 24.23. VM networking — `VMNetworkAdapters.csv`

**Source:** `Get-VMNetworkAdapter -VM`.

Per-VM adapters, switch association, reported MAC/IPs, spoofing/guards/mirroring/protection/QoS/offload. IPs are informational, not connectivity probes.

**Fields in CSV order:**

```text
Host, VMId, VMName, Name, Id, IsLegacy, SwitchName, SwitchId, Status, MacAddress, DynamicMacAddressEnabled, IPAddresses, MacAddressSpoofing, DhcpGuard, RouterGuard, PortMirroring, ProtectedNetwork, IovWeight, VmqWeight, MinimumBandwidthAbsolute, MinimumBandwidthWeight, MaximumBandwidth
```

### 24.24. VM VLAN settings — `VMVlans.csv`

**Source:** `Get-VMNetworkAdapterVlan -VMNetworkAdapter`.

One configuration per queried adapter. OperationMode contextualizes access/native/trunk/private VLAN fields; fields for other modes may be empty or provider-zero.

**Fields in CSV order:**

```text
Host, VMId, VMName, AdapterName, OperationMode, AccessVlanId, NativeVlanId, AllowedVlanIdList, PrimaryVlanId, SecondaryVlanId, SecondaryVlanIdList
```

### 24.25. Integration services — `IntegrationServices.csv`

**Source:** `Get-VMIntegrationService -VM`.

Integration services per VM: ID, Enabled and native status. Names/status may be localized. An Off VM is not automatically a heartbeat failure; Guest Service Interface may intentionally be disabled.

**Fields in CSV order:**

```text
Host, VMId, VMName, Name, Id, Enabled, PrimaryStatusDescription, SecondaryStatusDescription, PrimaryOperationalStatus, SecondaryOperationalStatus
```

### 24.26. Checkpoints — `Checkpoints.csv`

**Source:** `Get-VMSnapshot -VM`.

Cmdlet-visible checkpoints, including returned types. Calculated CreationTimeUtc/AgeDays; ParentSnapshot* describe hierarchy. No orphan-file scan or guarantee of every transient backup state.

**Fields in CSV order:**

```text
Host, VMId, VMName, Name, Id, ParentSnapshotId, ParentSnapshotName, CreationTimeUtc, AgeDays, SnapshotType
```

### 24.27. Replication — `Replication.csv`

**Source:** `Get-VMReplication -VM`.

Returned replication relationships, including extended relationships when exposed. ReplicationState=Disabled produces NotEnabled. Reported health/time do not prove recovery.

**Fields in CSV order:**

```text
Host, VMId, VMName, State, Health, Mode, RelationshipType, PrimaryServer, ReplicaServer, ReplicaPort, AuthenticationType, FrequencySec, LastReplicationTimeUtc, RecoveryHistory, AutoResynchronizeEnabled, ResynchronizeStartTime, ResynchronizeEndTime
```

### 24.28. Replica statistics — `ReplicationStats.csv`

**Source:** `Measure-VMReplication -VM`.

Statistics from Replica existing monitoring interval. Property availability depends on version; intervals are not uniform across hosts. Monitoring is not changed/reset.

**Fields in CSV order:**

```text
Host, VMId, VMName, ReplicationHealth, ReplicationState, LastReplicationTime, LastApplyTime, AverageReplicationLatency, AverageReplicationSize, PendingReplicationSize, MissedReplicationCount, SuccessfulReplicationCount, MonitoringStartTime, MonitoringInterval
```

### 24.29. VM firmware — `VMFirmware.csv`

**Source:** `Get-VMFirmware -VM`.

Generation 2 only. SecureBoot/template/network-boot/console where available. Secure Boot Off is a contextual observation, not a malware verdict.

**Fields in CSV order:**

```text
Host, VMId, VMName, SecureBoot, SecureBootTemplate, PreferredNetworkBootProtocol, ConsoleMode
```

### 24.30. VM security settings — `VMSecurity.csv`

**Source:** `Get-VMSecurity -VM`.

Generation 2 in this tool: vTPM, shielding and state/traffic encryption. Does not read Get-VMKeyProtector or validate Host Guardian Service.

**Fields in CSV order:**

```text
Host, VMId, VMName, TpmEnabled, Shielded, EncryptStateAndVmMigrationTraffic, VirtualizationBasedSecurityOptOut, KsdEnabled
```

### 24.31. Existing resource metering — `VMResources.csv`

**Source:** `Measure-VM -VM`.

Only when ResourceMeteringEnabled is already True. Average CPU is MHz; metering memory uses cmdlet-native MB; duration/aggregates follow the existing interval. Metering is not enabled.

**Fields in CSV order:**

```text
Host, VMId, VMName, MeteringDuration, AverageProcessorUsage, AverageMemoryUsage, MaximumMemoryUsage, MinimumMemoryUsage, TotalDiskAllocation, AggregatedAverageNormalizedIOPS, AggregatedAverageLatency, AggregatedDiskDataRead, AggregatedDiskDataWritten
```

### 24.32. Optical media — `DVDDrives.csv`

**Source:** `Get-VMDvdDrive -VM`.

Controller and attached optical/ISO media. Empty Path can mean an empty drive. No media ejection or ISO content access.

**Fields in CSV order:**

```text
Host, VMId, VMName, ControllerNumber, ControllerLocation, Path, DvdMediaType
```

### 24.33. DDA devices — `AssignedDevices.csv`

**Source:** `Get-VMAssignableDevice -VM`.

VM-attached DDA devices when available. Does not enumerate every host-assignable device or validate drivers/failover support.

**Fields in CSV order:**

```text
Host, VMId, VMName, Name, InstanceID, LocationPath
```

### 24.34. Virtual Fibre Channel — `FibreChannel.csv`

**Source:** `Get-VMFibreChannelHba -VM`.

Virtual Fibre Channel HBAs and A/B WWNs. Does not query SAN switches, zoning or guest LUNs.

**Fields in CSV order:**

```text
Host, VMId, VMName, Name, SanName, WorldWideNodeNameSetA, WorldWideNodeNameSetB, WorldWidePortNameSetA, WorldWidePortNameSetB
```

### 24.35. Cluster — `Cluster.csv`

**Source:** `Get-Cluster`.

Cluster configuration from the seed node: functional level, dynamic quorum and available communication/quarantine settings. Fault tolerance is not changed.

**Fields in CSV order:**

```text
Host, Name, Domain, ClusterFunctionalLevel, DynamicQuorum, DynamicWitness, QuarantineThreshold, QuarantineDuration, SameSubnetDelay, SameSubnetThreshold, CrossSubnetDelay, CrossSubnetThreshold
```

### 24.36. Cluster nodes — `ClusterNodes.csv`

**Source:** `Get-ClusterNode`.

Membership used to build host scope. State/DrainStatus/NodeWeight/DynamicWeight are cluster snapshots; query connectivity is evaluated separately.

**Fields in CSV order:**

```text
Host, Name, Id, State, NodeWeight, DynamicWeight, DrainStatus, FaultDomain
```

### 24.37. Cluster roles — `ClusterGroups.csv`

**Source:** `Get-ClusterGroup`.

Roles/groups, state and owner node. Not every role is a VM; Offline may be intentional. Does not automatically correlate every dependency with VMId.

**Fields in CSV order:**

```text
Host, Name, Id, State, OwnerNode, GroupType, Priority, FailoverThreshold, FailoverPeriod
```

### 24.38. Cluster resources — `ClusterResources.csv`

**Source:** `Get-ClusterResource`.

Resources/type, owner role/node, core flag and state. The review rule highlights Failed rather than classifying every Offline resource as failed.

**Fields in CSV order:**

```text
Host, Name, Id, State, OwnerGroup, OwnerNode, ResourceType, IsCoreResource
```

### 24.39. Cluster shared volumes — `ClusterVolumes.csv`

**Source:** `Get-ClusterSharedVolume / SharedVolumeInfo.Partition`.

One row per SharedVolumeInfo: CSV path, partition, capacity, redirection and FaultState. CSV here means Cluster Shared Volume, distinct from a data .csv file.

**Fields in CSV order:**

```text
Host, Name, OwnerNode, State, Path, PartitionName, FileSystem, SizeBytes, FreeBytes, FreePercent, RedirectedAccess, FaultState
```

### 24.40. Cluster networks — `ClusterNetworks.csv`

**Source:** `Get-ClusterNetwork`.

Cluster network addresses, roles and metrics. Does not test cables, redundancy or physical isolation.

**Fields in CSV order:**

```text
Host, Name, Address, AddressMask, Role, State, Metric, AutoMetric
```

### 24.41. Quorum — `ClusterQuorum.csv`

**Source:** `Get-ClusterQuorum`.

Reported quorum type and witness resource. Witness presence does not prove availability or appropriate design.

**Fields in CSV order:**

```text
Host, Cluster, QuorumType, QuorumResource
```

### 24.42. Recent events — `Events.csv`

**Source:** `Get-WinEvent`.

Records within selected channels/window/levels. EventId/Provider/RecordId/time/message support correlation. Missing localized messages cannot be interpreted as success.

**Fields in CSV order:**

```text
Host, LogName, TimeCreatedUtc, EventId, Level, Provider, RecordId, Message
```

### 24.43. Event coverage — `EventCoverage.csv`

**Source:** `Derivado da busca Get-WinEvent`.

One row per channel: UTC window, state, cap and truncation. Rows counts exported records, not all events in the channel/window.

**Fields in CSV order:**

```text
Host, LogName, StartUtc, EndUtc, Status, Rows, Truncated, Limit, Error
```

### 24.44. Existing BPA results — `BpaResults.csv`

**Source:** `Get-BpaResult -ModelId Microsoft/Windows/Hyper-V`.

Only with IncludeBpaResults. Existing results; native Compliance/Excluded/recommendations do not prove a new or recent scan.

**Fields in CSV order:**

```text
Host, ModelId, ResultNumber, Severity, Category, Title, Problem, Impact, Resolution, Compliance, Excluded
```

### 24.45. Virtualization-based security — `DeviceGuard.csv`

**Source:** `Get-CimInstance root/Microsoft/Windows/DeviceGuard: Win32_DeviceGuard`.

VBS status and numeric service/property arrays. VirtualizationBasedSecurityStatus: 0 disabled, 1 enabled but not running, 2 enabled and running; decode other arrays against version-specific documentation.

**Fields in CSV order:**

```text
Host, VirtualizationBasedSecurityStatus, SecurityServicesConfigured, SecurityServicesRunning, RequiredSecurityProperties, AvailableSecurityProperties
```

### 24.46. SMB configuration — `SmbSettings.csv`

**Source:** `Get-SmbClientConfiguration / Get-SmbServerConfiguration`.

Client and Server rows where available. Component-specific fields remain null on the other component. Signing preferences do not describe every negotiated connection.

**Fields in CSV order:**

```text
Host, Component, EnableSecuritySignature, RequireSecuritySignature, EnableSMB1Protocol, EnableSMB2Protocol, EncryptData, RejectUnencryptedAccess, EnableMultiChannel
```

### 24.47. SMB connections — `SmbConnections.csv`

**Source:** `Get-SmbConnection`.

SMB connections visible in the query context: dialect/encryption/signing where exposed. UserName and Credential are deliberately excluded.

**Fields in CSV order:**

```text
Host, ServerName, ShareName, Dialect, Encrypted, Signed, ContinuouslyAvailable, NumOpens
```

### 24.48. Network offloads — `AdapterOffloads.csv`

**Source:** `Get-NetAdapterRdma / Get-NetAdapterVmq / Get-NetAdapterSriov`.

Kind distinguishes RDMA, VMQ and SRIOV. Properties absent from a family remain null rather than False/0.

**Fields in CSV order:**

```text
Host, Kind, Name, InterfaceDescription, Enabled, OperationalState, SriovSupport, NumberOfReceiveQueues, NumberOfVMQs, BaseProcessorNumber, MaxProcessors
```

### 24.49. Management OS networking — `ManagementAdapters.csv`

**Source:** `Get-VMNetworkAdapter -ManagementOS`.

Management OS virtual adapters, separate from guest VM adapters. IPAddresses may not be populated by the cmdlet.

**Fields in CSV order:**

```text
Host, Name, SwitchName, SwitchId, Status, MacAddress, IPAddresses, ManagementOS
```

### 24.50. Host summary — `HostSummary.csv`

**Source:** `Derivado de Hosts/VMs/Checkpoints/Findings/Coverage`.

Per-host totals and ratio with InventoryStatus. Failed/truncated inventory leaves running/CPU/memory sums unknown; CollectedVMRows always means actually exported records.

**Fields in CSV order:**

```text
Host, CollectedVMRows, RunningVMRows, LogicalProcessors, ConfiguredVcpu, RunningVcpu, RunningVcpuPerLogicalProcessor, AssignedMemoryBytes, ConfiguredStartupMemoryBytes, HostFreeMemoryPercent, OldCheckpointRows, WarningFindings, CriticalFindings, CollectionProblems, InventoryStatus, Observation
```

### 24.51. VHD capacity per volume — `StorageCapacity.csv`

**Source:** `Derivado de Volumes/ClusterVolumes/VHDChains`.

Unique observed VHD paths per mapped host volume, including parents; see capacity limitations. Does not total SMB, physical provisioning or guest free space.

**Fields in CSV order:**

```text
Host, VolumePath, VolumeSizeBytes, VolumeFreeBytes, UniqueVhdPaths, ObservedFileSizeBytes, ObservedVirtualSizeBytes, NominalGrowthBytes, Observation
```

### 24.52. Findings for review — `Findings.csv`

**Source:** `Invoke-HvAssessment`.

Rules HV001–HV023, evidence and recommendations in original assessment language. Review rules never perform remediation.

**Fields in CSV order:**

```text
Severity, RuleId, Host, Target, Evidence, Recommendation, SourceId
```

### 24.53. Collection coverage — `Coverage.csv`

**Source:** `Pacotes do worker e controle de execução`.

One row per probe/scope. VM-detail scopes usually contain VMId; chains include path and events include channel. No artificial health percentage.

**Fields in CSV order:**

```text
Host, Dataset, Scope, Status, Rows, StartedUtc, EndedUtc, DurationSeconds, Detail
```

### 24.54. Collection failures — `Errors.csv`

**Source:** `Exceções de sondagem/worker`.

Exception type/message by host/dataset/scope. May contain internal paths/names; treat as infrastructure information. Unsupported/Truncated need not raise exceptions.

**Fields in CSV order:**

```text
Host, Dataset, Scope, ErrorType, Message
```

## 25. Essential dictionary and units

| Field | Meaning / unit |
|---|---|
| `Host` | Host producing the packet; failed transport can use the requested target. |
| `VMId / VMName` | GUID and name; VM name is not a unique key. |
| `State / Status / HealthStatus` | Native states; translated text is not a universal diagnosis. |
| `*Utc` | Normalized/calculated ISO8601 UTC date; null if unavailable. |
| `*Bytes` | Bytes; some HTML fields also show GiB (1 GiB = 1,073,741,824 bytes). |
| `MemoryTotal / MemoryAvailable (NumaNodes)` | NUMA cmdlet MiB, distinct from fields ending in Bytes. |
| `MemoryAssigned / MemoryDemand / MemoryStartup` | VM bytes in base inventory; not a guest process working set. |
| `Startup / Minimum / Maximum (VMMemory)` | Bytes; applicability depends on memory mode. |
| `AverageProcessorUsage (VMResources)` | MHz from existing metering, not a CPU percentage. |
| `Average/Maximum/MinimumMemoryUsage (VMResources)` | Measure-VM-reported MB per S18; not converted to bytes. |
| `CPUUsage / LoadPercentage` | Snapshot/provider percentage; not a time series or scheduling queue. |
| `FileSizeBytes / VirtualSizeBytes` | VHD file size versus virtual capacity; not guaranteed SAN physical allocation. |
| `RootPath / Path / ParentPath / Depth` | Attachment root, current file, parent and zero-based depth. |
| `ReadStatus` | Read, Error, DepthLimit or CycleDetected; Error does not mean Missing/Corrupt. |
| `NominalGrowthBytes` | Nonnegative nominal virtual/file-size difference, not a forecast. |
| `CollectedVMRows / RunningVMRows` | Actually collected records; running count can be unknown with incomplete inventory. |
| `RunningVcpuPerLogicalProcessor` | Configured vCPU in Running records / host logical processors. |
| `InventoryStatus` | VMs probe status; final worker failure invalidates totals as a complete census. |
| `OldCheckpointRows` | Observed rows above age threshold; zero does not prove absence if collection failed. |
| `EventId / Provider / RecordId` | Event/provider identity and channel sequence; correlate with log/time. |
| `Level` | In this filter: 1 Critical, 2 Error, 3 Warning. |
| `FrequencySec` | Reported Replica interval in seconds; not measured RPO. |
| `ReplicationStats` | Native VMReplicationHealth interval/properties/units; absent values are null. No automatic latency/size alert. |
| `MeteringDuration / MonitoringInterval` | Native accumulated interval, not a uniform tool-selected window. |
| `SourceId` | Official-source key, not a compliance endorsement. |
| `Scope` | Host, VMId, path, channel or control-probe scope. |
| `Rows / DurationSeconds` | Exported rows and probe duration; see event timing caveat. |
| `Empty / null / 0 / False` | No records, unknown, zero and Boolean false are distinct. |

## 26. Complete review-rule catalog

FMODEL review rules, not an executed BPA scan or universal Microsoft baseline. Code includes PT-BR/EN-US recommendations per trigger. Sources support interpretation; thresholds are initial local policy.

| RuleId | Severity | Source | Trigger |
|---|---|---|---|
| HV001 | Warning/Critical | S03 | Known Fixed volume free space below configured thresholds. |
| HV002 | Warning | S04 | Reported volume HealthStatus differs from Healthy. |
| HV003 | Warning/Critical | S05 | Host free memory below thresholds. |
| HV004 | Critical | S01 | VM State contains Critical or Failed. |
| HV005 | Warning | S01 | VM State is Paused; confirm intent. |
| HV006 | Info | S02 | Standard CheckpointType: review suitability. |
| HV007 | Warning/Critical | S06 | VM ReplicationHealth is Warning/Critical. |
| HV008 | Warning | S05 | VM MemoryStatus is Low/Warning. |
| HV009 | Warning | S03 | Checkpoint age exceeds threshold. |
| HV010 | Warning | S07 | VHD ReadStatus is not Read: failure, cycle or depth cap. |
| HV011 | Warning | S08 | Running VM has an adapter without SwitchName. |
| HV012 | Warning | S08 | Nonzero MAC repeats across different VMIds; isolation context must be reviewed. |
| HV013 | Info | S09 | Collected firmware reports Secure Boot Off/False/0. |
| HV014 | Critical | S01 | Returned vmms service State differs from Running. |
| HV015 | Warning | S10 | CBS or Windows Update registry reboot signal present. |
| HV016 | Info | S10 | PendingFileRenameOperations present; does not confirm reboot. |
| HV017 | Warning | S11 | Cluster node is Down or Joining. |
| HV018 | Critical | S11 | Cluster resource State is Failed. |
| HV019 | Warning | S12 | CSV redirected access or reported FaultState other than NoFaults. |
| HV020 | Warning | S13 | SMB Server reports EnableSMB1Protocol=True. |
| HV021 | Info | S14 | Exported events contain Critical/Error levels; correlate. |
| HV022 | Warning | S01 | Host coverage includes Failed, TimedOut, Partial, Truncated or Unsupported. |
| HV023 | Info | S15 | Running configured vCPU/logical-processor ratio exceeds threshold. |

## 27. Official sources and traceability

Microsoft references consulted on **2026-11-13**. Applicability depends on version/edition/scenario. Configuration references do not imply the tool executes their change commands.

| SourceId | Reference |
|---|---|
| S01 | [Hyper-V module](https://learn.microsoft.com/en-us/powershell/module/hyper-v) |
| S02 | [Hyper-V checkpoints](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/checkpoints) |
| S03 | [Checkpoint and differencing disk troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-server/virtualization/hyper-v-snapshots-checkpoints-differencing-disks) |
| S04 | [Get-Volume](https://learn.microsoft.com/en-us/powershell/module/storage/get-volume?view=windowsserver2025-ps) |
| S05 | [Hyper-V memory performance](https://learn.microsoft.com/en-us/windows-server/administration/performance-tuning/role/hyper-v-server/memory-performance) |
| S06 | [Hyper-V Replica overview](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/replication-overview) |
| S07 | [Get-VHD and in-use disk ownership](https://learn.microsoft.com/en-us/powershell/module/hyper-v/get-vhd?view=windowsserver2025-ps) |
| S08 | [Hyper-V Virtual Switch](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/virtual-switch) |
| S09 | [Plan for Hyper-V security](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/plan/plan-hyper-v-security-in-windows-server) |
| S10 | [Windows Update RebootRequired API (not called by this script)](https://learn.microsoft.com/en-us/windows/win32/api/wuapi/nf-wuapi-isysteminformation-get_rebootrequired) |
| S11 | [Get-ClusterResource](https://learn.microsoft.com/en-us/powershell/module/failoverclusters/get-clusterresource?view=windowsserver2025-ps) |
| S12 | [Cluster Shared Volumes overview](https://learn.microsoft.com/en-us/windows-server/failover-clustering/failover-cluster-csvs) |
| S13 | [Detect and manage SMB versions](https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3) |
| S14 | [Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent) |
| S15 | [Hyper-V processor performance](https://learn.microsoft.com/en-us/windows-server/administration/performance-tuning/role/hyper-v-server/processor-performance) |
| S16 | [Manage Hyper-V integration services](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/manage/manage-hyper-v-integration-services) |
| S17 | [Get-VMHostNumaNode](https://learn.microsoft.com/en-us/powershell/module/hyper-v/get-vmhostnumanode?view=windowsserver2025-ps) |
| S18 | [Measure-VM and resource-metering requirements/units](https://learn.microsoft.com/en-us/powershell/module/hyper-v/measure-vm?view=windowsserver2025-ps) |
| S19 | [PowerShell Remoting second hop](https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/ps-remoting-second-hop) |
| S20 | [Get-BpaResult: reads an existing scan](https://learn.microsoft.com/en-us/powershell/module/bestpractices/get-bparesult?view=windowsserver2025-ps) |
| S21 | [Get-VMHostSupportedVersion](https://learn.microsoft.com/en-us/powershell/module/hyper-v/get-vmhostsupportedversion?view=windowsserver2025-ps) |
| S22 | [Win32_DeviceGuard and VBS status](https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity) |
| S23 | [Get-SmbConnection and logon context](https://learn.microsoft.com/en-us/powershell/module/smbshare/get-smbconnection?view=windowsserver2025-ps) |
| S24 | [PowerShell execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1) |
| S25 | [Get-VMSecurity](https://learn.microsoft.com/en-us/powershell/module/hyper-v/get-vmsecurity?view=windowsserver2025-ps) |
| S26 | [Measure-VMReplication monitoring interval](https://learn.microsoft.com/en-us/powershell/module/hyper-v/measure-vmreplication?view=windowsserver2025-ps) |
| S27 | [Replicate a virtual machine](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/replication-virtual-machines) |

## 28. Validation and remaining acceptance

Tests: `tests/Test-HyperVHealthReport.ps1` and `tests/Test-HyperVCollectors.ps1`. Executed locally on Linux PowerShell 7.4.13 and through GitHub Actions on Windows PowerShell 5.1, PowerShell 7 Windows and PowerShell 7 Linux. Final code/results: `tests/evidence/VALIDATION.json`; repository workflow: `.github/workflows/hyper-v-health-validation.yml`.

Suites cover rules/contextual non-findings, CIM/units, normal/cyclic/depth-limited/denied VHD chains, empty/denied/capped inventory, generation 1, disabled Replica/metering, independent failures, empty/denied/capped events, cluster, timeout/owned cleanup, exports and CLI. A real local child process returns synthetic data and confirms an unrelated job remains available. WinRM/Hyper-V remain mocked.

HTML checked in Chromium: **16 checks**, at 1920, 1366 and 390 px, including sections, CSV links, page overflow, search/filters, navigation, expand/collapse, printing and no JS errors/external requests. This does not validate every browser/screen reader.

**Still required:** acceptance on real Hyper-V/WinRM/cluster/SMB, delegated permissions, version-specific properties, workloads/timing and organizational operational security. No real host/guest was queried, no failover/migration executed and no restore validated for this work.
