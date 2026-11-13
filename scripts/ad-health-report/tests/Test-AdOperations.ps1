#Requires -Version 5.1
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent;$script:checks=0;$script:workflows=0
function Assert($Value,[string]$Message){if(-not $Value){throw "FAIL: $Message"};$script:checks++}
function Assert-Throws([scriptblock]$Body,[string]$Message){$threw=$false;try{&$Body|Out-Null}catch{$threw=$true};Assert $threw $Message}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Export-ADHealthReport.ps1'),[ref]$tokens,[ref]$errors)
Assert ($errors.Count -eq 0) 'source parses'
foreach($f in $ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)){. ([scriptblock]::Create($f.Extent.Text))}
$effective=Get-AdEffectiveOptions ([pscustomobject]@{FullAssessment=$true})
Assert ($effective.IncludeOperationalChecks -and $effective.IncludeEventLogs -and $effective.IncludeServiceChecks -and $effective.IncludeDcDiagnostics -and $effective.DiagnosticProfile -eq 'Extended') 'FullAssessment expands explicitly'
Assert-Throws {Get-AdEffectiveOptions ([pscustomobject]@{DiskWarningPercent=5;DiskCriticalPercent=10})} 'bad disk thresholds rejected'
Assert-Throws {Get-AdEffectiveOptions ([pscustomobject]@{TimeWarningSeconds=10;TimeCriticalSeconds=1})} 'bad time thresholds rejected'
$extended=@(Get-AdDiagnosticTests Extended)
Assert ($extended.Count -eq 17 -and $extended -notcontains 'Intersite' -and $extended -notcontains 'FrsEvent') '17 selected read-oriented native tests'
Assert (@(Get-AdDiagnosticTests Baseline).Count -eq 5) 'baseline unchanged'
$samples=@(Convert-AdTimeSamples "12:00:00, -02.5000000s`n12:00:01, +03.0000000s`n12:00:02, -04,0000000s`nERROR: 0x123" example.test dc1.example.test)
Assert ($samples.Count -eq 3 -and $samples[0].OffsetSeconds -eq -2.5 -and $samples[2].AbsoluteOffsetSeconds -eq 4) 'signed and comma-decimal time parsing'
Assert (@(Convert-AdTimeSamples 'unrecognized time output' example.test dc1.example.test).Count -eq 0) 'parse error not zero offset'
Assert ((Get-AdMedian @(3,1,2)) -eq 2 -and (Get-AdMedian @(1,2,3,4)) -eq 2.5) 'odd/even medians'

$script:scenario='full';$script:sessionRemoved=0;$script:cimCalls=New-Object 'Collections.Generic.List[string]'
function New-CimSession {param($ComputerName,$OperationTimeoutSec,$ErrorAction) [pscustomobject]@{ComputerName=$ComputerName}}
function Remove-CimSession {param($CimSession,$ErrorAction) $script:sessionRemoved++}
function Get-CimInstance {
    param($CimSession,$ClassName,$Filter,$OperationTimeoutSec,$ErrorAction)
    $script:cimCalls.Add($ClassName)
    if($ClassName -eq 'Win32_OperatingSystem'){
        if($script:scenario -eq 'host-denied'){throw 'SYNTHETIC HOST DENIED'}
        [pscustomobject]@{LastBootUpTime=[datetime]::UtcNow.AddHours(-2);TotalVisibleMemorySize=8388608;FreePhysicalMemory=4194304;Caption='SYNTHETIC Windows Server';Version='10.0';BuildNumber='20348';SystemDrive='C:'}
    }elseif($ClassName -eq 'Win32_Volume'){
        [pscustomobject]@{Name='C:\';DriveLetter='C:';Label='OS';Capacity=100GB;FreeSpace=50GB}
        [pscustomobject]@{Name='C:\ADData\';DriveLetter=$null;Label='AD';Capacity=200GB;FreeSpace=2GB}
        [pscustomobject]@{Name='\\?\Volume{SYNTHETIC}\';DriveLetter=$null;Label='Hidden';Capacity=100MB;FreeSpace=50MB}
    }else{throw 'UNEXPECTED CIM CLASS'}
}
function Invoke-CimMethod {
    param($CimSession,$Namespace,$ClassName,$MethodName,$Arguments,$OperationTimeoutSec,$ErrorAction)
    if($script:scenario -eq 'registry-denied'){return [pscustomobject]@{ReturnValue=5;sValue=$null}}
    $path=switch($Arguments.sValueName){'DSA Database file'{'C:\ADData\NTDS\ntds.dit'};'Database log files path'{'C:\ADData\Logs'};'SysVol'{'C:\Windows\SYSVOL\sysvol'}}
    [pscustomobject]@{ReturnValue=0;sValue=$path}
}
$bundle=Get-AdHostBundle example.test dc1.example.test 5
Assert ($bundle.HostRows.Count -eq 1 -and $bundle.HostRows[0].UptimeHours -gt 1) 'boot/memory snapshot'
Assert ($bundle.DiskRows.Count -eq 3 -and $bundle.Errors.Count -eq 0) 'all fixed volumes retained'
Assert (@($bundle.Paths|Where-Object{$_.Component -eq 'NTDSDatabase' -and $_.Volume -eq 'C:\ADData\'}).Count -eq 1) 'longest mount path maps NTDS'
Assert (@($bundle.DiskRows|Where-Object{$_.AssessmentScope -eq 'UnmappedSystemVolume'}).Count -eq 1) 'hidden system volume excluded from capacity alerts'
Assert ($script:sessionRemoved -eq 1 -and @($script:cimCalls|Where-Object{$_ -eq 'Win32_OperatingSystem'}).Count -eq 1) 'single OS read and CIM cleanup'
$script:scenario='host-denied';$b=Get-AdHostBundle example.test dc1.example.test 5
Assert ($b.DiskRows.Count -eq 3 -and @($b.Errors|Where-Object{$_.Component -eq 'HostMetrics'}).Count -eq 1 -and $script:sessionRemoved -eq 2) 'host failure preserves disks and cleanup'
$script:scenario='registry-denied';$b=Get-AdHostBundle example.test dc1.example.test 5
Assert (@($b.Paths|Where-Object{$_.Status -eq 'RegistryError'}).Count -eq 3) 'registry denied not invented paths'

function Invoke-AdDnsQuery {
    [CmdletBinding()]param($Name,$Type,$Resolver)
    if($script:scenario -eq 'dns-error'){$e=New-Object Management.Automation.ErrorRecord((New-Object Exception('SYNTHETIC DNS REFUSED')),'DNS_ERROR_RCODE_REFUSED',[Management.Automation.ErrorCategory]::ResourceUnavailable,$Name);$PSCmdlet.ThrowTerminatingError($e)}
    if($Type -eq 'AAAA'){return}
    if($Type -eq 'A'){[pscustomobject]@{IPAddress='192.0.2.10';TTL=300}}
    else{[pscustomobject]@{NameTarget='dc1.example.test';Port=389;Priority=0;Weight=100;TTL=300}}
}
$script:scenario='full';Assert ((Get-AdDnsObservation example.test dc1.example.test dc1.example.test AAAA '').Status -eq 'NotPresent') 'missing AAAA separate from query error'
$script:scenario='dns-error';Assert ((Get-AdDnsObservation example.test dc1.example.test dc1.example.test A '').Status -eq 'QueryError') 'DNS error retained'
function Invoke-AdTimeQuery {
    param($DC,$Query,$Samples,$TimeoutSeconds)
    if($Query -ne 'Stripchart'){return [pscustomobject]@{TimedOut=$false;ExitCode=0;Text='SYNTHETIC localized evidence'}}
    $text="12:00:00, -02.5000000s`n12:00:01, -03.5000000s`n12:00:02, -04.5000000s"
    if($script:scenario -eq 'time-unknown'){$text='UNRECOGNIZED LOCALE'}
    [pscustomobject]@{TimedOut=($script:scenario -eq 'time-timeout');ExitCode=0;Text=$text}
}
$script:scenario='full';$time=Get-AdTimeBundle example.test dc1.example.test 3 5
Assert ($time.Summary.Status -eq 'Measured' -and $time.Summary.MedianOffsetSeconds -eq -3.5 -and $time.Summary.MedianAbsoluteOffsetSeconds -eq 3.5) 'negative deviation evaluated by magnitude'
$script:scenario='time-unknown';$time=Get-AdTimeBundle example.test dc1.example.test 3 5
Assert ($time.Summary.Status -eq 'InsufficientOrUnrecognizedSamples' -and $null -eq $time.Summary.MedianOffsetSeconds) 'unknown time never zero/pass'
function Invoke-AdEventQuery {
    [CmdletBinding()]param($DC,$Log,$Start,$End,$Maximum)
    if($script:scenario -eq 'event-denied'){throw 'SYNTHETIC EVENT ACCESS DENIED'}
    if($script:scenario -eq 'empty-events'){$e=New-Object Management.Automation.ErrorRecord((New-Object Exception('SYNTHETIC NO EVENTS')),'NoMatchingEventsFound',[Management.Automation.ErrorCategory]::ObjectNotFound,$Log);$PSCmdlet.ThrowTerminatingError($e)}
    if($Log -ne 'System'){return}
    foreach($i in 1..$Maximum){[pscustomobject]@{TimeCreated=[datetime]::UtcNow;Id=1000+$i;Level=2;ProviderName='SYNTHETIC';RecordId=$i;Message='=SYNTHETIC <script>alert(1)</script>'}}
}
$script:scenario='full';$events=Get-AdEventBundle example.test dc1.example.test System 24 2
Assert ($events.Rows.Count -eq 2 -and $events.Coverage.Truncated) 'event cap explicitly recorded'
$script:scenario='empty-events';Assert ((Get-AdEventBundle example.test dc1.example.test System 24 2).Coverage.Status -eq 'Collected') 'no matching events means successful empty query'

# Reuse only synthetic fixture function definitions from the regression suite.
$t=$null;$e=$null;$fixtures=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Test-AdHealth.ps1'),[ref]$t,[ref]$e)
foreach($name in @('New-FixtureAccount','New-FixturePolicy','Invoke-AdQuery')){$f=$fixtures.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true);. ([scriptblock]::Create($f.Extent.Text))}
function Initialize-AdRuntime {}
function Get-AdPingObservation {param($Domain,$DC,$TimeoutSeconds) [pscustomobject]@{Domain=$Domain;DC=$DC;Probe='ICMP';Status='NoReply';RoundtripMs=$null;Address='';Error='SYNTHETIC ICMP BLOCKED'}}
function Get-AdServiceObservations {param($DC,$TimeoutSeconds,$Domain) [pscustomobject]@{Domain=$Domain;DC=$DC;Name='NTDS';State='Running';StartMode='Auto';Observation='Observed'}}
function Invoke-AdDcdiag {param($DC,$Test,$TimeoutSeconds) $script:nativeTests.Add($Test);[pscustomobject]@{ExitCode=0;TimedOut=$false;Text='SYNTHETIC READ-ONLY TEST'}}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('fmodel-ad11-tests-'+[guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory $temp
try{
    foreach($scenario in @('full','dns-error','host-denied','registry-denied','time-unknown','time-timeout','event-denied','empty-events','baseline','whatif')){
        $script:scenario=$scenario;$script:case='clean';$script:queries=New-Object 'Collections.Generic.List[object]';$script:nativeTests=New-Object 'Collections.Generic.List[string]'
        $options=[pscustomobject]@{Server='dc1.example.test';OutputPath=(Join-Path $temp $scenario);FullAssessment=($scenario -ne 'baseline');MaxEventsPerLog=2;MaxHtmlRows=10}
        $caller=[pscustomobject]@{Allow=($scenario -ne 'whatif')};$caller|Add-Member ScriptMethod ShouldProcess {param($Target,$Action)$this.Allow}
        $result=Invoke-AdAssessment $options $caller
        if($scenario -eq 'whatif'){Assert ($result.Status -eq 'NotCollected' -and -not (Test-Path $options.OutputPath)) 'full WhatIf does not start collectors/create files';$script:workflows++;continue}
        $r=Get-Content -LiteralPath (Join-Path $result.RunFolder 'report.json') -Raw -Encoding UTF8|ConvertFrom-Json
        $schemas=Get-AdSchemas
        Assert ($schemas.Count -eq 63) '63 datasets'
        foreach($n in $schemas.Keys){Assert (Test-Path (Join-Path $result.RunFolder ($n.ToLowerInvariant()+'.csv'))) "CSV $n present"}
        Assert (@($r.Datasets.DCSummary).Count -eq 1) "$scenario DC summary present"
        Assert (@($r.Datasets.Timings).Count -gt 0 -and @($r.Datasets.Timings|Where-Object{$_.DurationSeconds -lt 0}).Count -eq 0) 'total timing seconds retained'
        if($scenario -eq 'baseline'){
            Assert ($script:nativeTests.Count -eq 0 -and @($r.Datasets.Disks).Count -eq 0) 'baseline does not run optional operational checks'
        }else{
            Assert ($script:nativeTests.Count -eq 17 -and $script:nativeTests -notcontains 'Intersite') 'full uses extended read-only tests'
            Assert ($r.Datasets.Connectivity[0].Status -eq 'NoReply' -and @($r.Datasets.Disks).Count -eq 3) 'ICMP failure never gates disks, time or diagnostics'
        }
        if($scenario -eq 'full'){
            Assert ($r.Datasets.DCSummary[0].UptimeHours -gt 1 -and $r.Datasets.DCSummary[0].MedianAbsoluteOffsetSeconds -eq 3.5) 'dashboard contains actual uptime and time numbers'
            Assert ($r.Datasets.DCSummary[0].ProcessingSeconds -gt 0 -and @($r.Datasets.Timings|Where-Object{$_.Dataset -eq 'HostBundle'}).Count -eq 1) 'real DC and host bundle durations recorded'
            Assert ($r.Status -eq 'CompletedWithFindings' -and $result.ExitCode -eq 2) 'full review status'
            Assert (@($r.Datasets.Findings|Where-Object{$_.RuleId -eq 'DC-DISK-SPACE'}).Count -eq 1) 'low mapped-volume capacity flagged; hidden volume not flagged'
            Assert (@($r.Datasets.Findings|Where-Object{$_.RuleId -eq 'DC-TIME-OFFSET'}).Count -eq 1) 'negative time offset finding'
            Assert (@($r.Datasets.EventLogCoverage|Where-Object{$_.Truncated}).Count -eq 1) 'bounded event coverage explicit'
            $eventCsv=@(Import-Csv (Join-Path $result.RunFolder 'events.csv'))
            Assert ($eventCsv[0].Message.StartsWith("'=")) 'event CSV formula protected'
            $html=[IO.File]::ReadAllText((Join-Path $result.RunFolder 'Report.html'))
            Assert ($html.Contains('dcsummary.csv') -and $html.Contains('timesummary.csv') -and $html.Contains('&lt;script&gt;')) 'all operational HTML sections and encoded messages'
        }
        if($scenario -in @('dns-error','host-denied','registry-denied','time-unknown','time-timeout','event-denied')){
            Assert ($r.Status -eq 'Partial' -and $result.ExitCode -eq 2 -and $r.Datasets.DCSummary[0].Observation -eq 'Incomplete') "$scenario never appears complete/healthy"
        }
        if($scenario -eq 'host-denied'){Assert (@($r.Datasets.Disks).Count -eq 3) 'host permission failure preserves independent disks'}
        if($scenario -eq 'empty-events'){Assert (@($r.Datasets.Events).Count -eq 0 -and @($r.Datasets.CollectionErrors|Where-Object{$_.Dataset -eq 'Events'}).Count -eq 0) 'empty log not error'}
        $script:workflows++
    }
    Write-Host "PASS: $checks assertions; $workflows operational workflows. Synthetic AD/DNS/CIM/time/events only."
}finally{Remove-Item -LiteralPath $temp -Recurse -Force}
