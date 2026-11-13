# Data dictionary — 63 datasets



[CSV-SCHEMAS.json](CSV-SCHEMAS.json) · [Manual](MANUAL.en-US.md)



Every column of every file is listed below. CSV uses comma/UTF-8 BOM; JSON preserves types. Empty fields are not automatically zero/false. Observation/coverage and raw sources qualify each value.



## Forest · forest.csv



`Name`, `RootDomain`, `ForestMode`, `SchemaVersion`, `SchemaLabel`, `SchemaMaster`, `DomainNamingMaster`, `Domains`, `Sites`



## Domains · domains.csv



`Domain`, `QueryServer`, `DistinguishedName`, `DomainMode`, `DomainSid`, `PDCEmulator`, `RIDMaster`, `InfrastructureMaster`, `Computers`, `Users`, `Groups`



## DomainControllers · domaincontrollers.csv



`Domain`, `HostName`, `Site`, `OperatingSystem`, `OperatingSystemVersion`, `IsGlobalCatalog`, `IsReadOnly`, `OperationMasterRoles`



## OrganizationalUnits · organizationalunits.csv



`Domain`, `Name`, `DistinguishedName`, `ParentDN`, `ProtectedFromAccidentalDeletion`, `CreatedUtc`, `ChangedUtc`



## ComputerSummary · computersummary.csv



`Domain`, `Category`, `OperatingSystem`, `Count`



## Computers · computers.csv



`Domain`, `Name`, `DNSHostName`, `DistinguishedName`, `ParentDN`, `SID`, `ObjectGuid`, `Category`, `OperatingSystem`, `OperatingSystemVersion`, `Enabled`, `LastLogonUtc`, `PasswordLastSetUtc`, `CreatedUtc`, `ChangedUtc`, `TrustedForDelegation`, `TrustedToAuthForDelegation`, `SupportedEncryptionTypes`



## Users · users.csv



`Domain`, `SamAccountName`, `UserPrincipalName`, `DistinguishedName`, `ParentDN`, `SID`, `ObjectGuid`, `Enabled`, `LockedOut`, `LastLogonUtc`, `PasswordLastSetUtc`, `AccountExpirationUtc`, `CreatedUtc`, `ChangedUtc`, `PasswordNeverExpires`, `PasswordNotRequired`, `DoesNotRequirePreAuth`, `TrustedForDelegation`, `AdminCount`, `SPNCount`, `SupportedEncryptionTypes`



## Groups · groups.csv



`Domain`, `Name`, `SamAccountName`, `SID`, `DistinguishedName`, `GroupCategory`, `GroupScope`, `AdminCount`, `CreatedUtc`, `ChangedUtc`



## PrivilegedMembers · privilegedmembers.csv



`Domain`, `GroupName`, `GroupSID`, `MemberName`, `MemberSID`, `MemberClass`, `MemberDN`, `MembershipType`



## PasswordPolicies · passwordpolicies.csv



`Domain`, `PolicyType`, `Name`, `Precedence`, `MinPasswordLength`, `ComplexityEnabled`, `ReversibleEncryptionEnabled`, `PasswordHistoryCount`, `MaxPasswordAgeDays`, `MinPasswordAgeDays`, `LockoutThreshold`, `LockoutDurationMinutes`, `AppliesTo`



## Trusts · trusts.csv



`Domain`, `Name`, `Direction`, `TrustType`, `ForestTransitive`, `SelectiveAuthentication`, `SIDFilteringQuarantined`, `SIDFilteringForestAware`



## Replication · replication.csv



`Domain`, `DC`, `Partition`, `Partner`, `LastReplicationAttemptUtc`, `LastReplicationSuccessUtc`, `LastReplicationResult`, `ConsecutiveReplicationFailures`



## ReplicationFailures · replicationfailures.csv



`Domain`, `DC`, `Partner`, `FailureType`, `FailureCount`, `FirstFailureUtc`, `LastError`



## Services · services.csv



`Domain`, `DC`, `Name`, `State`, `StartMode`, `Observation`



## NativeDiagnostics · nativediagnostics.csv



`Domain`, `DC`, `Test`, `Status`, `ExitCode`, `TimedOut`, `OutputFile`



## Findings · findings.csv



`Severity`, `RuleId`, `Category`, `Domain`, `Target`, `Evidence`, `Recommendation`



## Connectivity · connectivity.csv



`Domain`, `DC`, `Probe`, `Status`, `RoundtripMs`, `Address`, `Error`



## DNS · dns.csv



`Domain`, `DC`, `QueryName`, `QueryType`, `Resolver`, `Status`, `Address`, `Target`, `Port`, `Priority`, `Weight`, `TTL`, `Error`



## HostMetrics · hostmetrics.csv



`Domain`, `DC`, `CollectedUtc`, `OSName`, `OSVersion`, `Build`, `SystemDrive`, `LastBootUtc`, `UptimeHours`, `MemoryTotalBytes`, `MemoryFreeBytes`, `MemoryFreePercent`, `Observation`



## Disks · disks.csv



`Domain`, `DC`, `Volume`, `DriveLetter`, `Label`, `Roles`, `CapacityBytes`, `FreeBytes`, `FreeGiB`, `FreePercent`, `AssessmentScope`, `Observation`



## StoragePaths · storagepaths.csv



`Domain`, `DC`, `Component`, `Path`, `Status`, `Volume`, `Error`



## TimeSamples · timesamples.csv



`Domain`, `DC`, `Sample`, `CollectedUtc`, `Reference`, `OffsetSeconds`, `AbsoluteOffsetSeconds`, `RawLine`



## TimeSummary · timesummary.csv



`Domain`, `DC`, `Reference`, `RequestedSamples`, `ParsedSamples`, `Status`, `MedianOffsetSeconds`, `MedianAbsoluteOffsetSeconds`, `MaximumAbsoluteOffsetSeconds`, `ExitCode`, `TimedOut`, `RawText`



## TimeConfiguration · timeconfiguration.csv



`Domain`, `DC`, `Query`, `Status`, `ExitCode`, `TimedOut`, `RawText`



## Events · events.csv



`Domain`, `DC`, `LogName`, `TimeCreatedUtc`, `EventId`, `Level`, `Provider`, `RecordId`, `Message`, `MessageStatus`



## EventLogCoverage · eventlogcoverage.csv



`Domain`, `DC`, `LogName`, `StartUtc`, `EndUtc`, `Status`, `Exported`, `Truncated`, `Limit`, `Error`



## DCSummary · dcsummary.csv



`Domain`, `DC`, `Site`, `DnsAddresses`, `UptimeHours`, `LowestAssessedFreeGiB`, `LowestAssessedFreePercent`, `MedianAbsoluteOffsetSeconds`, `RecentEventRows`, `RecentEventsTruncated`, `ProcessingSeconds`, `Observation`, `CollectionErrors`, `Findings`, `Replication`, `Connectivity`, `DNS`, `HostMetrics`, `Disks`, `StoragePaths`, `TimeSummary`, `Services`, `EventLogCoverage`, `NativeDiagnostics`



## Timings · timings.csv



`Dataset`, `Scope`, `Status`, `Rows`, `DurationSeconds`



## Coverage · coverage.csv



`Dataset`, `Scope`, `Status`, `Rows`, `StartedUtc`, `EndedUtc`, `DurationSeconds`



## CollectionErrors · collectionerrors.csv



`Dataset`, `Scope`, `ErrorType`, `Message`



## OptionalFeatures · optionalfeatures.csv



`Forest`, `Feature`, `FeatureGuid`, `Enabled`, `EnabledScopes`, `QueryServer`, `Observation`



## Sites · sites.csv



`Forest`, `Name`, `DistinguishedName`, `Description`, `Subnets`, `InterSiteTopologyGenerator`



## Subnets · subnets.csv



`Forest`, `Name`, `Site`, `Location`, `Description`, `DistinguishedName`



## SiteLinks · sitelinks.csv



`Forest`, `Name`, `Cost`, `ReplicationFrequencyMinutes`, `Sites`, `DistinguishedName`



## AccountSecurityFlags · accountsecurityflags.csv



`Domain`, `QueryServer`, `Name`, `SamAccountName`, `ObjectClass`, `ObjectGuid`, `SID`, `DistinguishedName`, `Enabled`, `UserAccountControl`, `ReversibleEncryptionAllowed`, `UseDESKeyOnly`, `PasswordNotRequired`, `PasswordNeverExpires`, `DoesNotRequirePreAuth`, `TrustedForDelegation`, `TrustedToAuthForDelegation`, `NotDelegated`, `SmartcardRequired`, `SupportedEncryptionTypes`, `UserPrincipalName`, `Observation`



## SPNInventory · spninventory.csv



`Domain`, `SPN`, `NormalizedSPN`, `OwnerName`, `OwnerClass`, `OwnerGuid`, `OwnerDN`



## DuplicateSPNs · duplicatespns.csv



`SPN`, `OwnerCount`, `Domains`, `OwnerNames`, `OwnerGuids`, `OwnerDNs`, `AssessmentScope`, `Coverage`



## DuplicateUPNs · duplicateupns.csv



`UserPrincipalName`, `OwnerCount`, `Domains`, `OwnerNames`, `OwnerGuids`, `OwnerDNs`, `AssessmentScope`, `Coverage`



## DirectoryCoverage · directorycoverage.csv



`Domain`, `QueryServer`, `Objects`, `SPNValues`, `Truncated`, `ObjectLimit`, `SPNLimit`, `Observation`



## GroupPolicies · grouppolicies.csv



`Domain`, `QueryServer`, `Guid`, `Name`, `Status`, `CreatedUtc`, `ModifiedUtc`, `Owner`, `WmiFilter`, `ComputerVersionAD`, `ComputerVersionSysvol`, `UserVersionAD`, `UserVersionSysvol`, `ComputerSettings`, `UserSettings`, `LinkCount`, `Observation`, `SourceFile`



## GPOLinks · gpolinks.csv



`Domain`, `ScopeType`, `ScopeDN`, `ScopeName`, `GpoGuid`, `GpoDN`, `StoredPosition`, `LinkOptions`, `Enabled`, `Enforced`, `InheritanceBlocked`, `Observation`



## GPOSettings · gposettings.csv



`Domain`, `GpoGuid`, `GpoName`, `Area`, `SettingPath`, `Value`, `Attributes`, `SourceFile`



## GPOPermissions · gpopermissions.csv



`Domain`, `GpoGuid`, `GpoName`, `TrusteeName`, `TrusteeSID`, `TrusteeType`, `Permission`, `Inherited`, `SourceFile`



## GPOCoverage · gpocoverage.csv



`Domain`, `QueryServer`, `Discovered`, `Exported`, `Truncated`, `Limit`, `SettingsExported`, `SettingsTruncated`, `SettingsLimit`, `Observation`



## SysvolFiles · sysvolfiles.csv



`Domain`, `DC`, `RelativePath`, `Extension`, `Bytes`, `ModifiedUtc`, `Observation`



## SysvolSummary · sysvolsummary.csv



`Domain`, `DC`, `Root`, `Files`, `Directories`, `Bytes`, `Extension`, `ExtensionFiles`, `ExtensionBytes`, `Truncated`, `Limit`, `DurationSeconds`, `Observation`



## DnsServerConfiguration · dnsserverconfiguration.csv



`Domain`, `DC`, `Component`, `Property`, `Value`, `Observation`



## DnsZones · dnszones.csv



`Domain`, `DC`, `ZoneName`, `ZoneType`, `IsDsIntegrated`, `IsReverseLookupZone`, `DynamicUpdate`, `ReplicationScope`, `AgingEnabled`, `NoRefreshInterval`, `RefreshInterval`, `Observation`



## DnsRootHints · dnsroothints.csv



`Domain`, `DC`, `RecordType`, `HostName`, `NameServer`, `Address`, `Observation`



## DnsZoneIndicators · dnszoneindicators.csv



`Partition`, `Name`, `DistinguishedName`, `ObjectClass`, `QueryServer`, `Observation`



## BackupEvidence · backupevidence.csv



`Domain`, `DC`, `Source`, `Status`, `ExitCode`, `TimedOut`, `Partition`, `LastBackupUtc`, `AgeDays`, `Observation`, `RawText`, `SourceFile`



## HostHardware · hosthardware.csv



`Domain`, `DC`, `Manufacturer`, `Model`, `LogicalProcessors`, `PhysicalCores`, `Sockets`, `PhysicalMemoryBytes`, `OSBuild`, `UBR`, `InstallDateUtc`, `BIOSVersion`, `BIOSReleaseUtc`, `Observation`



## InstalledSoftware · installedsoftware.csv



`Domain`, `DC`, `RegistryView`, `ProductKey`, `DisplayName`, `DisplayVersion`, `Publisher`, `InstallDateRaw`, `InstallLocation`, `Observation`



## Hotfixes · hotfixes.csv



`Domain`, `DC`, `HotfixId`, `Description`, `InstalledOnRaw`, `InstalledUtc`, `InstalledBy`, `Observation`



## HostSecurity · hostsecurity.csv



`Domain`, `DC`, `Component`, `Setting`, `Value`, `Observation`, `Source`



## RegistryEvidence · registryevidence.csv



`Domain`, `DC`, `RuleId`, `RegistryPath`, `ValueName`, `ValueKind`, `Value`, `Observation`, `Error`



## SecurityReview · securityreview.csv



`Domain`, `DC`, `RuleId`, `Title`, `Profile`, `Expected`, `Observed`, `Comparison`, `Status`, `OSBuild`, `Reference`, `Observation`



## RSoPSettings · rsopsettings.csv



`Domain`, `DC`, `Area`, `SettingPath`, `Value`, `Attributes`, `SourceFile`



## UserRightsAssignments · userrightsassignments.csv



`Domain`, `DC`, `Right`, `PrincipalSID`, `PrincipalName`, `SourceGpo`, `Observation`, `SourceFile`



## SecurityEvents · securityevents.csv



`Domain`, `DC`, `LogName`, `TimeCreatedUtc`, `EventId`, `Level`, `Provider`, `RecordId`, `Message`, `MessageStatus`, `EventDataJson`, `Interpretation`



## LogConfiguration · logconfiguration.csv



`Domain`, `DC`, `LogName`, `Enabled`, `MaximumBytes`, `LogMode`, `RecordCount`, `OldestRecordNumber`, `LastWriteUtc`, `Observation`



## AuditPolicy · auditpolicy.csv



`Domain`, `DC`, `SubcategoryGuid`, `Value`, `SourceFile`, `Observation`



## AssessmentSources · assessmentsources.csv



`Id`, `Topic`, `Reference`, `AccessedDate`, `Usage`, `Limitations`



## Units and semantics



Bytes/CapacityBytes/FreeBytes/MaximumBytes/PhysicalMemoryBytes are bytes; FreeGiB divides by 1024³. Percentages range 0–100. DurationSeconds/ProcessingSeconds are seconds; AgeDays is days; UTC uses ISO 8601. AD/SYSVOL versions are counters, not Windows releases.

StoredPosition is raw attribute order; RegistryView is an Uninstall view, not proven binary architecture. LogicalProcessors differs from PhysicalCores. SupportedEncryptionTypes/UAC are bitmasks. Expected/Observed qualify individual rule scope only.

SettingPath identifies indexed XML leaves/attributes; Value/Attributes preserve data. SourceFile references local native evidence. RawText is unparsed evidence, not a language-based pass verdict. JSON in Value/EventDataJson retains localized/original fields.

Observation/Status/Coverage and Truncated/Limit specify source and limits. Read manual sections 30–40 for collectors. RootDomain/Domain/Forest/DC/QueryServer/ScopeDN are distinct contexts, and query targets are explicit.
