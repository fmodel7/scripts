#requires -Version 5.1
[CmdletBinding()]
param([string]$ExampleDirectory)
$ErrorActionPreference='Stop'
$core=Join-Path (Split-Path $PSScriptRoot -Parent) 'src/NtpPdc.Core.ps1'
$checks=0
function Assert($Condition,[string]$Name){if(-not $Condition){throw "FAIL: $Name"};$script:checks++}
$root=Join-Path ([IO.Path]::GetTempPath()) ('ntp-workflows-'+[guid]::NewGuid().ToString('N'))
$cases=@(
    @('Audit','Healthy','AuditCompleted'),@('WhatIf','Healthy','WhatIf'),@('Decline','Healthy','Declined'),
    @('Apply','Healthy','AppliedVerified'),@('Apply','Unverified','AppliedNeedsReview'),
    @('Apply','WrongPdc','Blocked'),@('Apply','RoleMoved','Blocked'),@('Apply','PolicyBefore','Blocked'),
    @('Apply','PolicyAppears','Blocked'),@('Apply','RoleMovedAfterBackup','Blocked'),@('Apply','PolicyAfterBackup','Blocked'),@('Apply','StoppedService','AppliedVerified'),@('Apply','BackupFail','Blocked'),@('Apply','BackupEmpty','Blocked'),
    @('Apply','JournalFail','Blocked'),@('Apply','ConfigFail','FailedAfterMutationPossible'),
    @('Apply','ResyncTimeout','FailedAfterMutationPossible'),@('Audit','DirectoryFailure','Blocked')
)
try{
    foreach($case in $cases){
        . $core
        . (Join-Path $PSScriptRoot 'Mock-Adapters.ps1')
        $script:scenario=$case[1]
        if($case[1] -eq 'StoppedService'){$script:seed.ServiceState='Stopped'}
        $params=@{OutputPath=(Join-Path $root ($case[0]+'-'+$case[1]));NtpServers=@('ntp1.example','ntp2.example','ntp3.example');VerificationTimeoutSeconds=0;Approve={param($Target,$Operation) return $true}}
        if($case[0] -ne 'Audit'){$params.Apply=$true}
        if($case[0] -eq 'WhatIf'){$params.WhatIfRequested=$true}
        if($case[0] -eq 'Decline'){$params.Approve={param($Target,$Operation) return $false}}
        $report=Invoke-PdcTimeConfiguration @params
        Assert ($report.State -eq $case[2]) ('State '+($case -join '/')+'; actual='+$report.State+'; error='+$report.Error)
        Assert ([IO.File]::Exists((Join-Path $report.RunFolder 'report.json'))) 'JSON exists'
        $saved=Get-Content (Join-Path $report.RunFolder 'report.json') -Raw|ConvertFrom-Json
        Assert ($saved.State -eq $report.State) 'Persisted outcome matches'
        foreach($lang in @('pt-BR','en-US')){
            $text=Get-Content (Join-Path $report.RunFolder "Report.$lang.html") -Raw
            Assert ($text -match '<!doctype html>' -and $text -match 'Content-Security-Policy') 'Offline encoded HTML exists'
            Assert ($text -notmatch '<script>alert' -and $text -notmatch '<script src') 'No unencoded data/script'
        }
        Assert ($script:calls.Config -le 1 -and $script:calls.Resync -le 1) 'No mutation retry'
        Assert ($script:calls.Lock -eq $script:calls.Unlock) 'Lock released'
        if($case[0] -in @('Audit','WhatIf','Decline') -or $case[2] -eq 'Blocked'){
            Assert ($script:calls.Config -eq 0 -and $script:calls.Registry -eq 0 -and $script:calls.Restart -eq 0 -and $script:calls.Resync -eq 0) 'Blocked/audit/preview does not change time configuration'
        }
        if($case[2] -eq 'AppliedVerified'){
            Assert ($report.ConfigurationVerified -and $report.Verification.Evidence.MeetsCriteria) 'Independent configuration/time evidence'
            Assert ($script:calls.Registry -eq 3 -and $script:calls.Config -eq 1 -and $script:calls.Update -eq 1 -and $script:calls.Restart -eq 1 -and $script:calls.Resync -eq 1) 'Expected mutation scope'
            Assert ($report.Before.Values.Type -eq 'NT5DS' -and $report.After.Values.Type -eq 'NTP') 'Before snapshot remains independent'
            $events=@(Get-Content (Join-Path $report.RunFolder 'actions.jsonl')|ConvertFrom-Json)
            Assert ($events.Count -eq $(if($case[1] -eq 'StoppedService'){16}else{14}) -and $events[0].Phase -eq 'INTENT') 'Persisted action intent/completion pairs'
            if($ExampleDirectory -and $case[1] -eq 'Healthy'){
                $null=[IO.Directory]::CreateDirectory($ExampleDirectory)
                # Clearly marked fictional report, no usable registry backup or internal real data.
                $report.Warnings=@('SYNTHETIC EXAMPLE. All directory, DNS, native commands, registry and service operations were mocked. No real server was configured.')+$report.Warnings
                Write-PdcAtomicText (Join-Path $ExampleDirectory 'Report-SYNTHETIC.pt-BR.html') ((ConvertTo-PdcHtml $report 'pt-BR') -replace '<main>','<main><section class="notice"><h1>EXEMPLO FICTICIO / SYNTHETIC EXAMPLE</h1><p>No real domain controller was configured.</p></section>')
                Write-PdcAtomicText (Join-Path $ExampleDirectory 'Report-SYNTHETIC.en-US.html') ((ConvertTo-PdcHtml $report 'en-US') -replace '<main>','<main><section class="notice"><h1>SYNTHETIC EXAMPLE</h1><p>No real domain controller was configured.</p></section>')
            }
        }
        if($case[1] -eq 'ResyncTimeout'){Assert ($report.MutationAttempted -and $script:calls.Resync -eq 1) 'Uncertain timeout outcome is explicit'}
        if($case[1] -eq 'ConfigFail'){Assert ($script:calls.Restart -eq 0 -and $script:calls.Resync -eq 0) 'Failing config stops later actions'}
        if($case[1] -in @('BackupFail','BackupEmpty','JournalFail')){Assert (-not $report.MutationAttempted) 'Persistence failure prevents first configuration write'}
    }
}finally{if(Test-Path $root){Remove-Item $root -Recurse -Force}}
Write-Host "PASS: $($cases.Count) mocked workflows, $checks assertions; no real domain, DNS/NTP, registry writes or service changes."
