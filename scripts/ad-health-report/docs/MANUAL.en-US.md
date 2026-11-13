# Complete manual — FMODEL AD Health Report 1.2.0

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

Real operation requires 64-bit Windows, Windows PowerShell 5.1 and the ActiveDirectory/RSAT module. The computer must reach the selected AD environment and authenticate with an authorized account. A management workstation with RSAT is suitable; executing inside a DC is not mandatory. Real collection rejects PowerShell 7; offline tests and FromReport also support PowerShell 7.

Elevation is not required by default. Directory reads can work with delegated permissions; replication, CIM or DCDiag can require additional rights. The tool grants none and does not evade ACLs. Do not use Domain Admin merely for convenience when a basic inventory can use narrower approved rights.

The current token is used. No embedded password, API key or credential export is involved. The tool does not install RSAT, enable WinRM, configure TrustedHosts or open firewall rules. DNS, authentication, AD Web Services and protocols required by each check must already be available. Optional CIM collection uses existing WSMan configuration.

## 4. Download, folder and VSCode

Open scripts/ad-health-report on GitHub, select AD-Health-Report-v1.2.0.zip and click Download raw file, then Extract All. Alternatively use Code → Download ZIP from the repository home, extract it and open scripts/ad-health-report. Git is not required to download.

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

The 30 datasets established in 1.1 remain; section 30 documents the 33 additions in 1.2, totaling 63 CSVs. Events have explicit window/caps; all data obtained under those limits is exported to CSV/JSON and rendered up to MaxHtmlRows. New fields:

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

## 30. Comprehensive 1.2 profile and execution

Version 1.2 retains the 1.1 inventory and FullAssessment behavior and adds 33 normalized datasets: **63 CSV files per run**, HTML, JSON, raw evidence and a SHA-256 manifest. Unrequested datasets retain CSV headers; consult Coverage to establish whether collection occurred. The collectors were independently implemented from official APIs, using ADxRay as a requirements reference; no ADxRay code or HTML was incorporated.

Run from the extracted directory, using 64-bit Windows PowerShell 5.1 and the required permissions:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -ComprehensiveAssessment -CreateArchive
```

To include all authorized domains of the forest:

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -ComprehensiveAssessment -Scope Forest -CreateArchive
```

ComprehensiveAssessment enables FullAssessment and IncludeDirectorySecurity, IncludeTopology, IncludeGpoInventory, IncludeSysvolInventory, IncludeDnsConfiguration, IncludeBackupEvidence, IncludeHostInventory, IncludeSecurityConfiguration, IncludeRsop and IncludeSecurityEvents. Scope still defaults to Domain. Sites, subnets, site links, optional features and site GPO links are forest reference metadata even when the directory inventory scope is Domain.

Individual options can be combined without the preset. FullAssessment keeps its 1.1 behavior: operational probes, operational events, services and Extended DCDiag. It does not silently add GPO/software inventory or Security queries. Test in a lab first. Queries can add load/audit events; the tool does not modify AD, GPOs, registry, DNS, firewall, services or clocks.

## 31. New parameters, limits and cost

| Parameter | Default | Behavior |
|---|---|---|
| ComprehensiveAssessment | false | Enables all additional categories above; Domain remains the default scope. |
| IncludeDirectorySecurity | false | AD Recycle Bin, account flags, SPNs/UPNs and duplicates within collected coverage. |
| IncludeTopology | false | Forest sites, subnets and site links. |
| IncludeGpoInventory | false | GPO metadata, XML, LDAP links and permissions with explicit domain/server. |
| IncludeSysvolInventory | false | File metadata at each DC UNC path; no execution or reading script contents. |
| IncludeDnsConfiguration | false | DNS administrative configuration, zones, aging, root hints and InProgress indicators. |
| IncludeBackupEvidence | false | repadmin /showbackup text and supporting Windows Backup events when available. |
| IncludeHostInventory | false | CPU/BIOS/model, Uninstall registry and QFE entries in one remote snapshot per DC. |
| IncludeSecurityConfiguration | false | SMB, Spooler, ActiveStore firewall, W32Time, selected registry, audit policy and log configuration. |
| IncludeRsop | false | Computer-specific RSoP XML, normalized values and user-right assignments. |
| IncludeSecurityEvents | false | Selected Security EventIDs and 4624 logon types 4/8 within the window/cap. |
| MaxDirectoryObjects | 100000 | 100–10000000; additional objects per domain; requests limit+1 to detect truncation. Does not cap the existing Users/Computers inventory. |
| MaxSpnValues | 500000 | 100–10000000; exported SPN values per domain. |
| MaxGpos | 5000 | 1–100000; detailed GPOs per domain. Get-GPO -All still discovers inventory before this processing cap. |
| MaxXmlCharacters | 25000000 | 1000–100000000; per GPO/RSoP/event XML; DTD/external entities prohibited. |
| MaxPolicySettings | 100000 | 1–1000000; normalized GPO rows per domain and RSoP rows per DC. Processed raw XML is retained. |
| MaxSysvolFiles | 20000 | 1–1000000; files per DC. |
| SysvolTimeoutSeconds | 120 | 5–1800; traversal budget; a blocking filesystem call may exceed it. |
| MaxSoftwareEntries | 5000 | 1–100000; combined Uninstall entries per DC, preserving Registry32/Registry64 views. |
| BackupWarningDays | 7 | 1–365; informational supporting-event age review, not an RPO or missing-backup verdict. Lookup covers at least 30 days or twice this value. |
| BaselineFile | empty | Local JSON up to 1 MiB using allowed catalog RuleIds. Enables IncludeSecurityConfiguration. |
| FromReport | empty | Regenerates reports from existing JSON without initializing AD; Windows PowerShell 5.1 or PowerShell 7. |
| CreateArchive | false | Creates a ZIP alongside the completed run directory, outside the manifested directory. |

TimeoutSeconds also bounds waiting for GroupPolicy/DnsServer module jobs and the remote snapshot job. Only jobs created by the call are received, canceled and removed. Transport shutdown/cancellation can take additional time. AD discovery/queries and filesystem I/O have their own behavior; this is not a global run deadline. Domains/DCs are processed serially. Large forests with many GPOs may take substantial time; no fixed duration is promised.

## 32. Accounts, identifiers and optional features

Get-ADObject queries accounts with sAMAccountName and objects with servicePrincipalName, with explicit properties/paging. Includes computer and service accounts when present. UAC bits produce Enabled, ReversibleEncryptionAllowed, UseDESKeyOnly, PasswordNotRequired, PasswordNeverExpires, DoesNotRequirePreAuth, TrustedForDelegation, TrustedToAuthForDelegation, NotDelegated and SmartcardRequired. Missing UAC produces UnknownUAC/null, not false.

ReversibleEncryptionAllowed is account configuration, not proof of stored password contents. UseDESKeyOnly is not proof of actual DES authentication. PasswordNotRequired does not prove an empty password. Passwords, hashes, LAPS secrets and managed passwords are not requested. SupportedEncryptionTypes is configuration evidence.

SPNInventory exports one value per owner. DuplicateSPNs groups case-insensitively and requires distinct owner DNs. DuplicateUPNs compares nonempty UPNs similarly. Comparisons are limited to exported data, not external forests or a uniqueness certification. Unqueried domains, replication lag, failures and limits reduce coverage. DirectoryCoverage records object/SPN counts, limits and truncation; limits produce Partial.

SkipUserInventory also restricts the new account collector to computers. Coverage becomes ComputersOnlyByRequest and identifier comparison is inherently partial. This option does not redact user identities from groups, events, GPOs or other evidence.

AD Recycle Bin is read using documented FeatureGUID 766ddcd8-acd0-445e-f3b9-a7f9b6744f2a, an explicit server and EnabledScopes. It is never enabled by the tool. Sites/Subnets/SiteLinks inventory configuration, cost and replication frequency; they do not simulate routes or measure all inter-site connections.

## 33. GPOs, links, settings and permissions

Get-GPO, Get-GPOReport and Get-GPPermission receive explicit iteration domain/server. Each GUID report is stored as native/GPO-*.xml. GUID/domain exposed in XML are checked against the requested target. Mismatches and invalid XML become collection errors while independent collectors continue.

GroupPolicies includes identity, status, owner, provider-exposed WMI filter, dates, AD/SYSVOL versions, User/Computer extension-node counts and observed links. ComputerSettings/UserSettings count extension nodes, not every effective client setting. Missing extension data is a review observation even with nonzero versions. AD/SYSVOL version differences require replication/timing review, not automatic repair.

GPOLinks reads gPLink/gPOptions for domains/OUs and forest configuration sites. Exports GPO DN, StoredPosition, enabled/enforced flags and returned scope inheritance blocking. StoredPosition is raw attribute position, not claimed effective client application order. There is no full LSDOU, filtering, loopback, deny or effective conflict computation. Scopes without gPLink are not a complete inventory of inheritance blocking.

GPOSettings normalizes XML leaves/attributes into indexed SettingPath/Value/Attributes; raw namespaces/text remain in XML. GPOPermissions records trustees/SIDs, permissions and inherited state exposed by the cmdlet; nested group privileges are not expanded. Filtering/delegation and other metadata remain in raw XML and normalized leaves.

No observed link and missing extension nodes produce informational review items. A domain link, disabled link, reserved GPO or enabled User/Computer configuration is not universally wrong and never triggers deletion. Cross-domain links, permissions and concurrent changes affect LinkCount. GPOCoverage records discovery/detail/settings counts and caps per domain.

## 34. Hardware, software, QFE and security configuration

A fixed remote snapshot per DC gathers requested categories using CIM ComputerSystem/OperatingSystem/BIOS/Processor/QFE, Uninstall registry reads, SmbShare, NetSecurity ActiveStore, Win32_Service and selected registry values. It does not use Win32_Product and its validation/repair behavior. It does not install modules or enable destination remoting.

HostHardware separates LogicalProcessors, PhysicalCores and Sockets. Includes manufacturer/model, RAM bytes, OSBuild/UBR when exposed, installation and BIOS. BIOS age does not prove an applicable newer firmware exists. InstalledSoftware preserves Registry32/Registry64 entries; registry view is not proof of binary architecture and does not enumerate all per-user/portable/package types. Publisher is not signature validation.

Hotfixes lists Win32_QuickFixEngineering entries. InstalledOnRaw is preserved; InstalledUtc is populated only for an actual provider DateTime. Ambiguous strings are not guessed. QFE does not cover all update types, catalogs or CVEs; a recent KB does not prove patch compliance or absence of vulnerabilities. Application data is not sent to external sites.

HostSecurity includes observed SMB client/server values, Spooler state/start mode, ActiveStore firewall profiles and machine/policy W32Time values. W32Time preserves Type, NtpServer, AnnounceFlags and provider enablement when available, without recalculating all policy precedence or proving synchronization. Existing raw w32tm and offset measurements remain in TimeConfiguration/TimeSummary. Localized status text is not parsed into a success verdict.

Spooler has separate interpretation: Stopped/Disabled are the selected identity-infrastructure review values. It is excluded from the generic core-service Running rule. Unknown SMB/registry results do not become Disabled. Firewall ActiveStore is configuration evidence, not a test of all network paths.

LogConfiguration contains enabled, MaximumBytes, mode, record count, oldest record and time when exposed; no universal mandatory size is assumed. AuditPolicy preserves auditpol /get /category:* /r data by subcategory GUID, localized fields as JSON and linked raw output. It does not compare English Success/Failure strings for compliance.

## 35. Security value review and caller-provided profiles

RegistryEvidence stores value, kind, path, observation and errors. The default catalog has 12 selected reads for LDAP signing/CBT, NoLMHash, NTLM level/minimum session security, local-account/anonymous restrictions, UAC, audit subcategories and Script Block Logging. SOURCES.json and the PS1 contain rule references and selected values.

SecurityReview compares observed DWORD values using EqualsAny/ContainsBits, plus eight SMB/Spooler/firewall observations and four RID-500 rights observations when RSoP is requested. This is a Microsoft-guidance-based selected review: **not the complete SCT package, CIS audit, compliance assessment or Microsoft certification**. LDAP/NTLM settings require compatibility/exception review before changes outside this tool.

MatchesSelectedValue means only that the read value matches the selected rule. ReviewValueDifference needs review. NotExplicitlyConfigured does not establish an effective safe/unsafe default. Unknown/UnknownTypeOrValue/UnknownOSBuild are not success. RestrictAnonymousSAM is retained as NotApplicableToDomainControllers because the cited policy does not affect DCs. Local-account settings do not establish domain password policy.

baseline.example.json demonstrates a **partial** profile for builds 20348/26100. Review/adapt to your approved OS/role baseline. Only built-in RuleIds are accepted; no commands, scriptblocks or arbitrary registry paths. Expected must contain DWORD integers, Comparison must be EqualsAny/ContainsBits, Role must be DomainController and ApplicableBuilds explicit. Profile hash appears in observations. Other builds produce NotApplicableOSBuild; missing build produces UnknownOSBuild.

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -ComprehensiveAssessment -BaselineFile .\docs\baseline.example.json
```

Do not transplant a Windows client baseline to DCs. Administrator RID-500 rights are inventoried by SID, including renamed accounts. The cited built-in Administrator deny-logon recommendations target workstations/member servers; the tool does not turn them into a DC deny-right rule. RSoP does not expand group membership or calculate effective rights.

## 36. DNS administration and SYSVOL contents

DnsServerConfiguration inventories Get-DnsServer components and preserves raw JSON in native. DnsZones includes integration, type, dynamic update, scope and aging for queryable primary zones. DnsRootHints preserves exposed NS/IPs. A DNS service not observed during a successful service query is NotApplicableNoDnsServiceObserved; permission/transport errors are not converted to a missing-role conclusion.

Recursion enabled, fewer than three forwarders, custom root hints or scavenging disabled are not automatically errors. Interpretation depends on architecture; disabling Windows DNS recursion also disables forwarders. DnsZoneIndicators reads InProgress names in DNS namingContexts exposed by each domain reference DC; it is an indicator, not proof that every occurrence is a duplicate zone or that every custom partition was inspected.

SYSVOL uses \\DC\SYSVOL\DOMAIN, keeping the DC target explicit. Collects file metadata, bytes, UTC timestamps and extension aggregates. Does not execute scripts, read their contents, scan malware or compare replica bytes. Reparse points are excluded and recorded as limitations. File access failures and file/time caps produce Partial. File extension/size or EXE presence does not prove malicious content.

## 37. Backup evidence and selected Security events

BackupEvidence preserves native/ADBackup-*.txt from repadmin /showbackup and process results. It does not select an arbitrary line or guess localized dates into LastBackupUtc. Naming contexts/timestamps remain in raw evidence for review. Exit 0 means EvidenceReviewRequired, not verified backup. No backup/restore is started.

Supporting collection discovers Microsoft-Windows-Backup provider channels and reads up to 16 recent ID-4 events. UTC event time may populate LastBackupUtc for this source; it does not establish AD/System State component coverage or recoverability. Missing provider/log may be NotPresent, common with third-party backup solutions. Access failure is an error; no event in the window does not prove no backups. Confirm jobs, components, retention and restore testing with the responsible solution.

SecurityEvents queries IDs 1102, 4618, 4649, 4719, 4765, 4766, 4794, 4897, 4964 and 5124 plus 4624 LogonType 4/8 through XML/EventData filtering. EventHours/MaxEventsPerLog apply, with cap+1 truncation detection. Selected events are not full incident detection or a SIEM analysis.

EventDataJson preserves XML fields. Type 4 is batch and can be expected; type 8, NetworkCleartext, does not itself prove cleartext credential transmission over the network. Localized message strings do not determine these types. Security access denial creates errors/Partial without blocking independent collectors. Real logs can contain sensitive identities/additional data.

## 38. RSoP normalization and inference limits

Get-GPResultantSetOfPolicy uses explicit Computer=DC and a unique local XML file. RSoPSettings normalizes exposed leaves/attributes, including security options, policy, audit, registry and profiles. UserRightsAssignments records internal right name, principal SID/name and source when exposed. Raw XML permits review beyond the normalized row cap.

An absent XML right is NotExposedInRSoP, not proof of no effective configuration. Presence of a policy/key name does not establish its value. Localized names are preserved, not compared with a rigid English name list. Node counts do not establish full policy coverage, conflict absence or effective privilege.

## 39. Offline rendering and ZIP packaging

```powershell
powershell.exe -NoProfile -File .\Export-ADHealthReport.ps1 -FromReport 'C:\Path\Run-...\report.json' -OutputPath 'C:\ADHealth-Study' -CreateArchive
```

Replace paths with actual local paths. FromReport also works with pwsh; it does not initialize RSAT/AD or perform new queries. Accepts JSON SchemaVersion=1 and known dataset names, regenerating all CSVs/HTML in a Rendered-* directory. Missing new data in a 1.0/1.1 JSON stays missing. The original assessment version is preserved, with RendererVersion=1.2.0 and the imported JSON hash.

When run-manifest.json is beside JSON, allowed native/*.txt/xml/json evidence is copied after SHA-256/length verification. Reparse points, UNC, arbitrary paths, files above 100 MiB or evidence above 500 MiB total are rejected. Manifest limit is 10 MiB. Without a manifest, JSON is rendered without copying external evidence. Hashes detect differences against the supplied manifest; they do not authenticate the author or make the manifest trustworthy.

CreateArchive uses .NET ZIP and preserves the run directory. ZIP is created alongside it and displayed in the console. It does not upload or email anything. Real reports may be sensitive; publish only fictional examples. The comprehensive preset does not silently enable archive creation.

## 40. Permissions, troubleshooting and acceptance

Directory collection uses ActiveDirectory ADWS/LDAP. GPO/RSoP uses GroupPolicy, SYSVOL SMB/DFS, host inventory WinRM/PowerShell Remoting/CIM, DNS administration DnsServer, and events remote log access. Each needs its own connectivity/permissions. AD RSAT does not necessarily install GroupPolicy/DnsServer or grant remote rights.

Entry does not require elevation by default; comprehensive assessment may need elevation/delegated rights for repadmin, RSoP, registry, remoting and Security. Do not use Domain Admin indiscriminately to make a test pass. Inspect Coverage/CollectionErrors, the specific source/cmdlet and approved scope. The tool grants no permissions and changes no execution policy.

In VSCode open the whole extracted folder and use its terminal. powershell.exe chooses Windows PowerShell 5.1 even if the current terminal is PowerShell 7. For home tests without a domain, run the three suites or open examples/SYNTHETIC/Report.html. No AD installation, simulated credentials or company server connection is required.

```powershell
powershell.exe -NoProfile -File .\tests\Test-AdHealth.ps1
powershell.exe -NoProfile -File .\tests\Test-AdOperations.ps1
powershell.exe -NoProfile -File .\tests\Test-AdExtensions.ps1
```

Automated coverage uses synthetic data/adapters, local files and harmless native helpers. Tests regression, XML/XXE, flags, GPO identity, caps, owned jobs, unknown values, export, render and hashes. It does not query real AD/remoting/DCDiag/repadmin infrastructure. See TESTING.en-US.md and EVIDENCE.json for actual successful runs. Perform acceptance in an authorized lab with real permissions/languages, RODC/separate DNS and multiple domains before operational use.

## 41. Sources and data dictionary

CSV-SCHEMAS.json lists all 63 files and every column extracted from the code. DATA-DICTIONARY.en-US.md maps datasets and semantics. SOURCES.en-US.md/SOURCES.json contain official references and selected catalog values. AssessmentSources travels with HTML/CSV/JSON outputs. References are reading links; the collector does not automatically access those websites.

## 42. Lifecycle review and additional role groups by SID

Findings includes OS-LIFECYCLE-REVIEW for selected legacy families and ordinary Windows 10 requiring edition/build/ESU confirmation. These are Info review hints, not universal unsupported-system verdicts. Direct Microsoft Lifecycle references and dated catalog evidence, checked 2026-11-13, accompany findings. Windows 10 LTSC/LTSB does not automatically receive Home/Pro dates; modern/unknown families are not classified by exclusion.

Product references include [Server 2012 R2](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2012-r2), [Server 2012](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2012), [Server 2008 R2](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2008-r2), [Windows 7](https://learn.microsoft.com/en-us/lifecycle/products/windows-7) and [Windows 10 Home/Pro](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro). Ordinary support dates do not establish ESU/custom entitlement or current host OS; AD attributes may be stale. No automatic internet lookup refreshes this catalog; review it during maintenance.

IncludeDirectorySecurity complements PrivilegedMembers with Domain Controllers (516), Read-only Domain Controllers (521), Group Policy Creator Owners (520), Print Operators (S-1-5-32-550), Distributed COM Users (S-1-5-32-562) and Cryptographic Operators (S-1-5-32-569), when present. With base groups this covers the 13 reference groups at the root; Schema/Enterprise Admins remain root-specific. SkipPrivilegedMembers also suppresses additional reads.

MembershipType remains DirectOnly, without nested groups, SIDHistory or effective-rights expansion. DC groups legitimately contain DC accounts; these members do not trigger an unsafe-count rule. Group discovery uses SIDs rather than localized/renamed names.
