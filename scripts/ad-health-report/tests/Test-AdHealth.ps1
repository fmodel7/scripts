#Requires -Version 5.1
# Offline synthetic tests. AST loads functions only; operational entry is never run.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
$source=Join-Path $root 'Export-ADHealthReport.ps1'
$script:assertions=0;$script:workflows=0
function Assert($Condition,[string]$Message){if(-not $Condition){throw "FAIL: $Message"};$script:assertions++}
function Assert-Throws([scriptblock]$Body,[string]$Message){$failed=$false;try{& $Body|Out-Null}catch{$failed=$true};Assert $failed $Message}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
Assert ($errors.Count -eq 0) 'standalone parses'
Assert ($ast.ScriptRequirements.RequiredPSVersion.Major -eq 5) 'PS5 minimum'
Assert ($ast.ParamBlock.Attributes.Extent.Text -match 'SupportsShouldProcess') 'supports WhatIf/Confirm'
foreach($definition in $ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)){
    . ([scriptblock]::Create($definition.Extent.Text))
}
Assert (-not ($ast.FindAll({param($node)$node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Test-Connection'},$true)).Count) 'no ping gate'
Assert ((Get-AdSchemaLabel 88) -eq 'Windows Server 2019 / 2022') 'schema88 shared by2019 and2022'
Assert ((Get-AdSchemaLabel 91) -eq 'Windows Server 2025') 'schema91'
Assert ((Get-AdSchemaLabel 999) -match 'Unknown') 'unknown schema stays unknown'
Assert ((Get-AdComputerClass ([pscustomobject]@{OperatingSystem=$null;userAccountControl=0})) -eq 'Unknown') 'missing OS not workstation'
Assert ((Get-AdComputerClass ([pscustomobject]@{OperatingSystem=$null;userAccountControl=8192})) -eq 'DomainController') 'DC from UAC even without OS'
Assert ((Get-AdComputerClass ([pscustomobject]@{OperatingSystem='Windows Server 2022';userAccountControl=0})) -eq 'ServerHint') 'server OS hint'
Assert ((Get-AdComputerClass ([pscustomobject]@{OperatingSystem='Windows 11 Pro';userAccountControl=0})) -eq 'WindowsClientHint') 'Windows client OS hint'
Assert ((Get-AdComputerClass ([pscustomobject]@{OperatingSystem='Linux';userAccountControl=0})) -eq 'Other') 'other OS'
Assert ((Get-AdParentDn 'CN=Doe\, Jane,OU=People,DC=example,DC=test') -eq 'OU=People,DC=example,DC=test') 'escaped comma DN'
Assert ((Get-AdParentDn 'CN=slash\\,OU=People,DC=example,DC=test') -eq 'OU=People,DC=example,DC=test') 'even backslashes DN separator'
Assert ((Get-AdParentDn '') -eq '') 'empty DN'
Assert ((Convert-AdDate $null) -eq '') 'null date stays unknown'
Assert ((Convert-AdDate 'invalid') -eq '') 'invalid date stays unknown'
Assert ((Convert-AdSid ([pscustomobject]@{Value='S-1-0-0'})) -eq 'S-1-0-0') 'SID object conversion'
foreach($text in @('=1+1','+formula','-formula','@SUM(A1:A2)',"`t=CMD",'  =formula')){
    Assert ((Convert-AdCsvValue $text).StartsWith("'")) 'CSV formula neutralization'
}
Assert ((Convert-AdCsvValue 'ordinary value') -eq 'ordinary value') 'ordinary CSV unchanged'
Assert-Throws {Invoke-AdDcdiag -DC "dc.example.test`n/evil" -Test Services -TimeoutSeconds 1} 'native host injection rejected'
Assert-Throws {Invoke-AdDcdiag -DC dc.example.test -Test InvalidTest -TimeoutSeconds 1} 'native test allowlist'

$temp=Join-Path ([IO.Path]::GetTempPath()) ('fmodel-ad-tests-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
try{
    $csv=Join-Path $temp 'roundtrip.csv'
    $csvRow=[pscustomobject]@{Name='São Paulo';Value="a, b `"quoted`"`nsecond line";Formula='=1+1'}
    Write-AdCsv $csv @('Name','Value','Formula') @($csvRow)
    $bytes=[IO.File]::ReadAllBytes($csv)
    Assert ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) 'CSV UTF8 BOM'
    $parsed=@(Import-Csv -LiteralPath $csv)
    Assert ($parsed.Count -eq 1 -and $parsed[0].Name -eq 'São Paulo' -and $parsed[0].Value -eq $csvRow.Value) 'CSV quote/newline/unicode roundtrip'
    Assert ($parsed[0].Formula -eq "'=1+1") 'CSV formula sanitized in serialized file'
    $empty=Join-Path $temp 'empty.csv';Write-AdCsv $empty @('Name','Value') @()
    Assert (([IO.File]::ReadAllText($empty)).Trim() -eq '"Name","Value"') 'empty CSV retains header'
    Assert ((Resolve-AdOutputPath $temp) -eq $temp) 'local output path resolves'
    Assert-Throws {Resolve-AdOutputPath (Join-Path $temp 'bad[1]')} 'output wildcards rejected'
    Assert-Throws {Resolve-AdOutputPath $csv} 'output file rejected'

    # Harmless real-process checks for the native runner, never dcdiag itself.
    $nativeSupported=$false
    if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){
        $script:nativePath=Join-Path $temp 'synthetic-dcdiag.sh'
        [IO.File]::WriteAllText($script:nativePath,"#!/bin/sh`ncase `"`$1`" in`n /s:timeout.example.test) sleep 5 ;;`n /s:error.example.test) echo synthetic-stderr >&2; exit 7 ;;`n *) echo synthetic-stdout ;;`nesac`n")
        & chmod +x $script:nativePath
        if($LASTEXITCODE -ne 0){throw 'chmod failed'}
        $nativeSupported=$true
    }elseif($PSVersionTable.PSEdition -eq 'Desktop'){
        $script:nativePath=Join-Path $temp 'synthetic-dcdiag.exe'
        $code='using System; using System.Threading; public class FmodelSyntheticDcdiag { public static void Main(string[] args) { if(args.Length>0 && args[0].Contains("timeout")){Thread.Sleep(5000);} else if(args.Length>0 && args[0].Contains("error")){Console.Error.WriteLine("synthetic-stderr");Environment.Exit(7);} else {Console.WriteLine("synthetic-stdout");} } }'
        Add-Type -TypeDefinition $code -OutputAssembly $script:nativePath -OutputType ConsoleApplication
        $nativeSupported=$true
    }
    if($nativeSupported){
        function Get-AdNativePath {$script:nativePath}
        $native=Invoke-AdDcdiag dc.example.test Services 2
        Assert ($native.ExitCode -eq 0 -and -not $native.TimedOut -and $native.Text -match 'synthetic-stdout') 'real native stdout/exit0'
        $native=Invoke-AdDcdiag error.example.test Services 2
        Assert ($native.ExitCode -eq 7 -and -not $native.TimedOut -and $native.Text -match 'synthetic-stderr') 'real native stderr/nonzero'
        $watch=[Diagnostics.Stopwatch]::StartNew();$native=Invoke-AdDcdiag timeout.example.test Services 1;$watch.Stop()
        Assert ($native.TimedOut -and $null -eq $native.ExitCode) 'real native timeout'
        Assert ($watch.Elapsed.TotalSeconds -lt 8) 'native timeout bounded'
    }

    function Initialize-AdRuntime {}
    function New-FixtureAccount {
        param([string]$Name,[string]$Domain,[string]$Kind,[bool]$Enabled,[bool]$Old,[bool]$Unknown)
        $dn=if($Domain -eq 'example.test'){'DC=example,DC=test'}else{'DC=child,DC=example,DC=test'}
        $last=if($Unknown){$null}elseif($Old){[datetime]::UtcNow.AddDays(-200)}else{[datetime]::UtcNow.AddDays(-1)}
        [pscustomobject]@{Name=$Name;DNSHostName="$Name.$Domain";SamAccountName=$Name;UserPrincipalName="$Name@$Domain";DistinguishedName="CN=$Name,OU=People,$dn";SID=[pscustomobject]@{Value='S-1-5-21-100-200-300-1001'};ObjectGUID=[guid]'11111111-1111-1111-1111-111111111111';Enabled=$Enabled;LockedOut=$false;OperatingSystem=if($Kind -eq 'Computer'){'Windows 11 Pro'}else{$null};OperatingSystemVersion='10.0';userAccountControl=0;LastLogonDate=$last;PasswordLastSet=[datetime]::UtcNow.AddDays(-30);whenCreated=[datetime]::UtcNow.AddYears(-1);whenChanged=[datetime]::UtcNow.AddDays(-1);AccountExpirationDate=$null;TrustedForDelegation=$false;TrustedToAuthForDelegation=$false;PasswordNeverExpires=$false;PasswordNotRequired=$false;DoesNotRequirePreAuth=$false;AdminCount=0;ServicePrincipalNames=@();'msDS-SupportedEncryptionTypes'=24}
    }
    function New-FixturePolicy {
        param([bool]$Fine)
        [pscustomobject]@{Name=if($Fine){'SYNTHETIC-FGPP'}else{'Default'};Precedence=if($Fine){1}else{$null};MinPasswordLength=14;ComplexityEnabled=$true;ReversibleEncryptionEnabled=($Fine -and $script:case -ne 'clean');PasswordHistoryCount=24;MaxPasswordAge=[timespan]::FromDays(42);MinPasswordAge=[timespan]::FromDays(1);LockoutThreshold=10;LockoutDuration=[timespan]::FromMinutes(30);AppliesTo=@('CN=Group,DC=example,DC=test')}
    }
    function Invoke-AdQuery {
        param([string]$Command,[hashtable]$Arguments)
        $script:queries.Add([pscustomobject]@{Command=$Command;Arguments=$Arguments.Clone()})
        $server=if($Arguments.ContainsKey('Server')){[string]$Arguments.Server}else{''}
        $domain=if($server -like '*child.example.test'){'child.example.test'}else{'example.test'}
        $dn=if($domain -eq 'example.test'){'DC=example,DC=test'}else{'DC=child,DC=example,DC=test'}
        $sid=if($domain -eq 'example.test'){'S-1-5-21-100-200-300'}else{'S-1-5-21-400-500-600'}
        switch($Command){
            'Get-ADRootDSE' {
                if($script:case -eq 'bootstrap-failure'){throw 'SYNTHETIC AD CONNECTION FAILURE'}
                [pscustomobject]@{dnsHostName="dc1.$domain";schemaNamingContext='CN=Schema,CN=Configuration,DC=example,DC=test'}
            }
            'Get-ADDomain' {[pscustomobject]@{DNSRoot=$domain;DistinguishedName=$dn;DomainMode='Windows2016Domain';DomainSID=[pscustomobject]@{Value=$sid};PDCEmulator="dc1.$domain";RIDMaster="dc1.$domain";InfrastructureMaster="dc1.$domain"}}
            'Get-ADForest' {[pscustomobject]@{Name='example.test';RootDomain='example.test';ForestMode='Windows2016Forest';SchemaMaster='dc1.example.test';DomainNamingMaster='dc1.example.test';Domains=@('example.test','child.example.test');Sites=@('SYNTHETIC-SITE')}}
            'Get-ADObject' {if($script:case -eq 'schema-error'){throw 'SYNTHETIC SCHEMA DENIED'};[pscustomobject]@{objectVersion=88}}
            'Get-ADDomainController' {
                if($Arguments.ContainsKey('Discover')){
                    if($script:case -eq 'forest-child-error'){throw 'SYNTHETIC CHILD ADWS FAILURE'}
                    [pscustomobject]@{HostName=@('dc1.child.example.test')}
                }else{[pscustomobject]@{HostName="dc1.$domain";Site='SYNTHETIC-SITE';OperatingSystem='Windows Server 2022';OperatingSystemVersion='10.0';IsGlobalCatalog=$true;IsReadOnly=$false;OperationMasterRoles=@('PDCEmulator','RIDMaster','InfrastructureMaster')}}
            }
            'Get-ADComputer' {
                $stale=New-FixtureAccount 'stale-server' $domain Computer $true ($script:case -ne 'clean') $false;$stale.OperatingSystem='Windows Server 2022';$stale
                New-FixtureAccount 'client' $domain Computer $true $false $false
                $missing=New-FixtureAccount 'missing-os' $domain Computer $true $true $true;$missing.OperatingSystem=$null;$missing
                $dc=New-FixtureAccount 'dc-account' $domain Computer $true $false $false;$dc.userAccountControl=8192;$dc.TrustedForDelegation=$true;$dc.OperatingSystem=$null;$dc
                $other=New-FixtureAccount 'other-os' $domain Computer $true $false $false;$other.OperatingSystem='Linux';$other
            }
            'Get-ADUser' {
                if($script:case -eq 'user-error'){throw 'SYNTHETIC USER DENIED'}
                New-FixtureAccount 'stale-user' $domain User $true ($script:case -ne 'clean') $false
                New-FixtureAccount 'unknown-logon' $domain User $true $true $true
                New-FixtureAccount 'disabled-old' $domain User $false $true $false
                $risky=New-FixtureAccount 'risky-user' $domain User $true $false $false
                if($script:case -ne 'clean'){$risky.PasswordNeverExpires=$true;$risky.PasswordNotRequired=$true;$risky.DoesNotRequirePreAuth=$true;$risky.TrustedForDelegation=$true;$risky.ServicePrincipalNames=@('HTTP/synthetic')};$risky
            }
            'Get-ADGroup' {
                $sids=@("$sid-512",'S-1-5-32-544','S-1-5-32-548','S-1-5-32-549','S-1-5-32-551')
                if($domain -eq 'example.test'){$sids+=@("$sid-518","$sid-519")}
                if($script:case -eq 'missing-privileged-group'){$sids=@($sids|Where-Object{$_ -ne "$sid-519"})}
                foreach($groupSid in $sids){[pscustomobject]@{Name="SYNTHETIC-$groupSid";SamAccountName="SYNTHETIC-$groupSid";SID=[pscustomobject]@{Value=$groupSid};DistinguishedName="CN=$groupSid,CN=Users,$dn";GroupCategory='Security';GroupScope='Global';AdminCount=1;whenCreated=[datetime]::UtcNow.AddYears(-1);whenChanged=[datetime]::UtcNow}}
            }
            'Get-ADGroupMember' {[pscustomobject]@{Name='SYNTHETIC-MEMBER';SID=[pscustomobject]@{Value="$sid-1100"};objectClass='user';DistinguishedName="CN=SYNTHETIC-MEMBER,CN=Users,$dn"}}
            'Get-ADOrganizationalUnit' {[pscustomobject]@{Name='SYNTHETIC-OU';DistinguishedName="OU=SYNTHETIC-OU,$dn";ProtectedFromAccidentalDeletion=$true;whenCreated=[datetime]::UtcNow.AddYears(-1);whenChanged=[datetime]::UtcNow}}
            'Get-ADDefaultDomainPasswordPolicy' {New-FixturePolicy $false}
            'Get-ADFineGrainedPasswordPolicy' {New-FixturePolicy $true}
            'Get-ADTrust' {[pscustomobject]@{Name='trusted.example.test';Direction='Bidirectional';TrustType='Uplevel';ForestTransitive=$true;SelectiveAuthentication=$true;SIDFilteringQuarantined=$false;SIDFilteringForestAware=$true}}
            'Get-ADReplicationPartnerMetadata' {[pscustomobject]@{Partition=$dn;Partner='CN=SYNTHETIC-PARTNER';LastReplicationAttempt=[datetime]::UtcNow;LastReplicationSuccess=[datetime]::UtcNow.AddMinutes(-5);LastReplicationResult=if($script:case -eq 'replication-findings'){1722}else{0};ConsecutiveReplicationFailures=if($script:case -eq 'replication-findings'){2}else{0}}}
            'Get-ADReplicationFailure' {if($script:case -eq 'replication-findings'){[pscustomobject]@{Partner='CN=SYNTHETIC-PARTNER';FailureType='Link';FailureCount=2;FirstFailureTime=[datetime]::UtcNow.AddHours(-1);LastError=1722}}}
            default {throw "UNEXPECTED QUERY: $Command"}
        }
    }
    function Get-AdServiceObservations {
        param([string]$DC,[int]$TimeoutSeconds,[string]$Domain)
        $script:serviceCalls++
        if($script:case -eq 'service-error'){throw 'SYNTHETIC CIM TIMEOUT'}
        [pscustomobject]@{Domain=$Domain;DC=$DC;Name='NTDS';State='Running';StartMode='Auto';Observation='Observed'}
    }
    function Invoke-AdDcdiag {
        param([string]$DC,[string]$Test,[int]$TimeoutSeconds)
        $script:nativeCalls++
        [pscustomobject]@{ExitCode=if($script:case -eq 'native-timeout'){$null}elseif($script:case -eq 'native-error'){7}else{0};TimedOut=($script:case -eq 'native-timeout');Text='SYNTHETIC ONLY - not dcdiag evidence'}
    }
    function Invoke-Case {
        param([string]$Case,[string]$Expected,[int]$Exit)
        $script:case=$Case;$script:queries=New-Object 'Collections.Generic.List[object]';$script:serviceCalls=0;$script:nativeCalls=0
        $base=Join-Path $temp $Case
        $options=[pscustomobject]@{Server='dc1.example.test';Scope=if($Case -in @('forest-child-error','forest-success')){'Forest'}else{'Domain'};OutputPath=$base;InactiveDays=90;PageSize=500;SkipUserInventory=($Case -eq 'skip');SkipPrivilegedMembers=($Case -eq 'skip');IncludeServiceChecks=($Case -in @('optional-success','service-error'));IncludeDcDiagnostics=($Case -in @('optional-success','native-timeout','native-error'));TimeoutSeconds=5;MaxHtmlRows=10}
        $caller=[pscustomobject]@{Allow=($Case -ne 'whatif')};$caller|Add-Member ScriptMethod ShouldProcess {param($Target,$Action)$this.Allow}
        $result=$null;$failed=$false
        try{$result=Invoke-AdAssessment $options $caller}catch{$failed=$true;$script:caseError=$_.Exception.Message}
        if($Expected -eq 'PreflightBlocked'){
            Assert $failed "$Case preflight blocked";Assert (-not (Test-Path -LiteralPath $base)) "$Case no files"
            $script:workflows++;return
        }
        Assert (-not $failed) "$Case returned normally $script:caseError"
        Assert ($result.Status -eq $Expected) "$Case status $($result.Status) expected $Expected"
        Assert ($result.ExitCode -eq $Exit) "$Case exit"
        if($Case -eq 'whatif'){
            Assert (-not (Test-Path -LiteralPath $base)) 'WhatIf writes no files'
            Assert ($script:serviceCalls -eq 0 -and $script:nativeCalls -eq 0) 'WhatIf no optional diagnostics'
            $script:workflows++;return
        }
        Assert (Test-Path -LiteralPath (Join-Path $result.RunFolder 'Report.html')) "$Case HTML exists"
        $report=Get-Content -LiteralPath (Join-Path $result.RunFolder 'report.json') -Raw|ConvertFrom-Json
        Assert ($report.Status -eq $Expected) "$Case JSON status"
        $schemas=Get-AdSchemas
        foreach($name in $schemas.Keys){Assert (Test-Path -LiteralPath (Join-Path $result.RunFolder ($name.ToLowerInvariant()+'.csv'))) "$Case CSV $name"}
        # PS5.1 returns a JSON array as one pipeline object; do not wrap it in @().
        $manifest=Get-Content (Join-Path $result.RunFolder 'run-manifest.json') -Raw|ConvertFrom-Json
        foreach($record in $manifest){Assert ((Get-FileHash -LiteralPath (Join-Path $result.RunFolder $record.Path) -Algorithm SHA256).Hash -ieq $record.SHA256) "$Case manifest $($record.Path)"}
        $computerCalls=@($script:queries|Where-Object{$_.Command -eq 'Get-ADComputer'})
        Assert ($computerCalls.Count -eq @($report.Datasets.Domains).Count) "$Case one computer inventory query per collected domain"
        Assert (@($computerCalls|Where-Object{$_.Arguments.Properties -contains '*'}).Count -eq 0) "$Case no wildcard account properties"
        if($Case -eq 'user-error'){
            Assert ($null -eq $report.Datasets.Domains[0].Users) 'failed user total null, not zero'
            Assert (@($report.Datasets.Coverage|Where-Object{$_.Dataset -eq 'Users' -and $_.Status -eq 'Failed'}).Count -eq 1) 'user failure coverage'
        }
        if($Case -eq 'skip'){
            Assert ($null -eq $report.Datasets.Domains[0].Users) 'skipped user total unknown'
            Assert (@($report.Datasets.Users).Count -eq 0 -and @($report.Datasets.PrivilegedMembers).Count -eq 0) 'skipped inventories empty'
            Assert (@($script:queries|Where-Object{$_.Command -in @('Get-ADUser','Get-ADGroupMember')}).Count -eq 0) 'skip avoids account/member queries'
        }
        if($Case -eq 'baseline'){
            Assert (@($report.Datasets.Computers).Count -eq 5 -and @($report.Datasets.Users).Count -eq 4) 'account row counts'
            Assert (@($report.Datasets.Groups).Count -eq 7 -and @($report.Datasets.PrivilegedMembers).Count -eq 7) 'privileged SIDs and direct memberships'
            Assert (@($report.Datasets.PrivilegedMembers|Where-Object{$_.MembershipType -ne 'DirectOnly'}).Count -eq 0) 'no recursive membership claim'
            Assert (@($report.Datasets.Findings|Where-Object{$_.RuleId -eq 'ACCOUNT-STALE-HINT'}).Count -eq 2) 'only enabled known-old accounts flagged stale'
            Assert (@($report.Datasets.Findings|Where-Object{$_.Target -in @('unknown-logon','disabled-old')}).Count -eq 0) 'unknown and disabled users not flagged'
            Assert (@($report.Datasets.Findings|Where-Object{$_.RuleId -eq 'UNCONSTRAINED-DELEGATION' -and $_.Target -eq 'dc-account'}).Count -eq 0) 'DC default delegation not flagged'
            Assert (@($report.Datasets.Computers|Where-Object{$_.Name -eq 'missing-os' -and $_.Category -eq 'Unknown'}).Count -eq 1) 'missing OS preserved'
            Assert (@($report.Datasets.PasswordPolicies).Count -eq 2 -and $report.Datasets.PasswordPolicies[0].MaxPasswordAgeDays -eq 42) 'default and fine-grained policy conversion'
            Assert (@($report.Datasets.OrganizationalUnits).Count -eq 1 -and @($report.Datasets.Trusts).Count -eq 1) 'OU and trust collected'
            Assert ($script:serviceCalls -eq 0 -and $script:nativeCalls -eq 0) 'optional network checks off by default'
        }
        if($Case -eq 'forest-child-error'){
            Assert (@($report.Datasets.Domains).Count -eq 1) 'forest partial retains root domain'
            Assert (@($report.Datasets.CollectionErrors|Where-Object{$_.Dataset -eq 'DomainBootstrap'}).Count -eq 1) 'forest child bootstrap error retained'
        }
        if($Case -eq 'forest-success'){Assert (@($report.Datasets.Domains).Count -eq 2 -and @($report.Datasets.Computers).Count -eq 10) 'forest domain coverage consistent'}
        if($Case -eq 'replication-findings'){Assert (@($report.Datasets.Findings|Where-Object{$_.RuleId -like 'REPLICATION-*'}).Count -eq 2) 'replication metadata and failure findings'}
        if($Case -eq 'optional-success'){Assert ($script:serviceCalls -eq 1 -and $script:nativeCalls -eq 5 -and @($report.Datasets.NativeDiagnostics).Count -eq 5) 'optional CIM/native calls without ping'}
        if($Case -in @('native-timeout','native-error')){Assert (@($report.Datasets.NativeDiagnostics).Count -eq 5 -and @($report.Datasets.CollectionErrors|Where-Object{$_.Dataset -eq 'NativeDiagnostics'}).Count -eq 5) 'native failure retains typed rows and errors'}
        $script:workflows++
    }
    $script:caseError=''
    Invoke-Case baseline CompletedWithFindings 2
    Invoke-Case clean Completed 0
    Invoke-Case user-error Partial 2
    Invoke-Case skip CompletedWithFindings 2
    Invoke-Case forest-child-error Partial 2
    Invoke-Case forest-success CompletedWithFindings 2
    Invoke-Case optional-success CompletedWithFindings 2
    Invoke-Case service-error Partial 2
    Invoke-Case native-timeout Partial 2
    Invoke-Case native-error Partial 2
    Invoke-Case schema-error Partial 2
    Invoke-Case missing-privileged-group Partial 2
    Invoke-Case replication-findings CompletedWithFindings 2
    Invoke-Case whatif NotCollected 0
    Invoke-Case bootstrap-failure PreflightBlocked 1

    $htmlReport=[pscustomobject]@{Version='1.0.0';RunId='SYNTHETIC';StartedUtc=[datetime]::UtcNow;EndedUtc=[datetime]::UtcNow;Status='Partial';Parameters=[pscustomobject]@{Scope='Domain';Server='example.test';InactiveDays=90;MaxHtmlRows=1};Datasets=[pscustomobject]@{Coverage=@();CollectionErrors=@([pscustomobject]@{Message='<img src=x onerror=alert(1)>'});Findings=@([pscustomobject]@{Severity='High';Target='</script><script>alert(1)</script>'},[pscustomobject]@{Severity='Info';Target='second row'});OrganizationalUnits=@([pscustomobject]@{Name='São Paulo'});ExtraDataset=@([pscustomobject]@{Value='safe'})}}
    $htmlPath=Join-Path $temp 'renderer.html';Write-AdHtmlReport $htmlPath $htmlReport
    $html=[IO.File]::ReadAllText($htmlPath)
    Assert ($html.Contains('&lt;img src=x onerror=alert(1)&gt;') -and -not $html.Contains('<img src=x')) 'HTML AD data escaped'
    Assert ($html.Contains('&lt;/script&gt;&lt;script&gt;alert(1)&lt;/script&gt;') -and -not $html.Contains('<script>alert(1)')) 'HTML script injection escaped'
    Assert ($html.Contains('HTML limitado a 1 de 2') -and $html.Contains('extradataset.csv') -and $html.Contains('organizationalunits.csv')) 'HTML cap and dynamic CSV links'
    Assert ($html.Contains('role="status"') -and $html.Contains('scope="col"') -and -not $html.Contains('innerHTML')) 'HTML accessible controls and safe DOM API'
    $nonce=[regex]::Match($html,"script-src 'nonce-([^']+)'").Groups[1].Value
    Assert ($nonce -ne '' -and $html.Contains('nonce="'+$nonce+'"')) 'HTML CSP nonce matches script'
    function Test-ActualWhatIf{[CmdletBinding(SupportsShouldProcess)]param();$PSCmdlet.ShouldProcess('SYNTHETIC','SYNTHETIC')}
    Assert (-not (Test-ActualWhatIf -WhatIf)) 'actual ShouldProcess WhatIf'
    Write-Host "PASS: $assertions assertions; $workflows synthetic workflows. No real AD queries, dcdiag or network connection. Native-process helper checks=$nativeSupported."
}finally{Remove-Item -LiteralPath $temp -Recurse -Force}
