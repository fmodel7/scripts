#requires -Version 5.1
$ErrorActionPreference='Stop'
$tool=Split-Path $PSScriptRoot -Parent
. (Join-Path $tool 'src/NtpPdc.Core.ps1')
$checks=0
function Assert($Condition,[string]$Name){if(-not $Condition){throw "FAIL: $Name"};$script:checks++}
$root=Join-Path ([IO.Path]::GetTempPath()) ('ntp entry '+[guid]::NewGuid().ToString('N'))
$fixture=Join-Path $root 'tool with spaces'
try{
    $null=[IO.Directory]::CreateDirectory((Join-Path $fixture 'src'))
    [IO.File]::Copy((Join-Path $tool 'Configure-NTP-PDC.ps1'),(Join-Path $fixture 'Configure-NTP-PDC.ps1'))
    $combined=[IO.File]::ReadAllText((Join-Path $tool 'src/NtpPdc.Core.ps1'))+[Environment]::NewLine+[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Mock-Adapters.ps1'))
    [IO.File]::WriteAllText((Join-Path $fixture 'src/NtpPdc.Core.ps1'),$combined,[Text.UTF8Encoding]::new($true))
    $hostPath=(Get-Process -Id $PID).Path
    foreach($mode in @('Audit','WhatIf','Apply')){
        $output=Join-Path $root $mode
        $entry=(Join-Path $fixture 'Configure-NTP-PDC.ps1').Replace("'","''")
        $escapedOutput=$output.Replace("'","''")
        $command="& '$entry' -OutputPath '$escapedOutput'"
        if($mode -ne 'Audit'){$command+=' -NtpServers ntp1.example,ntp2.example,ntp3.example -Apply'}
        if($mode -eq 'WhatIf'){$command+=' -WhatIf'}
        if($mode -eq 'Apply'){$command+=' -Confirm:$false'}
        $result=Invoke-PdcNative $hostPath @('-NoProfile','-NonInteractive','-Command',$command) 60
        Assert (-not $result.TimedOut -and $result.ExitCode -eq 0) ('Actual CLI '+$mode+'; '+$result.Output)
        $run=Get-ChildItem $output -Directory|Select-Object -First 1
        $report=Get-Content (Join-Path $run.FullName 'report.json') -Raw|ConvertFrom-Json
        $expected=if($mode -eq 'Audit'){'AuditCompleted'}elseif($mode -eq 'WhatIf'){'WhatIf'}else{'AppliedVerified'}
        Assert ($report.State -eq $expected) ('Actual CLI state '+$mode)
        if($mode -ne 'Apply'){Assert (-not $report.MutationAttempted) 'Actual CLI audit/WhatIf blocks mutations'}
        else{Assert ($report.MutationAttempted -and $report.ConfigurationVerified) 'Actual CLI Confirm false reaches mocked apply'}
    }
}finally{if(Test-Path $root){Remove-Item $root -Recurse -Force}}
Write-Host "PASS: 3 isolated actual entry-point processes, $checks checks, synthetic adapters only; path with spaces and ShouldProcess validated."
