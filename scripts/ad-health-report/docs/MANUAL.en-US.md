# Complete manual — FMODEL AD Health Report 1.1.0

**FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO**  
F. Model · fmodel@fmodel.com.br · Revision assistance: Akira (ChatGPT)  
[Português](MANUAL.pt-BR.md) · [Home](../README.en-US.md) · [Evidence](EVIDENCE.json)

## 1. Purpose and scope

Export-ADHealthReport.ps1 turns AD inventory and diagnostics into structured collection with an offline HTML report, CSV and JSON. It supports understanding the environment, preparing technical presentations and reviewing conditions requiring investigation. It is not certification of Active Directory security, compliance, availability or complete functionality.

The tool queries data and writes local files. It does not delete accounts, reset passwords, modify groups, force replication, transfer FSMO roles, change schema/GPO, start/restart services, repair DNS or apply automatic remediation. Queries can generate normal network traffic and authentication/audit events. “Read-only AD collection” does not mean no I/O: reports are written on the computer executing the script.

## 2. Improvements over the submitted script

The original repeated inventory queries for counts, classified any computer whose operating system did not contain “server” as a workstation, and displayed almost everything only in the console. It also converted schema results through formatted text and recognized DCDiag outcomes using English phrases, which could be misleading on other OS languages.

The new structure preserves usable CSV/JSON data, identifies collection scope/DC, distinguishes missing data from zero and records coverage/errors per collector. Computers missing OS information are not automatically declared workstations. FSMO roles come from AD object properties instead of relying on textual netdom parsing.

Independent checks are not gated by successful ping. Services and DCDiag are optional, and their failures are not isolated proof of a failed DC. Structured replication data complements native diagnostic evidence, whose completion is presented for review rather than declared healthy after matching an English “passed test” phrase.

## 3. Requirements and permissions

Real operation requires 64-bit Windows, Windows PowerShell 5.1 and the ActiveDirectory/RSAT module. The computer must reach the selected AD environment and authenticate with an authorized account. A management workstation with RSAT is suitable; executing inside a DC is not mandatory. PowerShell 7 is used only for offline tests in this delivery; the operational entry point rejects PowerShell 7.

Elevation is not required by default. Directory reads can work with delegated permissions; replication, CIM or DCDiag can require additional rights. The tool grants none and does not evade ACLs. Do not use Domain Admin merely for convenience when a basic inventory can use narrower approved rights.

The current token is used. No embedded password, API key or credential export is involved. The tool does not install RSAT, enable WinRM, configure TrustedHosts or open firewall rules. DNS, authentication, AD Web Services and protocols required by each check must already be available. Optional CIM collection uses existing WSMan configuration.

## 4. Download, folder and VSCode

Open scripts/ad-health-report on GitHub, select AD-Health-Report-v1.1.0.zip and click Download raw file, then Extract All. Alternatively use Code → Download ZIP from the repository home, extract it and open scripts/ad-health-report. Git is not required to download.

Open the extracted folder in VSCode through File → Open Folder and select a Windows PowerShell terminal. Trust only code whose origin/content you reviewed. Do not execute within the ZIP or dot-source the entry point; invoke the file by name. Preserve UTF-8 with BOM when editing for Windows PowerShell 5.1.

```powershell
Get-Location
Get-ChildItem
$PSVersionTable
Get-Module -ListAvailable ActiveDirectory
```

Do not append the folder name again if already inside it. If ActiveDirectory is unavailable, obtain/install the appropriate RSAT component through your approved IT process; the script does not install it automatically.

## 5. Test without contacting a domain

From the tool folder in a normal terminal:

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
```

The offline suite also runs with pwsh. It uses synthetic data/adapters without needing a domain, RSAT or Administrator. Automated checks exercise implemented behavior, including data handling and output, but do not prove integration with a real forest.

See EVIDENCE.json for actual tested environments, source version/hashes and limits. Passing a synthetic suite is not operational acceptance in the company's AD environment. Do not load test adapters as command replacements in a production administration session.

## 6. First real collection

In Windows PowerShell 5.1 with the AD module and read permissions:

```powershell
.\Export-ADHealthReport.ps1
```

Scope defaults to Domain, initially discovered from the executing computer's domain. Select an authorized DC explicitly when necessary:

```powershell
.\Export-ADHealthReport.ps1 -Server dc01.example.com
```

Replace example.com hostnames with real authorized servers. RootDSE identifies the context and its dnsHostName pins the DC. This keeps domain counts/queries from implicitly switching servers for each command.

Execution writes reports. There is no “apply fixes” stage. Do not add parameters from other projects, such as -Apply or -ScopeOverwrite; they are not part of this script.

## 7. Domain versus forest

Domain collects the selected domain. Forest enumerates forest domains and pins a DC for each domain's queries. Interpret counts together with Domain, Server and Coverage. Domain mode can still display forest metadata such as schema and forest FSMO roles; that does not make its account inventory forest-wide.

```powershell
.\Export-ADHealthReport.ps1 -Scope Forest
```

Failures in a domain do not make remaining counts a reliable complete forest total. Review which domains/collectors succeeded. A pinned DC also represents that DC's view at collection time; this is not a consistent transactional snapshot across every server.

## 8. Every parameter

| Parameter | Default/range | Effect |
|---|---|---|
| Server | Not supplied | Initial context; RootDSE dnsHostName pins the DC. |
| Scope | Domain; Domain/Forest | Selects domain-inventory scope. |
| OutputPath | LocalApplicationData/FMODEL/ADHealth | Local base for a unique Run-UTC-GUID folder. |
| InactiveDays | 90; 1–3650 | Activity-review threshold, subject to lastLogonTimestamp limitations. |
| IncludeServiceChecks | false | Optional CIM/WSMan service reads. |
| IncludeDcDiagnostics | false | Optional permitted DCDiag tests. |
| TimeoutSeconds | 60; 5–600 | Native-process/CIM-operation timeout, not a global deadline. |
| MaxHtmlRows | 1000; 10–10000 | Limits displayed HTML rows, not CSV/JSON. |
| PageSize | 500; 1–1000 | Page size for compatible inventory queries. |
| SkipUserInventory | false | Omits user inventory; coverage records the omission. |
| SkipPrivilegedMembers | false | Omits direct-member enumeration of selected sensitive groups. |
| WhatIf | false; common parameter | Performs only initial discovery/output validation, without full inventory or files. |
| Confirm | PowerShell preference; Low impact | Can request approval for collection/output, not remediation. |

SupportsShouldProcess uses Low impact: default execution does not require interactive confirmation. -WhatIf performs only bootstrap (runtime, AD context and path), creates no run folder and does not execute full collection; it returns NotCollected. Initial AD discovery reads still occur.

```powershell
.\Export-ADHealthReport.ps1 -Server dc01.example.com -WhatIf
```

These are collection/presentation options, not remediation switches. Smaller PageSize does not cap total objects; the server continues paging. TimeoutSeconds is not a whole-run deadline for discovery, module loading, LDAP/ADWS, DNS, output or every execution call.

## 9. Optional services and DCDiag

```powershell
.\Export-ADHealthReport.ps1 -IncludeServiceChecks -IncludeDcDiagnostics
```

NTDS, Netlogon, DNS, KDC, W32Time and DFSR are queried through CIM/WSMan without start, stop or restart. Observation=Observed means a record was returned; NotObserved means no matching record was observed, not a transport failure or a confirmed Stopped state. Missing status, denied access, unavailable transport or timeout require investigation; they do not automatically mean stopped service or offline DC. Whether DNS must run locally depends on DC roles/topology and cannot be decided from the service name alone.

The Baseline profile uses a restricted DCDiag test list: NetLogons, Replications, Services, Advertising and KnowsOfRoleHolders, with /q. No /fix, dynamic-DNS-update tests or comprehensive scan with additional effects is requested. The process has its own timeout, captures exit/output and saves raw logs under native. A timed-out process gets a timeout marker; its partial output is not retained. Attempting to terminate it does not turn the result into a completed test.

/q mainly prints error messages. Empty text, exit zero or process completion does not prove complete health. Rows are classified for review, such as CompletedReviewRequired, Timeout or CommandError. English “passed test” phrases are not required. DCDiag's own connectivity test depends on ICMP; successful independent AD queries do not eliminate that native diagnostic limitation.

## 10. Output files

Output is local to the executing computer under OutputPath. The default uses the current account's LocalApplicationData. OutputPath is a local FileSystem-provider base: relative paths follow the current PowerShell location; UNC, detected network drives and wildcard paths are rejected. Each execution receives its own Run-UTC-GUID folder to avoid mixing reports.

- Report.html: offline dashboard with local search and collected datasets.
- report.json: metadata/technical data, preserving collected values without spreadsheet-specific neutralization.
- A CSV per dataset, comma-delimited with UTF-8 BOM.
- run-manifest.json: SHA256 hashes of artifacts included in the run manifest.
- native/: raw optional diagnostic output when those checks run.

The manifest is generated after other artifacts and does not hash itself. Later-added files, such as a browser-printed PDF, are not automatically included. A manifest helps detect subsequent changes; it is not a digital signature, origin-authenticity attestation or collection-completeness proof. Large environments can generate substantial output. No automatic retention, compression, encryption or deletion policy is imposed on real reports.

## 11. Datasets and CSV names

| Dataset | CSV | Main content |
|---|---|---|
| Forest | forest.csv | Forest metadata, schema and forest roles. |
| Domains | domains.csv | Selected domains, functional mode and metadata. |
| DomainControllers | domaincontrollers.csv | Discovered DCs, domain, site and available facts. |
| OrganizationalUnits | organizationalunits.csv | OUs and selected properties. |
| ComputerSummary | computersummary.csv | Computer-inventory summary. |
| Computers | computers.csv | Computers and selected review indicators. |
| Users | users.csv | Users and selected attributes when enabled. |
| Groups | groups.csv | Groups and selected properties. |
| PrivilegedMembers | privilegedmembers.csv | Direct memberships in selected sensitive groups. |
| PasswordPolicies | passwordpolicies.csv | Collected default/fine-grained password policies. |
| Trusts | trusts.csv | Trust relationships and available properties. |
| Replication | replication.csv | Structured partner/partition metadata. |
| ReplicationFailures | replicationfailures.csv | Returned replication failures. |
| Services | services.csv | Optional service collection results. |
| NativeDiagnostics | nativediagnostics.csv | Native status, exit and diagnostic reference. |
| Findings | findings.csv | Findings and recommendations requiring review. |
| Coverage | coverage.csv | Successful, skipped or unavailable collection. |
| CollectionErrors | collectionerrors.csv | Per-step/query errors and limitations. |

A header-only CSV cannot by itself distinguish no objects from uncollected data. Coverage and CollectionErrors provide that distinction. Do not automatically fill missing data with zero when preparing charts/presentations.

## 12. HTML search and presentation limits

Open Report.html in a local browser. No CDN, Internet connection or external library is required. Search runs in the browser without sending data or queries to a server. AD/error/native text is encoded so it is not treated as executable markup.

MaxHtmlRows limits presentation only. Browser search reaches content embedded in HTML, not an external full-row database. When a table is reduced, use CSV/JSON to inspect all successfully collected data. Controls expand/collapse sections and print through the browser. Printing does not make diagnostics more complete. Raising the limit can increase memory use and slow the browser; it does not complete failed queries.

## 13. CSV and formula protection

CSV uses comma delimiters and UTF-8 BOM. If Excel's regional configuration fails to split columns, use Data → From Text/CSV, selecting UTF-8 and comma. Do not assume a semicolon delimiter from the Windows display language.

Potential spreadsheet formulas receive an apostrophe prefix. CSV quoting alone is insufficient to prevent Excel or similar tools from interpreting a formula. This protection can change a value's visible representation; inspect JSON for the collected value without this spreadsheet-specific transformation.

JSON preserves the collected data model, not every original directory/.NET object attribute. It is not an AD backup or restore format. This tool has no data-import or object-replay function.

## 14. Schema, functional levels and OS

Schema, domain/forest functional mode and DC operating system are separate concepts. The schema number does not establish every server's current OS or update status.

The mapping recognizes schema 88 as introduced with Windows Server 2019 and also used by Windows Server 2022; 91 corresponds to Windows Server 2025. Unknown versions should retain their numeric value for review instead of inventing a classification. A Windows2016Domain functional level does not necessarily mean all DCs run Windows Server 2016.

OperatingSystem and related attributes are directory inventory and may be absent/stale. They do not prove patch inventory, contracted support or live endpoint state. Missing OS information must not automatically turn a computer into a workstation.

## 15. Activity and account flags

InactiveDays supplies an account-review threshold. lastLogonTimestamp is replicated at a granularity controlled by msDS-LogonTimeSyncInterval and can lag a real logon. LastLogonDate is a convenient representation of that kind of data, not precise evidence of every logon.

lastLogon is maintained independently on each DC and is not replicated. An accurate domain-wide last-logon value requires querying every DC and evaluating those values. Neither that cost nor that result should be assumed here. Missing/zero means unknown, not proof that the account was never used.

PasswordNotRequired is a flag, not proof of a blank password. PasswordNeverExpires, disabled preauthentication, delegation and other reported conditions are contextual review signals. Service accounts, approved exceptions and compensating controls matter. The tool does not read passwords, hashes, LAPS secrets or gMSA key material and never automatically disables an account because of age.

## 16. Sensitive groups, policies and trusts

Sensitive groups are selected by SID rather than localized names. Selection includes domain Domain Admins; Schema Admins and Enterprise Admins in the forest root domain; and builtin groups such as Administrators, Account Operators, Server Operators and Backup Operators.

PrivilegedMembers enumeration is direct membership only. A nested group can appear as a group, but its users are not automatically expanded. This is not an effective-privilege audit. Primary groups, SIDHistory, delegated ACLs, external principals and cross-forest/resolution failures also limit completeness. adminCount=1 does not prove current privileged membership.

Password-policy inventory does not establish each user's effective policy. Fine-grained policies can override defaults; an individual investigation can require Get-ADUserResultantPasswordPolicy and context analysis. Listed trusts do not establish the safety of every cross-forest access path. No exploitation test or trust modification occurs.

## 17. Replication and check limitations

Get-ADReplicationPartnerMetadata queries inbound partners across hosted partitions selected by Partition='*'. Get-ADReplicationFailure adds failures associated with the target DC. Results and errors are retained for review; the tool does not force synchronization, recalculate topology or remove connections.

A successful read without returned failures describes the queried view at that moment, not future availability. A single-DC topology can have no replication partners and requires its own interpretation. Insufficient access/network error must not become “zero failures.” Old timestamps and result codes need assessment against replication frequency, site, partition and maintenance context.

## 18. Overall states, exit and coverage

| State | Exit | Interpretation |
|---|---|---|
| NotCollected | 0 | WhatIf or declined confirmation; no run folder. |
| Completed | 0 | Collection completed under implemented criteria; not proof of health/compliance. |
| CompletedWithFindings | 2 | High/medium-priority findings require review. |
| Partial | 2 | One or more collectors encountered errors/limitations; other data may exist. |
| Fatal failure | 1 | The process did not finish; this does not imply a persisted report with Status=Failed. |

Coverage uses Collected, Failed and NotRequested. Collected with zero rows means the query completed without records in that scope; Failed/NotRequested does not justify that conclusion. Partial takes priority over CompletedWithFindings when collection errors exist. Early failure can occur before a folder/report exists. Output permission/disk failure can leave incomplete files; retain messages and examine integrity before treating output as evidence. There is no atomic transaction across all files.

NotRequested coverage indicates a deliberate choice, such as SkipUserInventory or optional diagnostics not selected, not successful execution of that check. Evaluate overall state, Findings, Coverage and CollectionErrors together. Partial results must not be presented as a complete forest inventory.

## 19. Lower-volume collection and presentations

To omit users or sensitive-group members:

```powershell
.\Export-ADHealthReport.ps1 -SkipUserInventory -SkipPrivilegedMembers
```

Change the output base and HTML limit:

```powershell
.\Export-ADHealthReport.ps1 -OutputPath C:\AD-Reports -MaxHtmlRows 500
```

Review coverage before sharing counts. Missing collection is not absence of risk. Before presenting, record date, scope, DCs, options, account/permissions and limits. Use findings as review topics and connect recommendations to the organization's change process, not as automatic authorization to make changes.

## 20. File security and common problems

Reports can expose people/account names, SIDs, memberships, internal hosts, topology and sensitive conditions. Do not publish them to the public repository. Define storage, ACLs, retention and recipients under company policy. The tool does not encrypt, harden ACLs, automatically anonymize or email/upload output.

Unsigned script: inspect Get-ExecutionPolicy -List. AllSigned under MachinePolicy/UserPolicy requires corporate signing procedures. When RemoteSigned permits and origin was reviewed, Unblock-File -LiteralPath .\Export-ADHealthReport.ps1 removes the download mark; it does not override GPO or required signing. Do not indiscriminately switch to Unrestricted/Bypass.

Missing module: check RSAT and terminal version. AD query failure: inspect server, DNS, authentication and permissions. Service/CIM failure: review WSMan and specific rights rather than declaring the DC offline. Missing/blocked DCDiag: inspect administration tools and CollectionErrors. None of these components is installed/enabled by the script.

## 21. Acceptance, questions and references

Before production, use a representative authorized lab. Compare samples with AD consoles and test denied access, optional collectors, inaccessible domains, empty data and large datasets. Inspect CSV/JSON/HTML, formula protection, presentation limits and file integrity. Confirm intended permissions/diagnostics with the AD team; synthetic tests do not replace acceptance.

Does Completed mean everything is healthy? No. It means the workflow completed under implemented criteria. Coverage limits and unimplemented analyses remain.

Must I be Domain Admin? Not by default for basic inventory. Individual datasets can require specific rights; denied access must remain visible.

Does the script apply recommendations? No. It presents evidence and review items; changes require your approved procedure.

Does CSV retain everything when HTML is reduced? It retains every row that its collector obtained, not data from skipped/failed queries.

Primary references supporting cmdlet use and interpretation. This project is not Microsoft certified or endorsed:

- Schema: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/find-active-directory-schema
- Replication metadata: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adreplicationpartnermetadata
- Replication failures: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adreplicationfailure
- DCDiag: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/dcdiag
- lastLogon: https://learn.microsoft.com/en-us/windows/win32/adschema/a-lastlogon
- lastLogonTimestamp: https://learn.microsoft.com/en-us/windows/win32/adschema/a-lastlogontimestamp
- Group members: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adgroupmember
- Resultant password policy: https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduserresultantpasswordpolicy

[Home](../README.en-US.md) · [Version evidence](EVIDENCE.json)

## 22. Implemented finding rules

High/Medium are project review priorities, not official Microsoft compliance ratings or proof of compromise. Multiple findings can refer to one account. There is no universal security score.

| RuleId | Severity | Observed condition |
|---|---|---|
| ACCOUNT-STALE-HINT | Medium | Enabled account with both LastLogonUtc and CreatedUtc older than the InactiveDays cutoff. |
| UNCONSTRAINED-DELEGATION | High | Enabled account with TrustedForDelegation; computers classified as DomainController are excluded. |
| KERBEROS-PREAUTH | High | Enabled user with DoesNotRequirePreAuth=True. |
| PASSWORD-NOT-REQUIRED | High | Enabled user with PasswordNotRequired=True. |
| PASSWORD-NEVER-EXPIRES | Medium | Enabled user with PasswordNeverExpires=True. |
| REVERSIBLE-PASSWORD-POLICY | High | Collected policy with ReversibleEncryptionEnabled=True. |
| REPLICATION-ERROR | High | Nonzero replication result or positive ConsecutiveReplicationFailures. |
| REPLICATION-FAILURE-REPORTED | High | Failure record with positive FailureCount. |
| SERVICE-NOT-RUNNING | Medium | Observed service with State other than Running; expected role still needs assessment. |

Absence of a finding does not mean every property was evaluated. The tool does not universally determine OS support, each account's effective password quality, all delegation paths or effective privilege. Policy and approved exceptions require responsible-team assessment.

## 23. Dataset conventions and fields

Normalized dates are ISO 8601 UTC text. Missing/unconvertible dates are empty, not zero dates or evidence of no activity. Absent properties can be null in JSON and empty in CSV. SIDs/GUIDs are text. Selected lists are flattened with semicolons, not exported as restorable AD objects.

Computer categories are DomainController from the DC account bit; ServerHint when OS text contains server; WindowsClientHint for other Windows-prefixed text; Unknown for missing OS; and Other otherwise. These are inventory hints, not probes of the currently running OS.

SPNCount is only the count returned for a user; complete SPN strings are not exported in that column. SupportedEncryptionTypes records the collected attribute value, not algorithms actually negotiated in live sessions. ParentDN is derived from distinguishedName while respecting escaped commas; the parent is not necessarily an OU.

The following headers define this edition's export contract:

### Forest

Name, RootDomain, ForestMode, SchemaVersion, SchemaLabel, SchemaMaster, DomainNamingMaster, Domains, Sites

### Domains

Domain, QueryServer, DistinguishedName, DomainMode, DomainSid, PDCEmulator, RIDMaster, InfrastructureMaster, Computers, Users, Groups

### DomainControllers

Domain, HostName, Site, OperatingSystem, OperatingSystemVersion, IsGlobalCatalog, IsReadOnly, OperationMasterRoles

### OrganizationalUnits

Domain, Name, DistinguishedName, ParentDN, ProtectedFromAccidentalDeletion, CreatedUtc, ChangedUtc

### ComputerSummary

Domain, Category, OperatingSystem, Count

### Computers

Domain, Name, DNSHostName, DistinguishedName, ParentDN, SID, ObjectGuid, Category, OperatingSystem, OperatingSystemVersion, Enabled, LastLogonUtc, PasswordLastSetUtc, CreatedUtc, ChangedUtc, TrustedForDelegation, TrustedToAuthForDelegation, SupportedEncryptionTypes

### Users

Domain, SamAccountName, UserPrincipalName, DistinguishedName, ParentDN, SID, ObjectGuid, Enabled, LockedOut, LastLogonUtc, PasswordLastSetUtc, AccountExpirationUtc, CreatedUtc, ChangedUtc, PasswordNeverExpires, PasswordNotRequired, DoesNotRequirePreAuth, TrustedForDelegation, AdminCount, SPNCount, SupportedEncryptionTypes

### Groups

Domain, Name, SamAccountName, SID, DistinguishedName, GroupCategory, GroupScope, AdminCount, CreatedUtc, ChangedUtc

### PrivilegedMembers

Domain, GroupName, GroupSID, MemberName, MemberSID, MemberClass, MemberDN, MembershipType

### PasswordPolicies

Domain, PolicyType, Name, Precedence, MinPasswordLength, ComplexityEnabled, ReversibleEncryptionEnabled, PasswordHistoryCount, MaxPasswordAgeDays, MinPasswordAgeDays, LockoutThreshold, LockoutDurationMinutes, AppliesTo

### Trusts

Domain, Name, Direction, TrustType, ForestTransitive, SelectiveAuthentication, SIDFilteringQuarantined, SIDFilteringForestAware

### Replication

Domain, DC, Partition, Partner, LastReplicationAttemptUtc, LastReplicationSuccessUtc, LastReplicationResult, ConsecutiveReplicationFailures

### ReplicationFailures

Domain, DC, Partner, FailureType, FailureCount, FirstFailureUtc, LastError

### Services

Domain, DC, Name, State, StartMode, Observation

### NativeDiagnostics

Domain, DC, Test, Status, ExitCode, TimedOut, OutputFile

### Findings

Severity, RuleId, Category, Domain, Target, Evidence, Recommendation

### Coverage

Dataset, Scope, Status, Rows, StartedUtc, EndedUtc, DurationSeconds

### CollectionErrors

Dataset, Scope, ErrorType, Message

## 24. Full profile and scope

FullAssessment enables IncludeOperationalChecks, IncludeEventLogs, IncludeServiceChecks and IncludeDcDiagnostics and selects DiagnosticProfile=Extended. The preset always chooses Extended, even if Baseline was supplied too. Without the preset, options can be enabled individually. Scope remains Domain by default; depth does not automatically expand the number of domains.

```powershell
.\Export-ADHealthReport.ps1 -FullAssessment
.\Export-ADHealthReport.ps1 -FullAssessment -Scope Forest -WhatIf
```

WhatIf performs only documented bootstrap and does not run the new probes. Expanded collection needs additional rights/connectivity: WSMan/CIM, registry reads, DNS, RPC/Event Log and administrative diagnostics. AD read access does not automatically grant those rights. Failed collectors do not gate independent checks.

## 25. New parameters

| Parameter | Default/range | Effect |
|---|---|---|
| FullAssessment | false | Full preset above, retaining selected scope. |
| IncludeOperationalChecks | false | DNS, informational ICMP, host/volumes/registry and time. |
| IncludeEventLogs | false | Critical/error/warning events from four selected logs. |
| DiagnosticProfile | Baseline; Baseline/Extended | 5 or 17 tests when IncludeDcDiagnostics is enabled. |
| DnsServer | Empty | Uses collector-configured resolvers unless another DNS server is supplied. |
| TimeSamples | 3; 3–10 | Requested stripchart samples per DC. |
| TimeWarningSeconds | 1; 0.001–3600 | Medium review threshold for median absolute offset. |
| TimeCriticalSeconds | 5; 0.002–86400 | High threshold, greater than warning. |
| DiskWarningPercent | 15; 0.01–100 | Free-space percentage warning. |
| DiskCriticalPercent | 5; 0–99 | Critical percentage, below warning. |
| DiskWarningGiB | 10; 0.01–1000000 | Free-space GiB warning. |
| DiskCriticalGiB | 5; 0–999999 | Critical GiB, below warning. |
| EventHours | 24; 1–168 | Retrospective event window. |
| MaxEventsPerLog | 100; 1–1000 | Per-log/per-DC cap, explicitly recorded. |

Disk thresholds use unrounded values: critical when percentage OR GiB reaches its critical threshold; warning when either warning threshold is reached. These are configurable project operational criteria, not a universal Microsoft standard.

## 26. DNS, ICMP, host and storage

DNS queries DC A/AAAA and _ldap._tcp.dc._msdcs.DOMAIN / _kerberos._tcp.DOMAIN SRV records. Resolver, TTL, target/port/priority/weight are recorded as applicable. The default resolver belongs to the collector, not necessarily that DC's DNS service. This does not validate all DNS records/resolvers. Missing AAAA alone is not failure; transport/access errors differ from NotPresent. Missing both host addresses or an SRV record prompts review.

ICMP sends one attempt with up to five seconds for sending; name resolution has its own timing. NoReply does not prove a DC offline or gate CIM, AD, time or DCDiag. DCDiag can depend on ICMP internally regardless of this separation.

The CIM bundle reads OS and fixed volumes once each, reusing a session removed in finally. It records UTC boot, uptime hours and total/free memory bytes. Boot within 24 hours is Info for maintenance correlation, not automatic failure; clock-inconsistent uptime remains unknown.

It reads DSA Database file and Database log files path under NTDS/Parameters and SysVol under Netlogon/Parameters through CIM registry access, without changing registry values. Longest matching volume path maps roles, including folder mount points. Denied reads, unexpanded variables and unmapped paths remain explicit. NTDS/SYSVOL are not assumed to reside on C:.

All returned fixed volumes are exported. Capacity alerts evaluate volumes with a drive letter, visible mount path or identified role; hidden unbound system volumes remain UnmappedSystemVolume and do not receive generic GiB alerts. This does not replace system/recovery partition review. Bytes are retained; GiB means 1024³. Space and memory are snapshots, without cleanup or continuous RAM-pressure measurement.

## 27. Time, events and extended DCDiag

Time uses multiple w32tm /stripchart samples, retaining sign and computing signed median, median absolute value and maximum absolute value. Negative offsets matter and thresholds use unrounded measurements. Parsing requires recognized sample lines and invariant numeric conversion; unknown output, insufficient samples, error or timeout does not become zero.

Reference is always CollectorLocalClock: the collection computer's clock. This does not certify UTC accuracy or NTP synchronization. An incorrect collector clock can alert on every DC. Review reference, network delay/jitter and DC source before acting. Stripchart uses a different source-port/path from the W32Time client; response does not prove the service's network path. Read-only /query source, status /verbose and configuration output is retained without interpreting translated labels. No /resync, /config or clock adjustment runs.

Events query System, Directory Service, DFS Replication and DNS Server for levels 1/2/3 in the selected window. At most cap+1 is requested to detect truncation, then cap rows are exported and EventLogCoverage retained. These are recent obtained events, not complete history. No matches is a successful empty query; absent DNS log can be inapplicable, while other absent logs/access errors remain limitations. Unformattable messages preserve event metadata with MessageStatus=Unavailable. Historical events do not establish current failure.

Extended retains five Baseline tests and adds DFSREvent, SysVolCheck, KccEvent, MachineAccount, NCSecDesc, ObjectsReplicated, RidManager, SystemLog, VerifyReferences, CheckSDRefDom, CrossRefValidation and LocatorCheck. Connectivity is run by the framework. Legacy FrsEvent is not selected automatically. Intersite, /fix, /c, /e and DNS dynamic-update tests are excluded. Native results remain review-required; exit zero does not certify health.

TimeoutSeconds remains per native process/CIM operation, not global. DNS uses QuickTimeout; Event Log RPC does not receive this timeout parameter. Discovery, AD queries, events and disk I/O may exceed it. Processing is sequential to control load; plan for DC count, tests and samples.

## 28. Summary, durations and additional findings

DCSummary combines DNS-observed addresses, uptime, lowest assessed free GiB/percentage, median absolute offset, event count/truncation and duration. GiB and percentage minima can come from different volumes; use Disks to identify each. Uncollected metrics remain unknown rather than manufactured zeros. Section statuses describe evidence coverage, not health approval. Observation is Incomplete, ReviewRequired or CollectedEvidenceOnly.

Coverage includes DurationSeconds; Timings.csv records collector duration. HostBundle measures shared CIM/registry reads, while HostMetrics/Disks/StoragePaths measure extraction from that bundle. DCProcessing measures the complete DC stage including replication/checks, excluding final run export. Do not add parent DCProcessing to child durations as independent work. Stopwatch.TotalSeconds retains minutes unlike the Seconds component.

New rules: DC-DISK-SPACE (High/Medium), DC-TIME-OFFSET (High/Medium), DC-EVENTS-REVIEW (Medium), DC-DNS-SRV-NOT-PRESENT and DC-DNS-HOST-NOT-PRESENT (Medium), DC-RECENT-BOOT (Info). Disk rules use assessable volumes/configured thresholds; time requires recognized sampling. Findings support human review without repair, deletion or automatic changes.

## 29. Integration and new outputs

Operational features were identified by comparison with Get-ADHealth.ps1, whose header credits ALI TAJRAN: https://www.alitajran.com/active-directory-health-check-powershell-script/ . This tool's collectors/data handling are independently implemented; its English parser, obsolete SMTP and active replication tests were not incorporated. No email is sent; reports remain local.

Additional references: https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname ; https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent ; https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings . No real DC was assessed during development; registry, WinRM/RPC, DNS and time interpretation need authorized acceptance.

The previous 18 datasets remain plus 12 additions, totaling 30 CSVs. Events have explicit window/caps; all data obtained under those limits is exported to CSV/JSON and rendered up to MaxHtmlRows. New fields:

### Connectivity — connectivity.csv

Domain, DC, Probe, Status, RoundtripMs, Address, Error

### DNS — dns.csv

Domain, DC, QueryName, QueryType, Resolver, Status, Address, Target, Port, Priority, Weight, TTL, Error

### HostMetrics — hostmetrics.csv

Domain, DC, CollectedUtc, OSName, OSVersion, Build, SystemDrive, LastBootUtc, UptimeHours, MemoryTotalBytes, MemoryFreeBytes, MemoryFreePercent, Observation

### Disks — disks.csv

Domain, DC, Volume, DriveLetter, Label, Roles, CapacityBytes, FreeBytes, FreeGiB, FreePercent, AssessmentScope, Observation

### StoragePaths — storagepaths.csv

Domain, DC, Component, Path, Status, Volume, Error

### TimeSamples — timesamples.csv

Domain, DC, Sample, CollectedUtc, Reference, OffsetSeconds, AbsoluteOffsetSeconds, RawLine

### TimeSummary — timesummary.csv

Domain, DC, Reference, RequestedSamples, ParsedSamples, Status, MedianOffsetSeconds, MedianAbsoluteOffsetSeconds, MaximumAbsoluteOffsetSeconds, ExitCode, TimedOut, RawText

### TimeConfiguration — timeconfiguration.csv

Domain, DC, Query, Status, ExitCode, TimedOut, RawText

### Events — events.csv

Domain, DC, LogName, TimeCreatedUtc, EventId, Level, Provider, RecordId, Message, MessageStatus

### EventLogCoverage — eventlogcoverage.csv

Domain, DC, LogName, StartUtc, EndUtc, Status, Exported, Truncated, Limit, Error

### DCSummary — dcsummary.csv

Domain, DC, Site, DnsAddresses, UptimeHours, LowestAssessedFreeGiB, LowestAssessedFreePercent, MedianAbsoluteOffsetSeconds, RecentEventRows, RecentEventsTruncated, ProcessingSeconds, Observation, CollectionErrors, Findings, Replication, Connectivity, DNS, HostMetrics, Disks, StoragePaths, TimeSummary, Services, EventLogCoverage, NativeDiagnostics

### Timings — timings.csv

Dataset, Scope, Status, Rows, DurationSeconds

DCSummary: Domain, DC, Site, DnsAddresses, UptimeHours, LowestAssessedFreeGiB, LowestAssessedFreePercent, MedianAbsoluteOffsetSeconds, RecentEventRows, RecentEventsTruncated, ProcessingSeconds, Observation, CollectionErrors, Findings, Replication, Connectivity, DNS, HostMetrics, Disks, StoragePaths, TimeSummary, Services, EventLogCoverage, NativeDiagnostics
