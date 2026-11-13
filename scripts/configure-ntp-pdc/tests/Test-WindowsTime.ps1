#Requires -Version 5.1
# Offline tests: extract functions through AST; never execute operational entry points.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$tool=Split-Path $PSScriptRoot -Parent
$checks=0
function Assert($Condition,[string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}
function Assert-Throws([scriptblock]$Body,[string]$Message) {
    $threw=$false
    try { & $Body | Out-Null } catch { $threw=$true }
    Assert $threw $Message
}
$functionSets=@()
foreach($file in @('Configure-NTP-PDC.ps1','Configure-Time-DOMHIER.ps1')) {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $tool $file),[ref]$tokens,[ref]$errors)
    Assert ($errors.Count -eq 0) "$file parses"
    Assert ($ast.ScriptRequirements.RequiredPSVersion.Major -eq 5) "$file requires PS5+"
    Assert $ast.ScriptRequirements.IsElevationRequired "$file requires elevation"
    Assert ($ast.ParamBlock.Parameters.Count -eq 0) "$file has no custom parameters"
    $functions=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$true))
    $functionSets+=,($functions | ForEach-Object { $_.Extent.Text })
}
Assert (($functionSets[0] -join "`n") -ceq ($functionSets[1] -join "`n")) 'identical embedded engine in both standalone files'
foreach($definition in $functionSets[0]) { . ([scriptblock]::Create($definition)) }

$ctx=[pscustomobject]@{
    Computer='dc1.example.test'; RootPdc='dc1.example.test'; IsDC=$true
    PolicyPresent=$false; StartMode='Auto'; ServiceState='Running'; Domain='example.test'
    Operator='<SYNTHETIC>&operator'; OperatorSid='S-1-0-0'; Manufacturer='SYNTHETIC'; Model='SYNTHETIC'
    LocalAddresses=@('192.0.2.10')
    Settings=[pscustomobject]@{Type='NT5DS'; NtpServer='old.example.test,0x8'; AnnounceFlags=10; NtpClientEnabled=1; NtpServerEnabled=1}
}
function Copy-Context { $ctx | ConvertTo-Json -Depth 6 | ConvertFrom-Json }
Assert-Throws { Assert-TimeTarget $ctx 'DOMHIER' } 'DOMHIER blocks root PDC'
$other=Copy-Context; $other.Computer='member.example.test'; $other.IsDC=$false
Assert-Throws { Assert-TimeTarget $other 'PDC' } 'PDC blocks member'
$other=Copy-Context; $other.PolicyPresent=$true
Assert-Throws { Assert-TimeTarget $other 'PDC' } 'PDC blocks policy'
$other=Copy-Context; $other.StartMode='Disabled'
Assert-Throws { Assert-TimeTarget $other 'PDC' } 'PDC blocks disabled service'

# Pure DNS adapter, no network traffic.
function Resolve-TimeAddresses { param([string]$Name) [Net.IPAddress]::Parse('192.0.2.20') }
Assert ((Get-TimePeerList @('a.example.test') $ctx) -eq 'a.example.test,0x8') 'single client peer'
Assert ((Get-TimePeerList @('a.example.test','b.example.test') $ctx) -eq 'a.example.test,0x8 b.example.test,0xA') 'two-peer fallback'
Assert ((Get-TimePeerList @('a.example.test','b.example.test','c.example.test') $ctx) -eq 'a.example.test,0x8 b.example.test,0x8 c.example.test,0x8') 'three client peers'
Assert ((Get-TimePeerList @('A.example.test','a.example.test') $ctx) -eq 'a.example.test,0x8') 'deduplicate names'
foreach($bad in @('https://ntp.example.test','ntp.example.test,0x8','x y','192.0.2.1','a..example.test',('x'*254),'-ntp.example.test')) {
    Assert-Throws { Get-TimePeerList @($bad) $ctx } "invalid peer $bad"
}
Assert-Throws { Get-TimePeerList @() $ctx } 'empty peer set'
Assert-Throws { Get-TimePeerList @(1..11 | ForEach-Object { "ntp$_.example.test" }) $ctx } 'too many peers'
Assert-Throws { Get-TimePeerList @('dc1.example.test') $ctx } 'self hostname'
foreach($badIp in @('127.0.0.1','0.0.0.0','224.0.0.1','255.255.255.255','::1','::','ff02::1','::ffff:127.0.0.1','192.0.2.10')) {
    $script:address=$badIp
    function Resolve-TimeAddresses { param([string]$Name) [Net.IPAddress]::Parse($script:address) }
    Assert-Throws { Get-TimePeerList @('a.example.test') $ctx } "reject peer address $badIp"
}
function Resolve-TimeAddresses { param([string]$Name) throw 'SYNTHETIC DNS FAILURE' }
Assert-Throws { Get-TimePeerList @('a.example.test') $ctx } 'DNS failure blocks'
function Resolve-TimeAddresses { param([string]$Name) [Net.IPAddress]::Parse('192.0.2.20') }
Assert-Throws { Invoke-TimeNative 'w32tm.exe' @('/query',"bad`narg") } 'native argument newline rejected before execution'
Assert-Throws { Invoke-TimeNative 'w32tm.exe' @('bad"arg') } 'native argument quote rejected before execution'
$state=Copy-Context
$state.Settings.Type='NTP'; $state.Settings.NtpServer='b.example.test,0x8 a.example.test,0x8'
Assert (Test-TimeConfiguration $state 'PDC' 'A.EXAMPLE.TEST,0x8 b.example.test,0x8') 'peer order and case independent'
$state.ServiceState='Stopped'
Assert (-not (Test-TimeConfiguration $state 'PDC' 'a.example.test,0x8 b.example.test,0x8')) 'stopped service fails verification'

# Test the real native runner with a harmless child PowerShell, not W32Time.
$script:childHost=(Get-Process -Id $PID).Path
function Get-TimeNativePath { param([string]$Tool) $script:childHost }
Assert ((Invoke-TimeNative 'w32tm.exe' @('-NoProfile','-Command','Write-Output 42')) -eq '42') 'native stdout and zero exit'
Assert-Throws { Invoke-TimeNative 'w32tm.exe' @('-NoProfile','-Command','[Console]::Error.WriteLine(99); exit 7') } 'native nonzero exit and stderr'
$watch=[Diagnostics.Stopwatch]::StartNew()
Assert-Throws { Invoke-TimeNative 'w32tm.exe' @('-NoProfile','-Command','Start-Sleep -Seconds 40') } 'native timeout'
Assert ($watch.Elapsed.TotalSeconds -ge 28 -and $watch.Elapsed.TotalSeconds -lt 39) 'native timeout bounded around 30 seconds'

# Exercise the actual ShouldProcess implementation without operational entry code.
function Test-ShouldProcessCaller {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
    param()
    $PSCmdlet.ShouldProcess('SYNTHETIC','SYNTHETIC')
}
Assert (-not (Test-ShouldProcessCaller -WhatIf)) 'real WhatIf refuses application'
Assert (Test-ShouldProcessCaller -Confirm:$false) 'explicit confirmation suppression uses actual ShouldProcess'

$tempRoot=Join-Path ([IO.Path]::GetTempPath()) ('fmodel-time-tests-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory $tempRoot
$script:workflows=0
function Invoke-Case {
    param([string]$Case,[string]$Mode,[string]$Expected,[int]$ExitCode,[bool]$ExpectMutations)
    $script:case=$Case; $script:ops=New-Object 'Collections.Generic.List[string]'
    $script:reads=0; $script:folder=$null; $script:state=Copy-Context
    if($Mode -eq 'DOMHIER') { $script:state.Computer='member.example.test'; $script:state.IsDC=$false }
    switch($Case) {
        'policy' {$script:state.PolicyPresent=$true}
        'disabled' {$script:state.StartMode='Disabled'}
        'wrong-pdc' {$script:state.Computer='dc2.example.test'}
        'root-domhier' {$script:state.Computer=$script:state.RootPdc; $script:state.IsDC=$true}
        'child-pdc' {$script:state.Computer='childdc.child.example.test'; $script:state.IsDC=$true}
        'stopped' {$script:state.ServiceState='Stopped'}
    }
    function Get-TimeContext {
        $script:reads++
        $copy=$script:state | ConvertTo-Json -Depth 6 | ConvertFrom-Json
        if(($script:case -eq 'changed-after-approval' -and $script:reads -ge 2) -or
           ($script:case -eq 'changed-after-backup' -and $script:reads -ge 3) -or
           ($script:case -eq 'changed-after-mutation' -and $script:reads -ge 4)) { $copy.RootPdc='new.example.test' }
        if($script:case -eq 'setting-race' -and $script:reads -ge 3) { $copy.Settings.AnnounceFlags=5 }
        $copy
    }
    function New-TimeRunFolder {
        $script:folder=Join-Path $tempRoot ([guid]::NewGuid().ToString('N'))
        $null=New-Item -ItemType Directory $script:folder
        $script:folder
    }
    function Backup-TimeRegistry {
        param([string]$Folder)
        if($script:case -eq 'backup-failure') { throw 'SYNTHETIC BACKUP FAILURE' }
        $path=Join-Path $Folder 'W32Time-before.reg'
        [IO.File]::WriteAllText($path,'SYNTHETIC BACKUP - DO NOT IMPORT')
        $path
    }
    function Set-TimeRegistry {
        param([string]$Mode)
        $script:ops.Add('Registry')
        if($script:case -eq 'mutation-failure') { throw 'SYNTHETIC WRITE FAILURE' }
        $script:state.Settings.AnnounceFlags=10
    }
    function Set-TimeService {
        param([string]$Action)
        $script:ops.Add($Action)
        $script:state.ServiceState='Running'
    }
    function Invoke-TimeNative {
        param([string]$Tool,[string[]]$Arguments)
        if($Arguments[0] -eq '/config') {
            $script:ops.Add('Configure')
            if($Arguments -contains '/syncfromflags:domhier') { $script:state.Settings.Type='NT5DS' }
            else {
                $script:state.Settings.Type='NTP'
                $script:state.Settings.NtpServer=($Arguments | Where-Object {$_ -like '/manualpeerlist:*'}).Substring(16)
            }
            if($script:case -eq 'verify-mismatch') { $script:state.Settings.Type='NoSync' }
        }
        if($Arguments[0] -eq '/resync') {
            $script:ops.Add('Resync')
            if($script:case -eq 'resync-failure') { throw 'SYNTHETIC RESYNC FAILURE' }
        }
        if($script:case -eq 'query-failure' -and $script:reads -ge 4 -and $Arguments[0] -eq '/query') { throw 'SYNTHETIC QUERY FAILURE' }
        'SYNTHETIC ONLY'
    }
    $caller=[pscustomobject]@{Allow=($Case -notin @('whatif','decline'))}
    $caller | Add-Member ScriptMethod ShouldProcess { param($Target,$Action) return $this.Allow }
    $result=$null; $blocked=$false
    try { $result=Invoke-TimeSetup $Mode @('a.example.test','b.example.test','c.example.test') $caller }
    catch { $blocked=$true }
    if($Expected -eq 'PreflightBlocked') { Assert $blocked "$Case preflight blocked" }
    else {
        Assert (-not $blocked) "$Case returned normally"
        Assert ($result.Status -eq $Expected) "$Case status $($result.Status) expected $Expected"
        Assert ($result.ExitCode -eq $ExitCode) "$Case exit code"
    }
    Assert (($script:ops.Count -gt 0) -eq $ExpectMutations) "$Case mutation boundary"
    if($script:folder) {
        $report=Get-Content (Join-Path $script:folder 'report.json') -Raw | ConvertFrom-Json
        Assert ($report.Status -eq $Expected) "$Case report status"
        $html=Get-Content (Join-Path $script:folder 'Report.html') -Raw
        Assert ($html -notmatch '<SYNTHETIC>') "$Case HTML encoding"
        if($ExpectMutations) {
            $lines=@(Get-Content (Join-Path $script:folder 'actions.jsonl') | ForEach-Object {$_ | ConvertFrom-Json})
            Assert ($lines[0].State -eq 'INTENT') "$Case journal intent"
        }
    } elseif($Case -in @('whatif','decline')) {
        Assert ($null -eq $result.RunFolder) "$Case no output folder"
    }
    if($Case -eq 'stopped') { Assert ($script:ops[0] -eq 'Start') 'start stopped service before config' }
    $script:workflows++
}
try {
    Invoke-Case 'pdc' 'PDC' 'Configured' 0 $true
    Invoke-Case 'member' 'DOMHIER' 'Configured' 0 $true
    Invoke-Case 'child-pdc' 'DOMHIER' 'Configured' 0 $true
    foreach($case in @('policy','disabled','wrong-pdc')) { Invoke-Case $case 'PDC' 'PreflightBlocked' 1 $false }
    Invoke-Case 'root-domhier' 'DOMHIER' 'PreflightBlocked' 1 $false
    foreach($case in @('whatif','decline')) { Invoke-Case $case 'PDC' 'NotApplied' 0 $false }
    foreach($case in @('backup-failure','changed-after-approval','changed-after-backup','setting-race')) { Invoke-Case $case 'PDC' 'Blocked' 1 $false }
    foreach($case in @('mutation-failure','changed-after-mutation')) { Invoke-Case $case 'PDC' 'FailedAfterMutationPossible' 1 $true }
    foreach($case in @('verify-mismatch','query-failure','resync-failure')) { Invoke-Case $case 'PDC' 'ConfiguredNeedsReview' 2 $true }
    Invoke-Case 'stopped' 'PDC' 'Configured' 0 $true
    Write-Host "PASS: $checks assertions; $workflows mocked workflows; no live domain/time changes."
} finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
