#Requires -Version 5.1
<#
.SYNOPSIS
FMODEL AD Health Report 1.2.0 - read-only inventory and review evidence.
.DESCRIPTION
Reads AD through RSAT ActiveDirectory, writes HTML/CSV/JSON locally. No repairs.
Operational runtime: 64-bit Windows PowerShell 5.1. No default elevation requirement.
Optional CIM/dcdiag require delegated target permissions/elevation as applicable.
.EXAMPLE
.\Export-ADHealthReport.ps1
.EXAMPLE
.\Export-ADHealthReport.ps1 -Server dc1.example.test -Scope Forest
.EXAMPLE
.\Export-ADHealthReport.ps1 -IncludeServiceChecks -IncludeDcDiagnostics
.NOTES
FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO
F. Model | fmodel@fmodel.com.br | Akira (ChatGPT)
Sensitive AD inventory stays in local reports; never publish real outputs.
Run as a file, not by dot-sourcing. No real AD assessment tested in development.
#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
param(
    [string]$Server='',
    [ValidateSet('Domain','Forest')][string]$Scope='Domain',
    [string]$OutputPath='',
    [ValidateRange(1,3650)][int]$InactiveDays=90,
    [switch]$IncludeServiceChecks,
    [switch]$IncludeDcDiagnostics,
    [ValidateRange(5,600)][int]$TimeoutSeconds=60,
    [ValidateRange(10,10000)][int]$MaxHtmlRows=1000,
    [ValidateRange(1,1000)][int]$PageSize=500,
    [switch]$SkipUserInventory,
    [switch]$SkipPrivilegedMembers,
    [switch]$FullAssessment,
    [switch]$IncludeOperationalChecks,
    [switch]$IncludeEventLogs,
    [ValidateSet('Baseline','Extended')][string]$DiagnosticProfile='Baseline',
    [string]$DnsServer='',
    [ValidateRange(3,10)][int]$TimeSamples=3,
    [ValidateRange(0.001,3600)][double]$TimeWarningSeconds=1.0,
    [ValidateRange(0.002,86400)][double]$TimeCriticalSeconds=5.0,
    [ValidateRange(0.01,100)][double]$DiskWarningPercent=15.0,
    [ValidateRange(0,99)][double]$DiskCriticalPercent=5.0,
    [ValidateRange(0.01,1000000)][double]$DiskWarningGiB=10.0,
    [ValidateRange(0,999999)][double]$DiskCriticalGiB=5.0,
    [ValidateRange(1,168)][int]$EventHours=24,
    [ValidateRange(1,1000)][int]$MaxEventsPerLog=100,
    [switch]$ComprehensiveAssessment,
    [switch]$IncludeDirectorySecurity,
    [switch]$IncludeTopology,
    [switch]$IncludeGpoInventory,
    [switch]$IncludeSysvolInventory,
    [switch]$IncludeDnsConfiguration,
    [switch]$IncludeBackupEvidence,
    [switch]$IncludeHostInventory,
    [switch]$IncludeSecurityConfiguration,
    [switch]$IncludeRsop,
    [switch]$IncludeSecurityEvents,
    [ValidateRange(100,10000000)][int]$MaxDirectoryObjects=100000,
    [ValidateRange(100,10000000)][int]$MaxSpnValues=500000,
    [ValidateRange(1,100000)][int]$MaxGpos=5000,
    [ValidateRange(1000,100000000)][int]$MaxXmlCharacters=25000000,
    [ValidateRange(1,1000000)][int]$MaxPolicySettings=100000,
    [ValidateRange(1,1000000)][int]$MaxSysvolFiles=20000,
    [ValidateRange(5,1800)][int]$SysvolTimeoutSeconds=120,
    [ValidateRange(1,100000)][int]$MaxSoftwareEntries=5000,
    [ValidateRange(1,365)][int]$BackupWarningDays=7,
    [string]$BaselineFile='',
    [string]$FromReport='',
    [switch]$CreateArchive
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-AdField {
    param($Object,[string]$Name)
    if ($null -eq $Object) { return $null }
    $p=$Object.PSObject.Properties[$Name]
    if ($null -ne $p) { $p.Value }
}
function Convert-AdDate {
    param($Value)
    if ($null -eq $Value) { return '' }
    try { ([datetime]$Value).ToUniversalTime().ToString('o') } catch { '' }
}
function Convert-AdSid {
    param($Value)
    if ($null -eq $Value) { return '' }
    $v=Get-AdField $Value 'Value'
    if ($null -ne $v) { return [string]$v }
    [string]$Value
}
function Get-AdParentDn {
    param([string]$Dn)
    $slashes=0
    for($i=0;$i -lt $Dn.Length;$i++) {
        if($Dn[$i] -eq ',' -and $slashes%2 -eq 0) { return $Dn.Substring($i+1) }
        if($Dn[$i] -eq '\') { $slashes++ } else { $slashes=0 }
    }
    ''
}
function Get-AdSchemaLabel {
    param([int]$Version)
    $map=@{30='Windows Server 2003';31='Windows Server 2003 R2';44='Windows Server 2008';47='Windows Server 2008 R2';56='Windows Server 2012';69='Windows Server 2012 R2';87='Windows Server 2016';88='Windows Server 2019 / 2022';91='Windows Server 2025'}
    if($map.ContainsKey($Version)){$map[$Version]}else{'Unknown / Desconhecido'}
}
function Get-AdComputerClass {
    param($Computer)
    $uac=Get-AdField $Computer 'userAccountControl'
    if($null -ne $uac -and ([long]$uac -band 8192) -ne 0){return 'DomainController'}
    $os=[string](Get-AdField $Computer 'OperatingSystem')
    if([string]::IsNullOrWhiteSpace($os)){return 'Unknown'}
    if($os -match '(?i)server'){return 'ServerHint'}
    if($os -match '(?i)^windows'){return 'WindowsClientHint'}
    'Other'
}
function Invoke-AdQuery {
    param([ValidateSet('Get-ADRootDSE','Get-ADDomain','Get-ADForest','Get-ADObject','Get-ADDomainController','Get-ADComputer','Get-ADUser','Get-ADGroup','Get-ADGroupMember','Get-ADOrganizationalUnit','Get-ADDefaultDomainPasswordPolicy','Get-ADFineGrainedPasswordPolicy','Get-ADTrust','Get-ADReplicationPartnerMetadata','Get-ADReplicationFailure','Get-ADOptionalFeature','Get-ADReplicationSite','Get-ADReplicationSubnet','Get-ADReplicationSiteLink')][string]$Command,[hashtable]$Arguments)
    & ('ActiveDirectory\'+$Command) @Arguments -ErrorAction Stop
}
function Initialize-AdRuntime {
    if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or -not [Environment]::Is64BitProcess -or $PSVersionTable.PSEdition -ne 'Desktop') {
        throw 'Use Windows PowerShell 5.1 de 64 bits (powershell.exe); PowerShell 7 somente para testes offline / offline tests only.'
    }
    Import-Module ActiveDirectory -ErrorAction Stop
}
function Get-AdSchemas {
    $schemas=[ordered]@{
        Forest='Name,RootDomain,ForestMode,SchemaVersion,SchemaLabel,SchemaMaster,DomainNamingMaster,Domains,Sites'
        Domains='Domain,QueryServer,DistinguishedName,DomainMode,DomainSid,PDCEmulator,RIDMaster,InfrastructureMaster,Computers,Users,Groups'
        DomainControllers='Domain,HostName,Site,OperatingSystem,OperatingSystemVersion,IsGlobalCatalog,IsReadOnly,OperationMasterRoles'
        OrganizationalUnits='Domain,Name,DistinguishedName,ParentDN,ProtectedFromAccidentalDeletion,CreatedUtc,ChangedUtc'
        ComputerSummary='Domain,Category,OperatingSystem,Count'
        Computers='Domain,Name,DNSHostName,DistinguishedName,ParentDN,SID,ObjectGuid,Category,OperatingSystem,OperatingSystemVersion,Enabled,LastLogonUtc,PasswordLastSetUtc,CreatedUtc,ChangedUtc,TrustedForDelegation,TrustedToAuthForDelegation,SupportedEncryptionTypes'
        Users='Domain,SamAccountName,UserPrincipalName,DistinguishedName,ParentDN,SID,ObjectGuid,Enabled,LockedOut,LastLogonUtc,PasswordLastSetUtc,AccountExpirationUtc,CreatedUtc,ChangedUtc,PasswordNeverExpires,PasswordNotRequired,DoesNotRequirePreAuth,TrustedForDelegation,AdminCount,SPNCount,SupportedEncryptionTypes'
        Groups='Domain,Name,SamAccountName,SID,DistinguishedName,GroupCategory,GroupScope,AdminCount,CreatedUtc,ChangedUtc'
        PrivilegedMembers='Domain,GroupName,GroupSID,MemberName,MemberSID,MemberClass,MemberDN,MembershipType'
        PasswordPolicies='Domain,PolicyType,Name,Precedence,MinPasswordLength,ComplexityEnabled,ReversibleEncryptionEnabled,PasswordHistoryCount,MaxPasswordAgeDays,MinPasswordAgeDays,LockoutThreshold,LockoutDurationMinutes,AppliesTo'
        Trusts='Domain,Name,Direction,TrustType,ForestTransitive,SelectiveAuthentication,SIDFilteringQuarantined,SIDFilteringForestAware'
        Replication='Domain,DC,Partition,Partner,LastReplicationAttemptUtc,LastReplicationSuccessUtc,LastReplicationResult,ConsecutiveReplicationFailures'
        ReplicationFailures='Domain,DC,Partner,FailureType,FailureCount,FirstFailureUtc,LastError'
        Services='Domain,DC,Name,State,StartMode,Observation'
        NativeDiagnostics='Domain,DC,Test,Status,ExitCode,TimedOut,OutputFile'
        Findings='Severity,RuleId,Category,Domain,Target,Evidence,Recommendation'
        Connectivity='Domain,DC,Probe,Status,RoundtripMs,Address,Error'
        DNS='Domain,DC,QueryName,QueryType,Resolver,Status,Address,Target,Port,Priority,Weight,TTL,Error'
        HostMetrics='Domain,DC,CollectedUtc,OSName,OSVersion,Build,SystemDrive,LastBootUtc,UptimeHours,MemoryTotalBytes,MemoryFreeBytes,MemoryFreePercent,Observation'
        Disks='Domain,DC,Volume,DriveLetter,Label,Roles,CapacityBytes,FreeBytes,FreeGiB,FreePercent,AssessmentScope,Observation'
        StoragePaths='Domain,DC,Component,Path,Status,Volume,Error'
        TimeSamples='Domain,DC,Sample,CollectedUtc,Reference,OffsetSeconds,AbsoluteOffsetSeconds,RawLine'
        TimeSummary='Domain,DC,Reference,RequestedSamples,ParsedSamples,Status,MedianOffsetSeconds,MedianAbsoluteOffsetSeconds,MaximumAbsoluteOffsetSeconds,ExitCode,TimedOut,RawText'
        TimeConfiguration='Domain,DC,Query,Status,ExitCode,TimedOut,RawText'
        Events='Domain,DC,LogName,TimeCreatedUtc,EventId,Level,Provider,RecordId,Message,MessageStatus'
        EventLogCoverage='Domain,DC,LogName,StartUtc,EndUtc,Status,Exported,Truncated,Limit,Error'
        DCSummary='Domain,DC,Site,DnsAddresses,UptimeHours,LowestAssessedFreeGiB,LowestAssessedFreePercent,MedianAbsoluteOffsetSeconds,RecentEventRows,RecentEventsTruncated,ProcessingSeconds,Observation,CollectionErrors,Findings,Replication,Connectivity,DNS,HostMetrics,Disks,StoragePaths,TimeSummary,Services,EventLogCoverage,NativeDiagnostics'
        Timings='Dataset,Scope,Status,Rows,DurationSeconds'
        Coverage='Dataset,Scope,Status,Rows,StartedUtc,EndedUtc,DurationSeconds'
        CollectionErrors='Dataset,Scope,ErrorType,Message'
    }
    $extended=Get-AdExtensionSchemas;foreach($key in $extended.Keys){$schemas[$key]=$extended[$key]};$schemas
}
function Add-AdRows {
    param($Report,[string]$Dataset,[object[]]$Rows)
    foreach($row in $Rows){if($null -ne $row){$Report.Datasets[$Dataset].Add($row)}}
}
function Invoke-AdCollection {
    param($Report,[string]$Dataset,[string]$Scope,[scriptblock]$Read,[switch]$Skip)
    $watch=[Diagnostics.Stopwatch]::StartNew();$start=[datetime]::UtcNow.ToString('o');$status='Collected';$count=0
    if($Skip){$status='NotRequested'}else{
        try{$before=$Report.Datasets[$Dataset].Count;$rows=@(& $Read);Add-AdRows $Report $Dataset $rows;$count=$Report.Datasets[$Dataset].Count-$before}
        catch{
            $status='Failed'
            Add-AdRows $Report 'CollectionErrors' @([pscustomobject]@{Dataset=$Dataset;Scope=$Scope;ErrorType=$_.Exception.GetType().FullName;Message=$_.Exception.Message})
        }
    }
    Add-AdRows $Report 'Timings' @([pscustomobject]@{Dataset=$Dataset;Scope=$Scope;Status=$status;Rows=$count;DurationSeconds=$watch.Elapsed.TotalSeconds})
    Add-AdRows $Report 'Coverage' @([pscustomobject]@{Dataset=$Dataset;Scope=$Scope;Status=$status;Rows=$count;StartedUtc=$start;EndedUtc=[datetime]::UtcNow.ToString('o');DurationSeconds=$watch.Elapsed.TotalSeconds})
}
function New-AdFinding {
    param($Report,[string]$Severity,[string]$RuleId,[string]$Category,[string]$Domain,[string]$Target,[string]$Evidence,[string]$Recommendation)
    Add-AdRows $Report 'Findings' @([pscustomobject]@{Severity=$Severity;RuleId=$RuleId;Category=$Category;Domain=$Domain;Target=$Target;Evidence=$Evidence;Recommendation=$Recommendation})
}
function Convert-AdAccount {
    param($Account,[string]$Domain,[ValidateSet('Users','Computers')][string]$Kind)
    $r=[ordered]@{Domain=$Domain}
    if($Kind -eq 'Computers'){
        foreach($n in @('Name','DNSHostName')){$r[$n]=Get-AdField $Account $n}
    }else{foreach($n in @('SamAccountName','UserPrincipalName')){$r[$n]=Get-AdField $Account $n}}
    $r['DistinguishedName']=Get-AdField $Account 'DistinguishedName'
    $r['ParentDN']=Get-AdParentDn $r.DistinguishedName
    $r['SID']=Convert-AdSid (Get-AdField $Account 'SID')
    $r['ObjectGuid']=[string](Get-AdField $Account 'ObjectGUID')
    if($Kind -eq 'Computers'){
        $r['Category']=Get-AdComputerClass $Account
        foreach($n in @('OperatingSystem','OperatingSystemVersion')){$r[$n]=Get-AdField $Account $n}
    }
    foreach($n in @('Enabled')){$r[$n]=Get-AdField $Account $n}
    if($Kind -eq 'Users'){$r['LockedOut']=Get-AdField $Account 'LockedOut'}
    foreach($pair in @(@('LastLogonUtc','LastLogonDate'),@('PasswordLastSetUtc','PasswordLastSet'),@('CreatedUtc','whenCreated'),@('ChangedUtc','whenChanged'))){$r[$pair[0]]=Convert-AdDate (Get-AdField $Account $pair[1])}
    if($Kind -eq 'Users'){
        $r['AccountExpirationUtc']=Convert-AdDate (Get-AdField $Account 'AccountExpirationDate')
        foreach($n in @('PasswordNeverExpires','PasswordNotRequired','DoesNotRequirePreAuth','TrustedForDelegation','AdminCount')){$r[$n]=Get-AdField $Account $n}
        $r['SPNCount']=@((Get-AdField $Account 'ServicePrincipalNames') | Where-Object{$null -ne $_}).Count
    }else{foreach($n in @('TrustedForDelegation','TrustedToAuthForDelegation')){$r[$n]=Get-AdField $Account $n}}
    $r['SupportedEncryptionTypes']=Get-AdField $Account 'msDS-SupportedEncryptionTypes'
    [pscustomobject]$r
}
function Convert-AdPolicy {
    param($Policy,[string]$Domain,[string]$Type)
    $r=[ordered]@{Domain=$Domain;PolicyType=$Type}
    foreach($n in @('Name','Precedence','MinPasswordLength','ComplexityEnabled','ReversibleEncryptionEnabled','PasswordHistoryCount','LockoutThreshold')){$r[$n]=Get-AdField $Policy $n}
    foreach($pair in @(@('MaxPasswordAgeDays','MaxPasswordAge','TotalDays'),@('MinPasswordAgeDays','MinPasswordAge','TotalDays'),@('LockoutDurationMinutes','LockoutDuration','TotalMinutes'))){
        $value=Get-AdField $Policy $pair[1];$r[$pair[0]]=if($null -ne $value){Get-AdField $value $pair[2]}else{$null}
    }
    $r['AppliesTo']=@((Get-AdField $Policy 'AppliesTo')) -join '; '
    [pscustomobject]$r
}
function Get-AdServiceObservations {
    param([string]$DC,[int]$TimeoutSeconds,[string]$Domain)
    $rows=@(Get-CimInstance -ComputerName $DC -ClassName Win32_Service -Filter "Name='NTDS' OR Name='Netlogon' OR Name='DNS' OR Name='KDC' OR Name='W32Time' OR Name='DFSR'" -OperationTimeoutSec $TimeoutSeconds -ErrorAction Stop)
    foreach($name in @('NTDS','Netlogon','DNS','KDC','W32Time','DFSR')){
        $service=@($rows|Where-Object{$_.Name -ieq $name})
        [pscustomobject]@{Domain=$Domain;DC=$DC;Name=$name;State=if($service.Count){$service[0].State}else{''};StartMode=if($service.Count){$service[0].StartMode}else{''};Observation=if($service.Count){'Observed'}else{'NotObserved'}}
    }
}
function Get-AdNativePath { Join-Path ([Environment]::SystemDirectory) 'dcdiag.exe' }
function Invoke-AdDcdiag {
    param([string]$DC,[ValidateSet('NetLogons','Replications','Services','Advertising','KnowsOfRoleHolders','DFSREvent','SysVolCheck','KccEvent','MachineAccount','NCSecDesc','ObjectsReplicated','RidManager','SystemLog','VerifyReferences','CheckSDRefDom','CrossRefValidation','LocatorCheck')][string]$Test,[int]$TimeoutSeconds)
    if($DC -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$'){throw 'Invalid DC hostname.'}
    Invoke-AdReadProcess (Get-AdNativePath) "/s:$DC /test:$Test /q" $TimeoutSeconds
}
function Resolve-AdOutputPath {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path)){$Path=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'FMODEL\ADHealth'}
    $provider=$null;$drive=$null
    $full=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path,[ref]$provider,[ref]$drive)
    if($provider.Name -ne 'FileSystem' -or $full.StartsWith('\\') -or $full -match '[\x00-\x1F*?\[\]]'){throw 'Use a local FileSystem output directory without wildcards.'}
    if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){
        $info=New-Object IO.DriveInfo([IO.Path]::GetPathRoot($full));if($info.DriveType -eq 'Network'){throw 'Network output not supported.'}
    }
    if((Test-Path -LiteralPath $full) -and -not (Get-Item -LiteralPath $full).PSIsContainer){throw 'OutputPath is a file.'}
    $full
}
function Convert-AdCsvValue {
    param($Value)
    if($null -eq $Value){return ''}
    $s=[string]$Value
    if($s -match '^[\s\x00-\x1F]*[=+@-]') { return "'"+$s }
    $s
}
function Write-AdCsv {
    param([string]$Path,[string[]]$Fields,[object[]]$Rows)
    $encoding=New-Object Text.UTF8Encoding($true)
    $writer=New-Object IO.StreamWriter($Path,$false,$encoding)
    try{
        $writer.WriteLine(($Fields|ForEach-Object{ '"'+$_.Replace('"','""')+'"' }) -join ',')
        foreach($row in $Rows){
            $values=foreach($f in $Fields){$v=Convert-AdCsvValue (Get-AdField $row $f);'"'+$v.Replace('"','""')+'"'}
            $writer.WriteLine($values -join ',')
        }
    }finally{$writer.Dispose()}
}
function Complete-AdFindings {
    param($Report)
    $cutoff=[datetime]::Parse($Report.StartedUtc).ToUniversalTime().AddDays(-$Report.Parameters.InactiveDays)
    foreach($kind in @('Users','Computers')){
        foreach($a in $Report.Datasets[$kind]){
            $name=if($kind -eq 'Users'){$a.SamAccountName}else{$a.Name}
            if($a.Enabled -eq $true){
                if($a.LastLogonUtc -and $a.CreatedUtc -and ([datetime]$a.LastLogonUtc).ToUniversalTime() -lt $cutoff -and ([datetime]$a.CreatedUtc).ToUniversalTime() -lt $cutoff){New-AdFinding $Report 'Medium' 'ACCOUNT-STALE-HINT' $kind $a.Domain $name "Replicated LastLogonDate before $($cutoff.ToString('o'))." 'Review with owner and other activity evidence; do not disable/delete automatically.'}
                if($a.TrustedForDelegation -eq $true -and ($kind -eq 'Users' -or $a.Category -ne 'DomainController')){New-AdFinding $Report 'High' 'UNCONSTRAINED-DELEGATION' $kind $a.Domain $name 'TrustedForDelegation flag is set.' 'Review necessity and approved constrained delegation alternatives.'}
            }
            if($kind -eq 'Users' -and $a.Enabled -eq $true){
                foreach($rule in @(@('DoesNotRequirePreAuth','High','KERBEROS-PREAUTH'),@('PasswordNotRequired','High','PASSWORD-NOT-REQUIRED'),@('PasswordNeverExpires','Medium','PASSWORD-NEVER-EXPIRES'))){
                    if($a.($rule[0]) -eq $true){New-AdFinding $Report $rule[1] $rule[2] 'Users' $a.Domain $name ($rule[0]+' flag is set.') 'Review account purpose, policy and compensating controls. A flag alone does not prove compromise or a blank password.'}
                }
            }
        }
    }
    foreach($p in $Report.Datasets.PasswordPolicies){if($p.ReversibleEncryptionEnabled -eq $true){New-AdFinding $Report 'High' 'REVERSIBLE-PASSWORD-POLICY' 'PasswordPolicies' $p.Domain $p.Name 'ReversibleEncryptionEnabled=True' 'Review application dependency and policy scope; this does not inspect stored passwords.'}}
    foreach($r in $Report.Datasets.Replication){if(($null -ne $r.LastReplicationResult -and $r.LastReplicationResult -ne 0) -or $r.ConsecutiveReplicationFailures -gt 0){New-AdFinding $Report 'High' 'REPLICATION-ERROR' 'Replication' $r.Domain $r.DC "Result=$($r.LastReplicationResult); failures=$($r.ConsecutiveReplicationFailures); partition=$($r.Partition)" 'Investigate replication, DNS, topology and permissions before repair.'}}
    foreach($r in $Report.Datasets.ReplicationFailures){if($r.FailureCount -gt 0){New-AdFinding $Report 'High' 'REPLICATION-FAILURE-REPORTED' 'Replication' $r.Domain $r.DC "FailureCount=$($r.FailureCount); error=$($r.LastError)" 'Review raw replication failure and current status.'}}
    foreach($s in $Report.Datasets.Services){if($s.Observation -eq 'Observed' -and $s.State -ne 'Running'){New-AdFinding $Report 'Medium' 'SERVICE-NOT-RUNNING' 'Services' $s.Domain $s.DC "$($s.Name) state=$($s.State)" 'Review service role and expected configuration; no service was started.'}}
}
function Invoke-AdAssessment {
    param($Options,$Caller)
    $Options=Get-AdEffectiveOptions $Options
    if($Options.BaselineFile){$null=Get-AdSecurityProfile $Options.BaselineFile}
    Initialize-AdRuntime
    $server=[string]$Options.Server
    if(-not $server){$d=Invoke-AdQuery 'Get-ADDomain' @{Current='LocalComputer'};$server=$d.DNSRoot}
    $root=Invoke-AdQuery 'Get-ADRootDSE' @{Server=$server}
    $server=[string]$root.dnsHostName
    if([string]::IsNullOrWhiteSpace($server)){throw 'Cannot identify a specific AD query DC.'}
    $domain=Invoke-AdQuery 'Get-ADDomain' @{Server=$server}
    $forest=Invoke-AdQuery 'Get-ADForest' @{Server=$server}
    $base=Resolve-AdOutputPath $Options.OutputPath
    if(-not $Caller.ShouldProcess("$($Options.Scope): $($domain.DNSRoot)",'Read AD inventory and write local HTML/CSV/JSON reports')){return [pscustomobject]@{Status='NotCollected';ExitCode=0;RunFolder=$null}}
    $folder=Join-Path $base ('Run-{0}-{1}' -f [datetime]::UtcNow.ToString('yyyyMMdd-HHmmss'),[guid]::NewGuid().ToString('N'))
    $null=New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop
    $optionsCopy=[ordered]@{};foreach($p in $Options.PSObject.Properties){$optionsCopy[$p.Name]=$p.Value};$optionsCopy.Server=$server
    $report=[pscustomobject]@{SchemaVersion=1;Version='1.2.0';RunId=[IO.Path]::GetFileName($folder);StartedUtc=[datetime]::UtcNow.ToString('o');EndedUtc='';Status='Collecting';Parameters=[pscustomobject]$optionsCopy;Datasets=[ordered]@{}}
    $schemas=Get-AdSchemas;foreach($name in $schemas.Keys){$report.Datasets[$name]=New-Object 'Collections.Generic.List[object]'}
    Invoke-AdCollection $report 'Forest' $forest.Name {
        $schema=Invoke-AdQuery 'Get-ADObject' @{Identity=$root.schemaNamingContext;Properties=@('objectVersion');Server=$server}
        [pscustomobject]@{Name=$forest.Name;RootDomain=$forest.RootDomain;ForestMode=[string]$forest.ForestMode;SchemaVersion=[int]$schema.objectVersion;SchemaLabel=Get-AdSchemaLabel ([int]$schema.objectVersion);SchemaMaster=$forest.SchemaMaster;DomainNamingMaster=$forest.DomainNamingMaster;Domains=(@($forest.Domains)-join '; ');Sites=(@($forest.Sites)-join '; ')}
    }
    Invoke-AdExtendedForest $report $Options $forest $root $server
    Add-AdRows $report 'AssessmentSources' @(Get-AdAssessmentSources)
    $domains=if($Options.Scope -eq 'Forest'){@($forest.Domains|Sort-Object)}else{@($domain.DNSRoot)}
    foreach($dnsDomain in $domains){
        $beforeErrors=$report.Datasets.CollectionErrors.Count
        try{
            if($dnsDomain -ieq $domain.DNSRoot){$queryServer=$server;$current=$domain}
            else{
                $discovered=Invoke-AdQuery 'Get-ADDomainController' @{Discover=$true;DomainName=$dnsDomain;Service='ADWS'}
                $queryServer=[string](@($discovered.HostName)[0]);$dcRoot=Invoke-AdQuery 'Get-ADRootDSE' @{Server=$queryServer};$queryServer=[string]$dcRoot.dnsHostName
                $current=Invoke-AdQuery 'Get-ADDomain' @{Server=$queryServer}
            }
            if($current.DNSRoot -ine $dnsDomain -or -not $queryServer){throw 'Discovered DC does not match requested domain.'}
        }catch{
            Add-AdRows $report 'CollectionErrors' @([pscustomobject]@{Dataset='DomainBootstrap';Scope=$dnsDomain;ErrorType=$_.Exception.GetType().FullName;Message=$_.Exception.Message})
            Add-AdRows $report 'Coverage' @([pscustomobject]@{Dataset='DomainBootstrap';Scope=$dnsDomain;Status='Failed';Rows=0;StartedUtc=[datetime]::UtcNow.ToString('o');EndedUtc=[datetime]::UtcNow.ToString('o')})
            continue
        }
        Write-Host "FMODEL | AD | $dnsDomain | $queryServer" -ForegroundColor Cyan
        $common=@{Server=$queryServer;SearchBase=$current.DistinguishedName;ResultPageSize=$Options.PageSize;Filter='*'}
        Invoke-AdCollection $report 'Computers' $dnsDomain {
            $argsComputer=$common.Clone();$argsComputer.Properties=@('OperatingSystem','OperatingSystemVersion','DNSHostName','Enabled','LastLogonDate','PasswordLastSet','whenCreated','whenChanged','TrustedForDelegation','TrustedToAuthForDelegation','msDS-SupportedEncryptionTypes','userAccountControl')
            foreach($a in (Invoke-AdQuery 'Get-ADComputer' $argsComputer)){Convert-AdAccount $a $dnsDomain 'Computers'}
        }
        Invoke-AdCollection $report 'Users' $dnsDomain {
            $argsUser=$common.Clone();$argsUser.Properties=@('Enabled','LockedOut','LastLogonDate','PasswordLastSet','AccountExpirationDate','whenCreated','whenChanged','PasswordNeverExpires','PasswordNotRequired','DoesNotRequirePreAuth','TrustedForDelegation','AdminCount','ServicePrincipalNames','msDS-SupportedEncryptionTypes')
            foreach($a in (Invoke-AdQuery 'Get-ADUser' $argsUser)){Convert-AdAccount $a $dnsDomain 'Users'}
        } -Skip:$Options.SkipUserInventory
        Invoke-AdCollection $report 'Groups' $dnsDomain {
            $argsGroup=$common.Clone();$argsGroup.Properties=@('whenCreated','whenChanged','AdminCount')
            foreach($g in (Invoke-AdQuery 'Get-ADGroup' $argsGroup)){
                [pscustomobject]@{Domain=$dnsDomain;Name=$g.Name;SamAccountName=$g.SamAccountName;SID=Convert-AdSid $g.SID;DistinguishedName=$g.DistinguishedName;GroupCategory=[string]$g.GroupCategory;GroupScope=[string]$g.GroupScope;AdminCount=Get-AdField $g 'AdminCount';CreatedUtc=Convert-AdDate (Get-AdField $g 'whenCreated');ChangedUtc=Convert-AdDate (Get-AdField $g 'whenChanged')}
            }
        }
        Invoke-AdCollection $report 'OrganizationalUnits' $dnsDomain {
            $argsOU=$common.Clone();$argsOU.Properties=@('ProtectedFromAccidentalDeletion','whenCreated','whenChanged')
            foreach($o in (Invoke-AdQuery 'Get-ADOrganizationalUnit' $argsOU)){
                [pscustomobject]@{Domain=$dnsDomain;Name=$o.Name;DistinguishedName=$o.DistinguishedName;ParentDN=Get-AdParentDn $o.DistinguishedName;ProtectedFromAccidentalDeletion=$o.ProtectedFromAccidentalDeletion;CreatedUtc=Convert-AdDate (Get-AdField $o 'whenCreated');ChangedUtc=Convert-AdDate (Get-AdField $o 'whenChanged')}
            }
        }
        Invoke-AdCollection $report 'PasswordPolicies' "$dnsDomain / Default" {Convert-AdPolicy (Invoke-AdQuery 'Get-ADDefaultDomainPasswordPolicy' @{Identity=$dnsDomain;Server=$queryServer}) $dnsDomain 'Default'}
        Invoke-AdCollection $report 'PasswordPolicies' "$dnsDomain / FGPP" {
            foreach($p in (Invoke-AdQuery 'Get-ADFineGrainedPasswordPolicy' @{Filter='*';Server=$queryServer;Properties=@('AppliesTo')})){Convert-AdPolicy $p $dnsDomain 'FineGrained'}
        }
        Invoke-AdCollection $report 'Trusts' $dnsDomain {
            foreach($t in (Invoke-AdQuery 'Get-ADTrust' @{Filter='*';Server=$queryServer})){
                $row=[ordered]@{Domain=$dnsDomain};foreach($n in @('Name','Direction','TrustType','ForestTransitive','SelectiveAuthentication','SIDFilteringQuarantined','SIDFilteringForestAware')){$row[$n]=[string](Get-AdField $t $n)};[pscustomobject]$row
            }
        }
        Invoke-AdCollection $report 'DomainControllers' $dnsDomain {
            foreach($dc in (Invoke-AdQuery 'Get-ADDomainController' @{Filter='*';Server=$queryServer})){
                [pscustomobject]@{Domain=$dnsDomain;HostName=$dc.HostName;Site=$dc.Site;OperatingSystem=$dc.OperatingSystem;OperatingSystemVersion=$dc.OperatingSystemVersion;IsGlobalCatalog=$dc.IsGlobalCatalog;IsReadOnly=$dc.IsReadOnly;OperationMasterRoles=(@($dc.OperationMasterRoles)-join '; ')}
            }
        }
        Invoke-AdExtendedDomain $report $Options $dnsDomain $queryServer $current.DistinguishedName $folder $forest.RootDomain
        $sid=Convert-AdSid $current.DomainSID
        $groupSids=@("$sid-512",'S-1-5-32-544','S-1-5-32-548','S-1-5-32-549','S-1-5-32-551')
        if($dnsDomain -ieq $forest.RootDomain){$groupSids+=@("$sid-518","$sid-519")}
        foreach($groupSid in $groupSids){
            Invoke-AdCollection $report 'PrivilegedMembers' "$dnsDomain / $groupSid" {
                $matching=@($report.Datasets.Groups|Where-Object{$_.Domain -eq $dnsDomain -and $_.SID -eq $groupSid})
                if(-not $matching.Count){throw "Privileged group SID was not available in group inventory: $groupSid"}
                foreach($m in (Invoke-AdQuery 'Get-ADGroupMember' @{Identity=$matching[0].DistinguishedName;Server=$queryServer})){
                    [pscustomobject]@{Domain=$dnsDomain;GroupName=$matching[0].Name;GroupSID=$groupSid;MemberName=$m.Name;MemberSID=Convert-AdSid (Get-AdField $m 'SID');MemberClass=$m.objectClass;MemberDN=$m.DistinguishedName;MembershipType='DirectOnly'}
                }
            } -Skip:$Options.SkipPrivilegedMembers
        }
        foreach($dcRow in @($report.Datasets.DomainControllers|Where-Object{$_.Domain -eq $dnsDomain})){
            $dcWatch=[Diagnostics.Stopwatch]::StartNew()
            $dcName=[string]$dcRow.HostName
            Invoke-AdCollection $report 'Replication' $dcName {
                foreach($p in (Invoke-AdQuery 'Get-ADReplicationPartnerMetadata' @{Target=$dcName;Scope='Server';Partition='*';PartnerType='Inbound'})){
                    [pscustomobject]@{Domain=$dnsDomain;DC=$dcName;Partition=$p.Partition;Partner=$p.Partner;LastReplicationAttemptUtc=Convert-AdDate $p.LastReplicationAttempt;LastReplicationSuccessUtc=Convert-AdDate $p.LastReplicationSuccess;LastReplicationResult=$p.LastReplicationResult;ConsecutiveReplicationFailures=$p.ConsecutiveReplicationFailures}
                }
            }
            Invoke-AdCollection $report 'ReplicationFailures' $dcName {
                foreach($p in (Invoke-AdQuery 'Get-ADReplicationFailure' @{Target=$dcName;Scope='Server'})){
                    [pscustomobject]@{Domain=$dnsDomain;DC=$dcName;Partner=$p.Partner;FailureType=[string]$p.FailureType;FailureCount=$p.FailureCount;FirstFailureUtc=Convert-AdDate $p.FirstFailureTime;LastError=$p.LastError}
                }
            }
            Invoke-AdCollection $report 'Services' $dcName {Get-AdServiceObservations $dcName $Options.TimeoutSeconds $dnsDomain} -Skip:(-not $Options.IncludeServiceChecks)
            if($Options.IncludeDcDiagnostics){
                $nativeFolder=Join-Path $folder 'native';$null=New-Item -ItemType Directory -Path $nativeFolder -Force
                foreach($test in @(Get-AdDiagnosticTests $Options.DiagnosticProfile)){
                    Invoke-AdCollection $report 'NativeDiagnostics' "$dcName / $test" {
                        $native=Invoke-AdDcdiag $dcName $test $Options.TimeoutSeconds
                        $nativeName=('{0}-{1}.txt' -f $test,[guid]::NewGuid().ToString('N'))
                        [IO.File]::WriteAllText((Join-Path $nativeFolder $nativeName),$native.Text,(New-Object Text.UTF8Encoding($false)))
                        $nativeStatus=if($native.TimedOut){'Timeout'}elseif($native.ExitCode -ne 0){'CommandError'}else{'CompletedReviewRequired'}
                        if($nativeStatus -ne 'CompletedReviewRequired'){
                            Add-AdRows $report 'CollectionErrors' @([pscustomobject]@{Dataset='NativeDiagnostics';Scope="$dcName / $test";ErrorType=$nativeStatus;Message="Native diagnostic incomplete; raw=native/$nativeName"})
                        }
                        [pscustomobject]@{Domain=$dnsDomain;DC=$dcName;Test=$test;Status=$nativeStatus;ExitCode=$native.ExitCode;TimedOut=$native.TimedOut;OutputFile=('native/'+$nativeName)}
                    }
                }
            }else{Invoke-AdCollection $report 'NativeDiagnostics' $dcName {} -Skip}
            Invoke-AdOperationalCollections $report $Options $dnsDomain $dcName
            Invoke-AdExtendedDc $report $Options $dnsDomain $dcName $folder
            Add-AdRows $report 'Timings' @([pscustomobject]@{Dataset='DCProcessing';Scope=$dcName;Status='Completed';Rows=1;DurationSeconds=$dcWatch.Elapsed.TotalSeconds})
        }
        $counts=@{};foreach($kind in @('Computers','Users','Groups')){
            $coverage=@($report.Datasets.Coverage|Where-Object{$_.Dataset -eq $kind -and $_.Scope -eq $dnsDomain})
            $counts[$kind]=if($coverage.Count -and $coverage[0].Status -eq 'Collected'){$coverage[0].Rows}else{$null}
        }
        Add-AdRows $report 'Domains' @([pscustomobject]@{Domain=$dnsDomain;QueryServer=$queryServer;DistinguishedName=$current.DistinguishedName;DomainMode=[string]$current.DomainMode;DomainSid=$sid;PDCEmulator=$current.PDCEmulator;RIDMaster=$current.RIDMaster;InfrastructureMaster=$current.InfrastructureMaster;Computers=$counts.Computers;Users=$counts.Users;Groups=$counts.Groups})
        foreach($g in @($report.Datasets.Computers|Where-Object{$_.Domain -eq $dnsDomain}|Group-Object Category,OperatingSystem)){
            Add-AdRows $report 'ComputerSummary' @([pscustomobject]@{Domain=$dnsDomain;Category=$g.Group[0].Category;OperatingSystem=$g.Group[0].OperatingSystem;Count=$g.Count})
        }
    }
    Complete-AdExtensionFindings $report
    Complete-AdFindings $report
    Complete-AdOperationalFindings $report
    $report.EndedUtc=[datetime]::UtcNow.ToString('o')
    $important=@($report.Datasets.Findings|Where-Object{$_.Severity -in @('High','Medium')}).Count
    $report.Status=if($report.Datasets.CollectionErrors.Count){'Partial'}elseif($important){'CompletedWithFindings'}else{'Completed'}
    Write-AdAssessmentFiles $report $folder
    [pscustomobject]@{Status=$report.Status;ExitCode=if($report.Status -eq 'Completed'){0}else{2};RunFolder=$folder;Findings=$report.Datasets.Findings.Count;CollectionErrors=$report.Datasets.CollectionErrors.Count}
}

function Get-AdEffectiveOptions {
    param($InputOptions)
    $defaults=[ordered]@{Server='';Scope='Domain';OutputPath='';InactiveDays=90;IncludeServiceChecks=$false;IncludeDcDiagnostics=$false;TimeoutSeconds=60;MaxHtmlRows=1000;PageSize=500;SkipUserInventory=$false;SkipPrivilegedMembers=$false;FullAssessment=$false;IncludeOperationalChecks=$false;IncludeEventLogs=$false;DiagnosticProfile='Baseline';DnsServer='';TimeSamples=3;TimeWarningSeconds=1.0;TimeCriticalSeconds=5.0;DiskWarningPercent=15.0;DiskCriticalPercent=5.0;DiskWarningGiB=10.0;DiskCriticalGiB=5.0;EventHours=24;MaxEventsPerLog=100}
    $extended=Get-AdExtensionDefaults;foreach($key in $extended.Keys){$defaults[$key]=$extended[$key]}
    foreach($key in @($defaults.Keys)){$p=$InputOptions.PSObject.Properties[$key];if($null -ne $p){$defaults[$key]=$p.Value}}
    if($defaults.ComprehensiveAssessment){$defaults.FullAssessment=$true;foreach($k in @('IncludeDirectorySecurity','IncludeTopology','IncludeGpoInventory','IncludeSysvolInventory','IncludeDnsConfiguration','IncludeBackupEvidence','IncludeHostInventory','IncludeSecurityConfiguration','IncludeRsop','IncludeSecurityEvents')){$defaults[$k]=$true}}
    if($defaults.BaselineFile){$defaults.IncludeSecurityConfiguration=$true}
    if($defaults.FullAssessment){foreach($k in @('IncludeServiceChecks','IncludeDcDiagnostics','IncludeOperationalChecks','IncludeEventLogs')){$defaults[$k]=$true};$defaults.DiagnosticProfile='Extended'}
    if($defaults.TimeCriticalSeconds -le $defaults.TimeWarningSeconds -or $defaults.DiskCriticalPercent -ge $defaults.DiskWarningPercent -or $defaults.DiskCriticalGiB -ge $defaults.DiskWarningGiB){throw 'Critical thresholds must be stricter than warning thresholds.'}
    [pscustomobject]$defaults
}
function Get-AdDiagnosticTests {
    param([ValidateSet('Baseline','Extended')][string]$Profile)
    $tests=@('NetLogons','Replications','Services','Advertising','KnowsOfRoleHolders')
    if($Profile -eq 'Extended'){$tests+=@('DFSREvent','SysVolCheck','KccEvent','MachineAccount','NCSecDesc','ObjectsReplicated','RidManager','SystemLog','VerifyReferences','CheckSDRefDom','CrossRefValidation','LocatorCheck')}
    $tests
}
function Invoke-AdReadProcess {
    param([string]$File,[string]$Arguments,[int]$TimeoutSeconds)
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=$File;$psi.Arguments=$Arguments;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $p=New-Object Diagnostics.Process;$p.StartInfo=$psi
    try{
        $null=$p.Start();$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
        if(-not $p.WaitForExit($TimeoutSeconds*1000)){try{$p.Kill()}catch{};return [pscustomobject]@{ExitCode=$null;TimedOut=$true;Text='Timeout. Partial native output not retained.'}}
        [pscustomobject]@{ExitCode=$p.ExitCode;TimedOut=$false;Text=($out.GetAwaiter().GetResult()+[Environment]::NewLine+$err.GetAwaiter().GetResult())}
    }finally{$p.Dispose()}
}
function Invoke-AdDnsQuery {
    param([string]$Name,[ValidateSet('A','AAAA','SRV')][string]$Type,[string]$Resolver)
    $arguments=@{Name=$Name;Type=$Type;DnsOnly=$true;NoHostsFile=$true;QuickTimeout=$true;ErrorAction='Stop'}
    if($Resolver){$arguments.Server=$Resolver}
    Resolve-DnsName @arguments
}
function Get-AdDnsObservation {
    param([string]$Domain,[string]$DC,[string]$Name,[string]$Type,[string]$Resolver)
    try{
        $records=@(Invoke-AdDnsQuery $Name $Type $Resolver);$matched=$false
        foreach($r in $records){
            $address=Get-AdField $r 'IPAddress';$target=Get-AdField $r 'NameTarget'
            if(($Type -eq 'SRV' -and $target) -or ($Type -ne 'SRV' -and $address)){
                $matched=$true
                [pscustomobject]@{Domain=$Domain;DC=$DC;QueryName=$Name;QueryType=$Type;Resolver=if($Resolver){$Resolver}else{'CollectorConfiguredDNS'};Status='Observed';Address=$address;Target=$target;Port=Get-AdField $r 'Port';Priority=Get-AdField $r 'Priority';Weight=Get-AdField $r 'Weight';TTL=Get-AdField $r 'TTL';Error=''}
            }
        }
        if(-not $matched){[pscustomobject]@{Domain=$Domain;DC=$DC;QueryName=$Name;QueryType=$Type;Resolver=if($Resolver){$Resolver}else{'CollectorConfiguredDNS'};Status='NotPresent';Address='';Target='';Port=$null;Priority=$null;Weight=$null;TTL=$null;Error='No matching record returned.'}}
    }catch{
        $id=$_.FullyQualifiedErrorId
        $status=if($id -match '^(DNS_ERROR_RCODE_NAME_ERROR|DNS_INFO_NO_RECORDS)(,|$)'){'NotPresent'}else{'QueryError'}
        [pscustomobject]@{Domain=$Domain;DC=$DC;QueryName=$Name;QueryType=$Type;Resolver=if($Resolver){$Resolver}else{'CollectorConfiguredDNS'};Status=$status;Address='';Target='';Port=$null;Priority=$null;Weight=$null;TTL=$null;Error=$_.Exception.Message}
    }
}
function Get-AdVolumeRoles {
    param([string]$Volume,[object[]]$Paths)
    $roles=foreach($p in $Paths){if($p.Status -eq 'Observed' -and $p.Volume -ieq $Volume){$p.Component}}
    @($roles)-join '; '
}
function Get-AdPingObservation {
    param([string]$Domain,[string]$DC,[int]$TimeoutSeconds)
    $ping=New-Object Net.NetworkInformation.Ping
    try{
        $reply=$ping.Send($DC,[math]::Min(5000,$TimeoutSeconds*1000))
        [pscustomobject]@{Domain=$Domain;DC=$DC;Probe='ICMP';Status=if($reply.Status -eq 'Success'){'Reply'}else{'NoReply'};RoundtripMs=if($reply.Status -eq 'Success'){$reply.RoundtripTime}else{$null};Address=if($reply.Address){$reply.Address.ToString()}else{''};Error=if($reply.Status -eq 'Success'){''}else{$reply.Status.ToString()}}
    }catch{[pscustomobject]@{Domain=$Domain;DC=$DC;Probe='ICMP';Status='Error';RoundtripMs=$null;Address='';Error=$_.Exception.Message}}
    finally{$ping.Dispose()}
}
function Get-AdHostBundle {
    param([string]$Domain,[string]$DC,[int]$TimeoutSeconds)
    $hostRows=@();$diskRows=@();$paths=@();$errors=New-Object 'Collections.Generic.List[object]';$session=$null;$os=$null;$volumes=@()
    try{
        $session=New-CimSession -ComputerName $DC -OperationTimeoutSec $TimeoutSeconds -ErrorAction Stop
        try{
            $os=Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem -OperationTimeoutSec $TimeoutSeconds -ErrorAction Stop
            $boot=Convert-AdDate $os.LastBootUpTime;$hours=$null;$observation='Observed'
            if($boot){$hours=([datetime]::UtcNow-([datetime]$boot).ToUniversalTime()).TotalHours;if($hours -lt 0){$observation='ClockInconsistent';$hours=$null}}
            $total=[long]$os.TotalVisibleMemorySize*1KB;$free=[long]$os.FreePhysicalMemory*1KB
            $hostRows=@([pscustomobject]@{Domain=$Domain;DC=$DC;CollectedUtc=[datetime]::UtcNow.ToString('o');OSName=$os.Caption;OSVersion=$os.Version;Build=$os.BuildNumber;SystemDrive=$os.SystemDrive;LastBootUtc=$boot;UptimeHours=$hours;MemoryTotalBytes=$total;MemoryFreeBytes=$free;MemoryFreePercent=if($total -gt 0){[math]::Round(100.0*$free/$total,2)}else{$null};Observation=$observation})
            $paths+= [pscustomobject]@{Domain=$Domain;DC=$DC;Component='OS';Path=($os.SystemDrive+'\');Status='Observed';Volume='';Error=''}
        }catch{$errors.Add([pscustomobject]@{Component='HostMetrics';Message=$_.Exception.Message})}
        try{$volumes=@(Get-CimInstance -CimSession $session -ClassName Win32_Volume -Filter 'DriveType=3' -OperationTimeoutSec $TimeoutSeconds -ErrorAction Stop)}catch{$errors.Add([pscustomobject]@{Component='Disks';Message=$_.Exception.Message})}
        $registry=@(@('NTDSDatabase','SYSTEM\CurrentControlSet\Services\NTDS\Parameters','DSA Database file'),@('NTDSLogs','SYSTEM\CurrentControlSet\Services\NTDS\Parameters','Database log files path'),@('SYSVOL','SYSTEM\CurrentControlSet\Services\Netlogon\Parameters','SysVol'))
        foreach($item in $registry){
            try{
                $registryArguments=@{hDefKey=[uint32]2147483650;sSubKeyName=$item[1];sValueName=$item[2]}
                $value=Invoke-CimMethod -CimSession $session -Namespace root/default -ClassName StdRegProv -MethodName GetStringValue -Arguments $registryArguments -OperationTimeoutSec $TimeoutSeconds -ErrorAction Stop
                if($value.ReturnValue -eq 13){$value=Invoke-CimMethod -CimSession $session -Namespace root/default -ClassName StdRegProv -MethodName GetExpandedStringValue -Arguments $registryArguments -OperationTimeoutSec $TimeoutSeconds -ErrorAction Stop}
                if($value.ReturnValue -ne 0 -or [string]::IsNullOrWhiteSpace($value.sValue)){throw "Registry read return=$($value.ReturnValue)"}
                $path=[string]$value.sValue;$status=if($path.Contains('%')){'Unexpanded'}else{'Observed'}
                $paths+=[pscustomobject]@{Domain=$Domain;DC=$DC;Component=$item[0];Path=$path;Status=$status;Volume='';Error=''}
            }catch{$paths+=[pscustomobject]@{Domain=$Domain;DC=$DC;Component=$item[0];Path='';Status='RegistryError';Volume='';Error=$_.Exception.Message}}
        }
        foreach($p in $paths){
            if($p.Status -eq 'Observed'){
                $match=@($volumes|Where-Object{$_.Name -and $p.Path.StartsWith([string]$_.Name,[StringComparison]::OrdinalIgnoreCase)}|Sort-Object @{Expression={$_.Name.Length};Descending=$true})
                if($match.Count){$p.Volume=[string]$match[0].Name}else{$p.Status='VolumeUnmapped'}
            }
        }
        $diskRows=@(foreach($v in $volumes){
            $capacity=Get-AdField $v 'Capacity';$free=Get-AdField $v 'FreeSpace';$usable=$null -ne $capacity -and [double]$capacity -gt 0 -and $null -ne $free
            $roles=Get-AdVolumeRoles ([string]$v.Name) $paths
            [pscustomobject]@{Domain=$Domain;DC=$DC;Volume=$v.Name;DriveLetter=$v.DriveLetter;Label=$v.Label;Roles=$roles;CapacityBytes=$capacity;FreeBytes=$free;FreeGiB=if($usable){[math]::Round([double]$free/1GB,3)}else{$null};FreePercent=if($usable){[math]::Round(100.0*[double]$free/[double]$capacity,3)}else{$null};AssessmentScope=if($roles -or $v.DriveLetter -or $v.Name -match '^[A-Za-z]:\\'){'VisibleOrRoleMapped'}else{'UnmappedSystemVolume'};Observation=if($usable){'Observed'}else{'UnknownCapacity'}}
        })
    }catch{foreach($component in @('HostMetrics','Disks','StoragePaths')){$errors.Add([pscustomobject]@{Component=$component;Message=$_.Exception.Message})}}
    finally{if($session){Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue}}
    [pscustomobject]@{HostRows=$hostRows;DiskRows=$diskRows;Paths=$paths;Errors=@($errors.ToArray())}
}
function Get-AdTimeNativePath {Join-Path ([Environment]::SystemDirectory) 'w32tm.exe'}
function Invoke-AdTimeQuery {
    param([string]$DC,[ValidateSet('Stripchart','Source','Status','Configuration')][string]$Query,[int]$Samples,[int]$TimeoutSeconds)
    if($DC -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$'){throw 'Invalid DC hostname.'}
    $nativeArguments=if($Query -eq 'Stripchart'){"/stripchart /computer:$DC /samples:$Samples /period:1 /dataonly"}else{"/query /computer:$DC /$($Query.ToLowerInvariant())"}
    if($Query -eq 'Status'){$nativeArguments+=' /verbose'}
    Invoke-AdReadProcess (Get-AdTimeNativePath) $nativeArguments $TimeoutSeconds
}
function Get-AdMedian {
    param([double[]]$Values)
    if($Values.Count -eq 0){return $null};$sorted=@($Values|Sort-Object);$m=[int][math]::Floor($sorted.Count/2)
    if($sorted.Count%2){return $sorted[$m]};($sorted[$m-1]+$sorted[$m])/2.0
}
function Convert-AdTimeSamples {
    param([string]$Text,[string]$Domain,[string]$DC)
    $i=0
    foreach($line in ($Text -split '\r?\n')){
        if($line -match '^\s*\d{1,2}:\d{2}:\d{2}[^,]*,\s*(?<Offset>[+-]\d+(?:[.,]\d+)?)s\s*$'){
            $number=0.0
            if([double]::TryParse($Matches.Offset.Replace(',','.'),[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$number)){
                $i++;[pscustomobject]@{Domain=$Domain;DC=$DC;Sample=$i;CollectedUtc=[datetime]::UtcNow.ToString('o');Reference='CollectorLocalClock';OffsetSeconds=$number;AbsoluteOffsetSeconds=[math]::Abs($number);RawLine=$line}
            }
        }
    }
}
function Get-AdTimeBundle {
    param([string]$Domain,[string]$DC,[int]$Samples,[int]$TimeoutSeconds)
    $native=Invoke-AdTimeQuery $DC Stripchart $Samples $TimeoutSeconds
    $rows=@(Convert-AdTimeSamples $native.Text $Domain $DC)
    $status=if($native.TimedOut){'Timeout'}elseif($native.ExitCode -ne 0){'CommandError'}elseif($rows.Count -lt $Samples){'InsufficientOrUnrecognizedSamples'}else{'Measured'}
    $summary=[pscustomobject]@{Domain=$Domain;DC=$DC;Reference='CollectorLocalClock';RequestedSamples=$Samples;ParsedSamples=$rows.Count;Status=$status;MedianOffsetSeconds=if($rows.Count){Get-AdMedian @($rows.OffsetSeconds)}else{$null};MedianAbsoluteOffsetSeconds=if($rows.Count){Get-AdMedian @($rows.AbsoluteOffsetSeconds)}else{$null};MaximumAbsoluteOffsetSeconds=if($rows.Count){($rows.AbsoluteOffsetSeconds|Measure-Object -Maximum).Maximum}else{$null};ExitCode=$native.ExitCode;TimedOut=$native.TimedOut;RawText=$native.Text}
    $config=@(foreach($q in @('Source','Status','Configuration')){
        try{$n=Invoke-AdTimeQuery $DC $q $Samples $TimeoutSeconds;[pscustomobject]@{Domain=$Domain;DC=$DC;Query=$q;Status=if($n.TimedOut){'Timeout'}elseif($n.ExitCode -ne 0){'CommandError'}else{'CompletedReviewRequired'};ExitCode=$n.ExitCode;TimedOut=$n.TimedOut;RawText=$n.Text}}
        catch{[pscustomobject]@{Domain=$Domain;DC=$DC;Query=$q;Status='QueryError';ExitCode=$null;TimedOut=$false;RawText=$_.Exception.Message}}
    })
    [pscustomobject]@{Samples=$rows;Summary=$summary;Configuration=$config}
}
function Invoke-AdEventQuery {
    param([string]$DC,[string]$Log,[datetime]$Start,[datetime]$End,[int]$Maximum)
    Get-WinEvent -ComputerName $DC -FilterHashtable @{LogName=$Log;StartTime=$Start;EndTime=$End;Level=@(1,2,3)} -MaxEvents $Maximum -ErrorAction Stop
}
function Get-AdEventBundle {
    param([string]$Domain,[string]$DC,[string]$Log,[int]$Hours,[int]$Maximum)
    $end=[datetime]::UtcNow;$start=$end.AddHours(-$Hours);$events=@();$status='Collected';$errorText=''
    try{$events=@(Invoke-AdEventQuery $DC $Log $start $end ($Maximum+1))}
    catch{if($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*'){$status='Collected'}elseif($_.FullyQualifiedErrorId -like 'NoMatchingLogsFound*'){$status='NotPresent';$errorText=$_.Exception.Message}else{$status='QueryError';$errorText=$_.Exception.Message}}
    $truncated=$events.Count -gt $Maximum
    $rows=@(foreach($e in @($events|Select-Object -First $Maximum)){
        $messageStatus='Formatted';try{$message=Get-AdField $e 'Message'}catch{$message='Message unavailable: '+$_.Exception.Message;$messageStatus='Unavailable'}
        [pscustomobject]@{Domain=$Domain;DC=$DC;LogName=$Log;TimeCreatedUtc=Convert-AdDate $e.TimeCreated;EventId=$e.Id;Level=$e.Level;Provider=$e.ProviderName;RecordId=$e.RecordId;Message=$message;MessageStatus=$messageStatus}
    })
    $coverage=[pscustomobject]@{Domain=$Domain;DC=$DC;LogName=$Log;StartUtc=$start.ToString('o');EndUtc=$end.ToString('o');Status=$status;Exported=$rows.Count;Truncated=$truncated;Limit=$Maximum;Error=$errorText}
    [pscustomobject]@{Rows=$rows;Coverage=$coverage}
}
function Add-AdOperationalError {
    param($Report,[string]$Dataset,[string]$Scope,[string]$Message)
    Add-AdRows $Report 'CollectionErrors' @([pscustomobject]@{Dataset=$Dataset;Scope=$Scope;ErrorType='OperationalObservationIncomplete';Message=$Message})
}
function Invoke-AdOperationalCollections {
    param($Report,$Options,[string]$Domain,[string]$DC)
    $scope=$DC
    if($Options.IncludeOperationalChecks){
        Invoke-AdCollection $Report 'Connectivity' $scope {Get-AdPingObservation $Domain $DC $Options.TimeoutSeconds}
        Invoke-AdCollection $Report 'DNS' $scope {
            foreach($type in @('A','AAAA')){Get-AdDnsObservation $Domain $DC $DC $type $Options.DnsServer}
            foreach($query in @("_ldap._tcp.dc._msdcs.$Domain","_kerberos._tcp.$Domain")){Get-AdDnsObservation $Domain $DC $query 'SRV' $Options.DnsServer}
        }
        foreach($row in @($Report.Datasets.DNS|Where-Object{$_.DC -eq $DC -and $_.Status -eq 'QueryError'})){Add-AdOperationalError $Report DNS $DC $row.Error}
        foreach($row in @($Report.Datasets.Connectivity|Where-Object{$_.DC -eq $DC -and $_.Status -eq 'Error'})){Add-AdOperationalError $Report Connectivity $DC $row.Error}
        $hostWatch=[Diagnostics.Stopwatch]::StartNew()
        try{$bundle=Get-AdHostBundle $Domain $DC $Options.TimeoutSeconds}catch{$bundle=[pscustomobject]@{HostRows=@();DiskRows=@();Paths=@();Errors=@([pscustomobject]@{Component='HostMetrics';Message=$_.Exception.Message},[pscustomobject]@{Component='Disks';Message=$_.Exception.Message},[pscustomobject]@{Component='StoragePaths';Message=$_.Exception.Message})}}
        Add-AdRows $Report 'Timings' @([pscustomobject]@{Dataset='HostBundle';Scope=$DC;Status=if($bundle.Errors.Count){'Incomplete'}else{'Collected'};Rows=(@($bundle.HostRows).Count+@($bundle.DiskRows).Count+@($bundle.Paths).Count);DurationSeconds=$hostWatch.Elapsed.TotalSeconds})
        foreach($pair in @(@('HostMetrics','HostRows'),@('Disks','DiskRows'),@('StoragePaths','Paths'))){
            $dataset=$pair[0];$property=$pair[1]
            Invoke-AdCollection $Report $dataset $scope { $problem=@($bundle.Errors|Where-Object{$_.Component -eq $dataset});if($problem.Count){throw $problem[0].Message};$bundle.$property }
        }
        foreach($path in @($Report.Datasets.StoragePaths|Where-Object{$_.DC -eq $DC -and $_.Status -ne 'Observed'})){Add-AdOperationalError $Report StoragePaths $DC "$($path.Component): $($path.Status); $($path.Error)"}
        foreach($disk in @($Report.Datasets.Disks|Where-Object{$_.DC -eq $DC -and $_.Observation -ne 'Observed'})){Add-AdOperationalError $Report Disks $DC "$($disk.Volume): $($disk.Observation)"}
        Invoke-AdCollection $Report 'TimeSummary' $scope {
            $timeBundle=Get-AdTimeBundle $Domain $DC $Options.TimeSamples $Options.TimeoutSeconds
            Add-AdRows $Report 'TimeSamples' $timeBundle.Samples
            Add-AdRows $Report 'TimeConfiguration' $timeBundle.Configuration
            $timeBundle.Summary
        }
        foreach($row in @($Report.Datasets.TimeSummary|Where-Object{$_.DC -eq $DC -and $_.Status -ne 'Measured'})){Add-AdOperationalError $Report TimeSummary $DC $row.Status}
        foreach($row in @($Report.Datasets.TimeConfiguration|Where-Object{$_.DC -eq $DC -and $_.Status -ne 'CompletedReviewRequired'})){Add-AdOperationalError $Report TimeConfiguration $DC "$($row.Query): $($row.Status)"}
    }else{foreach($d in @('Connectivity','DNS','HostMetrics','Disks','StoragePaths','TimeSummary','TimeSamples','TimeConfiguration')){Invoke-AdCollection $Report $d $scope {} -Skip}}
    if($Options.IncludeEventLogs){
        foreach($log in @('System','Directory Service','DFS Replication','DNS Server')){
            Invoke-AdCollection $Report 'EventLogCoverage' "$DC / $log" {
                $events=Get-AdEventBundle $Domain $DC $log $Options.EventHours $Options.MaxEventsPerLog
                Add-AdRows $Report 'Events' $events.Rows
                $events.Coverage
            }
        }
        foreach($row in @($Report.Datasets.EventLogCoverage|Where-Object{$_.DC -eq $DC -and ($_.Status -eq 'QueryError' -or ($_.Status -eq 'NotPresent' -and $_.LogName -ne 'DNS Server'))})){Add-AdOperationalError $Report Events $DC "$($row.LogName): $($row.Status); $($row.Error)"}
    }else{foreach($d in @('Events','EventLogCoverage')){Invoke-AdCollection $Report $d $scope {} -Skip}}
}
function Complete-AdOperationalFindings {
    param($Report)
    $o=$Report.Parameters
    foreach($disk in $Report.Datasets.Disks){
        if($disk.Observation -ne 'Observed' -or $disk.AssessmentScope -ne 'VisibleOrRoleMapped'){continue}
        $freeGiB=[double]$disk.FreeBytes/1GB;$freePercent=100.0*[double]$disk.FreeBytes/[double]$disk.CapacityBytes
        $level=if($freePercent -le $o.DiskCriticalPercent -or $freeGiB -le $o.DiskCriticalGiB){'High'}elseif($freePercent -le $o.DiskWarningPercent -or $freeGiB -le $o.DiskWarningGiB){'Medium'}else{''}
        if($level){New-AdFinding $Report $level 'DC-DISK-SPACE' Disks $disk.Domain $disk.DC "$($disk.Volume): $($disk.FreeGiB) GiB / $($disk.FreePercent)% free; roles=$($disk.Roles)" 'Review capacity and configured thresholds. No files were deleted.'}
    }
    foreach($h in $Report.Datasets.HostMetrics){if($null -ne $h.UptimeHours -and $h.UptimeHours -le 24){New-AdFinding $Report Info 'DC-RECENT-BOOT' HostMetrics $h.Domain $h.DC "UptimeHours=$($h.UptimeHours)" 'Correlate with planned maintenance; a recent boot alone is not a failure.'}}
    foreach($t in $Report.Datasets.TimeSummary){if($t.Status -eq 'Measured' -and $null -ne $t.MedianAbsoluteOffsetSeconds -and $t.MedianAbsoluteOffsetSeconds -ge $o.TimeWarningSeconds){$severity=if($t.MedianAbsoluteOffsetSeconds -ge $o.TimeCriticalSeconds){'High'}else{'Medium'};New-AdFinding $Report $severity 'DC-TIME-OFFSET' TimeSummary $t.Domain $t.DC "Median absolute offset=$($t.MedianAbsoluteOffsetSeconds)s relative to collector clock." 'Verify the collector reference, network delay and DC time source; no clock was changed.'}}
    foreach($e in $Report.Datasets.EventLogCoverage){if($e.Status -eq 'Collected' -and $e.Exported -gt 0){New-AdFinding $Report Medium 'DC-EVENTS-REVIEW' Events $e.Domain $e.DC "$($e.LogName): $($e.Exported) warning/error/critical events; truncated=$($e.Truncated); since=$($e.StartUtc)" 'Review event IDs and timestamps; historical events do not prove a current outage.'}}
    foreach($dc in $Report.Datasets.DomainControllers){
        $dns=@($Report.Datasets.DNS|Where-Object{$_.DC -eq $dc.HostName})
        foreach($q in @($dns|Where-Object{$_.QueryType -eq 'SRV' -and $_.Status -eq 'NotPresent'})){New-AdFinding $Report Medium 'DC-DNS-SRV-NOT-PRESENT' DNS $dc.Domain $dc.HostName "$($q.QueryName) not returned by $($q.Resolver)." 'Review resolver configuration and AD service registration; do not create records automatically.'}
        $hosts=@($dns|Where-Object{$_.QueryName -eq $dc.HostName -and $_.QueryType -in @('A','AAAA')})
        if($hosts.Count -eq 2 -and @($hosts|Where-Object{$_.Status -ne 'NotPresent'}).Count -eq 0){New-AdFinding $Report Medium 'DC-DNS-HOST-NOT-PRESENT' DNS $dc.Domain $dc.HostName 'Neither A nor AAAA was returned.' 'Review DNS and the selected resolver. A missing AAAA record alone is not a failure.'}
        $coverage=@($Report.Datasets.Coverage|Where-Object{$_.Scope -eq $dc.HostName -or $_.Scope.StartsWith($dc.HostName+' / ')})
        $errors=@($Report.Datasets.CollectionErrors|Where-Object{$_.Scope -eq $dc.HostName -or $_.Scope.StartsWith($dc.HostName+' / ')})
        $findings=@($Report.Datasets.Findings|Where-Object{$_.Target -eq $dc.HostName})
        $hostRows=@($Report.Datasets.HostMetrics|Where-Object{$_.DC -eq $dc.HostName});$diskRows=@($Report.Datasets.Disks|Where-Object{$_.DC -eq $dc.HostName -and $_.AssessmentScope -eq 'VisibleOrRoleMapped' -and $_.Observation -eq 'Observed'});$timeRows=@($Report.Datasets.TimeSummary|Where-Object{$_.DC -eq $dc.HostName});$eventRows=@($Report.Datasets.EventLogCoverage|Where-Object{$_.DC -eq $dc.HostName});$duration=@($Report.Datasets.Timings|Where-Object{$_.Dataset -eq 'DCProcessing' -and $_.Scope -eq $dc.HostName})
        $summary=[ordered]@{Domain=$dc.Domain;DC=$dc.HostName;Site=$dc.Site;DnsAddresses=(@($dns|Where-Object{$_.Address}|ForEach-Object{$_.Address}|Sort-Object -Unique)-join '; ');UptimeHours=if($hostRows.Count){$hostRows[0].UptimeHours}else{$null};LowestAssessedFreeGiB=if($diskRows.Count){($diskRows.FreeGiB|Measure-Object -Minimum).Minimum}else{$null};LowestAssessedFreePercent=if($diskRows.Count){($diskRows.FreePercent|Measure-Object -Minimum).Minimum}else{$null};MedianAbsoluteOffsetSeconds=if($timeRows.Count -and $timeRows[0].Status -eq 'Measured'){$timeRows[0].MedianAbsoluteOffsetSeconds}else{$null};RecentEventRows=if($eventRows.Count){($eventRows.Exported|Measure-Object -Sum).Sum}else{$null};RecentEventsTruncated=if($eventRows.Count){@($eventRows|Where-Object{$_.Truncated}).Count -gt 0}else{$null};ProcessingSeconds=if($duration.Count){$duration[0].DurationSeconds}else{$null};Observation=if($errors.Count){'Incomplete'}elseif(@($findings|Where-Object{$_.Severity -in @('High','Medium')}).Count){'ReviewRequired'}else{'CollectedEvidenceOnly'};CollectionErrors=$errors.Count;Findings=$findings.Count}
        foreach($name in @('Replication','Connectivity','DNS','HostMetrics','Disks','StoragePaths','TimeSummary','Services','EventLogCoverage','NativeDiagnostics')){
            $items=@($coverage|Where-Object{$_.Dataset -eq $name});$sectionErrors=@($errors|Where-Object{$_.Dataset -eq $name -or ($name -eq 'TimeSummary' -and $_.Dataset -eq 'TimeConfiguration') -or ($name -eq 'EventLogCoverage' -and $_.Dataset -eq 'Events')});$summary[$name]=if($sectionErrors.Count){'Incomplete'}elseif(-not $items.Count){'Unknown'}elseif(@($items|Where-Object{$_.Status -eq 'Failed'}).Count){'Failed'}elseif(@($items|Where-Object{$_.Status -eq 'Collected'}).Count){'Collected'}else{'NotRequested'}
        }
        Add-AdRows $Report 'DCSummary' @([pscustomobject]$summary)
    }
}

# Independently implemented collectors. No ADxRay code or HTML is incorporated.
function Get-AdExtensionDefaults {
    [ordered]@{ComprehensiveAssessment=$false;IncludeDirectorySecurity=$false;IncludeTopology=$false;IncludeGpoInventory=$false;IncludeSysvolInventory=$false;IncludeDnsConfiguration=$false;IncludeBackupEvidence=$false;IncludeHostInventory=$false;IncludeSecurityConfiguration=$false;IncludeRsop=$false;IncludeSecurityEvents=$false;MaxDirectoryObjects=100000;MaxSpnValues=500000;MaxGpos=5000;MaxXmlCharacters=25000000;MaxPolicySettings=100000;MaxSysvolFiles=20000;SysvolTimeoutSeconds=120;MaxSoftwareEntries=5000;BackupWarningDays=7;BaselineFile='';FromReport=''}
}
function Get-AdExtensionSchemas {
    [ordered]@{
        OptionalFeatures='Forest,Feature,FeatureGuid,Enabled,EnabledScopes,QueryServer,Observation'
        Sites='Forest,Name,DistinguishedName,Description,Subnets,InterSiteTopologyGenerator'
        Subnets='Forest,Name,Site,Location,Description,DistinguishedName'
        SiteLinks='Forest,Name,Cost,ReplicationFrequencyMinutes,Sites,DistinguishedName'
        AccountSecurityFlags='Domain,QueryServer,Name,SamAccountName,ObjectClass,ObjectGuid,SID,DistinguishedName,Enabled,UserAccountControl,ReversibleEncryptionAllowed,UseDESKeyOnly,PasswordNotRequired,PasswordNeverExpires,DoesNotRequirePreAuth,TrustedForDelegation,TrustedToAuthForDelegation,NotDelegated,SmartcardRequired,SupportedEncryptionTypes,UserPrincipalName,Observation'
        SPNInventory='Domain,SPN,NormalizedSPN,OwnerName,OwnerClass,OwnerGuid,OwnerDN'
        DuplicateSPNs='SPN,OwnerCount,Domains,OwnerNames,OwnerGuids,OwnerDNs,AssessmentScope,Coverage'
        DuplicateUPNs='UserPrincipalName,OwnerCount,Domains,OwnerNames,OwnerGuids,OwnerDNs,AssessmentScope,Coverage'
        DirectoryCoverage='Domain,QueryServer,Objects,SPNValues,Truncated,ObjectLimit,SPNLimit,Observation'
        GroupPolicies='Domain,QueryServer,Guid,Name,Status,CreatedUtc,ModifiedUtc,Owner,WmiFilter,ComputerVersionAD,ComputerVersionSysvol,UserVersionAD,UserVersionSysvol,ComputerSettings,UserSettings,LinkCount,Observation,SourceFile'
        GPOLinks='Domain,ScopeType,ScopeDN,ScopeName,GpoGuid,GpoDN,StoredPosition,LinkOptions,Enabled,Enforced,InheritanceBlocked,Observation'
        GPOSettings='Domain,GpoGuid,GpoName,Area,SettingPath,Value,Attributes,SourceFile'
        GPOPermissions='Domain,GpoGuid,GpoName,TrusteeName,TrusteeSID,TrusteeType,Permission,Inherited,SourceFile'
        GPOCoverage='Domain,QueryServer,Discovered,Exported,Truncated,Limit,SettingsExported,SettingsTruncated,SettingsLimit,Observation'
        SysvolFiles='Domain,DC,RelativePath,Extension,Bytes,ModifiedUtc,Observation'
        SysvolSummary='Domain,DC,Root,Files,Directories,Bytes,Extension,ExtensionFiles,ExtensionBytes,Truncated,Limit,DurationSeconds,Observation'
        DnsServerConfiguration='Domain,DC,Component,Property,Value,Observation'
        DnsZones='Domain,DC,ZoneName,ZoneType,IsDsIntegrated,IsReverseLookupZone,DynamicUpdate,ReplicationScope,AgingEnabled,NoRefreshInterval,RefreshInterval,Observation'
        DnsRootHints='Domain,DC,RecordType,HostName,NameServer,Address,Observation'
        DnsZoneIndicators='Partition,Name,DistinguishedName,ObjectClass,QueryServer,Observation'
        BackupEvidence='Domain,DC,Source,Status,ExitCode,TimedOut,Partition,LastBackupUtc,AgeDays,Observation,RawText,SourceFile'
        HostHardware='Domain,DC,Manufacturer,Model,LogicalProcessors,PhysicalCores,Sockets,PhysicalMemoryBytes,OSBuild,UBR,InstallDateUtc,BIOSVersion,BIOSReleaseUtc,Observation'
        InstalledSoftware='Domain,DC,RegistryView,ProductKey,DisplayName,DisplayVersion,Publisher,InstallDateRaw,InstallLocation,Observation'
        Hotfixes='Domain,DC,HotfixId,Description,InstalledOnRaw,InstalledUtc,InstalledBy,Observation'
        HostSecurity='Domain,DC,Component,Setting,Value,Observation,Source'
        RegistryEvidence='Domain,DC,RuleId,RegistryPath,ValueName,ValueKind,Value,Observation,Error'
        SecurityReview='Domain,DC,RuleId,Title,Profile,Expected,Observed,Comparison,Status,OSBuild,Reference,Observation'
        RSoPSettings='Domain,DC,Area,SettingPath,Value,Attributes,SourceFile'
        UserRightsAssignments='Domain,DC,Right,PrincipalSID,PrincipalName,SourceGpo,Observation,SourceFile'
        SecurityEvents='Domain,DC,LogName,TimeCreatedUtc,EventId,Level,Provider,RecordId,Message,MessageStatus,EventDataJson,Interpretation'
        LogConfiguration='Domain,DC,LogName,Enabled,MaximumBytes,LogMode,RecordCount,OldestRecordNumber,LastWriteUtc,Observation'
        AuditPolicy='Domain,DC,SubcategoryGuid,Value,SourceFile,Observation'
        AssessmentSources='Id,Topic,Reference,AccessedDate,Usage,Limitations'
    }
}
function Add-AdExtensionError {
    param($Report,[string]$Dataset,[string]$Scope,[string]$Message,[string]$Type='Incomplete')
    Add-AdRows $Report 'CollectionErrors' @([pscustomobject]@{Dataset=$Dataset;Scope=$Scope;ErrorType=$Type;Message=$Message})
}
function Invoke-AdModuleRead {
    param([ValidateSet('GroupPolicy','DnsServer')][string]$Module,[string]$Command,[hashtable]$Arguments,[int]$TimeoutSeconds=60)
    $allow=@{GroupPolicy=@('Get-GPO','Get-GPOReport','Get-GPPermission','Get-GPResultantSetOfPolicy');DnsServer=@('Get-DnsServer','Get-DnsServerZone','Get-DnsServerZoneAging')}
    if($Command -notin $allow[$Module]){throw 'Read command not allowed.'}
    $job=$null
    try{
        $job=Start-Job -ScriptBlock {param($m,$c,$a) $ErrorActionPreference='Stop';Import-Module $m -ErrorAction Stop;& ($m+'\'+$c) @a -ErrorAction Stop} -ArgumentList @($Module,$Command,$Arguments) -ErrorAction Stop
        $done=Wait-Job -Job $job -Timeout $TimeoutSeconds
        if($null -eq $done){throw ('Module query timeout: '+$Module+' / '+$Command)}
        Receive-Job -Job $job -ErrorAction Stop
    }finally{if($null -ne $job){if($job.State -in @('Running','NotStarted','Blocked')){Stop-Job -Job $job -ErrorAction SilentlyContinue};Remove-Job -Job $job -Force -ErrorAction SilentlyContinue}}
}
function Save-AdEvidence {
    param([string]$Folder,[string]$Prefix,[string]$Text,[ValidateSet('txt','xml','json')][string]$Extension='txt')
    if($Prefix -notmatch '^[A-Za-z][A-Za-z0-9-]*$'){throw 'Invalid evidence prefix.'}
    $dir=Join-Path $Folder 'native';$null=New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
    $name=$Prefix+'-'+[guid]::NewGuid().ToString('N')+'.'+$Extension
    [IO.File]::WriteAllText((Join-Path $dir $name),$Text,(New-Object Text.UTF8Encoding($false)))
    'native/'+$name
}
function Convert-AdSafeXml {
    param([string]$Text,[int]$MaxCharacters=25000000)
    if([string]::IsNullOrWhiteSpace($Text) -or $Text.Length -gt $MaxCharacters){throw 'XML is empty or exceeds the configured character limit.'}
    $settings=New-Object Xml.XmlReaderSettings;$settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit;$settings.XmlResolver=$null;$settings.MaxCharactersInDocument=$MaxCharacters
    $input=New-Object IO.StringReader($Text);$reader=$null
    try{$reader=[Xml.XmlReader]::Create($input,$settings);$doc=New-Object Xml.XmlDocument;$doc.XmlResolver=$null;$doc.Load($reader);return ,$doc}finally{if($null -ne $reader){$reader.Dispose()};$input.Dispose()}
}
function Get-AdXmlText {
    param([Xml.XmlNode]$Node,[string]$XPath)
    $n=$Node.SelectSingleNode($XPath);if($null -ne $n){return [string]$n.InnerText};''
}
function Get-AdXmlLeaves {
    param([Xml.XmlNode]$Node,[int]$Limit)
    $rows=New-Object 'Collections.Generic.List[object]';$stack=New-Object 'Collections.Generic.Stack[object]'
    $stack.Push([pscustomobject]@{Node=$Node;Path=$Node.LocalName;Depth=0});$truncated=$false
    while($stack.Count -gt 0){
        $item=$stack.Pop();if($item.Depth -gt 128){throw 'XML nesting exceeds 128 levels.'}
        $children=@($item.Node.ChildNodes|Where-Object{$_.NodeType -eq [Xml.XmlNodeType]::Element})
        $attributes=@($item.Node.Attributes|Where-Object{$_.Prefix -ne 'xmlns' -and $_.Name -ne 'xmlns'}|ForEach-Object{$_.Name+'='+$_.Value}) -join '; '
        if($children.Count -eq 0 -or $attributes){
            if($rows.Count -ge $Limit){$truncated=$true;break}
            $rows.Add([pscustomobject]@{SettingPath=$item.Path;Value=if($children.Count -eq 0){$item.Node.InnerText}else{''};Attributes=$attributes})
        }
        $positions=@{};$next=New-Object 'Collections.Generic.List[object]'
        foreach($child in $children){$key=$child.NamespaceURI+'|'+$child.LocalName;if(-not $positions.ContainsKey($key)){$positions[$key]=0};$positions[$key]++;$next.Add([pscustomobject]@{Node=$child;Path=$item.Path+'/'+$child.LocalName+'['+$positions[$key]+']';Depth=$item.Depth+1})}
        for($i=$next.Count-1;$i -ge 0;$i--){$stack.Push($next[$i])}
    }
    [pscustomobject]@{Rows=$rows.ToArray();Truncated=$truncated}
}
function Convert-AdSecurityAccount {
    param($Account,[string]$Domain,[string]$Server)
    $uac=Get-AdField $Account 'userAccountControl';$known=$null -ne $uac
    $r=[ordered]@{Domain=$Domain;QueryServer=$Server;Name=Get-AdField $Account 'Name';SamAccountName=Get-AdField $Account 'sAMAccountName';ObjectClass=Get-AdField $Account 'ObjectClass';ObjectGuid=[string](Get-AdField $Account 'ObjectGUID');SID=Convert-AdSid (Get-AdField $Account 'objectSid');DistinguishedName=Get-AdField $Account 'DistinguishedName';Enabled=if($known){([long]$uac -band 2) -eq 0}else{$null};UserAccountControl=$uac}
    foreach($pair in @(@('ReversibleEncryptionAllowed',128),@('UseDESKeyOnly',2097152),@('PasswordNotRequired',32),@('PasswordNeverExpires',65536),@('DoesNotRequirePreAuth',4194304),@('TrustedForDelegation',524288),@('TrustedToAuthForDelegation',16777216),@('NotDelegated',1048576),@('SmartcardRequired',262144))){$r[$pair[0]]=if($known){([long]$uac -band [long]$pair[1]) -ne 0}else{$null}}
    $r.SupportedEncryptionTypes=Get-AdField $Account 'msDS-SupportedEncryptionTypes';$r.UserPrincipalName=Get-AdField $Account 'userPrincipalName';$r.Observation=if($known){'Observed'}else{'UnknownUAC'};[pscustomobject]$r
}
function Invoke-AdExtendedForest {
    param($Report,$Options,$Forest,$Root,[string]$Server)
    Invoke-AdCollection $Report 'OptionalFeatures' $Forest.Name {
        $f=Invoke-AdQuery 'Get-ADOptionalFeature' @{Identity='766ddcd8-acd0-445e-f3b9-a7f9b6744f2a';Server=$Server;Properties=@('EnabledScopes','FeatureGUID')}
        if($null -eq $f -or $null -eq $f.PSObject.Properties['EnabledScopes']){throw 'Optional feature response did not expose EnabledScopes.'}
        $scopes=@(Get-AdField $f 'EnabledScopes');[pscustomobject]@{Forest=$Forest.Name;Feature='Active Directory Recycle Bin';FeatureGuid='766ddcd8-acd0-445e-f3b9-a7f9b6744f2a';Enabled=(@($scopes|Where-Object{$_}).Count -gt 0);EnabledScopes=($scopes -join '; ');QueryServer=$Server;Observation='Observed'}
    } -Skip:(-not $Options.IncludeDirectorySecurity)
    foreach($spec in @(@('Sites','Get-ADReplicationSite'),@('Subnets','Get-ADReplicationSubnet'),@('SiteLinks','Get-ADReplicationSiteLink'))){
        Invoke-AdCollection $Report $spec[0] $Forest.Name {
            $all=@(Invoke-AdQuery $spec[1] @{Filter='*';Server=$Server;Properties='*'})
            foreach($a in $all){
                if($spec[0] -eq 'Sites'){[pscustomobject]@{Forest=$Forest.Name;Name=$a.Name;DistinguishedName=$a.DistinguishedName;Description=Get-AdField $a 'Description';Subnets=(@(Get-AdField $a 'Subnets') -join '; ');InterSiteTopologyGenerator=[string](Get-AdField $a 'InterSiteTopologyGenerator')}}
                elseif($spec[0] -eq 'Subnets'){[pscustomobject]@{Forest=$Forest.Name;Name=$a.Name;Site=[string](Get-AdField $a 'Site');Location=Get-AdField $a 'Location';Description=Get-AdField $a 'Description';DistinguishedName=$a.DistinguishedName}}
                else{[pscustomobject]@{Forest=$Forest.Name;Name=$a.Name;Cost=Get-AdField $a 'Cost';ReplicationFrequencyMinutes=Get-AdField $a 'ReplicationFrequencyInMinutes';Sites=(@(Get-AdField $a 'SitesIncluded') -join '; ');DistinguishedName=$a.DistinguishedName}}
            }
        } -Skip:(-not $Options.IncludeTopology)
    }
    # Site links to GPOs are forest configuration data, read once.
    Invoke-AdCollection $Report 'GPOLinks' ($Forest.Name+' / Sites') {
        $base='CN=Sites,'+[string]$Root.configurationNamingContext
        foreach($s in (Invoke-AdQuery 'Get-ADObject' @{LDAPFilter='(gPLink=*)';SearchBase=$base;Server=$Server;Properties=@('gPLink','gPOptions');ResultPageSize=$Options.PageSize})){Convert-AdGpoLinks $s 'ForestConfiguration' 'Site'}
    } -Skip:(-not $Options.IncludeGpoInventory)
}
function Convert-AdGpoLinks {
    param($ScopeObject,[string]$Domain,[string]$ScopeType='DomainOrOU')
    $raw=[string](Get-AdField $ScopeObject 'gPLink');$matches=[regex]::Matches($raw,'\[(?i:LDAP)://(?<dn>[^\]]+);(?<flags>\d+)\]')
    if($raw -and ($matches.Value -join '') -ne $raw){throw 'Unrecognized gPLink representation; raw directory evidence requires review.'}
    $position=0;$inheritance=Get-AdField $ScopeObject 'gPOptions'
    foreach($m in $matches){$position++;$dn=$m.Groups['dn'].Value;$flags=[int]$m.Groups['flags'].Value;$id=[regex]::Match($dn,'(?i)^CN=\{(?<id>[0-9a-f-]{36})\},').Groups['id'].Value
        [pscustomobject]@{Domain=$Domain;ScopeType=$ScopeType;ScopeDN=$ScopeObject.DistinguishedName;ScopeName=$ScopeObject.Name;GpoGuid=$id;GpoDN=$dn;StoredPosition=$position;LinkOptions=$flags;Enabled=($flags -band 1) -eq 0;Enforced=($flags -band 2) -ne 0;InheritanceBlocked=if($null -ne $inheritance){([int]$inheritance -band 1) -ne 0}else{$null};Observation='StoredAttributeOrderNotEffectivePrecedence'}
    }
}
function Invoke-AdExtendedDomain {
    param($Report,$Options,[string]$Domain,[string]$Server,[string]$Base,[string]$Folder,[string]$ForestRootDomain)
    if($Options.IncludeDnsConfiguration){
        Invoke-AdCollection $Report 'DnsZoneIndicators' $Domain {
            $naming=Invoke-AdQuery 'Get-ADRootDSE' @{Server=$Server}
            foreach($partition in @($naming.namingContexts|Where-Object{$_ -match '(?i)^DC=DomainDnsZones,' -or ($_ -match '(?i)^DC=ForestDnsZones,' -and $Domain -ieq $ForestRootDomain)})){
                $items=@(Invoke-AdQuery 'Get-ADObject' @{LDAPFilter='(name=*..InProgress*)';SearchBase=[string]$partition;Server=$Server;ResultPageSize=$Options.PageSize;ResultSetSize=($Options.MaxDirectoryObjects+1)})
                if($items.Count -gt $Options.MaxDirectoryObjects){Add-AdExtensionError $Report 'DnsZoneIndicators' $partition 'DNS indicator query truncated.' 'Truncated'}
                foreach($a in @($items|Select-Object -First $Options.MaxDirectoryObjects)){[pscustomobject]@{Partition=$partition;Name=$a.Name;DistinguishedName=$a.DistinguishedName;ObjectClass=$a.ObjectClass;QueryServer=$Server;Observation='NameIndicatorReviewRequired'}}
            }
        }
    }else{Invoke-AdCollection $Report 'DnsZoneIndicators' $Domain {} -Skip}
    Invoke-AdCollection $Report 'AccountSecurityFlags' $Domain {
        $filter=if($Options.SkipUserInventory){'(&(objectClass=computer)(sAMAccountName=*))'}else{'(|(servicePrincipalName=*)(&(objectClass=user)(sAMAccountName=*)))'}
        $args=@{LDAPFilter=$filter;SearchBase=$Base;Server=$Server;ResultPageSize=$Options.PageSize;ResultSetSize=($Options.MaxDirectoryObjects+1);Properties=@('sAMAccountName','objectSid','userAccountControl','userPrincipalName','servicePrincipalName','msDS-SupportedEncryptionTypes')}
        $accounts=@(Invoke-AdQuery 'Get-ADObject' $args);$truncated=$accounts.Count -gt $Options.MaxDirectoryObjects;$values=0;$spnTruncated=$false
        foreach($a in @($accounts|Select-Object -First $Options.MaxDirectoryObjects)){
            Convert-AdSecurityAccount $a $Domain $Server
            foreach($spn in @((Get-AdField $a 'servicePrincipalName')|Where-Object{$_})){
                if($values -ge $Options.MaxSpnValues){$spnTruncated=$true;break};$values++
                Add-AdRows $Report 'SPNInventory' @([pscustomobject]@{Domain=$Domain;SPN=[string]$spn;NormalizedSPN=([string]$spn).ToLowerInvariant();OwnerName=$a.Name;OwnerClass=$a.ObjectClass;OwnerGuid=[string]$a.ObjectGUID;OwnerDN=$a.DistinguishedName})
            }
        }
        Add-AdRows $Report 'DirectoryCoverage' @([pscustomobject]@{Domain=$Domain;QueryServer=$Server;Objects=[math]::Min($accounts.Count,$Options.MaxDirectoryObjects);SPNValues=$values;Truncated=($truncated -or $spnTruncated);ObjectLimit=$Options.MaxDirectoryObjects;SPNLimit=$Options.MaxSpnValues;Observation=if($truncated -or $spnTruncated){'Truncated'}elseif($Options.SkipUserInventory){'ComputersOnlyByRequest'}else{'ObservedWithinSelectedScope'}})
        if($truncated -or $spnTruncated){Add-AdExtensionError $Report 'AccountSecurityFlags' $Domain 'Directory/SPN limit reached; absence of duplicates is inconclusive outside exported coverage.' 'Truncated'}
    } -Skip:(-not $Options.IncludeDirectorySecurity)
    Invoke-AdCollection $Report 'GPOLinks' $Domain {
        foreach($s in (Invoke-AdQuery 'Get-ADObject' @{LDAPFilter='(gPLink=*)';SearchBase=$Base;Server=$Server;Properties=@('gPLink','gPOptions');ResultPageSize=$Options.PageSize})){Convert-AdGpoLinks $s $Domain}
    } -Skip:(-not $Options.IncludeGpoInventory)
    Invoke-AdCollection $Report 'GroupPolicies' $Domain {Get-AdGpoInventory $Report $Options $Domain $Server $Folder} -Skip:(-not $Options.IncludeGpoInventory)
}
function Get-AdGpoInventory {
    param($Report,$Options,[string]$Domain,[string]$Server,[string]$Folder)
    $gpos=@(Invoke-AdModuleRead GroupPolicy Get-GPO @{All=$true;Domain=$Domain;Server=$Server} -TimeoutSeconds $Options.TimeoutSeconds)
    $truncated=$gpos.Count -gt $Options.MaxGpos;$settingsCount=0;$settingsTruncated=$false;$done=0
    foreach($g in @($gpos|Select-Object -First $Options.MaxGpos)){
        $guid=[string]$g.Id;$name=[string]$g.DisplayName;$source='';$status='Observed';$computerCount=$null;$userCount=$null
        try{
            $xml=[string](Invoke-AdModuleRead GroupPolicy Get-GPOReport @{Guid=$g.Id;Domain=$Domain;Server=$Server;ReportType='Xml'} -TimeoutSeconds $Options.TimeoutSeconds)
            $doc=Convert-AdSafeXml $xml $Options.MaxXmlCharacters;$xmlGuid=Get-AdXmlText $doc "/*[local-name()='GPO']/*[local-name()='Identifier']/*[local-name()='Identifier']"
            if(-not $xmlGuid){$xmlGuid=Get-AdXmlText $doc "/*[local-name()='GPO']/*[local-name()='Identifier']"}
            if($xmlGuid -and $xmlGuid.Trim('{}') -ine $guid.Trim('{}')){throw 'GPO XML identity does not match the requested GUID.'}
            $xmlDomain=Get-AdXmlText $doc "/*[local-name()='GPO']/*[local-name()='Identifier']/*[local-name()='Domain']"
            if($xmlDomain -and $xmlDomain -ine $Domain){throw 'GPO XML domain does not match selected domain.'}
            $source=Save-AdEvidence $Folder 'GPO' $xml 'xml'
            $computerCount=@($doc.SelectNodes("/*[local-name()='GPO']/*[local-name()='Computer']/*[local-name()='ExtensionData']/*")).Count
            $userCount=@($doc.SelectNodes("/*[local-name()='GPO']/*[local-name()='User']/*[local-name()='ExtensionData']/*")).Count
            $remaining=[math]::Max(0,$Options.MaxPolicySettings-$settingsCount);$flat=Get-AdXmlLeaves $doc.DocumentElement $remaining
            $settingsTruncated=$settingsTruncated -or $flat.Truncated
            foreach($leaf in $flat.Rows){$settingsCount++;Add-AdRows $Report 'GPOSettings' @([pscustomobject]@{Domain=$Domain;GpoGuid=$guid;GpoName=$name;Area=if($leaf.SettingPath -match '/Computer\['){'Computer'}elseif($leaf.SettingPath -match '/User\['){'User'}else{'Metadata'};SettingPath=$leaf.SettingPath;Value=$leaf.Value;Attributes=$leaf.Attributes;SourceFile=$source})}
        }catch{$status='Partial';Add-AdExtensionError $Report 'GPOSettings' ($Domain+' / '+$guid) $_.Exception.Message 'QueryOrParseError'}
        try{
            foreach($p in (Invoke-AdModuleRead GroupPolicy Get-GPPermission @{Guid=$g.Id;All=$true;Domain=$Domain;Server=$Server} -TimeoutSeconds $Options.TimeoutSeconds)){
                $trustee=Get-AdField $p 'Trustee';Add-AdRows $Report 'GPOPermissions' @([pscustomobject]@{Domain=$Domain;GpoGuid=$guid;GpoName=$name;TrusteeName=Get-AdField $trustee 'Name';TrusteeSID=Convert-AdSid (Get-AdField $trustee 'Sid');TrusteeType=[string](Get-AdField $trustee 'SidType');Permission=[string](Get-AdField $p 'Permission');Inherited=Get-AdField $p 'Inherited';SourceFile=$source})
            }
        }catch{Add-AdExtensionError $Report 'GPOPermissions' ($Domain+' / '+$guid) $_.Exception.Message 'QueryError';$status='Partial'}
        $computer=Get-AdField $g 'Computer';$user=Get-AdField $g 'User';$done++
        [pscustomobject]@{Domain=$Domain;QueryServer=$Server;Guid=$guid;Name=$name;Status=[string](Get-AdField $g 'GpoStatus');CreatedUtc=Convert-AdDate (Get-AdField $g 'CreationTime');ModifiedUtc=Convert-AdDate (Get-AdField $g 'ModificationTime');Owner=Get-AdField $g 'Owner';WmiFilter=[string](Get-AdField $g 'WmiFilter');ComputerVersionAD=Get-AdField $computer 'DSVersion';ComputerVersionSysvol=Get-AdField $computer 'SysvolVersion';UserVersionAD=Get-AdField $user 'DSVersion';UserVersionSysvol=Get-AdField $user 'SysvolVersion';ComputerSettings=$computerCount;UserSettings=$userCount;LinkCount=@($Report.Datasets.GPOLinks|Where-Object{$_.GpoGuid -ieq $guid.Trim('{}')}).Count;Observation=$status;SourceFile=$source}
    }
    Add-AdRows $Report 'GPOCoverage' @([pscustomobject]@{Domain=$Domain;QueryServer=$Server;Discovered=$gpos.Count;Exported=$done;Truncated=$truncated;Limit=$Options.MaxGpos;SettingsExported=$settingsCount;SettingsTruncated=$settingsTruncated;SettingsLimit=$Options.MaxPolicySettings;Observation=if($truncated -or $settingsTruncated){'Truncated'}else{'Observed'}})
    if($truncated -or $settingsTruncated){Add-AdExtensionError $Report 'GroupPolicies' $Domain 'GPO/normalized setting limit reached; raw XML may contain additional settings for exported GPOs.' 'Truncated'}
}
function Get-AdDnsConfiguration {
    param($Report,$Options,[string]$Domain,[string]$DC,[string]$Folder)
    $role=@($Report.Datasets.Services|Where-Object{$_.DC -eq $DC -and $_.Name -eq 'DNS' -and $_.Observation -eq 'NotObserved'})
    if($role.Count -eq 1){[pscustomobject]@{Domain=$Domain;DC=$DC;Component='DNSRole';Property='Service';Value='NotObserved';Observation='NotApplicableNoDnsServiceObserved'};return}
    $config=Invoke-AdModuleRead DnsServer Get-DnsServer @{ComputerName=$DC} -TimeoutSeconds $Options.TimeoutSeconds
    $json=$config|ConvertTo-Json -Depth 16
    $null=Save-AdEvidence $Folder 'DNSConfiguration' $json 'json'
    foreach($name in @('ServerSetting','ServerForwarder','ServerRecursion','ServerScavenging','ServerCache','ServerDsSetting')){
        $component=Get-AdField $config $name
        if($null -eq $component){[pscustomobject]@{Domain=$Domain;DC=$DC;Component=$name;Property='';Value='';Observation='NotExposed'};continue}
        foreach($p in $component.PSObject.Properties|Where-Object{$_.Name -notmatch '^(Cim|PS|Runspace)'}){
            [pscustomobject]@{Domain=$Domain;DC=$DC;Component=$name;Property=$p.Name;Value=if($p.Value -is [array]){(@($p.Value|ForEach-Object{[string]$_}) -join '; ')}else{[string]$p.Value};Observation='Observed'}
        }
    }
    $hints=Get-AdField $config 'ServerRootHint'
    foreach($category in @('NameServer','IPAddress')){
        foreach($h in @(Get-AdField $hints $category)){
            if($null -eq $h){continue};$data=Get-AdField $h 'RecordData'
            Add-AdRows $Report 'DnsRootHints' @([pscustomobject]@{Domain=$Domain;DC=$DC;RecordType=Get-AdField $h 'RecordType';HostName=Get-AdField $h 'HostName';NameServer=Get-AdField $data 'NameServer';Address=(@((Get-AdField $data 'IPv4Address'),(Get-AdField $data 'IPv6Address'))|Where-Object{$_}) -join '; ';Observation='Observed'})
        }
    }
    foreach($z in @(Invoke-AdModuleRead DnsServer Get-DnsServerZone @{ComputerName=$DC} -TimeoutSeconds $Options.TimeoutSeconds)){
        $aging=$null;$obs='Observed'
        if([string](Get-AdField $z 'ZoneType') -eq 'Primary'){
            try{$aging=Invoke-AdModuleRead DnsServer Get-DnsServerZoneAging @{ComputerName=$DC;Name=$z.ZoneName} -TimeoutSeconds $Options.TimeoutSeconds}catch{$obs='AgingQueryError';Add-AdExtensionError $Report 'DnsZones' ($DC+' / '+$z.ZoneName) $_.Exception.Message 'QueryError'}
        }else{$obs='AgingNotApplicable'}
        Add-AdRows $Report 'DnsZones' @([pscustomobject]@{Domain=$Domain;DC=$DC;ZoneName=$z.ZoneName;ZoneType=[string](Get-AdField $z 'ZoneType');IsDsIntegrated=Get-AdField $z 'IsDsIntegrated';IsReverseLookupZone=Get-AdField $z 'IsReverseLookupZone';DynamicUpdate=[string](Get-AdField $z 'DynamicUpdate');ReplicationScope=[string](Get-AdField $z 'ReplicationScope');AgingEnabled=Get-AdField $aging 'AgingEnabled';NoRefreshInterval=[string](Get-AdField $aging 'NoRefreshInterval');RefreshInterval=[string](Get-AdField $aging 'RefreshInterval');Observation=$obs})
    }
}
function Get-AdSysvolInventory {
    param($Report,$Options,[string]$Domain,[string]$DC,[string]$RootOverride='')
    if($DC -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$' -or $Domain -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$'){throw 'Invalid SYSVOL host/domain.'}
    $root=if($RootOverride){$RootOverride}else{'\\'+$DC+'\SYSVOL\'+$Domain};$watch=[Diagnostics.Stopwatch]::StartNew();$stack=New-Object 'Collections.Generic.Stack[string]';$stack.Push($root)
    $files=0;$dirs=0;$bytes=0L;$truncated=$false;$errors=0;$byExtension=@{}
    while($stack.Count -gt 0){
        if($watch.Elapsed.TotalSeconds -ge $Options.SysvolTimeoutSeconds){$truncated=$true;break}
        $dir=$stack.Pop();$dirs++
        try{
            # Enumerate lazily; never recurse into a reparse point or execute a file.
            foreach($path in [IO.Directory]::EnumerateFileSystemEntries($dir)){
                if($watch.Elapsed.TotalSeconds -ge $Options.SysvolTimeoutSeconds){$truncated=$true;break}
                try{
                    $attr=[IO.File]::GetAttributes($path)
                    if(($attr -band [IO.FileAttributes]::ReparsePoint) -ne 0){$errors++;Add-AdExtensionError $Report 'SysvolFiles' $DC 'A reparse point was excluded from SYSVOL inventory.' 'ExcludedReparsePoint';continue}
                    if(($attr -band [IO.FileAttributes]::Directory) -ne 0){$stack.Push($path);continue}
                    if($files -ge $Options.MaxSysvolFiles){$truncated=$true;break}
                    $f=New-Object IO.FileInfo($path);$files++;$bytes+=$f.Length;$ext=$f.Extension.ToLowerInvariant();if(-not $ext){$ext='[no extension]'}
                    if(-not $byExtension.ContainsKey($ext)){$byExtension[$ext]=@{Files=0;Bytes=0L}};$byExtension[$ext].Files++;$byExtension[$ext].Bytes+=$f.Length
                    [pscustomobject]@{Domain=$Domain;DC=$DC;RelativePath=$f.FullName.Substring($root.Length).TrimStart('\');Extension=$ext;Bytes=$f.Length;ModifiedUtc=$f.LastWriteTimeUtc.ToString('o');Observation='ObservedMetadataOnly'}
                }catch{$errors++;Add-AdExtensionError $Report 'SysvolFiles' $DC $_.Exception.Message 'FileReadError'}
            }
        }catch{$errors++;Add-AdExtensionError $Report 'SysvolFiles' $DC $_.Exception.Message 'DirectoryReadError'}
        if($truncated){break}
    }
    foreach($ext in @($byExtension.Keys|Sort-Object)){
        Add-AdRows $Report 'SysvolSummary' @([pscustomobject]@{Domain=$Domain;DC=$DC;Root=$root;Files=$files;Directories=$dirs;Bytes=$bytes;Extension=$ext;ExtensionFiles=$byExtension[$ext].Files;ExtensionBytes=$byExtension[$ext].Bytes;Truncated=$truncated;Limit=$Options.MaxSysvolFiles;DurationSeconds=$watch.Elapsed.TotalSeconds;Observation=if($errors){'Partial'}elseif($truncated){'Truncated'}else{'ObservedMetadataOnly'}})
    }
    if($byExtension.Count -eq 0){Add-AdRows $Report 'SysvolSummary' @([pscustomobject]@{Domain=$Domain;DC=$DC;Root=$root;Files=0;Directories=$dirs;Bytes=0;Extension='';ExtensionFiles=0;ExtensionBytes=0;Truncated=$truncated;Limit=$Options.MaxSysvolFiles;DurationSeconds=$watch.Elapsed.TotalSeconds;Observation=if($errors){'Partial'}elseif($truncated){'Truncated'}else{'ObservedEmpty'}})}
    if($truncated){Add-AdExtensionError $Report 'SysvolFiles' $DC 'SYSVOL file/time limit reached. A blocking filesystem call may exceed the traversal budget.' 'Truncated'}
}
function Get-AdRegistryCatalog {
    $s='https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/'
    @(
        @{Id='LDAP-SIGNING';Title='LDAP server signing';Path='SYSTEM\CurrentControlSet\Services\NTDS\Parameters';Name='LDAPServerIntegrity';Expected=@(2);Reference='https://learn.microsoft.com/en-us/windows-server/identity/manage-ldap-signing-group-policy'},
        @{Id='LDAP-CBT';Title='LDAP channel binding';Path='SYSTEM\CurrentControlSet\Services\NTDS\Parameters';Name='LdapEnforceChannelBinding';Expected=@(2);Reference='https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/ldap-channel-binding'},
        @{Id='NO-LM-HASH';Title='Do not store LM password hash';Path='SYSTEM\CurrentControlSet\Control\Lsa';Name='NoLMHash';Expected=@(1);Reference=($s+'network-security-do-not-store-lan-manager-hash-value-on-next-password-change')},
        @{Id='NTLM-LEVEL';Title='LAN Manager authentication level';Path='SYSTEM\CurrentControlSet\Control\Lsa';Name='LmCompatibilityLevel';Expected=@(5);Reference=($s+'network-security-lan-manager-authentication-level')},
        @{Id='NO-BLANK-REMOTE';Title='Limit blank password use';Path='SYSTEM\CurrentControlSet\Control\Lsa';Name='LimitBlankPasswordUse';Expected=@(1);Reference=($s+'accounts-limit-local-account-use-of-blank-passwords-to-console-logon-only')},
        @{Id='RESTRICT-SAM';DcApplicable=$false;Title='Restrict anonymous SAM enumeration';Path='SYSTEM\CurrentControlSet\Control\Lsa';Name='RestrictAnonymousSAM';Expected=@(1);Reference=($s+'network-access-do-not-allow-anonymous-enumeration-of-sam-accounts')},
        @{Id='NULL-SESSIONS';Title='Restrict anonymous named pipes/shares';Path='SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters';Name='RestrictNullSessAccess';Expected=@(1);Reference=($s+'network-access-restrict-anonymous-access-to-named-pipes-and-shares')},
        @{Id='UAC';Title='Admin Approval Mode';Path='SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System';Name='EnableLUA';Expected=@(1);Reference=($s+'user-account-control-run-all-administrators-in-admin-approval-mode')},
        @{Id='AUDIT-SUBCATEGORY';Title='Force audit subcategory settings';Path='SYSTEM\CurrentControlSet\Control\Lsa';Name='SCENoApplyLegacyAuditPolicy';Expected=@(1);Reference=($s+'audit-force-audit-policy-subcategory-settings-to-override')},
        @{Id='PS-LOGGING';Title='PowerShell script block logging';Path='SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging';Name='EnableScriptBlockLogging';Expected=@(1);Reference='https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_logging_windows?view=powershell-5.1'},
        @{Id='NTLM-MIN-CLIENT';Title='NTLM client minimum session security';Path='SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0';Name='NTLMMinClientSec';Expected=@(537395200);Comparison='ContainsBits';Reference=($s+'network-security-minimum-session-security-for-ntlm-ssp-based-including-secure-rpc-clients')},
        @{Id='NTLM-MIN-SERVER';Title='NTLM server minimum session security';Path='SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0';Name='NTLMMinServerSec';Expected=@(537395200);Comparison='ContainsBits';Reference=($s+'network-security-minimum-session-security-for-ntlm-ssp-based-including-secure-rpc-servers')}
    )
}
function Invoke-AdRemoteSnapshot {
    param([string]$DC,$Options)
    if($DC -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$'){throw 'Invalid remote computer name.'}
    $catalog=ConvertTo-Json -InputObject @(Get-AdRegistryCatalog) -Depth 6 -Compress
    $read={
        param([string]$CatalogJson,[bool]$Hardware,[bool]$Security,[int]$MaxSoftware)
        $ErrorActionPreference='Stop'
        $result=[ordered]@{Hardware=@();Software=@();Hotfixes=@();Security=@();Registry=@();Logs=@();Errors=@();AuditText='';AuditExit=$null;SoftwareTruncated=$false}
        function SnapshotError([string]$Dataset,$ErrorObject){$result.Errors+=,[pscustomobject]@{Dataset=$Dataset;Message=[string]$ErrorObject}}
        if($Hardware){
            try{
                $cs=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop;$os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop;$bios=Get-CimInstance Win32_BIOS -ErrorAction Stop;$cpu=@(Get-CimInstance Win32_Processor -ErrorAction Stop)
                $ubr=$null;try{$ubr=(Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR -ErrorAction Stop).UBR}catch{}
                $result.Hardware=@([pscustomobject]@{Manufacturer=$cs.Manufacturer;Model=$cs.Model;LogicalProcessors=$cs.NumberOfLogicalProcessors;PhysicalCores=($cpu|Measure-Object NumberOfCores -Sum).Sum;Sockets=$cpu.Count;PhysicalMemoryBytes=$cs.TotalPhysicalMemory;OSBuild=$os.BuildNumber;UBR=$ubr;InstallDateUtc=if($os.InstallDate){([datetime]$os.InstallDate).ToUniversalTime().ToString('o')}else{''};BIOSVersion=(@($bios.SMBIOSBIOSVersion) -join '; ');BIOSReleaseUtc=if($bios.ReleaseDate){([datetime]$bios.ReleaseDate).ToUniversalTime().ToString('o')}else{''};Observation='Observed'})
            }catch{SnapshotError 'HostHardware' $_.Exception.Message}
            foreach($view in @('Registry64','Registry32')){
                $base=$null;$key=$null
                try{
                    $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryView]::$view)
                    $key=$base.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',$false)
                    if($null -eq $key){continue}
                    foreach($name in $key.GetSubKeyNames()){
                        $sub=$null
                        try{
                            $sub=$key.OpenSubKey($name,$false);if($null -eq $sub){continue};$display=$sub.GetValue('DisplayName',$null)
                            if(-not $display){continue};if($result.Software.Count -ge $MaxSoftware){$result.SoftwareTruncated=$true;break}
                            $result.Software+=,[pscustomobject]@{RegistryView=$view;ProductKey=$name;DisplayName=[string]$display;DisplayVersion=[string]$sub.GetValue('DisplayVersion','');Publisher=[string]$sub.GetValue('Publisher','');InstallDateRaw=[string]$sub.GetValue('InstallDate','');InstallLocation=[string]$sub.GetValue('InstallLocation','');Observation='UninstallRegistryEntry'}
                        }catch{SnapshotError 'InstalledSoftware' $_.Exception.Message}finally{if($null -ne $sub){$sub.Dispose()}}
                    }
                }catch{SnapshotError 'InstalledSoftware' $_.Exception.Message}finally{if($null -ne $key){$key.Dispose()};if($null -ne $base){$base.Dispose()}}
            }
            try{
                foreach($fix in @(Get-CimInstance Win32_QuickFixEngineering -ErrorAction Stop)){
                    $raw=[string]$fix.InstalledOn;$parsed=$null
                    # Dates remain raw unless provider returned an actual typed date.
                    if($fix.InstalledOn -is [datetime]){$parsed=$fix.InstalledOn.ToUniversalTime().ToString('o')}
                    $result.Hotfixes+=,[pscustomobject]@{HotfixId=$fix.HotFixID;Description=$fix.Description;InstalledOnRaw=$raw;InstalledUtc=$parsed;InstalledBy=$fix.InstalledBy;Observation='QFEOnlyNotPatchCompliance'}
                }
            }catch{SnapshotError 'Hotfixes' $_.Exception.Message}
        }
        if($Security){
            # Preserve machine/policy W32Time configuration without parsing localized console labels.
            foreach($entry in @(
                @('Machine','SYSTEM\CurrentControlSet\Services\W32Time\Parameters','Type'),
                @('Machine','SYSTEM\CurrentControlSet\Services\W32Time\Parameters','NtpServer'),
                @('Machine','SYSTEM\CurrentControlSet\Services\W32Time\Config','AnnounceFlags'),
                @('Machine','SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient','Enabled'),
                @('Machine','SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer','Enabled'),
                @('Policy','SOFTWARE\Policies\Microsoft\W32Time\Parameters','Type'),
                @('Policy','SOFTWARE\Policies\Microsoft\W32Time\Parameters','NtpServer'))){
                $key=$null;$value=$null;$status='NotExplicitlyConfigured'
                try{$key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($entry[1],$false);if($null -ne $key -and @($key.GetValueNames()) -contains $entry[2]){$value=$key.GetValue($entry[2],$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$status='Observed'}}catch{$status='QueryError';SnapshotError 'HostSecurity' $_.Exception.Message}finally{if($null -ne $key){$key.Dispose()}}
                $result.Security+=,[pscustomobject]@{Component=('W32Time-'+$entry[0]);Setting=($entry[1]+'\'+$entry[2]);Value=$value;Observation=$status;Source='ReadOnlyRegistryConfigurationNotSynchronizationProof'}
            }
            foreach($kind in @('Server','Client')){
                try{
                    $smb=if($kind -eq 'Server'){Get-SmbServerConfiguration -ErrorAction Stop}else{Get-SmbClientConfiguration -ErrorAction Stop}
                    foreach($setting in @('EnableSMB1Protocol','EnableSMB2Protocol','RequireSecuritySignature','EnableSecuritySignature','EncryptData','EnableInsecureGuestLogons','RejectUnencryptedAccess')){
                        $p=$smb.PSObject.Properties[$setting];if($null -ne $p){$result.Security+=,[pscustomobject]@{Component=('SMB'+$kind);Setting=$setting;Value=$p.Value;Observation='Observed';Source='SmbShare'}}
                    }
                }catch{SnapshotError 'HostSecurity' $_.Exception.Message}
            }
            try{
                $sp=@(Get-CimInstance Win32_Service -Filter "Name='Spooler'" -ErrorAction Stop)
                if($sp.Count -eq 0){$result.Security+=,[pscustomobject]@{Component='Spooler';Setting='Service';Value='';Observation='NotInstalled';Source='Win32_Service'}}
                else{foreach($name in @('State','StartMode')){$result.Security+=,[pscustomobject]@{Component='Spooler';Setting=$name;Value=$sp[0].$name;Observation='Observed';Source='Win32_Service'}}}
            }catch{SnapshotError 'HostSecurity' $_.Exception.Message}
            try{foreach($fw in @(Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop)){$result.Security+=,[pscustomobject]@{Component='Firewall';Setting=[string]$fw.Name;Value=[string]$fw.Enabled;Observation='Observed';Source='ActiveStore'}}}catch{SnapshotError 'HostSecurity' $_.Exception.Message}
            foreach($rule in @($CatalogJson|ConvertFrom-Json)){
                $key=$null;$value=$null;$kind='';$observation='NotConfigured';$errorText=''
                try{
                    $key=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey([string]$rule.Path,$false)
                    if($null -ne $key -and @($key.GetValueNames()) -contains [string]$rule.Name){$value=$key.GetValue($rule.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$kind=[string]$key.GetValueKind($rule.Name);$observation='Observed'}
                }catch{$observation='QueryError';$errorText=$_.Exception.Message;SnapshotError 'RegistryEvidence' $errorText}finally{if($null -ne $key){$key.Dispose()}}
                $result.Registry+=,[pscustomobject]@{RuleId=$rule.Id;RegistryPath=$rule.Path;ValueName=$rule.Name;ValueKind=$kind;Value=$value;Observation=$observation;Error=$errorText}
            }
            foreach($log in @('System','Security','Directory Service','DFS Replication','DNS Server')){
                try{$cfg=Get-WinEvent -ListLog $log -ErrorAction Stop;$result.Logs+=,[pscustomobject]@{LogName=$log;Enabled=$cfg.IsEnabled;MaximumBytes=$cfg.MaximumSizeInBytes;LogMode=[string]$cfg.LogMode;RecordCount=$cfg.RecordCount;OldestRecordNumber=$cfg.OldestRecordNumber;LastWriteUtc=if($cfg.LastWriteTime){$cfg.LastWriteTime.ToUniversalTime().ToString('o')}else{''};Observation='Observed'}}catch{if($log -ne 'DNS Server'){SnapshotError 'LogConfiguration' $_.Exception.Message}else{$result.Logs+=,[pscustomobject]@{LogName=$log;Enabled=$null;MaximumBytes=$null;LogMode='';RecordCount=$null;OldestRecordNumber=$null;LastWriteUtc='';Observation='NotPresentOrUnavailable'}}}
            }
            try{$result.AuditText=(& "$env:SystemRoot\System32\auditpol.exe" /get /category:* /r 2>&1|Out-String);$result.AuditExit=$LASTEXITCODE;if($LASTEXITCODE -ne 0){SnapshotError 'AuditPolicy' ('auditpol exit '+$LASTEXITCODE)}}catch{SnapshotError 'AuditPolicy' $_.Exception.Message}
        }
        [pscustomobject]$result
    }
    $session=New-PSSessionOption -OpenTimeout ([math]::Min(30000,$Options.TimeoutSeconds*1000)) -OperationTimeout ($Options.TimeoutSeconds*1000) -IdleTimeout ([math]::Max(60000,$Options.TimeoutSeconds*2000))
    $job=$null
    try{
        $job=Invoke-Command -ComputerName $DC -ScriptBlock $read -ArgumentList @($catalog,[bool]$Options.IncludeHostInventory,[bool]$Options.IncludeSecurityConfiguration,[int]$Options.MaxSoftwareEntries) -SessionOption $session -AsJob -ErrorAction Stop
        $done=Wait-Job -Job $job -Timeout $Options.TimeoutSeconds
        if($null -eq $done){throw 'Remote snapshot timeout.'}
        Receive-Job -Job $job -ErrorAction Stop
    }finally{if($null -ne $job){if($job.State -in @('Running','NotStarted','Blocked')){Stop-Job -Job $job -ErrorAction SilentlyContinue};Remove-Job -Job $job -Force -ErrorAction SilentlyContinue}}
}
function Get-AdSecurityProfile {
    param([string]$Path)
    $rules=@(Get-AdRegistryCatalog|ForEach-Object{[pscustomobject]$_})
    if(-not $Path){return [pscustomobject]@{Name='FMODEL selected Microsoft guidance review';Builds=@();Rules=$rules;SourceHash='';Reference='https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10'}}
    $p=Get-AdLocalInputFile $Path 1048576
    if($p.PSIsContainer -or $p.Length -gt 1MB -or ($p.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Baseline must be a local JSON file up to 1 MiB without a reparse point.'}
    $profile=[IO.File]::ReadAllText($p.FullName)|ConvertFrom-Json
    if($profile.SchemaVersion -ne 1 -or $profile.Role -ne 'DomainController' -or -not $profile.Name -or @($profile.ApplicableBuilds).Count -eq 0 -or @($profile.Rules).Count -eq 0 -or @($profile.Rules).Count -gt 100){throw 'Invalid baseline schema, role, build list or rules.'}
    $selected=New-Object 'Collections.Generic.List[object]';$ids=@{}
    foreach($r in $profile.Rules){
        $matches=@($rules|Where-Object{$_.Id -eq $r.RuleId});if($matches.Count -ne 1 -or $ids.ContainsKey([string]$r.RuleId)){throw 'Baseline RuleId must be unique and match the built-in read-only registry catalog.'}
        if($r.Comparison -notin @('EqualsAny','ContainsBits') -or @($r.Expected).Count -eq 0 -or @($r.Expected).Count -gt 16){throw 'Unsupported baseline comparison or expected values.'}
        foreach($value in $r.Expected){$n=0L;if(-not [long]::TryParse([string]$value,[ref]$n) -or $n -lt 0 -or $n -gt [uint32]::MaxValue){throw 'Baseline values must be DWORD integers.'}}
        $copy=[ordered]@{};foreach($prop in $matches[0].PSObject.Properties){$copy[$prop.Name]=$prop.Value};$copy.Expected=@($r.Expected);$copy.Comparison=$r.Comparison;$selected.Add([pscustomobject]$copy);$ids[[string]$r.RuleId]=$true
    }
    [pscustomobject]@{Name=[string]$profile.Name;Builds=@($profile.ApplicableBuilds|ForEach-Object{[int]$_});Rules=$selected.ToArray();SourceHash=(Get-FileHash -LiteralPath $p.FullName -Algorithm SHA256).Hash;Reference='CallerProvidedProfileNotMicrosoftCertification'}
}
function Add-AdSecurityReview {
    param($Report,[string]$Domain,[string]$DC,[string]$Build,$Profile)
    foreach($rule in $Profile.Rules){
        $obs=@($Report.Datasets.RegistryEvidence|Where-Object{$_.DC -eq $DC -and $_.RuleId -eq $rule.Id});$value=$null;$status='Unknown';$note='Selected registry value; defaults and effective policy require review.'
        $comparison=Get-AdField $rule 'Comparison';if(-not $comparison){$comparison='EqualsAny'}
        if($obs.Count -eq 1){
            $value=$obs[0].Value
            if($obs[0].Observation -eq 'NotConfigured'){$status='NotExplicitlyConfigured'}
            elseif($obs[0].Observation -eq 'Observed'){
                $parsed=0L
                if($obs[0].ValueKind -eq 'DWord' -and [long]::TryParse([string]$value,[ref]$parsed)){
                    if($parsed -lt 0){$parsed=[long]$parsed+4294967296L}
                    $match=$false;foreach($expected in $rule.Expected){if(($comparison -eq 'EqualsAny' -and $parsed -eq [long]$expected) -or ($comparison -eq 'ContainsBits' -and ($parsed -band [long]$expected) -eq [long]$expected)){$match=$true}}
                    $status=if($match){'MatchesSelectedValue'}else{'ReviewValueDifference'}
                }else{$status='UnknownTypeOrValue'}
            }
        }
        if((Get-AdField $rule 'DcApplicable') -eq $false){$status='NotApplicableToDomainControllers';$note='The linked policy has no effect on domain controllers; retained as configuration evidence.'}
        if($Profile.Builds.Count -gt 0){if(-not $Build){$status='UnknownOSBuild'}elseif([int]$Build -notin $Profile.Builds){$status='NotApplicableOSBuild'}}
        Add-AdRows $Report 'SecurityReview' @([pscustomobject]@{Domain=$Domain;DC=$DC;RuleId=$rule.Id;Title=$rule.Title;Profile=$Profile.Name;Expected=(@($rule.Expected) -join '; ');Observed=$value;Comparison=$comparison;Status=$status;OSBuild=$Build;Reference=$rule.Reference;Observation=($note+' ProfileSHA256='+$Profile.SourceHash)})
    }
    $checks=@(
        @('SMBServer','EnableSMB1Protocol','False','SMB1-SERVER','SMB1 server protocol','https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3'),
        @('SMBServer','RequireSecuritySignature','True','SMB-SERVER-SIGNING','SMB server signing','https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing'),
        @('SMBClient','RequireSecuritySignature','True','SMB-CLIENT-SIGNING','SMB client signing','https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing'),
        @('Spooler','State','Stopped','SPOOLER-STATE','Print Spooler state','https://learn.microsoft.com/en-us/defender-for-identity/security-posture-assessments/identity-infrastructure'),
        @('Spooler','StartMode','Disabled','SPOOLER-START','Print Spooler start mode','https://learn.microsoft.com/en-us/defender-for-identity/security-posture-assessments/identity-infrastructure'),
        @('Firewall','Domain','True','FIREWALL-DOMAIN','Domain firewall profile','https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/'),
        @('Firewall','Private','True','FIREWALL-PRIVATE','Private firewall profile','https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/'),
        @('Firewall','Public','True','FIREWALL-PUBLIC','Public firewall profile','https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/')
    )
    foreach($check in $checks){
        $obs=@($Report.Datasets.HostSecurity|Where-Object{$_.DC -eq $DC -and $_.Component -eq $check[0] -and $_.Setting -eq $check[1]});$value=$null;$status='Unknown'
        if($obs.Count -eq 1 -and $obs[0].Observation -eq 'Observed'){$value=[string]$obs[0].Value;$status=if($value -ieq $check[2]){'MatchesSelectedValue'}else{'ReviewValueDifference'}}
        Add-AdRows $Report 'SecurityReview' @([pscustomobject]@{Domain=$Domain;DC=$DC;RuleId=$check[3];Title=$check[4];Profile='FMODEL operational guidance review';Expected=$check[2];Observed=$value;Comparison='Equals';Status=$status;OSBuild=$Build;Reference=$check[5];Observation='Configuration observation; compatibility, role and approved exceptions require review.'})
    }
}
function Get-AdBackupEvidence {
    param($Report,$Options,[string]$Domain,[string]$DC,[string]$Folder)
    if($DC -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*$'){throw 'Invalid backup target.'}
    $n=Invoke-AdReadProcess (Get-AdBackupNativePath) ('/showbackup '+$DC) $Options.TimeoutSeconds
    $source=Save-AdEvidence $Folder 'ADBackup' $n.Text
    if($n.TimedOut -or $n.ExitCode -ne 0){Add-AdExtensionError $Report 'BackupEvidence' $DC ('repadmin failed/timed out; '+$source) 'NativeError'}
    [pscustomobject]@{Domain=$Domain;DC=$DC;Source='RepadminShowBackup';Status=if($n.TimedOut){'Timeout'}elseif($n.ExitCode -ne 0){'CommandError'}else{'EvidenceReviewRequired'};ExitCode=$n.ExitCode;TimedOut=$n.TimedOut;Partition='See raw naming-context evidence';LastBackupUtc='';AgeDays=$null;Observation='Native timestamps/partitions are preserved, not guessed from language-dependent output. This is not restoration or backup completeness proof.';RawText=$n.Text;SourceFile=$source}
    # Event ID 4 is a supporting Windows Backup observation, not proof of AD System State coverage.
    try{
        $events=@(Invoke-AdBackupEventQuery $DC ([datetime]::UtcNow.AddDays(-[math]::Max(30,$Options.BackupWarningDays*2))) 17)
        if($events.Count -gt 16){Add-AdExtensionError $Report 'BackupEvidence' $DC 'Windows Backup event evidence capped at 16 recent entries.' 'Truncated'}
        foreach($e in @($events|Select-Object -First 16)){
            $message='';try{$message=[string]$e.Message}catch{}
            [pscustomobject]@{Domain=$Domain;DC=$DC;Source='WindowsBackupOperationalEvent4';Status='SupportingEvidence';ExitCode=$null;TimedOut=$false;Partition='NotEstablishedByEvent';LastBackupUtc=Convert-AdDate $e.TimeCreated;AgeDays=if($e.TimeCreated){([datetime]::UtcNow-([datetime]$e.TimeCreated).ToUniversalTime()).TotalDays}else{$null};Observation='Backup completion event; verify included components, result and restore test with the backup solution.';RawText=$message;SourceFile=''}
        }
    }catch{
        if($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*' -and $_.FullyQualifiedErrorId -notlike 'NoMatchingLogsFound*' -and $_.FullyQualifiedErrorId -notlike 'NoMatchingProvidersFound*'){Add-AdExtensionError $Report 'BackupEvidence' $DC $_.Exception.Message 'EventQueryError'}
        [pscustomobject]@{Domain=$Domain;DC=$DC;Source='WindowsBackupOperationalEvent4';Status=if($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*'){'NoEventsInWindow'}elseif($_.FullyQualifiedErrorId -like 'NoMatchingLogsFound*' -or $_.FullyQualifiedErrorId -like 'NoMatchingProvidersFound*'){'NotPresent'}else{'QueryError'};ExitCode=$null;TimedOut=$false;Partition='';LastBackupUtc='';AgeDays=$null;Observation='No complete backup conclusion can be drawn from this event query.';RawText=$_.Exception.Message;SourceFile=''}
    }
}
function Get-AdBackupNativePath { Join-Path ([Environment]::SystemDirectory) 'repadmin.exe' }
function Invoke-AdBackupEventQuery {
    param([string]$DC,[datetime]$Start,[int]$Maximum)
    $provider=Get-WinEvent -ListProvider 'Microsoft-Windows-Backup' -ComputerName $DC -ErrorAction Stop
    $logs=@($provider.LogLinks|ForEach-Object{$_.LogName}|Where-Object{$_}|Sort-Object -Unique)
    if($logs.Count -eq 0){throw 'Windows Backup provider did not expose a log channel.'}
    Get-WinEvent -ComputerName $DC -FilterHashtable @{LogName=$logs;ProviderName='Microsoft-Windows-Backup';Id=4;StartTime=$Start} -MaxEvents $Maximum -ErrorAction Stop
}
function Invoke-AdSecurityEventQuery {
    param([string]$DC,[datetime]$Start,[datetime]$End,[int]$Maximum)
    $from=$Start.ToUniversalTime().ToString('o');$to=$End.ToUniversalTime().ToString('o')
    $ids='EventID=1102 or EventID=4618 or EventID=4649 or EventID=4719 or EventID=4765 or EventID=4766 or EventID=4794 or EventID=4897 or EventID=4964 or EventID=5124'
    $xml="<QueryList><Query Id='0' Path='Security'><Select Path='Security'>*[System[($ids) and TimeCreated[@SystemTime&gt;='$from' and @SystemTime&lt;='$to']]]</Select><Select Path='Security'>*[System[EventID=4624 and TimeCreated[@SystemTime&gt;='$from' and @SystemTime&lt;='$to']]] and *[EventData[Data[@Name='LogonType']='4' or Data[@Name='LogonType']='8']]</Select></Query></QueryList>"
    Get-WinEvent -ComputerName $DC -FilterXml $xml -MaxEvents $Maximum -ErrorAction Stop
}
function Get-AdSecurityEvents {
    param($Report,$Options,[string]$Domain,[string]$DC)
    $end=[datetime]::UtcNow;$start=$end.AddHours(-$Options.EventHours);$events=@();$status='Collected';$errorText=''
    try{$events=@(Invoke-AdSecurityEventQuery $DC $start $end ($Options.MaxEventsPerLog+1))}catch{if($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*'){$status='QueryError';$errorText=$_.Exception.Message;Add-AdExtensionError $Report 'SecurityEvents' $DC $errorText 'QueryError'}}
    $truncated=$events.Count -gt $Options.MaxEventsPerLog
    foreach($e in @($events|Select-Object -First $Options.MaxEventsPerLog)){
        $message='';$messageStatus='Formatted';try{$message=[string]$e.Message}catch{$messageStatus='Unavailable'}
        $eventData=[ordered]@{};$interpretation='Selected event for review; not a confirmed incident.'
        try{
            $doc=Convert-AdSafeXml $e.ToXml() $Options.MaxXmlCharacters
            $index=0;foreach($d in $doc.SelectNodes("/*[local-name()='Event']/*[local-name()='EventData']/*[local-name()='Data']")){$index++;$name=$d.GetAttribute('Name');if(-not $name){$name='Data'+$index};if($eventData.Contains($name)){$name+='_'+$index};$eventData[$name]=$d.InnerText}
            if($e.Id -eq 4624){$interpretation=if($eventData['LogonType'] -eq '8'){'NetworkCleartext logon type; does not itself prove cleartext credentials traversed the network.'}elseif($eventData['LogonType'] -eq '4'){'Batch logon; may be expected for scheduled work.'}else{'Other logon type; review event XML.'}}
        }catch{$messageStatus+=';EventXmlUnavailable';Add-AdExtensionError $Report 'SecurityEvents' $DC $_.Exception.Message 'EventXmlError'}
        [pscustomobject]@{Domain=$Domain;DC=$DC;LogName='Security';TimeCreatedUtc=Convert-AdDate $e.TimeCreated;EventId=$e.Id;Level=$e.Level;Provider=$e.ProviderName;RecordId=$e.RecordId;Message=$message;MessageStatus=$messageStatus;EventDataJson=ConvertTo-Json -InputObject $eventData -Depth 5 -Compress;Interpretation=$interpretation}
    }
    Add-AdRows $Report 'EventLogCoverage' @([pscustomobject]@{Domain=$Domain;DC=$DC;LogName='Security';StartUtc=$start.ToString('o');EndUtc=$end.ToString('o');Status=$status;Exported=[math]::Min($events.Count,$Options.MaxEventsPerLog);Truncated=$truncated;Limit=$Options.MaxEventsPerLog;Error=$errorText})
}
function Get-AdRsopInventory {
    param($Report,$Options,[string]$Domain,[string]$DC,[string]$Folder)
    $dir=Join-Path $Folder 'native';$null=New-Item -ItemType Directory -Path $dir -Force
    $name='RSoP-'+[guid]::NewGuid().ToString('N')+'.xml';$file=Join-Path $dir $name
    $null=Invoke-AdModuleRead GroupPolicy Get-GPResultantSetOfPolicy @{Computer=$DC;ReportType='Xml';Path=$file} -TimeoutSeconds $Options.TimeoutSeconds
    if(-not (Test-Path -LiteralPath $file)){throw 'RSoP command did not create its requested evidence file.'}
    $info=Get-Item -LiteralPath $file;if($info.Length -gt $Options.MaxXmlCharacters*4){throw 'RSoP file exceeds configured XML limit.'}
    $doc=Convert-AdSafeXml ([IO.File]::ReadAllText($file)) $Options.MaxXmlCharacters
    $flat=Get-AdXmlLeaves $doc.DocumentElement $Options.MaxPolicySettings
    foreach($p in $flat.Rows){[pscustomobject]@{Domain=$Domain;DC=$DC;Area=if($p.SettingPath -match '/ComputerResults\['){'Computer'}elseif($p.SettingPath -match '/UserResults\['){'User'}else{'Metadata'};SettingPath=$p.SettingPath;Value=$p.Value;Attributes=$p.Attributes;SourceFile=('native/'+$name)}}
    if($flat.Truncated){Add-AdExtensionError $Report 'RSoPSettings' $DC 'Normalized RSoP limit reached; raw XML retained.' 'Truncated'}
    foreach($r in $doc.SelectNodes("//*[local-name()='UserRightsAssignment']")){
        $right=Get-AdXmlText $r "./*[local-name()='Name']";$source=Get-AdXmlText $r "./*[local-name()='GPO']/*[local-name()='Name']"
        $members=@($r.SelectNodes("./*[local-name()='Member']"))
        if($members.Count -eq 0){Add-AdRows $Report 'UserRightsAssignments' @([pscustomobject]@{Domain=$Domain;DC=$DC;Right=$right;PrincipalSID='';PrincipalName='';SourceGpo=$source;Observation='NoMembersExposed';SourceFile=('native/'+$name)})}
        foreach($m in $members){Add-AdRows $Report 'UserRightsAssignments' @([pscustomobject]@{Domain=$Domain;DC=$DC;Right=$right;PrincipalSID=Get-AdXmlText $m "./*[local-name()='SID']";PrincipalName=Get-AdXmlText $m "./*[local-name()='Name']";SourceGpo=$source;Observation='RsopEvidenceNotEffectivePrivilegeAnalysis';SourceFile=('native/'+$name)})}
    }
}
function Add-AdSnapshotRows {
    param($Report,[string]$Dataset,[object[]]$Rows,[string]$Domain,[string]$DC)
    $fields=@((Get-AdSchemas)[$Dataset] -split ','|Where-Object{$_ -notin @('Domain','DC')})
    foreach($row in $Rows){if($null -eq $row){continue};$copy=[ordered]@{Domain=$Domain;DC=$DC};foreach($name in $fields){$copy[$name]=Get-AdField $row $name};Add-AdRows $Report $Dataset @([pscustomobject]$copy)}
}
function Invoke-AdExtendedDc {
    param($Report,$Options,[string]$Domain,[string]$DC,[string]$Folder)
    Invoke-AdCollection $Report 'SysvolFiles' $DC {Get-AdSysvolInventory $Report $Options $Domain $DC} -Skip:(-not $Options.IncludeSysvolInventory)
    Invoke-AdCollection $Report 'DnsServerConfiguration' $DC {Get-AdDnsConfiguration $Report $Options $Domain $DC $Folder} -Skip:(-not $Options.IncludeDnsConfiguration)
    Invoke-AdCollection $Report 'BackupEvidence' $DC {Get-AdBackupEvidence $Report $Options $Domain $DC $Folder} -Skip:(-not $Options.IncludeBackupEvidence)
    Invoke-AdCollection $Report 'RSoPSettings' $DC {Get-AdRsopInventory $Report $Options $Domain $DC $Folder} -Skip:(-not $Options.IncludeRsop)
    Invoke-AdCollection $Report 'SecurityEvents' $DC {Get-AdSecurityEvents $Report $Options $Domain $DC} -Skip:(-not $Options.IncludeSecurityEvents)
    if($Options.IncludeHostInventory -or $Options.IncludeSecurityConfiguration){
        $snapshot=$null;$timer=[Diagnostics.Stopwatch]::StartNew()
        try{$snapshot=Invoke-AdRemoteSnapshot $DC $Options;if($null -eq $snapshot){throw 'Remote snapshot returned no result.'}}
        catch{foreach($key in @('HostHardware','InstalledSoftware','Hotfixes','HostSecurity','RegistryEvidence','LogConfiguration','AuditPolicy')){if(($Options.IncludeHostInventory -and $key -in @('HostHardware','InstalledSoftware','Hotfixes')) -or ($Options.IncludeSecurityConfiguration -and $key -notin @('HostHardware','InstalledSoftware','Hotfixes'))){Add-AdExtensionError $Report $key $DC $_.Exception.Message 'RemoteSnapshotError'}}}
        Add-AdRows $Report 'Timings' @([pscustomobject]@{Dataset='RemoteSnapshot';Scope=$DC;Status=if($null -eq $snapshot){'Failed'}else{'Returned'};Rows=1;DurationSeconds=$timer.Elapsed.TotalSeconds})
        foreach($spec in @(@('HostHardware','Hardware'),@('InstalledSoftware','Software'),@('Hotfixes','Hotfixes'),@('HostSecurity','Security'),@('RegistryEvidence','Registry'),@('LogConfiguration','Logs'))){
            $key=$spec[0];$property=$spec[1];$requested=if($key -in @('HostHardware','InstalledSoftware','Hotfixes')){$Options.IncludeHostInventory}else{$Options.IncludeSecurityConfiguration}
            Invoke-AdCollection $Report $key $DC {
                if($null -eq $snapshot){throw 'Remote snapshot unavailable; see errors.'}
                Add-AdSnapshotRows $Report $key @(Get-AdField $snapshot $property) $Domain $DC
                foreach($e in @((Get-AdField $snapshot 'Errors')|Where-Object{$_.Dataset -eq $key})){Add-AdExtensionError $Report $key $DC $e.Message 'RemoteQueryError'}
            } -Skip:(-not $requested)
        }
        if($null -ne $snapshot -and (Get-AdField $snapshot 'SoftwareTruncated')){Add-AdExtensionError $Report 'InstalledSoftware' $DC 'Software entry cap reached; inventory is partial.' 'Truncated'}
        Invoke-AdCollection $Report 'AuditPolicy' $DC {
            if($null -eq $snapshot){throw 'Remote snapshot unavailable.'}
            $text=[string](Get-AdField $snapshot 'AuditText');$source=Save-AdEvidence $Folder 'AuditPolicy' $text
            if((Get-AdField $snapshot 'AuditExit') -ne 0){throw 'Audit policy query failed; raw evidence retained.'}
            $rows=@($text|ConvertFrom-Csv);$parsed=0
            foreach($row in $rows){$guid=@($row.PSObject.Properties|Where-Object{[string]$_.Value -match '^\{[0-9a-fA-F-]{36}\}$'});if($guid.Count -eq 1){$parsed++;[pscustomobject]@{Domain=$Domain;DC=$DC;SubcategoryGuid=$guid[0].Value;Value=ConvertTo-Json -InputObject $row -Depth 4 -Compress;SourceFile=$source;Observation='LocalizedFieldsPreservedNoEnglishPassParser'}}}
            if($parsed -eq 0){throw 'No audit subcategory GUIDs recognized; raw evidence retained, not treated as empty success.'}
        } -Skip:(-not $Options.IncludeSecurityConfiguration)
        if($Options.IncludeSecurityConfiguration){
            $build='';$hw=@($Report.Datasets.HostHardware|Where-Object{$_.DC -eq $DC});if($hw.Count){$build=[string]$hw[0].OSBuild}else{$metric=@($Report.Datasets.HostMetrics|Where-Object{$_.DC -eq $DC});if($metric.Count){$build=[string]$metric[0].Build}}
            Invoke-AdCollection $Report 'SecurityReview' $DC {Add-AdSecurityReview $Report $Domain $DC $build (Get-AdSecurityProfile $Options.BaselineFile)}
        }
    }else{foreach($key in @('HostHardware','InstalledSoftware','Hotfixes','HostSecurity','RegistryEvidence','SecurityReview','LogConfiguration','AuditPolicy')){Invoke-AdCollection $Report $key $DC {} -Skip}}
}
function Complete-AdExtensionFindings {
    param($Report)
    $o=$Report.Parameters
    if($o.IncludeRsop){
        foreach($dc in $Report.Datasets.DomainControllers){
            $domain=@($Report.Datasets.Domains|Where-Object{$_.Domain -eq $dc.Domain});if($domain.Count -ne 1){continue};$adminSid=[string]$domain[0].DomainSid+'-500'
            foreach($right in @('SeDenyNetworkLogonRight','SeDenyBatchLogonRight','SeDenyServiceLogonRight','SeDenyRemoteInteractiveLogonRight')){
                $evidence=@($Report.Datasets.UserRightsAssignments|Where-Object{$_.DC -eq $dc.HostName -and $_.Right -eq $right});$sids=@($evidence|ForEach-Object{$_.PrincipalSID}|Where-Object{$_});$status=if($evidence.Count -eq 0){'NotExposedInRSoP'}else{'EvidenceOnlyNotDcRecommendation'}
                Add-AdRows $Report 'SecurityReview' @([pscustomobject]@{Domain=$dc.Domain;DC=$dc.HostName;RuleId=('ADMIN500-'+$right);Title='Built-in Administrator deny-right evidence';Profile='Role-specific evidence, not a DC deny-right baseline';Expected='No DC deny-right recommendation inferred';Observed=($sids -join '; ');Comparison='EvidenceOnly';Status=$status;OSBuild='';Reference='https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-d--securing-built-in-administrator-accounts-in-active-directory';Observation=('The cited deny-right guidance targets member servers/workstations. Direct SID '+$adminSid+' present='+[string]($adminSid -in $sids)+'. No DC compliance or effective access verdict inferred.')})
            }
        }
    }
    $incomplete=$o.SkipUserInventory -or @($Report.Datasets.DirectoryCoverage|Where-Object{$_.Truncated}).Count -gt 0 -or @($Report.Datasets.CollectionErrors|Where-Object{$_.Dataset -in @('AccountSecurityFlags','DomainBootstrap')}).Count -gt 0
    foreach($spec in @(@('SPNInventory','NormalizedSPN','DuplicateSPNs'),@('AccountSecurityFlags','UserPrincipalName','DuplicateUPNs'))){
        $dataset=$spec[0];$property=$spec[1]
        foreach($g in @($Report.Datasets[$dataset]|Where-Object{Get-AdField $_ $property}|Group-Object -Property $property)){
            $owners=if($dataset -eq 'SPNInventory'){@($g.Group|Sort-Object OwnerDN -Unique)}else{@($g.Group|Sort-Object DistinguishedName -Unique)}
            if($owners.Count -lt 2){continue}
            $names=if($dataset -eq 'SPNInventory'){@($owners.OwnerName)}else{@($owners.Name)};$guids=if($dataset -eq 'SPNInventory'){@($owners.OwnerGuid)}else{@($owners.ObjectGuid)};$dns=if($dataset -eq 'SPNInventory'){@($owners.OwnerDN)}else{@($owners.DistinguishedName)}
            $row=[ordered]@{};$row[ $(if($dataset -eq 'SPNInventory'){'SPN'}else{'UserPrincipalName'}) ]=$g.Name;$row.OwnerCount=$owners.Count;$row.Domains=(@($owners.Domain|Sort-Object -Unique) -join '; ');$row.OwnerNames=($names -join '; ');$row.OwnerGuids=($guids -join '; ');$row.OwnerDNs=($dns -join '; ');$row.AssessmentScope=$o.Scope;$row.Coverage=if($incomplete){'PartialSelectedScope'}else{'SelectedScopeOnly'}
            Add-AdRows $Report $spec[2] @([pscustomobject]$row)
            New-AdFinding $Report High 'DIRECTORY-DUPLICATE-IDENTIFIER' $spec[2] $row.Domains $g.Name ('Distinct owners='+$owners.Count) 'Review identity ownership and replication before changing registrations. Only exported scope was compared.'
        }
    }
    foreach($r in $Report.Datasets.AccountSecurityFlags){foreach($flag in @('ReversibleEncryptionAllowed','UseDESKeyOnly')){if((Get-AdField $r $flag) -eq $true){New-AdFinding $Report High ('ACCOUNT-'+$flag.ToUpperInvariant()) AccountSecurityFlags $r.Domain $r.DistinguishedName ($flag+'=True') 'Review application requirements and authentication evidence. A configured flag does not prove actual password storage or protocol use.'}}}
    foreach($r in $Report.Datasets.OptionalFeatures){if($r.Enabled -eq $false){New-AdFinding $Report Medium 'AD-RECYCLE-BIN-DISABLED' OptionalFeatures $r.Forest $r.Feature 'EnabledScopes is empty.' 'Review recovery strategy and feature prerequisites. No feature was enabled.'}}
    foreach($r in $Report.Datasets.SecurityReview){if($r.Status -eq 'ReviewValueDifference'){New-AdFinding $Report Medium 'DC-SECURITY-REVIEW' SecurityReview $r.Domain $r.DC ($r.RuleId+': observed='+$r.Observed+' expected='+$r.Expected) 'Review the linked guidance, OS defaults, role, compatibility and approved exceptions. This is not full baseline compliance.'}}
    foreach($r in $Report.Datasets.GroupPolicies){
        if($r.Observation -ne 'Observed'){continue}
        if($r.LinkCount -eq 0){New-AdFinding $Report Info 'GPO-NO-OBSERVED-LINK' GroupPolicies $r.Domain $r.Name 'No link was found within the queried domain and forest site scope.' 'Review intended use, permissions and cross-domain links. No GPO was deleted.'}
        if($r.ComputerSettings -eq 0 -and $r.UserSettings -eq 0){New-AdFinding $Report Info 'GPO-NO-EXTENSION-DATA' GroupPolicies $r.Domain $r.Name 'No user/computer extension data exposed in XML.' 'Review the raw report and metadata; this is not an instruction to delete the GPO.'}
        if(($null -ne $r.ComputerVersionAD -and $null -ne $r.ComputerVersionSysvol -and $r.ComputerVersionAD -ne $r.ComputerVersionSysvol) -or ($null -ne $r.UserVersionAD -and $null -ne $r.UserVersionSysvol -and $r.UserVersionAD -ne $r.UserVersionSysvol)){New-AdFinding $Report Medium 'GPO-VERSION-DIFFERENCE' GroupPolicies $r.Domain $r.Name 'Directory/SYSVOL version difference at queried DC.' 'Review replication and raw XML. Snapshot timing can affect this observation.'}
    }
    foreach($r in $Report.Datasets.BackupEvidence){if($r.Source -eq 'WindowsBackupOperationalEvent4' -and $null -ne $r.AgeDays -and $r.AgeDays -gt $o.BackupWarningDays){New-AdFinding $Report Info 'BACKUP-EVENT-AGE' BackupEvidence $r.Domain $r.DC ('Supporting event age days='+$r.AgeDays) 'Check current backup jobs, component coverage and restore testing. Event age is not proof that backups stopped.'}}
    # Every normalized dataset gets coverage, including derived and bundle-fed sets.
    foreach($key in (Get-AdExtensionSchemas).Keys){
        if(@($Report.Datasets.Coverage|Where-Object{$_.Dataset -eq $key}).Count -eq 0){
            $rows=$Report.Datasets[$key].Count
            $requested=$o.ComprehensiveAssessment -or $rows -gt 0
            Add-AdRows $Report 'Coverage' @([pscustomobject]@{Dataset=$key;Scope='DerivedOrBundle';Status=if($requested){'DerivedSeeParentCoverage'}else{'NotRequestedOrNoParentRows'};Rows=$rows;StartedUtc=$Report.StartedUtc;EndedUtc=[datetime]::UtcNow.ToString('o');DurationSeconds=0})
        }
    }
}
function Get-AdAssessmentSources {
    $refs=@(
        @('W32TIME','Windows Time configuration','https://learn.microsoft.com/en-us/windows-server/networking/windows-time-service/windows-time-service-tools-and-settings','Preserve raw W32Time evidence and machine/policy registry values','Configuration and measured offset do not certify UTC accuracy'),
        @('ADMIN500','Role-specific built-in Administrator guidance','https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-d--securing-built-in-administrator-accounts-in-active-directory','Inventory rights by SID without a DC deny-right verdict','The cited deny-right recommendations target workstations/member servers'),
        @('GPO-PERMISSIONS','Group Policy permissions','https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gppermission?view=windowsserver2025-ps','Read trustee permissions per GPO','Does not establish effective privilege across nested groups'),
        @('AD-FEATURES','AD optional features','https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adoptionalfeature?view=windowsserver2025-ps','Feature GUID and EnabledScopes','Read-only observation; no activation'),
        @('AD-SPN','SPN and UPN uniqueness','https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/spn-and-upn-uniqueness','Compare distinct object owners within exported scope','Not proof of forest-wide uniqueness with incomplete/domain-only collection'),
        @('AD-UAC','Account flags','https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/useraccountcontrol-manipulate-account-properties','Decode documented UAC bits','Flags are configuration, not actual authentication/password contents'),
        @('GPO','Group Policy XML report','https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gporeport?view=windowsserver2025-ps','Explicit Domain/Server/Guid; preserve XML','No claim of effective policy or conflict resolution'),
        @('RSOP','Resultant Set of Policy','https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gpresultantsetofpolicy?view=windowsserver2025-ps','Computer-specific XML evidence','Requires target permissions; not effective privileges analysis'),
        @('DNS-CONFIG','DNS server configuration','https://learn.microsoft.com/en-us/powershell/module/dnsserver/get-dnsserver?view=windowsserver2025-ps','Inventory configuration without changing DNS','Recursion/forwarder/scavenging choices are architecture dependent'),
        @('DNS-RECURSION','DNS recursion and forwarders','https://learn.microsoft.com/en-us/windows-server/networking/dns/quickstart-install-configure-dns-server','Interpret configuration with server role','Disabling recursion also disables forwarders'),
        @('BACKUP','AD partition backup evidence','https://learn.microsoft.com/en-us/services-hub/microsoft-engage-center/health/remediation-steps-ad/investigate-why-active-directory-directory-partitions-are-not-backed-up-for-longer-than-half-the-tom','Read repadmin /showbackup output','No restoration test, RPO or component-coverage proof'),
        @('HOTFIX','QFE inventory limits','https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-hotfix?view=powershell-5.1','Inventory QFE/KB evidence','Does not enumerate all update types or prove patch compliance'),
        @('SECURITY-GUIDANCE','Microsoft Security Compliance Toolkit','https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10','Guide baseline selection and value comparison','Built-in selected guidance review is not a complete SCT baseline'),
        @('SMB','SMB signing','https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing','Observe effective client/server signing requirement','Compatibility and approved exceptions require review'),
        @('SPOOLER','Identity infrastructure security','https://learn.microsoft.com/en-us/defender-for-identity/security-posture-assessments/identity-infrastructure','Separate Spooler security review','Stopped/Disabled is distinct from core AD services expected Running'),
        @('LDAP','LDAP signing','https://learn.microsoft.com/en-us/windows-server/identity/manage-ldap-signing-group-policy','Selected LDAPServerIntegrity comparison','Absent registry value does not establish effective default'),
        @('LDAP-CBT','LDAP channel binding','https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/ldap-channel-binding','Preserve channel binding configuration','No bind test or client compatibility certification'),
        @('AUDIT','Audit policy query','https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/auditpol-get','Read CSV by subcategory GUID','Retain localized settings; no English pass/fail parser'),
        @('EVENT-4624','Successful logon event fields','https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4624','Use EventData LogonType rather than message text','Type 8 alone does not establish cleartext transmission'),
        @('FUNCTIONAL-LEVELS','AD DS functional levels','https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-functional-levels','Separate OS/build from DFL/FFL','2019/2022 OS does not imply 2019/2022 functional levels')
    )
    foreach($r in $refs){[pscustomobject]@{Id=$r[0];Topic=$r[1];Reference=$r[2];AccessedDate='2026-11-13';Usage=$r[3];Limitations=$r[4]}}
}
function Write-AdAssessmentFiles {
    param($Report,[string]$Folder)
    $schemas=Get-AdSchemas
    foreach($name in $schemas.Keys){Write-AdCsv (Join-Path $Folder ($name.ToLowerInvariant()+'.csv')) ($schemas[$name] -split ',') @($Report.Datasets[$name].ToArray())}
    [IO.File]::WriteAllText((Join-Path $Folder 'report.json'),($Report|ConvertTo-Json -Depth 16),(New-Object Text.UTF8Encoding($false)))
    Write-AdHtmlReport (Join-Path $Folder 'Report.html') $Report
    $hashes=Get-ChildItem -LiteralPath $Folder -File -Recurse|Where-Object{$_.Name -ne 'run-manifest.json'}|ForEach-Object{[pscustomobject]@{Path=$_.FullName.Substring($Folder.Length+1).Replace('\','/');SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant();Bytes=$_.Length}}
    [IO.File]::WriteAllText((Join-Path $Folder 'run-manifest.json'),(@($hashes)|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
}
function Get-AdLocalInputFile {
    param([string]$Path,[long]$MaximumBytes=104857600)
    $full=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if($full.StartsWith('\\') -or $full -match '[\x00-\x1f]'){throw 'Input must be a local regular file.'}
    $item=Get-Item -LiteralPath $full -ErrorAction Stop
    if($item -isnot [IO.FileInfo] -or $item.Length -gt $MaximumBytes){throw 'Input is not a file or exceeds its size limit.'}
    $part=$item
    while($null -ne $part){if(($part.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Reparse points are not allowed for imported evidence.'};$part=if($part -is [IO.DirectoryInfo]){$part.Parent}else{$part.Directory}}
    $item
}
function Invoke-AdRenderSnapshot {
    param([string]$InputFile,[string]$OutputPath,[int]$MaxHtmlRows,$Caller)
    $input=Get-AdLocalInputFile $InputFile
    $loaded=[IO.File]::ReadAllText($input.FullName)|ConvertFrom-Json
    if($loaded.SchemaVersion -ne 1 -or $null -eq $loaded.Datasets -or $null -eq $loaded.Parameters){throw 'Unsupported report schema.'}
    $schemas=Get-AdSchemas;$sets=[ordered]@{}
    foreach($p in $loaded.Datasets.PSObject.Properties){if($p.Name -notin @($schemas.Keys)){throw ('Unknown imported dataset: '+$p.Name)}}
    foreach($name in $schemas.Keys){$sets[$name]=New-Object 'Collections.Generic.List[object]';foreach($row in @(Get-AdField $loaded.Datasets $name)){if($null -ne $row){$sets[$name].Add($row)}}}
    $base=Resolve-AdOutputPath $OutputPath
    if(-not $Caller.ShouldProcess($input.FullName,'Render existing JSON and verified local evidence to HTML/CSV without directory queries')){return [pscustomobject]@{Status='NotRendered';ExitCode=0;RunFolder=$null;Findings=0;CollectionErrors=0}}
    $folder=Join-Path $base ('Rendered-{0}-{1}' -f [datetime]::UtcNow.ToString('yyyyMMdd-HHmmss'),[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $folder -Force
    $loaded.Datasets=$sets;$loaded.Parameters|Add-Member -NotePropertyName MaxHtmlRows -NotePropertyValue $MaxHtmlRows -Force
    $loaded|Add-Member -NotePropertyName RendererVersion -NotePropertyValue '1.2.0' -Force
    $loaded|Add-Member -NotePropertyName RenderedUtc -NotePropertyValue ([datetime]::UtcNow.ToString('o')) -Force
    $loaded|Add-Member -NotePropertyName ImportedReportSHA256 -NotePropertyValue ((Get-FileHash -LiteralPath $input.FullName -Algorithm SHA256).Hash) -Force
    $copied=0;$manifest=Join-Path $input.DirectoryName 'run-manifest.json'
    if(Test-Path -LiteralPath $manifest){
        $m=Get-AdLocalInputFile $manifest 10485760;$entries=@([IO.File]::ReadAllText($m.FullName)|ConvertFrom-Json);$used=0L
        foreach($entry in $entries){
            if([string]$entry.Path -notmatch '^native/[A-Za-z0-9][A-Za-z0-9.-]*\.(txt|xml|json)$'){continue}
            $file=Get-AdLocalInputFile (Join-Path $input.DirectoryName ([string]$entry.Path)) 104857600
            $used+=$file.Length;if($used -gt 524288000){throw 'Imported evidence exceeds 500 MiB total limit.'}
            if((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ine [string]$entry.SHA256 -or $file.Length -ne [long]$entry.Bytes){throw 'Imported evidence hash or length mismatch.'}
            $dest=Join-Path $folder 'native';$null=New-Item -ItemType Directory -Path $dest -Force;Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $dest $file.Name) -ErrorAction Stop;$copied++
        }
    }
    $loaded|Add-Member -NotePropertyName RenderEvidenceFilesCopied -NotePropertyValue $copied -Force
    Write-AdAssessmentFiles $loaded $folder
    [pscustomobject]@{Status='RenderedOffline';ExitCode=0;RunFolder=$folder;Findings=$sets.Findings.Count;CollectionErrors=$sets.CollectionErrors.Count}
}
function New-AdReportArchive {
    param([string]$Folder)
    $dir=Get-Item -LiteralPath $Folder -ErrorAction Stop
    if(-not $dir.PSIsContainer){throw 'Archive source must be a report directory.'}
    $target=$dir.FullName+'.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    [IO.Compression.ZipFile]::CreateFromDirectory($dir.FullName,$target,[IO.Compression.CompressionLevel]::Optimal,$true)
    $target
}

function Write-AdHtmlReport {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Report
    )

    function Get-AdReportProperty {
        param($Object,[string]$Name)
        if ($null -eq $Object) { return $null }
        if ($Object -is [Collections.IDictionary]) { return $Object[$Name] }
        $property=$Object.PSObject.Properties[$Name]
        if ($null -ne $property) { return $property.Value }
        return $null
    }

    function ConvertTo-AdReportText {
        param($Value)
        if ($null -eq $Value) { return '' }
        if ($Value -is [DateTime]) { return $Value.ToUniversalTime().ToString('o') }
        if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime().ToString('o') }
        if ($Value -is [Array]) { return (($Value | ForEach-Object { [string]$_ }) -join '; ') }
        return [string]$Value
    }

    function ConvertTo-AdReportHtml {
        param($Value)
        [Net.WebUtility]::HtmlEncode((ConvertTo-AdReportText $Value))
    }

    $datasets=Get-AdReportProperty $Report 'Datasets'
    $parameters=Get-AdReportProperty $Report 'Parameters'
    $maxRows=1000
    $limitValue=Get-AdReportProperty $parameters 'MaxHtmlRows'
    if ($null -ne $limitValue) {
        $parsed=0
        if ([int]::TryParse([string]$limitValue,[ref]$parsed) -and $parsed -gt 0) {
            $maxRows=[Math]::Min($parsed,50000)
        }
    }

    # Values entering CSS, identifiers and href are fixed labels, not directory data.
    $sectionSpecs=@(
        @{Key='Coverage';Label='Cobertura da coleta / Collection coverage';Open=$true},
        @{Key='CollectionErrors';Label='Erros e limitações / Collection errors';Open=$true},
        @{Key='Findings';Label='Observações e recomendações / Findings and recommendations';Open=$true},
        @{Key='Forest';Label='Floresta / Forest';Open=$true},
        @{Key='Domains';Label='Domínios / Domains';Open=$true},
        @{Key='ComputerSummary';Label='Resumo dos computadores / Computer summary';Open=$true},
        @{Key='DCSummary';Label='Resumo operacional dos DCs / DC operational summary';Open=$true},
        @{Key='DomainControllers';Label='Controladores de domínio / Domain controllers';Open=$true},
        @{Key='OrganizationalUnits';Label='Unidades organizacionais / Organizational units';Open=$false},
        @{Key='PasswordPolicies';Label='Políticas de senha / Password policies';Open=$false},
        @{Key='Trusts';Label='Relações de confiança / Trust relationships';Open=$false},
        @{Key='Replication';Label='Replicação / Replication';Open=$false},
        @{Key='ReplicationFailures';Label='Falhas de replicação / Replication failures';Open=$true},
        @{Key='Connectivity';Label='ICMP informativo / Informational ICMP';Open=$false},
        @{Key='DNS';Label='DNS e descoberta AD / DNS and AD discovery';Open=$false},
        @{Key='HostMetrics';Label='Inicialização e memória / Boot and memory';Open=$false},
        @{Key='Disks';Label='Capacidade de volumes / Volume capacity';Open=$false},
        @{Key='StoragePaths';Label='Caminhos NTDS e SYSVOL / NTDS and SYSVOL paths';Open=$false},
        @{Key='TimeSummary';Label='Diferença de horário / Time offset';Open=$false},
        @{Key='TimeSamples';Label='Amostras de horário / Time samples';Open=$false},
        @{Key='TimeConfiguration';Label='Evidências W32Time / W32Time evidence';Open=$false},
        @{Key='Events';Label='Eventos recentes / Recent events';Open=$false},
        @{Key='EventLogCoverage';Label='Cobertura de eventos / Event log coverage';Open=$false},
        @{Key='Timings';Label='Duração por coletor / Collector durations';Open=$false},
        @{Key='Services';Label='Serviços dos DCs / DC services';Open=$false},
        @{Key='NativeDiagnostics';Label='Diagnósticos nativos / Native diagnostics';Open=$false},
        @{Key='PrivilegedMembers';Label='Membros de grupos privilegiados / Privileged group members';Open=$false},
        @{Key='Groups';Label='Grupos / Groups';Open=$false},
        @{Key='OptionalFeatures';Label='Recursos opcionais e Lixeira do AD / Optional features and AD Recycle Bin';Open=$false},
        @{Key='Sites';Label='Sites da floresta / Forest sites';Open=$false},
        @{Key='Subnets';Label='Sub-redes / Subnets';Open=$false},
        @{Key='SiteLinks';Label='Vínculos entre sites / Site links';Open=$false},
        @{Key='AccountSecurityFlags';Label='Segurança das contas / Account security flags';Open=$false},
        @{Key='SPNInventory';Label='SPNs e proprietários / SPNs and owners';Open=$false},
        @{Key='DuplicateSPNs';Label='SPNs duplicados / Duplicate SPNs';Open=$false},
        @{Key='DuplicateUPNs';Label='UPNs duplicados / Duplicate UPNs';Open=$false},
        @{Key='DirectoryCoverage';Label='Cobertura dos identificadores / Identifier coverage';Open=$false},
        @{Key='GroupPolicies';Label='Inventário de GPOs / GPO inventory';Open=$false},
        @{Key='GPOLinks';Label='Vínculos de GPOs / GPO links';Open=$false},
        @{Key='GPOSettings';Label='Configurações e metadados de GPOs / GPO settings and metadata';Open=$false},
        @{Key='GPOPermissions';Label='Permissões de GPOs / GPO permissions';Open=$false},
        @{Key='GPOCoverage';Label='Cobertura das GPOs / GPO coverage';Open=$false},
        @{Key='SysvolFiles';Label='Arquivos do SYSVOL / SYSVOL files';Open=$false},
        @{Key='SysvolSummary';Label='Resumo do SYSVOL / SYSVOL summary';Open=$false},
        @{Key='DnsServerConfiguration';Label='Configuração dos servidores DNS / DNS server configuration';Open=$false},
        @{Key='DnsZones';Label='Zonas DNS / DNS zones';Open=$false},
        @{Key='DnsRootHints';Label='Root hints DNS / DNS root hints';Open=$false},
        @{Key='DnsZoneIndicators';Label='Indícios de objetos DNS InProgress / DNS InProgress indicators';Open=$false},
        @{Key='BackupEvidence';Label='Evidências de backup / Backup evidence';Open=$false},
        @{Key='HostHardware';Label='Hardware e firmware / Hardware and firmware';Open=$false},
        @{Key='InstalledSoftware';Label='Aplicativos instalados / Installed software';Open=$false},
        @{Key='Hotfixes';Label='KBs e atualizações QFE / KB and QFE updates';Open=$false},
        @{Key='HostSecurity';Label='Segurança do host e W32Time / Host security and W32Time';Open=$false},
        @{Key='RegistryEvidence';Label='Valores observados no Registro / Observed registry values';Open=$false},
        @{Key='SecurityReview';Label='Revisão de segurança por valor / Security value review';Open=$false},
        @{Key='RSoPSettings';Label='Políticas resultantes observadas / Resultant policy evidence';Open=$false},
        @{Key='UserRightsAssignments';Label='Direitos de usuário por SID / User rights by SID';Open=$false},
        @{Key='SecurityEvents';Label='Eventos de segurança selecionados / Selected security events';Open=$false},
        @{Key='LogConfiguration';Label='Configuração dos logs / Log configuration';Open=$false},
        @{Key='AuditPolicy';Label='Política de auditoria por GUID / Audit policy by GUID';Open=$false},
        @{Key='AssessmentSources';Label='Fontes oficiais e limites / Official sources and limits';Open=$false},
        @{Key='Users';Label='Contas de usuários / User accounts';Open=$false},
        @{Key='Computers';Label='Contas de computadores / Computer accounts';Open=$false}
    )
    $keys=if ($datasets -is [Collections.IDictionary]) { @($datasets.Keys | ForEach-Object { [string]$_ }) }
          elseif ($null -ne $datasets) { @($datasets.PSObject.Properties | ForEach-Object { $_.Name }) }
          else { @() }
    $sections=New-Object 'Collections.Generic.List[object]'
    foreach ($spec in $sectionSpecs) { if ($spec.Key -in $keys) { $sections.Add($spec) } }
    foreach ($key in $keys) {
        if ($key -notin @($sectionSpecs | ForEach-Object { $_.Key })) {
            $sections.Add(@{Key=$key;Label=$key;Open=$false})
        }
    }
    for ($i=0;$i -lt $sections.Count;$i++) { $sections[$i]['Id']='dataset-'+[string]$i }
    $nonceBytes=New-Object byte[] 16
    $random=[Security.Cryptography.RandomNumberGenerator]::Create()
    try { $random.GetBytes($nonceBytes) } finally { $random.Dispose() }
    $nonce=[Convert]::ToBase64String($nonceBytes)
    $version=ConvertTo-AdReportHtml (Get-AdReportProperty $Report 'Version')
    $runId=ConvertTo-AdReportHtml (Get-AdReportProperty $Report 'RunId')
    $status=ConvertTo-AdReportHtml (Get-AdReportProperty $Report 'Status')
    $started=ConvertTo-AdReportHtml (Get-AdReportProperty $Report 'StartedUtc')
    $ended=ConvertTo-AdReportHtml (Get-AdReportProperty $Report 'EndedUtc')
    $scope=ConvertTo-AdReportHtml (Get-AdReportProperty $parameters 'Scope')
    $server=ConvertTo-AdReportHtml (Get-AdReportProperty $parameters 'Server')
    $inactive=ConvertTo-AdReportHtml (Get-AdReportProperty $parameters 'InactiveDays')
    $html=New-Object Text.StringBuilder
    [void]$html.Append(@"
<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none';style-src 'unsafe-inline';script-src 'nonce-$nonce';base-uri 'none';form-action 'none';object-src 'none'">
<title>FMODEL | Active Directory Report $version</title>
<style>
:root{color-scheme:light;--navy:#12385c;--blue:#1766a4;--muted:#536579;--line:#d4dfea;--paper:#fff;--back:#eef3f8}
*{box-sizing:border-box}body{margin:0;background:var(--back);color:#172d44;font:16px/1.5 system-ui,-apple-system,'Segoe UI',sans-serif}
main{max-width:1480px;margin:0 auto;padding:24px}a{color:#0a568f}a:focus-visible,input:focus-visible,button:focus-visible,summary:focus-visible{outline:3px solid #d68906;outline-offset:3px}
.hero{background:var(--navy);color:white;padding:28px;border-radius:14px}.hero p{margin:.4rem 0}.hero a{color:#dcefff}h1{font-size:clamp(1.6rem,3vw,2.3rem);margin:0 0 .3rem}h2{font-size:1.2rem;color:var(--navy)}.subtitle{font-weight:600;letter-spacing:.02em}.meta{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px;margin:20px 0}.meta div,.card{background:white;border:1px solid var(--line);border-radius:10px;padding:16px}.meta dt{font-size:.8rem;font-weight:700;color:var(--muted);text-transform:uppercase}.meta dd{margin:4px 0 0;overflow-wrap:anywhere}.notice{border-left:5px solid #b7770c;background:#fff8e6;padding:18px;border-radius:6px;margin:18px 0}.notice p{margin:.35rem 0}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin:18px 0}.card strong{display:block;font-size:1.75rem;color:var(--navy)}.card span{font-size:.9rem;color:var(--muted)}
.toolbar{display:flex;flex-wrap:wrap;gap:12px;align-items:center;margin:18px 0}.toolbar button{font:inherit;background:white;border:1px solid #7b96b0;border-radius:6px;padding:8px 14px;color:var(--navy);cursor:pointer}nav{background:white;border:1px solid var(--line);border-radius:10px;padding:16px}nav a{display:inline-block;margin:4px 14px 4px 0;font-size:.9rem}
details{background:white;border:1px solid var(--line);border-radius:10px;margin:16px 0;overflow:hidden}summary{padding:17px 20px;cursor:pointer;font-weight:700;background:#e5eef7;color:var(--navy)}summary .badge{float:right;font-size:.85rem;background:white;border:1px solid #a9c1d7;border-radius:20px;padding:1px 10px;margin-left:8px}.section-body{padding:16px 20px}.section-tools{display:flex;align-items:center;flex-wrap:wrap;gap:12px;margin-bottom:10px}.section-tools label{font-weight:600;font-size:.9rem}.section-tools input{max-width:100%;width:300px;font:inherit;padding:7px 10px;border:1px solid #9bb0c5;border-radius:6px}.row-count{color:var(--muted);font-size:.85rem}.table-wrap{overflow-x:auto;max-height:620px;overflow-y:auto;border:1px solid var(--line);border-radius:6px}table{border-collapse:collapse;width:100%;font-size:.85rem}caption{text-align:left;padding:10px;font-weight:600;background:#f4f7fb}th,td{padding:9px 11px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top;overflow-wrap:anywhere;max-width:500px;min-width:110px}th{background:#174a77;color:white;position:sticky;top:0;z-index:1;font-weight:600}tbody tr:nth-child(even){background:#f5f8fb}tbody tr.severity-danger{box-shadow:inset 4px 0 #bc3030}tbody tr.severity-warning{box-shadow:inset 4px 0 #b5760d}tbody tr.severity-info{box-shadow:inset 4px 0 #28709e}tr[hidden]{display:none}.truncate{font-weight:600;color:#805400;background:#fff8e6;border-radius:6px;padding:12px}.empty{padding:10px 0;color:var(--muted)}footer{color:var(--muted);font-size:.85rem;border-top:1px solid var(--line);padding:20px 0;margin-top:24px}code{overflow-wrap:anywhere}.noscript{font-weight:600}.privacy{font-weight:600}
@media(max-width:600px){main{padding:12px}.hero{padding:20px}.section-body{padding:12px}summary{padding:14px}.section-tools{align-items:flex-start;flex-direction:column}.section-tools input{width:100%}th,td{min-width:100px}}
@media print{body{background:white;font-size:10pt}main{max-width:none;padding:0}.hero{background:white;color:#12385c;border-bottom:3px solid #12385c;border-radius:0}.hero a{color:#12385c}.toolbar,nav,.section-tools{display:none}details{break-inside:auto;border-radius:0}summary{break-after:avoid}.table-wrap{max-height:none;overflow:visible}table{font-size:7pt}th{position:static;background:#e5eef7;color:#12385c}tr{break-inside:avoid}a{color:#12385c}.meta,.cards{break-inside:avoid}}
</style></head><body><main>
<header class="hero"><p class="subtitle">FMODEL - IT</p><h1>Active Directory — inventário e análise / inventory and review</h1>
<p>FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO</p><p>F. Model · <a href="mailto:fmodel@fmodel.com.br">fmodel@fmodel.com.br</a> · v$version</p></header>
<dl class="meta"><div><dt>Resultado / Result</dt><dd>$status</dd></div><div><dt>Escopo / Scope</dt><dd>$scope</dd></div><div><dt>Servidor solicitado / Requested server</dt><dd>$server</dd></div><div><dt>Execução / Run ID</dt><dd>$runId</dd></div><div><dt>Início UTC / Started UTC</dt><dd>$started</dd></div><div><dt>Fim UTC / Ended UTC</dt><dd>$ended</dd></div><div><dt>Limiar de inatividade / Inactivity threshold</dt><dd>$inactive dias / days</dd></div></dl>
<aside class="notice"><p><strong>Leia a cobertura e os erros primeiro. / Read coverage and errors first.</strong></p>
<p>Este relatório é uma observação de consultas, sem correção automática. Ausência de dados ou erro de coleta não significa ausência de problema. Uma execução concluída não certifica a saúde ou segurança do domínio.</p>
<p>This is a query snapshot without automatic remediation. Missing data or a collection error is not proof that a problem is absent. Completion does not certify domain health or security.</p>
<p class="privacy">Dados internos e de identidade: armazene e compartilhe conforme a política da empresa. / Internal and identity data: store and share under organizational policy.</p></aside>
<section aria-label="Linhas coletadas / Collected rows"><h2>Linhas coletadas / Collected rows</h2><div class="cards">
"@)
    foreach ($key in @('Domains','DomainControllers','Computers','Users','Groups','Findings','CollectionErrors')) {
        $value=Get-AdReportProperty $datasets $key
        $rows=@($value | Where-Object { $null -ne $_ })
        [void]$html.Append('<div class="card"><strong>'+[string]$rows.Count+'</strong><span>'+(ConvertTo-AdReportHtml $key)+'</span></div>')
    }
    [void]$html.Append('</div><p>As contagens acima são linhas disponíveis neste relatório; verifique a cobertura antes de interpretá-las como totais do AD. / Counts are available report rows; inspect coverage before treating them as AD totals.</p></section><div class="toolbar"><button type="button" id="expand-all">Expandir tudo / Expand all</button><button type="button" id="collapse-all">Recolher tabelas / Collapse tables</button><button type="button" id="print-report">Imprimir / Print</button></div><noscript><p class="noscript">JavaScript desativado: as tabelas continuam disponíveis; use os controles nativos de expansão ou os CSV. / JavaScript disabled: tables remain available through native expansion controls or CSV files.</p></noscript><nav aria-label="Seções / Sections">')
    foreach ($section in $sections) { [void]$html.Append('<a href="#section-'+$section.Id+'">'+(ConvertTo-AdReportHtml $section.Label)+'</a>') }
    [void]$html.Append('</nav>')

    foreach ($section in $sections) {
        $key=[string]$section.Key
        $sectionId=[string]$section.Id
        $value=Get-AdReportProperty $datasets $key
        $rows=@($value | Where-Object { $null -ne $_ })
        $count=$rows.Count
        $open=if ($section.Open) { ' open' } else { '' }
        [void]$html.Append('<details id="section-'+$sectionId+'"'+$open+'><summary>'+(ConvertTo-AdReportHtml $section.Label)+'<span class="badge">'+[string]$count+'</span></summary><div class="section-body">')
        if ($key -match '^[a-zA-Z][a-zA-Z0-9]*$') {
            [void]$html.Append('<p><a href="'+$key.ToLowerInvariant()+'.csv" download>CSV completo / Full CSV</a></p>')
        }
        if ($count -eq 0) {
            [void]$html.Append('<p class="empty">Nenhuma linha disponível. Consulte Coverage e CollectionErrors para distinguir coleta vazia, ignorada ou com falha. / No rows available. Inspect Coverage and CollectionErrors to distinguish empty, skipped or failed collection.</p></div></details>')
            continue
        }
        if ($rows[0] -is [Collections.IDictionary]) { $columns=@($rows[0].Keys | ForEach-Object { [string]$_ }) }
        else { $columns=@($rows[0].PSObject.Properties | ForEach-Object { $_.Name }) }
        $displayCount=[Math]::Min($count,$maxRows)
        if ($count -gt $displayCount) {
            [void]$html.Append('<p class="truncate">HTML limitado a '+[string]$displayCount+' de '+[string]$count+' linhas. O CSV contém todas as linhas exportadas. / HTML limited to '+[string]$displayCount+' of '+[string]$count+' rows. CSV contains every exported row.</p>')
        }
        [void]$html.Append('<div class="section-tools"><label for="search-'+$sectionId+'">Buscar nas linhas exibidas / Search displayed rows</label><input id="search-'+$sectionId+'" class="table-search" type="search" data-table="table-'+$sectionId+'" data-count="count-'+$sectionId+'" autocomplete="off"><span class="row-count" id="count-'+$sectionId+'" role="status" aria-live="polite">'+[string]$displayCount+' / '+[string]$displayCount+'</span></div><div class="table-wrap"><table id="table-'+$sectionId+'"><caption>'+(ConvertTo-AdReportHtml $section.Label)+'</caption><thead><tr>')
        foreach ($column in $columns) { [void]$html.Append('<th scope="col">'+(ConvertTo-AdReportHtml $column)+'</th>') }
        [void]$html.Append('</tr></thead><tbody>')
        for ($i=0;$i -lt $displayCount;$i++) {
            $row=$rows[$i]
            $severity=''
            foreach ($field in @('Severity','Status','State','Result')) {
                $valueText=ConvertTo-AdReportText (Get-AdReportProperty $row $field)
                if ($valueText -match '(?i)critical|high|error|failed|failure|critical|cr[ií]tic|erro|falh') { $severity='severity-danger';break }
                if ($valueText -match '(?i)warning|unknown|missing|partial|notcollected|skipped|attention|aviso|desconhec|parcial|ignorado|aten[çc]') { $severity='severity-warning' }
                elseif (-not $severity -and $valueText -match '(?i)info|low|collected|success|passed|coletado') { $severity='severity-info' }
            }
            [void]$html.Append('<tr'+$(if ($severity) { ' class="'+$severity+'"' } else { '' })+'>')
            foreach ($column in $columns) { [void]$html.Append('<td>'+(ConvertTo-AdReportHtml (Get-AdReportProperty $row $column))+'</td>') }
            [void]$html.Append('</tr>')
        }
        [void]$html.Append('</tbody></table></div></div></details>')
    }

    [void]$html.Append(@"
<footer><p>FMODEL · fmodel@fmodel.com.br · Active Directory Report $version</p>
<p>Filtros do HTML abrangem apenas as linhas exibidas; os CSV são a referência para os dados completos exportados. / HTML filters cover displayed rows only; CSV files are the reference for full exported data.</p>
<p>Os dados representam o período da coleta e podem mudar após a execução. Este material não é certificação Microsoft. / Data represents collection time and can change afterward. This material is not Microsoft certification.</p></footer>
</main><script nonce="$nonce">
(function(){
  'use strict';
  function normalized(value){var text=String(value).toLocaleLowerCase();try{return text.normalize('NFD').replace(/[\u0300-\u036f]/g,'');}catch(e){return text;}}
  Array.prototype.forEach.call(document.querySelectorAll('.table-search'),function(input){
    input.addEventListener('input',function(){
      var query=normalized(input.value),table=document.getElementById(input.getAttribute('data-table')),counter=document.getElementById(input.getAttribute('data-count'));
      if(!table){return;}var rows=table.querySelectorAll('tbody tr'),visible=0;
      Array.prototype.forEach.call(rows,function(row){var match=normalized(row.textContent).indexOf(query)!==-1;row.hidden=!match;if(match){visible++;}});
      if(counter){counter.textContent=visible+' / '+rows.length;}
    });
  });
  function setAll(open){Array.prototype.forEach.call(document.querySelectorAll('details'),function(item){item.open=open;});}
  document.getElementById('expand-all').addEventListener('click',function(){setAll(true);});
  document.getElementById('collapse-all').addEventListener('click',function(){setAll(false);});
  document.getElementById('print-report').addEventListener('click',function(){window.print();});
  Array.prototype.forEach.call(document.querySelectorAll('nav a'),function(link){link.addEventListener('click',function(){var target=document.getElementById(link.getAttribute('href').slice(1));if(target){target.open=true;}});});
  var printState=[];
  window.addEventListener('beforeprint',function(){printState=[];Array.prototype.forEach.call(document.querySelectorAll('details'),function(item){printState.push(item.open);item.open=true;});});
  window.addEventListener('afterprint',function(){Array.prototype.forEach.call(document.querySelectorAll('details'),function(item,index){if(index<printState.length){item.open=printState[index];}});});
}());
</script></body></html>
"@)
    $encoding=New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path,$html.ToString(),$encoding)
}


$options=[pscustomobject]@{Server=$Server;Scope=$Scope;OutputPath=$OutputPath;InactiveDays=$InactiveDays;IncludeServiceChecks=[bool]$IncludeServiceChecks;IncludeDcDiagnostics=[bool]$IncludeDcDiagnostics;TimeoutSeconds=$TimeoutSeconds;MaxHtmlRows=$MaxHtmlRows;PageSize=$PageSize;SkipUserInventory=[bool]$SkipUserInventory;SkipPrivilegedMembers=[bool]$SkipPrivilegedMembers;FullAssessment=[bool]$FullAssessment;IncludeOperationalChecks=[bool]$IncludeOperationalChecks;IncludeEventLogs=[bool]$IncludeEventLogs;DiagnosticProfile=$DiagnosticProfile;DnsServer=$DnsServer;TimeSamples=$TimeSamples;TimeWarningSeconds=$TimeWarningSeconds;TimeCriticalSeconds=$TimeCriticalSeconds;DiskWarningPercent=$DiskWarningPercent;DiskCriticalPercent=$DiskCriticalPercent;DiskWarningGiB=$DiskWarningGiB;DiskCriticalGiB=$DiskCriticalGiB;EventHours=$EventHours;MaxEventsPerLog=$MaxEventsPerLog}
foreach($key in (Get-AdExtensionDefaults).Keys){if($key -ne 'HotfixReviewDays'){$options|Add-Member -NotePropertyName $key -NotePropertyValue (Get-Variable -Name $key -ValueOnly)}}
try {
    if($FromReport){$result=Invoke-AdRenderSnapshot $FromReport $OutputPath $MaxHtmlRows $PSCmdlet}else{$result=Invoke-AdAssessment $options $PSCmdlet}
    if($CreateArchive -and $result.RunFolder){$archive=New-AdReportArchive $result.RunFolder;$result|Add-Member -NotePropertyName Archive -NotePropertyValue $archive}
    $result|Format-List Status,RunFolder,Archive,Findings,CollectionErrors|Out-Host
    exit $result.ExitCode
}catch{
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
