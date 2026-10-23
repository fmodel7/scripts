#requires -Version 5.1
$ErrorActionPreference='Stop'
$folder=Split-Path $PSScriptRoot -Parent
$checks=0
function Assert($Condition,[string]$Name){if(-not $Condition){throw "FAIL: $Name"};$script:checks++}
function Assert-Throws([scriptblock]$Code,[string]$Name){$failed=$false;try{& $Code|Out-Null}catch{$failed=$true};Assert $failed $Name}
foreach($file in Get-ChildItem $folder -Filter '*.ps1' -Recurse){
    $tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Assert ($errors.Count -eq 0) ('Parser '+$file.Name)
}
. (Join-Path $folder 'src/NtpPdc.Core.ps1')
foreach($name in @('a b','x,0x8','https://x.org','a"b','a/b','a\b','localhost','127.0.0.1','::1','::ffff:127.0.0.1','0.0.0.0','::','224.0.0.1','ff02::1','255.255.255.255','x..org','-x.org','x-.org',"bad`nname",'fe80::1%3','a&b.org','a;b.org')){Assert-Throws {ConvertTo-PdcPeerName $name} ('Reject '+$name)}
Assert ((ConvertTo-PdcPeerName 'NTP.EXAMPLE.ORG.') -ceq 'ntp.example.org') 'DNS normalization'
Assert ((ConvertTo-PdcPeerName 'bücher.example') -ceq 'xn--bcher-kva.example') 'IDN normalization'
Assert ((ConvertTo-PdcPeerName '2001:db8::123') -ceq '2001:db8::123') 'IPv6 peer'
$p=Get-PdcPeerPlan @('NTP1.EXAMPLE','ntp1.example','ntp2.example')
Assert ($p.Servers.Count -eq 2) 'Case-insensitive deduplication'
Assert ($p.PeerList -ceq 'ntp1.example,0x8 ntp2.example,0xA') 'Two peers use client + fallback/client'
Assert ($p.AnnounceFlags -eq 10) 'Automatic announce default'
Assert ((Get-PdcPeerPlan @('ntp1.example') 'Always').AnnounceFlags -eq 5) 'Explicit Always announce'
$p=Get-PdcPeerPlan @('ntp1.example','ntp2.example','ntp3.example')
Assert ($p.PeerList -ceq 'ntp1.example,0x8 ntp2.example,0x8 ntp3.example,0x8') 'Three adaptive client peers'
Assert ((Get-PdcPeerPlan).Servers.Count -eq 0) 'No implicit provider'
Assert-Throws {Get-PdcPeerPlan @(1..11|ForEach-Object{"ntp$_.example"})} 'Peer count bounded'
$peers=@([pscustomobject]@{Server='ntp1.example';Addresses=@('192.0.2.123')})
$good="Leap Indicator: 0(no warning)`nStratum: 2 (secondary reference)`nTime since Last Good Sync Time: 4.25s"
function NativeResult([string]$Output,[int]$Code=0,[bool]$Timeout=$false){[pscustomobject]@{Output=$Output;ExitCode=$Code;TimedOut=$Timeout}}
$source=NativeResult 'ntp1.example';$status=NativeResult $good
$e=Test-PdcTimeEvidence $source $status $peers 300
Assert $e.MeetsCriteria 'Recognized healthy status and approved source'
Assert ((Test-PdcTimeEvidence (NativeResult '192.0.2.123') $status $peers 300).MeetsCriteria) 'Source matches resolved IP'
Assert ((Test-PdcTimeEvidence (NativeResult 'NTP1.EXAMPLE,0x8') $status $peers 300).MeetsCriteria) 'Native flag/case source normalization'
$pt="Indicador de salto: 0(sem aviso)`nEstrato: 2`nTempo desde a última sincronização bem-sucedida: 4,25s"
Assert ((Test-PdcTimeEvidence $source (NativeResult $pt) $peers 300).MeetsCriteria) 'Recognized Portuguese labels/decimal comma'
foreach($badSource in @('Local CMOS Clock','Relógio CMOS Local','VM IC Time Synchronization Provider','other.example',"ntp1.example`nother",'')){
    Assert (-not (Test-PdcTimeEvidence (NativeResult $badSource) $status $peers 300).MeetsCriteria) 'Unapproved/local/host source does not verify'
}
foreach($badStatus in @('',($good -replace 'Indicator: 0','Indicator: 3'),($good -replace 'Stratum: 2','Stratum: 16'),($good -replace 'Stratum: 2','Stratum: 0'),($good -replace '4.25s','999s'),($good -replace '4.25s','unknown'),"$good`nLeap Indicator: 0",'Sprungindikator: 0')){
    Assert (-not (Test-PdcTimeEvidence $source (NativeResult $badStatus) $peers 300).MeetsCriteria) 'Missing/stale/unknown/duplicated status remains unverified'
}
Assert (-not (Test-PdcTimeEvidence (NativeResult 'ntp1.example' 5) $status $peers 300).MeetsCriteria) 'Native query exit code matters'
Assert (-not (Test-PdcTimeEvidence $source (NativeResult $good 0 $true) $peers 300).MeetsCriteria) 'Native query timeout matters'
Assert-Throws {Assert-PdcNativeSuccess (NativeResult 'success text' 5) 'test'} 'Text cannot override failed exit code'
Assert-Throws {Assert-PdcNativeSuccess (NativeResult 'success text' 0 $true) 'test'} 'Timeout cannot claim success'
$settings=[pscustomobject]@{Values=[pscustomobject]@{Type='NTP';PeerList=$p.PeerList;AnnounceFlags=10;NtpClientEnabled=1;NtpServerEnabled=1};ServiceState='Running'}
Assert (Test-PdcConfiguration $settings $p) 'Exact effective local settings'
$settings.Values.AnnounceFlags=5
Assert (-not (Test-PdcConfiguration $settings $p)) 'Incorrect announcement rejected'
$settings.Values.AnnounceFlags=10;$settings.ServiceState='Stopped'
Assert (-not (Test-PdcConfiguration $settings $p)) 'Stopped service not verified'
$context=[pscustomobject]@{IsForestRootPdc=$true;ProductType=2;OSBuild=20348;LocalFqdn='dc1.example';ComputerName='dc1';LocalAddresses=@('192.0.2.1')}
$settings|Add-Member -NotePropertyName ServiceStartMode -NotePropertyValue 'Auto'
$settings|Add-Member -NotePropertyName Registry -NotePropertyValue @('Type','PeerList','AnnounceFlags','NtpClientEnabled','NtpServerEnabled'|ForEach-Object{[pscustomobject]@{Field=$_;KeyExists=$true}})
$policy=[pscustomobject]@{Present=$false}
Assert-Throws {Resolve-PdcPeers @('192.0.2.1') $context} 'Self-IP upstream loop rejected without network'
Assert-Throws {Resolve-PdcPeers @('dc1.example') $context} 'Self-DNS upstream loop rejected without network'
$context.IsForestRootPdc=$false
Assert-Throws {Assert-PdcApplyTarget $context $settings $policy} 'Other DC/child PDC/member rejected'
$context.IsForestRootPdc=$true;$policy.Present=$true
Assert-Throws {Assert-PdcApplyTarget $context $settings $policy} 'Policy branch blocks local changes'
$policy.Present=$false;$settings.ServiceStartMode='Disabled'
Assert-Throws {Assert-PdcApplyTarget $context $settings $policy} 'Disabled service not silently re-enabled'
$settings.ServiceStartMode='Auto';$context.OSBuild=9600
Assert-Throws {Assert-PdcApplyTarget $context $settings $policy} 'Unsupported server build rejected'
$context.OSBuild=20348;$settings.Registry[0].KeyExists=$false
Assert-Throws {Assert-PdcApplyTarget $context $settings $policy} 'Missing registry key not silently repaired'
$path=Join-Path ([IO.Path]::GetTempPath()) ('ntp-unit-'+[guid]::NewGuid().ToString('N'))
try{
    $null=[IO.Directory]::CreateDirectory($path)
    $file=Join-Path $path 'atomic.txt';Write-PdcAtomicText $file 'first';Write-PdcAtomicText $file 'second'
    Assert (([IO.File]::ReadAllText($file)) -ceq 'second') 'Atomic replacement preserves final content'
    Assert (@(Get-ChildItem $path -Filter '*.tmp').Count -eq 0) 'No temporary files left'
    $journal=Join-Path $path 'actions.jsonl';Write-PdcAction $journal 'test' 'INTENT';Write-PdcAction $journal 'test' 'COMPLETED'
    $lines=@(Get-Content $journal|ConvertFrom-Json)
    Assert ($lines.Count -eq 2 -and $lines[0].Phase -eq 'INTENT' -and $lines[1].Phase -eq 'COMPLETED') 'Durable journal event order'
    Assert-Throws {Write-PdcAction (Join-Path $path 'missing/actions.jsonl') 'test' 'INTENT'} 'Journal failure propagates before mutation'
}finally{if(Test-Path $path){Remove-Item $path -Recurse -Force}}
if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){
    Add-Type -AssemblyName System.DirectoryServices -ErrorAction Stop
    Assert ($null -ne ('System.DirectoryServices.ActiveDirectory.Domain' -as [type])) 'Windows directory API type available (no bind)'
    $snapshot=Get-PdcSettings
    Assert ($snapshot.Registry.Count -eq 8 -and $snapshot.PSObject.Properties['ServiceStartMode']) 'Real local registry/CIM snapshot (read-only)'
    $native=Invoke-PdcNative (Join-Path ([Environment]::SystemDirectory) 'w32tm.exe') @('/?') 20
    Assert (-not $native.TimedOut -and $native.Output.Length -gt 0) 'Real Windows native help smoke (read-only)'
}
Write-Host "PASS: $checks core checks; no domain login, live DNS/NTP, service changes or registry writes."
