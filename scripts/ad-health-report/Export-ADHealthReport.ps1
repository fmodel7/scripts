#Requires -Version 5.1
<#
.SYNOPSIS
FMODEL AD Health Report 1.1.0 - read-only inventory and review evidence.
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
    [ValidateRange(1,1000)][int]$MaxEventsPerLog=100
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
    param([ValidateSet('Get-ADRootDSE','Get-ADDomain','Get-ADForest','Get-ADObject','Get-ADDomainController','Get-ADComputer','Get-ADUser','Get-ADGroup','Get-ADGroupMember','Get-ADOrganizationalUnit','Get-ADDefaultDomainPasswordPolicy','Get-ADFineGrainedPasswordPolicy','Get-ADTrust','Get-ADReplicationPartnerMetadata','Get-ADReplicationFailure')][string]$Command,[hashtable]$Arguments)
    & ('ActiveDirectory\'+$Command) @Arguments -ErrorAction Stop
}
function Initialize-AdRuntime {
    if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or -not [Environment]::Is64BitProcess -or $PSVersionTable.PSEdition -ne 'Desktop') {
        throw 'Use Windows PowerShell 5.1 de 64 bits (powershell.exe); PowerShell 7 somente para testes offline / offline tests only.'
    }
    Import-Module ActiveDirectory -ErrorAction Stop
}
function Get-AdSchemas {
    [ordered]@{
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
}
function Add-AdRows {
    param($Report,[string]$Dataset,[object[]]$Rows)
    foreach($row in $Rows){if($null -ne $row){$Report.Datasets[$Dataset].Add($row)}}
}
function Invoke-AdCollection {
    param($Report,[string]$Dataset,[string]$Scope,[scriptblock]$Read,[switch]$Skip)
    $watch=[Diagnostics.Stopwatch]::StartNew();$start=[datetime]::UtcNow.ToString('o');$status='Collected';$count=0
    if($Skip){$status='NotRequested'}else{
        try{$rows=@(& $Read);Add-AdRows $Report $Dataset $rows;$count=$rows.Count}
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
    $report=[pscustomobject]@{SchemaVersion=1;Version='1.1.0';RunId=[IO.Path]::GetFileName($folder);StartedUtc=[datetime]::UtcNow.ToString('o');EndedUtc='';Status='Collecting';Parameters=[pscustomobject]$optionsCopy;Datasets=[ordered]@{}}
    $schemas=Get-AdSchemas;foreach($name in $schemas.Keys){$report.Datasets[$name]=New-Object 'Collections.Generic.List[object]'}
    Invoke-AdCollection $report 'Forest' $forest.Name {
        $schema=Invoke-AdQuery 'Get-ADObject' @{Identity=$root.schemaNamingContext;Properties=@('objectVersion');Server=$server}
        [pscustomobject]@{Name=$forest.Name;RootDomain=$forest.RootDomain;ForestMode=[string]$forest.ForestMode;SchemaVersion=[int]$schema.objectVersion;SchemaLabel=Get-AdSchemaLabel ([int]$schema.objectVersion);SchemaMaster=$forest.SchemaMaster;DomainNamingMaster=$forest.DomainNamingMaster;Domains=(@($forest.Domains)-join '; ');Sites=(@($forest.Sites)-join '; ')}
    }
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
    Complete-AdFindings $report
    Complete-AdOperationalFindings $report
    $report.EndedUtc=[datetime]::UtcNow.ToString('o')
    $important=@($report.Datasets.Findings|Where-Object{$_.Severity -in @('High','Medium')}).Count
    $report.Status=if($report.Datasets.CollectionErrors.Count){'Partial'}elseif($important){'CompletedWithFindings'}else{'Completed'}
    foreach($name in $schemas.Keys){Write-AdCsv (Join-Path $folder ($name.ToLowerInvariant()+'.csv')) ($schemas[$name] -split ',') @($report.Datasets[$name].ToArray())}
    [IO.File]::WriteAllText((Join-Path $folder 'report.json'),($report|ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))
    Write-AdHtmlReport (Join-Path $folder 'Report.html') $report
    $hashes=Get-ChildItem -LiteralPath $folder -File -Recurse | ForEach-Object{[pscustomobject]@{Path=$_.FullName.Substring($folder.Length+1).Replace('\','/');SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant();Bytes=$_.Length}}
    [IO.File]::WriteAllText((Join-Path $folder 'run-manifest.json'),(@($hashes)|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
    [pscustomobject]@{Status=$report.Status;ExitCode=if($report.Status -eq 'Completed'){0}else{2};RunFolder=$folder;Findings=$report.Datasets.Findings.Count;CollectionErrors=$report.Datasets.CollectionErrors.Count}
}

function Get-AdEffectiveOptions {
    param($InputOptions)
    $defaults=[ordered]@{Server='';Scope='Domain';OutputPath='';InactiveDays=90;IncludeServiceChecks=$false;IncludeDcDiagnostics=$false;TimeoutSeconds=60;MaxHtmlRows=1000;PageSize=500;SkipUserInventory=$false;SkipPrivilegedMembers=$false;FullAssessment=$false;IncludeOperationalChecks=$false;IncludeEventLogs=$false;DiagnosticProfile='Baseline';DnsServer='';TimeSamples=3;TimeWarningSeconds=1.0;TimeCriticalSeconds=5.0;DiskWarningPercent=15.0;DiskCriticalPercent=5.0;DiskWarningGiB=10.0;DiskCriticalGiB=5.0;EventHours=24;MaxEventsPerLog=100}
    foreach($key in @($defaults.Keys)){$p=$InputOptions.PSObject.Properties[$key];if($null -ne $p){$defaults[$key]=$p.Value}}
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
try {
    $result=Invoke-AdAssessment $options $PSCmdlet
    $result|Format-List Status,RunFolder,Findings,CollectionErrors|Out-Host
    exit $result.ExitCode
}catch{
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
