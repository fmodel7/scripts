#Requires -Version 5.1
# Synthetic adapters and local files only. No real directory, remoting, DNS or event log queries.
param([string]$KeepExample='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$script:checks=0;$script:workflows=0;$root=Split-Path $PSScriptRoot -Parent
function Assert($Value,[string]$Message){if(-not $Value){throw "FAIL: $Message"};$script:checks++}
function Assert-Throws([scriptblock]$Body,[string]$Message){$failed=$false;try{&$Body|Out-Null}catch{$failed=$true};Assert $failed $Message}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Export-ADHealthReport.ps1'),[ref]$tokens,[ref]$errors)
Assert ($errors.Count -eq 0) 'standalone parses'
foreach($f in $ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)){. ([scriptblock]::Create($f.Extent.Text))}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('fmodel-ad12-'+[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $temp
function New-TestReport($Options){$sets=[ordered]@{};foreach($k in (Get-AdSchemas).Keys){$sets[$k]=New-Object 'Collections.Generic.List[object]'};[pscustomobject]@{Version='1.2.0';SchemaVersion=1;RunId='SYNTHETIC-EXAMPLE-NOT-A-LIVE-ASSESSMENT';StartedUtc=[datetime]::UtcNow.ToString('o');EndedUtc=[datetime]::UtcNow.ToString('o');Status='SyntheticExample';Parameters=$Options;Datasets=$sets}}
try{
    $o=Get-AdEffectiveOptions ([pscustomobject]@{ComprehensiveAssessment=$true})
    foreach($n in @('IncludeDirectorySecurity','IncludeTopology','IncludeGpoInventory','IncludeSysvolInventory','IncludeDnsConfiguration','IncludeBackupEvidence','IncludeHostInventory','IncludeSecurityConfiguration','IncludeRsop','IncludeSecurityEvents','FullAssessment')){Assert $o.$n "$n enabled by explicit comprehensive preset"}
    Assert ($o.Scope -eq 'Domain' -and -not (Get-AdEffectiveOptions ([pscustomobject]@{FullAssessment=$true})).IncludeGpoInventory) 'scope and old FullAssessment behavior preserved'
    Assert ((Get-AdSchemas).Count -eq 63) '63 normalized datasets'
    Assert (@(Read-AdJsonList '[{"Path":"a"},{"Path":"b"}]').Count -eq 2) 'manifest JSON arrays flatten consistently on Windows PowerShell 5.1 and 7'
    Assert (@(Read-SnapshotCatalog '[{"Id":"a"},{"Id":"b"}]').Count -eq 2) 'remote registry catalog parses independent rules on Windows PowerShell 5.1 and 7'
    Assert (@(Get-AdRegistryCatalog).Count -eq 12) '12 registry guidance rules'
    $a=[pscustomobject]@{Name='SYNTHETIC';ObjectClass='user';ObjectGUID='a';DistinguishedName='CN=A,DC=example,DC=test';userAccountControl=(128+2097152+32+65536+4194304+262144);objectSid='S-1-5-21-1-2-3-1001'}
    $flags=Convert-AdSecurityAccount $a example.test dc1.example.test
    Assert ($flags.ReversibleEncryptionAllowed -and $flags.UseDESKeyOnly -and $flags.PasswordNotRequired -and $flags.PasswordNeverExpires -and $flags.SmartcardRequired -and -not $flags.TrustedForDelegation) 'UAC bits interpreted independently'
    $a.userAccountControl=$null;$flags=Convert-AdSecurityAccount $a example.test dc1.example.test
    Assert ($null -eq $flags.Enabled -and $null -eq $flags.UseDESKeyOnly -and $flags.Observation -eq 'UnknownUAC') 'unknown account flags never default false'
    $xml=Convert-AdSafeXml '<r xmlns="urn:example"><x a="1">=formula</x><x>two</x></r>' 1000
    $flat=Get-AdXmlLeaves $xml.DocumentElement 10
    Assert ($flat.Rows.Count -eq 2 -and $flat.Rows[0].SettingPath -eq 'r/x[1]' -and $flat.Rows[1].SettingPath -eq 'r/x[2]' -and $flat.Rows[0].Attributes -eq 'a=1') 'namespace independent XML paths preserve repeated elements and attributes'
    Assert ((Get-AdXmlLeaves $xml.DocumentElement 1).Truncated) 'normalized XML cap explicit'
    Assert-Throws {Convert-AdSafeXml '<!DOCTYPE r [<!ENTITY x SYSTEM "file:///not-read">]><r>&x;</r>' 1000} 'DTD and external entities rejected'
    Assert-Throws {Convert-AdSafeXml '<r>broken' 1000} 'malformed XML rejected'
    Assert-Throws {Convert-AdSafeXml '<r>too-long</r>' 5} 'XML input size cap'
    $g1='11111111-1111-1111-1111-111111111111';$g2='22222222-2222-2222-2222-222222222222'
    $scope=[pscustomobject]@{Name='OU1';DistinguishedName='OU=OU1,DC=example,DC=test';gPOptions=1;gPLink="[LDAP://CN={$g1},CN=Policies,CN=System,DC=example,DC=test;1][LDAP://CN={$g2},CN=Policies,CN=System,DC=example,DC=test;2]"}
    $links=@(Convert-AdGpoLinks $scope example.test)
    Assert ($links.Count -eq 2 -and -not $links[0].Enabled -and $links[1].Enforced -and $links[0].InheritanceBlocked -and $links[1].StoredPosition -eq 2) 'link flags and stored order do not claim effective precedence'
    $scope.gPLink='malformed';Assert-Throws {Convert-AdGpoLinks $scope example.test} 'malformed links not silently ignored'
    $r=New-TestReport $o
    Add-AdRows $r RegistryEvidence @([pscustomobject]@{Domain='example.test';DC='dc1.example.test';RuleId='LDAP-SIGNING';ValueKind='DWord';Value=0;Observation='Observed'},[pscustomobject]@{Domain='example.test';DC='dc1.example.test';RuleId='NO-LM-HASH';ValueKind='';Value=$null;Observation='NotConfigured'})
    Add-AdSecurityReview $r example.test dc1.example.test 20348 (Get-AdSecurityProfile '')
    Assert (@($r.Datasets.SecurityReview|Where-Object{$_.RuleId -eq 'LDAP-SIGNING' -and $_.Status -eq 'ReviewValueDifference'}).Count -eq 1) 'value zero not presence-based pass'
    Assert (@($r.Datasets.SecurityReview|Where-Object{$_.RuleId -eq 'NO-LM-HASH' -and $_.Status -eq 'NotExplicitlyConfigured'}).Count -eq 1) 'missing registry is not guessed effective default'
    Assert (@($r.Datasets.SecurityReview|Where-Object{$_.RuleId -eq 'SMB1-SERVER' -and $_.Status -eq 'Unknown'}).Count -eq 1) 'missing SMB is unknown'
    $baseline=Join-Path $temp 'baseline.json'
    [IO.File]::WriteAllText($baseline,'{"SchemaVersion":1,"Role":"DomainController","Name":"SYNTHETIC PROFILE","ApplicableBuilds":[26100],"Rules":[{"RuleId":"LDAP-SIGNING","Comparison":"EqualsAny","Expected":[2]}]}')
    $profile=Get-AdSecurityProfile $baseline;$r=New-TestReport $o;Add-AdSecurityReview $r example.test dc1.example.test 20348 $profile
    Assert ($r.Datasets.SecurityReview[0].Status -eq 'NotApplicableOSBuild') 'custom profile OS applicability checked'
    [IO.File]::WriteAllText($baseline,'{"SchemaVersion":1,"Role":"DomainController","Name":"BAD","ApplicableBuilds":[26100],"Rules":[{"RuleId":"READ-SAM-SECRETS","Comparison":"EqualsAny","Expected":[1]}]}')
    Assert-Throws {Get-AdSecurityProfile $baseline} 'custom baseline cannot add arbitrary registry paths/commands'
    # Actual SYSVOL traversal algorithm against local synthetic files, never a share.
    $sv=Join-Path $temp 'sysvol';$null=New-Item -ItemType Directory $sv
    foreach($n in 1..4){[IO.File]::WriteAllText((Join-Path $sv ("$n.ps1")),'SYNTHETIC FILE NEVER EXECUTED')}
    $r=New-TestReport $o;$small=Get-AdEffectiveOptions ([pscustomobject]@{MaxSysvolFiles=2})
    $files=@(Get-AdSysvolInventory $r $small example.test dc1.example.test $sv)
    Assert ($files.Count -eq 2 -and $r.Datasets.SysvolSummary[0].Truncated -and $r.Datasets.CollectionErrors.Count -eq 1) 'actual traversal respects file cap and records truncation'
    # Job ownership: fake job engine, not jobs belonging to another process/session.
    $script:removed=New-Object 'Collections.Generic.List[int]';$script:stopped=New-Object 'Collections.Generic.List[int]';$script:jobTimeout=$false
    function Start-Job {param($ScriptBlock,$ArgumentList,$ErrorAction) [pscustomobject]@{Id=77;State=if($script:jobTimeout){'Running'}else{'Completed'}}}
    function Wait-Job {param($Job,$Timeout) if(-not $script:jobTimeout){$Job}}
    function Receive-Job {param($Job,$ErrorAction) 'SYNTHETIC JOB RESULT'}
    function Remove-Job {param($Job,[switch]$Force,$ErrorAction) $script:removed.Add($Job.Id)}
    function Stop-Job {param($Job,$ErrorAction) $script:stopped.Add($Job.Id)}
    Assert ((Invoke-AdModuleRead GroupPolicy Get-GPO @{All=$true}) -eq 'SYNTHETIC JOB RESULT') 'module job result received'
    Assert ($script:removed.Count -eq 1 -and $script:removed[0] -eq 77) 'only owned job removed'
    Assert-Throws {Invoke-AdModuleRead GroupPolicy Remove-GPO @{}} 'module command allowlist rejects mutations'
    $script:jobTimeout=$true;Assert-Throws {Invoke-AdModuleRead GroupPolicy Get-GPO @{All=$true}} 'module query timeout raises failure'
    Assert ($script:removed.Count -eq 2 -and $script:stopped.Count -eq 1 -and $script:stopped[0] -eq 77) 'timeout job stopped and cleaned up by its own reference'

    $fixtureAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Test-AdHealth.ps1'),[ref]$tokens,[ref]$errors)
    foreach($name in @('New-FixtureAccount','New-FixturePolicy','Invoke-AdQuery')){$f=$fixtureAst.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true);. ([scriptblock]::Create($f.Extent.Text))}
    $script:baseQuery=${function:Invoke-AdQuery};$script:scenario='full';$script:case='forest';$script:queries=New-Object 'Collections.Generic.List[object]'
    function Invoke-AdQuery {
        param($Command,$Arguments)
        $domain=if($Arguments.ContainsKey('Server') -and [string]$Arguments.Server -like '*child*'){'child.example.test'}else{'example.test'};$dn='DC='+$domain.Replace('.',',DC=')
        if($Command -eq 'Get-ADRootDSE'){$v=&$script:baseQuery $Command $Arguments;$v|Add-Member -NotePropertyName configurationNamingContext -NotePropertyValue 'CN=Configuration,DC=example,DC=test';$v|Add-Member -NotePropertyName namingContexts -NotePropertyValue @($dn,('DC=DomainDnsZones,'+$dn),'DC=ForestDnsZones,DC=example,DC=test');return $v}
        if($Command -eq 'Get-ADOptionalFeature'){return [pscustomobject]@{EnabledScopes=@('CN=Partitions,CN=Configuration,DC=example,DC=test')}}
        if($Command -in @('Get-ADReplicationSite','Get-ADReplicationSubnet','Get-ADReplicationSiteLink')){return [pscustomobject]@{Name='SYNTHETIC-SITE';DistinguishedName='CN=Synthetic,CN=Sites,CN=Configuration,DC=example,DC=test';Cost=100;ReplicationFrequencyInMinutes=180;SitesIncluded=@('SITE-A','SITE-B');Subnets=@('192.0.2.0/24')}}
        if($Command -eq 'Get-ADObject' -and $Arguments.ContainsKey('LDAPFilter')){
            if($script:scenario -eq 'directory-denied' -and $Arguments.LDAPFilter -notmatch 'gPLink|InProgress'){throw 'SYNTHETIC DIRECTORY SECURITY DENIED'}
            if($Arguments.LDAPFilter -eq '(gPLink=*)'){
                $id=if($domain -eq 'example.test'){'11111111-1111-1111-1111-111111111111'}else{'33333333-3333-3333-3333-333333333333'}
                return [pscustomobject]@{Name='Policies';DistinguishedName=$dn;gPOptions=0;gPLink="[LDAP://CN={$id},CN=Policies,CN=System,$dn;0]"}
            }
            if($Arguments.LDAPFilter -like '*InProgress*'){return [pscustomobject]@{Name='SYNTHETIC..InProgress';DistinguishedName=('DC=SYNTHETIC..InProgress,'+$Arguments.SearchBase);ObjectClass='dnsZone'}}
            $records=@(foreach($i in 1..3){[pscustomobject]@{Name=('SYNTHETIC-'+$i);sAMAccountName=('synthetic'+$i);ObjectClass=if($i -eq 3){'computer'}else{'user'};ObjectGUID=($domain+'-owner-'+$i);objectSid=('S-1-5-21-1-2-3-'+(1000+$i));DistinguishedName=("CN=Synthetic-$i,$dn");userAccountControl=if($i -eq 1){128+2097152}else{512};userPrincipalName=if($i -le 2){'DUPLICATE@example.test'}else{''};servicePrincipalName=@('HTTP/shared.example.test');'msDS-SupportedEncryptionTypes'=24}})
            if($Arguments.LDAPFilter -like '*objectClass=computer*' -and $Arguments.LDAPFilter -notlike '*|*'){$records=@($records|Where-Object{$_.ObjectClass -eq 'computer'})}
            return $records
        }
        &$script:baseQuery $Command $Arguments
    }
    function Initialize-AdRuntime {}
    function Get-AdServiceObservations {param($DC,$TimeoutSeconds,$Domain) [pscustomobject]@{Domain=$Domain;DC=$DC;Name='NTDS';State='Running';StartMode='Auto';Observation='Observed'}}
    function Invoke-AdDcdiag {param($DC,$Test,$TimeoutSeconds) [pscustomobject]@{ExitCode=0;TimedOut=$false;Text='SYNTHETIC DIAGNOSTIC OUTPUT'}}
    function Invoke-AdOperationalCollections {param($Report,$Options,$Domain,$DC) foreach($key in @('HostMetrics','Disks','DNS','TimeSummary','Connectivity','Events')){Invoke-AdCollection $Report $key $DC {} -Skip}}
    function Invoke-AdModuleRead {
        param($Module,$Command,$Arguments,$TimeoutSeconds)
        $domain=if($Arguments.ContainsKey('Domain')){[string]$Arguments.Domain}else{''};$id=if($domain -eq 'example.test'){'11111111-1111-1111-1111-111111111111'}else{'33333333-3333-3333-3333-333333333333'}
        if($script:scenario -eq 'gpo-denied' -and $Module -eq 'GroupPolicy'){throw 'SYNTHETIC GPO DENIED'}
        switch($Command){
            'Get-GPO' {[pscustomobject]@{Id=$id;DisplayName='<img src=x onerror=alert(1)> política';GpoStatus='AllSettingsEnabled';CreationTime=[datetime]::UtcNow.AddYears(-1);ModificationTime=[datetime]::UtcNow.AddDays(-2);Owner='EXAMPLE\SYNTHETIC';WmiFilter='';Computer=[pscustomobject]@{DSVersion=7;SysvolVersion=7};User=[pscustomobject]@{DSVersion=7;SysvolVersion=7}}}
            'Get-GPOReport' {if($script:scenario -eq 'gpo-wrong-domain'){$domain='wrong.example.test'};"<GPO xmlns='urn:synthetic'><Identifier><Identifier>{$id}</Identifier><Domain>$domain</Domain></Identifier><Computer><VersionDirectory>7</VersionDirectory><VersionSysvol>7</VersionSysvol></Computer><User><VersionDirectory>7</VersionDirectory></User><Name>=SYNTHETIC-FORMULA</Name></GPO>"}
            'Get-GPPermission' {[pscustomobject]@{Trustee=[pscustomobject]@{Name='SYNTHETIC ADMINS';Sid='S-1-5-21-1-2-3-512';SidType='Group'};Permission='GpoEditDeleteModifySecurity';Inherited=$false}}
            'Get-GPResultantSetOfPolicy' {[IO.File]::WriteAllText($Arguments.Path,"<Rsop><ComputerResults><Name>$($Arguments.Computer)</Name><ExtensionData><Extension><UserRightsAssignment><Name>SeDenyNetworkLogonRight</Name><Member><SID>S-1-5-21-1-2-3-500</SID><Name>EXAMPLE\RENAMED-ADMIN</Name></Member></UserRightsAssignment></Extension></ExtensionData></ComputerResults></Rsop>")}
            'Get-DnsServer' {if($script:scenario -eq 'dns-unavailable'){throw 'SYNTHETIC DNS ROLE UNAVAILABLE'};[pscustomobject]@{ServerForwarder=[pscustomobject]@{IPAddress=@('192.0.2.53');UseRootHint=$true};ServerRecursion=[pscustomobject]@{Enable=$true};ServerScavenging=[pscustomobject]@{ScavengingState=$false};ServerRootHint=[pscustomobject]@{NameServer=@([pscustomobject]@{RecordType='NS';HostName='.';RecordData=[pscustomobject]@{NameServer='a.root-servers.net.'}})}}}
            'Get-DnsServerZone' {[pscustomobject]@{ZoneName='example.test';ZoneType='Primary';IsDsIntegrated=$true;DynamicUpdate='Secure';IsReverseLookupZone=$false;ReplicationScope='Domain'}}
            'Get-DnsServerZoneAging' {[pscustomobject]@{AgingEnabled=$false;NoRefreshInterval=[timespan]::FromDays(7);RefreshInterval=[timespan]::FromDays(7)}}
            default {throw "UNEXPECTED module command $Command"}
        }
    }
    function Invoke-AdRemoteSnapshot {
        param($DC,$Options)
        if($script:scenario -eq 'remote-denied'){throw 'SYNTHETIC REMOTING DENIED'}
        [pscustomobject]@{Hardware=@([pscustomobject]@{OSBuild='20348';LogicalProcessors=4;PhysicalCores=2;Sockets=1;PhysicalMemoryBytes=8GB;Observation='Observed'});Software=@([pscustomobject]@{RegistryView='Registry32';DisplayName='=SYNTHETIC SOFTWARE';DisplayVersion='1.0';Publisher='<script>not executable</script>';Observation='UninstallRegistryEntry'});Hotfixes=@([pscustomobject]@{HotfixId='KB-SYNTHETIC';InstalledOnRaw='10/11/2026';InstalledUtc='';Observation='QFEOnlyNotPatchCompliance'});Security=@([pscustomobject]@{Component='SMBServer';Setting='EnableSMB1Protocol';Value=$false;Observation='Observed';Source='Synthetic'},[pscustomobject]@{Component='Spooler';Setting='State';Value='Stopped';Observation='Observed';Source='Synthetic'},[pscustomobject]@{Component='Spooler';Setting='StartMode';Value='Disabled';Observation='Observed';Source='Synthetic'});Registry=@(Get-AdRegistryCatalog|ForEach-Object{[pscustomobject]@{RuleId=$_.Id;RegistryPath=$_.Path;ValueName=$_.Name;ValueKind='DWord';Value=if($_.Id -eq 'LDAP-SIGNING'){0}else{$_.Expected[0]};Observation='Observed';Error=''}});Logs=@([pscustomobject]@{LogName='Security';Enabled=$true;MaximumBytes=1GB;LogMode='Circular';RecordCount=100;Observation='Observed'});Errors=@();AuditText="Computer,Subcategory,GUID,Setting`nSYNTHETIC,Auditoria,{0CCE9210-69AE-11D9-BED3-505054503030},Success";AuditExit=0;SoftwareTruncated=($script:scenario -eq 'software-cap')}
    }
    $script:sysvolReader=${function:Get-AdSysvolInventory}
    function Get-AdSysvolInventory {param($Report,$Options,$Domain,$DC) &$script:sysvolReader $Report $Options $Domain $DC $sv}
    function Get-AdBackupNativePath {'SYNTHETIC_REPADMIN_NOT_EXECUTED'}
    function Invoke-AdReadProcess {param($File,$Arguments,$TimeoutSeconds) [pscustomobject]@{Text='SYNTHETIC repadmin /showbackup evidence; no parsed local timestamp';ExitCode=0;TimedOut=$false}}
    function Invoke-AdBackupEventQuery {param($DC,$Start,$Maximum) [pscustomobject]@{TimeCreated=[datetime]::UtcNow.AddDays(-2);Message='SYNTHETIC Windows Backup event, components not established'}}
    function Invoke-AdSecurityEventQuery {
        param($DC,$Start,$End,$Maximum)
        if($script:scenario -eq 'security-denied'){throw 'SYNTHETIC SECURITY LOG DENIED'}
        foreach($n in 1..3){$e=[pscustomobject]@{Id=4624;TimeCreated=[datetime]::UtcNow.AddMinutes(-$n);Level=0;ProviderName='SYNTHETIC';RecordId=$n;Message='=SYNTHETIC EVENT'};$e|Add-Member ScriptMethod ToXml {'<Event><EventData><Data Name="LogonType">8</Data><Data Name="TargetUserName">SYNTHETIC</Data></EventData></Event>'};$e}
    }
    foreach($scenario in @('full','gpo-denied','gpo-wrong-domain','directory-denied','remote-denied','dns-unavailable','security-denied','software-cap','xml-cap','skip-users','whatif')){
        $script:scenario=$scenario;$script:case='forest';$script:queries=New-Object 'Collections.Generic.List[object]'
        $opts=[pscustomobject]@{Server='dc1.example.test';Scope='Forest';ComprehensiveAssessment=$true;OutputPath=(Join-Path $temp $scenario);MaxEventsPerLog=2;MaxHtmlRows=10;SkipUserInventory=($scenario -eq 'skip-users');MaxPolicySettings=if($scenario -eq 'xml-cap'){2}else{100000}}
        $caller=[pscustomobject]@{Allow=($scenario -ne 'whatif')};$caller|Add-Member ScriptMethod ShouldProcess {param($Target,$Action)$this.Allow}
        $result=Invoke-AdAssessment $opts $caller
        if($scenario -eq 'whatif'){Assert ($result.Status -eq 'NotCollected') 'comprehensive WhatIf does not collect';$script:workflows++;continue}
        $data=Get-Content -LiteralPath (Join-Path $result.RunFolder 'report.json') -Raw -Encoding UTF8|ConvertFrom-Json
        foreach($key in (Get-AdSchemas).Keys){Assert (Test-Path (Join-Path $result.RunFolder ($key.ToLowerInvariant()+'.csv'))) "$scenario CSV $key"}
        if($scenario -eq 'full'){
            Assert (@($data.Datasets.GroupPolicies).Count -eq 2 -and @($data.Datasets.GPOLinks).Count -eq 3) 'GPOs/links from two domains plus sites'
            Assert (@($data.Datasets.DuplicateSPNs).Count -eq 1 -and $data.Datasets.DuplicateSPNs[0].OwnerCount -eq 6) 'duplicates across distinct owners and domains'
            Assert (@($data.Datasets.DuplicateUPNs).Count -eq 1 -and $data.Datasets.DuplicateUPNs[0].OwnerCount -eq 4) 'UPN duplicates preserved'
            Assert (@($data.Datasets.UserRightsAssignments).Count -eq 2 -and $data.Datasets.UserRightsAssignments[0].PrincipalSID -like '*-500') 'renamed Administrator identified by SID evidence'
            Assert (@($data.Datasets.DnsZones).Count -eq 2 -and @($data.Datasets.BackupEvidence).Count -eq 4 -and @($data.Datasets.AuditPolicy).Count -eq 2) 'DNS/backup/audit evidence exported'
            Assert (@($data.Datasets.SecurityEvents).Count -eq 4 -and $data.Datasets.SecurityEvents[0].Interpretation -like '*does not itself prove*') 'logon type parsed from XML with restrained interpretation'
            Assert (@($data.Datasets.SecurityReview|Where-Object{$_.RuleId -like 'SPOOLER-*' -and $_.Status -eq 'ReviewValueDifference'}).Count -eq 0) 'stopped disabled Spooler not core-service failure'
            Assert (@($data.Datasets.Findings|Where-Object{$_.RuleId -eq 'GPO-NO-EXTENSION-DATA'}).Count -eq 2) 'empty GPO recognized despite nonzero versions'
            Assert (@($data.Datasets.HostHardware).Count -eq 2 -and @($data.Datasets.InstalledSoftware).Count -eq 2 -and @($data.Datasets.Hotfixes).Count -eq 2) 'host inventory bundle exported'
            $html=[IO.File]::ReadAllText((Join-Path $result.RunFolder 'Report.html'));Assert ($html.Contains('&lt;img') -and $html.Contains('&lt;script&gt;not executable') -and -not $html.Contains('<img src=x')) 'untrusted GPO/software strings HTML encoded'
            $csv=@(Import-Csv (Join-Path $result.RunFolder 'installedsoftware.csv'));Assert ($csv[0].DisplayName.StartsWith("'=")) 'new CSV formula protected'
            Assert (@($data.Datasets.AssessmentSources).Count -ge 17) 'official sources carried in runtime report'
            $script:goodFolder=$result.RunFolder
            if($KeepExample){$null=New-Item -ItemType Directory -Path $KeepExample -Force;Copy-Item -Path (Join-Path $result.RunFolder '*') -Destination $KeepExample -Recurse -Force}
        }elseif($scenario -eq 'skip-users'){
            Assert (@($data.Datasets.AccountSecurityFlags|Where-Object{$_.ObjectClass -eq 'user'}).Count -eq 0 -and @($data.Datasets.Users).Count -eq 0) 'SkipUserInventory also restricts new directory collector'
        }else{Assert ($data.Status -eq 'Partial' -and $result.ExitCode -eq 2) "$scenario exports surviving collectors and incomplete status"}
        $script:workflows++
    }
    $caller=[pscustomobject]@{Allow=$true};$caller|Add-Member ScriptMethod ShouldProcess {param($Target,$Action)$this.Allow}
    $rendered=Invoke-AdRenderSnapshot (Join-Path $script:goodFolder 'report.json') (Join-Path $temp 'rendered') 10 $caller
    Assert ($rendered.Status -eq 'RenderedOffline' -and (Test-Path (Join-Path $rendered.RunFolder 'Report.html'))) 'offline render recreates HTML/CSV'
    Assert (@(Get-ChildItem (Join-Path $rendered.RunFolder 'native') -File).Count -gt 0) 'offline render copies only manifest-verified raw evidence'
    $archive=New-AdReportArchive $rendered.RunFolder;Assert (Test-Path -LiteralPath $archive) 'optional archive created outside the hashed run directory'
    $bad=Get-Content (Join-Path $script:goodFolder 'report.json') -Raw|ConvertFrom-Json;$bad.Datasets|Add-Member -NotePropertyName '../../evil' -NotePropertyValue @();$badFile=Join-Path $temp 'bad.json';$bad|ConvertTo-Json -Depth 16|Set-Content -LiteralPath $badFile
    Assert-Throws {Invoke-AdRenderSnapshot $badFile (Join-Path $temp 'bad-render') 10 $caller} 'unknown dataset/path injection rejected'
    $native=Get-ChildItem (Join-Path $script:goodFolder 'native') -File|Select-Object -First 1;[IO.File]::AppendAllText($native.FullName,'TAMPERED')
    Assert-Throws {Invoke-AdRenderSnapshot (Join-Path $script:goodFolder 'report.json') (Join-Path $temp 'tampered-render') 10 $caller} 'tampered evidence is rejected during offline render'
    Write-Host "PASS: $checks assertions; $workflows comprehensive workflows. Synthetic directory/GPO/DNS/remoting/events; local file and AST checks only."
}finally{Remove-Item -LiteralPath $temp -Recurse -Force}
