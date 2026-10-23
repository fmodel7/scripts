#requires -Version 5.1
<#
.SYNOPSIS
    Audit or configure time on the current forest-root PDC Emulator.
.DESCRIPTION
    FMODEL 1.0.0. Audit is the default. Apply requires explicit upstream peers,
    elevated 64-bit Windows PowerShell, verified forest-root PDC identity, no
    W32Time policy branch, pre-change backup and ShouldProcess confirmation.
    Writes local JSON and PT-BR/EN-US HTML reports. Never changes hypervisor
    integration, Group Policy, firewall, time zone or phase correction limits.
.PARAMETER NtpServers
    Approved DNS names or IPs, without flags. No default provider. One to ten
    unique peers; two peers use client/fallback-only for the second entry.
.PARAMETER Apply
    Explicitly enable W32Time changes, service restart/start and resync.
.PARAMETER ReliabilityMode
    Automatic=AnnounceFlags 10 (default). Always=5 (explicit operator choice).
.PARAMETER OutputPath
    Local report/backup root. Default: LocalApplicationData/FMODEL/NtpPdc. Normal filesystem ACLs are inherited.
.PARAMETER ProbePeers
    Optional three-sample stripchart per requested peer. Does not change time.
.PARAMETER NativeTimeoutSeconds
    Timeout per native process; default 20 seconds. Timed-out mutations may
    already have been processed by the Windows service.
.PARAMETER VerificationTimeoutSeconds
    Monotonic polling window; default 120. In-flight reads can exceed it.
.PARAMETER VerificationIntervalSeconds
    Verification polling interval; default 5 seconds.
.PARAMETER MaxSyncAgeSeconds
    Maximum recognized last-good-sync age; default 300 seconds.
.EXAMPLE
    .\Configure-NTP-PDC.ps1
    Read local state only; writes local reports. Requires elevated Windows.
.EXAMPLE
    .\Configure-NTP-PDC.ps1 -NtpServers ntp1.example.net,ntp2.example.net,ntp3.example.net -Apply -WhatIf
    Preview after preflight. Replace reserved example hosts with approved peers.
.NOTES
    Exit 0: audit/WhatIf/declined/AppliedVerified; 2: AppliedNeedsReview;
    1: preflight or operation failure. Success is not accuracy certification.
    Read README.md / README.en-US.md before real use. Do not dot-source.
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateCount(0,10)][string[]]$NtpServers=@(),
    [switch]$Apply,
    [ValidateSet('Automatic','Always')][string]$ReliabilityMode='Automatic',
    [string]$OutputPath,
    [switch]$ProbePeers,
    [ValidateRange(5,120)][int]$NativeTimeoutSeconds=20,
    [ValidateRange(10,600)][int]$VerificationTimeoutSeconds=120,
    [ValidateRange(1,30)][int]$VerificationIntervalSeconds=5,
    [ValidateRange(30,86400)][int]$MaxSyncAgeSeconds=300
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'src/NtpPdc.Core.ps1')
$entryCmdlet=$PSCmdlet
$approve={param($Target,$Operation) $entryCmdlet.ShouldProcess($Target,$Operation)}.GetNewClosure()
try{
    $parameters=@{NtpServers=$NtpServers;Apply=$Apply;WhatIfRequested=[bool]$WhatIfPreference;ReliabilityMode=$ReliabilityMode;OutputPath=$OutputPath;ProbePeers=$ProbePeers;NativeTimeoutSeconds=$NativeTimeoutSeconds;VerificationTimeoutSeconds=$VerificationTimeoutSeconds;VerificationIntervalSeconds=$VerificationIntervalSeconds;MaxSyncAgeSeconds=$MaxSyncAgeSeconds;Approve=$approve}
    $result=Invoke-PdcTimeConfiguration @parameters
    $result|Select-Object State,Mode,ConfigurationVerified,MutationAttempted,RunFolder,Error
    Write-Host ('HTML: '+(Join-Path $result.RunFolder 'Report.pt-BR.html'))
    if($result.State -eq 'AppliedNeedsReview'){Write-Warning 'Configuration/time evidence needs review; synchronization was not confirmed.';exit 2}
    if($result.State -in @('Blocked','FailedAfterMutationPossible')){Write-Error $result.Error -ErrorAction Continue;exit 1}
    exit 0
}catch{
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
