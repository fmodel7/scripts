#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$script:checks=0
function Assert-True {param([bool]$Condition,[string]$Message);$script:checks++;if(-not $Condition){throw "FAIL: $Message"}}
function Assert-Throws {param([scriptblock]$Action,[string]$Message);$thrown=$false;try{& $Action | Out-Null}catch{$thrown=$true};Assert-True $thrown $Message}
$root=Split-Path $PSScriptRoot -Parent;$source=Join-Path $root 'Export-HyperVHealthReport.ps1'
$tokens=$null;$parseErrors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
Assert-True ($parseErrors.Count -eq 0) 'Script parses'
$commands=@($ast.FindAll({param($x)$x -is [Management.Automation.Language.CommandAst]},$true) | ForEach-Object {$_.GetCommandName()})
foreach($forbidden in @('Invoke-Expression','iex','Get-WmiObject','Set-ExecutionPolicy','Install-WindowsFeature','Add-WindowsFeature','Set-VM','Start-VM','Stop-VM','Remove-VM','Remove-VMSnapshot','Merge-VHD','Enable-VMResourceMetering','Test-Cluster','Send-MailMessage','Restart-Service')){Assert-True ($forbidden -notin $commands) "No infrastructure mutation: $forbidden"}
. $source
Assert-True ((Get-HvSchemas).Count -eq 54) 'All 54 schemas registered'
Assert-True ($null -eq (Get-HvField $null X)) 'Null-safe field'
Assert-True ((Get-HvField @{X=2} X) -eq 2) 'Dictionary field'
Assert-True ((Get-HvField ([pscustomobject]@{X=3}) X) -eq 3) 'Object field'
Assert-True ($null -eq (Get-HvField ([pscustomobject]@{}) X)) 'Missing remains unknown'
Assert-True ((Convert-HvDate ([datetime]'2026-11-13T10:00:00Z')) -match 'Z$') 'UTC date'
Assert-True ($null -eq (Convert-HvDate 'not a date')) 'Malformed date stays unknown'
Assert-True ((Convert-HvCsvCell '=2+2') -eq '"''=2+2"') 'Formula guarded'
foreach($cell in @('+cmd','-cmd','@SUM(A1:A2)',"`t=cmd","`n=cmd",'  =cmd')){Assert-True ((Convert-HvCsvCell $cell).StartsWith('"''')) 'Formula prefix whitespace guarded'}
Assert-True ((Convert-HvCsvCell (-7)) -eq '"-7"') 'Numeric negatives remain numbers'
Assert-True ((Convert-HvCsvCell 'He said "x"') -eq '"He said ""x"""') 'CSV quotes escaped'
foreach($target in @('HV01','hv01.lab.example','localhost','.','192.0.2.1','::1')){Assert-HvTarget $target;$script:checks++}
foreach($target in @('host;whoami','host*','-x','https://host','host/VM','host name')){Assert-Throws {Assert-HvTarget $target} 'Reject arbitrary target syntax'}
$work=Join-Path ([IO.Path]::GetTempPath()) ('hv-report-tests-'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($work)
try{
    $r=New-HvReport en-US
    $r.Parameters=@{VolumeWarningPercent=15;VolumeCriticalPercent=5;MemoryWarningPercent=10;MemoryCriticalPercent=5;CheckpointWarningDays=7;VcpuRatioWarning=8}
    Add-HvExampleData $r;Invoke-HvAssessment $r
    Assert-True ($r.Status -eq 'SyntheticExample') 'Example explicitly synthetic'
    foreach($rule in @('HV001','HV003','HV004','HV006','HV007','HV009','HV013','HV016','HV021')){Assert-True ($rule -in @($r.Datasets.Findings | ForEach-Object {$_.RuleId})) "Review rule $rule"}
    Assert-True ('HV015' -notin @($r.Datasets.Findings | ForEach-Object {$_.RuleId})) 'File rename signal not confirmed reboot'
    Assert-True ($r.Datasets.StorageCapacity.Count -eq 2) 'Storage mapping per host'
    $storage=@($r.Datasets.StorageCapacity | Where-Object {$_.Host -eq 'HV-LAB02'})[0]
    Assert-True ($storage.UniqueVhdPaths -eq 2 -and $storage.ObservedFileSizeBytes -eq 290GB) 'Parent path sizes kept distinct'
    Add-HvRows $r VHDChains @($r.Datasets.VHDChains[0]);Invoke-HvAssessment $r
    Assert-True (@($r.Datasets.StorageCapacity | Where-Object {$_.Host -eq 'HV-LAB01'})[0].UniqueVhdPaths -eq 1) 'Repeated path deduplicated'
    Add-HvRows $r VMs @([pscustomobject]@{Host='HV-LAB01';VMId='x';VMName='<script>window.bad=1</script>';State='Off';Notes='=HYPERLINK("https://example.invalid")'})
    $result=Write-HvDeliverables $r $work 1 -CreateZip
    Assert-True (Test-Path -LiteralPath $result.Html) 'HTML exists'
    Assert-True (Test-Path -LiteralPath $result.Zip) 'ZIP exists'
    $html=[IO.File]::ReadAllText($result.Html)
    Assert-True ($html -match 'nonce-' -and $html -notmatch '<script>window.bad') 'CSP and HTML escaping'
    Assert-True ($html -match 'Search covers displayed records only') 'HTML limit is explicit'
    Assert-True ($html -notmatch '<script[^>]+src=' -and $html -notmatch '<link[^>]+href=') 'Offline assets only'
    $csvs=@(Get-ChildItem -LiteralPath $result.CsvDirectory -Filter '*.csv')
    Assert-True ($csvs.Count -eq 54) 'One CSV per dataset even empty'
    foreach($key in (Get-HvSchemas).Keys){
        $csv=Join-Path $result.CsvDirectory ($key+'.csv');$bytes=[IO.File]::ReadAllBytes($csv)
        Assert-True ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) "$key UTF8 BOM"
        $parsed=@(Import-Csv -LiteralPath $csv);Assert-True ($parsed.Count -eq $r.Datasets[$key].Count) "$key exact row count"
        $actualHeader=([IO.File]::ReadAllLines($csv)[0] -split ',' | ForEach-Object {$_.Trim('"')}) -join ','
        Assert-True ($actualHeader -eq (Get-HvSchemas)[$key]) "$key schema header contract"
    }
    $vmCsv=@(Import-Csv -LiteralPath (Join-Path $result.CsvDirectory 'VMs.csv'))
    Assert-True ($vmCsv[-1].Notes.StartsWith("'=")) 'Spreadsheet formulas guarded in actual output'
    $json=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($result.Json))
    Assert-True ($json.Datasets.VMs[-1].Notes.StartsWith('=')) 'Raw value preserved in JSON'
    $loaded=Read-HvOfflineReport $result.Json 'pt-BR'
    foreach($key in (Get-HvSchemas).Keys){Assert-True ($loaded.Datasets[$key].Count -eq $r.Datasets[$key].Count) "$key offline round trip"}
    Assert-True ($loaded.Language -eq 'pt-BR') 'Offline language override'
    foreach($line in [IO.File]::ReadAllLines((Join-Path $result.ReportDirectory 'MANIFEST-SHA256.txt'))){
        $pair=$line -split '  ',2;$file=Join-Path $result.ReportDirectory $pair[1];Assert-True ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -eq $pair[0]) 'Report manifest verifies'
    }
    $r.Datasets.Errors.Add([pscustomobject]@{Host='test';Dataset='test';Scope='test';ErrorType='test';Message='<img src=x onerror=bad>'});$r.Language='en-US';Write-HvHtml (Join-Path $work 'encoded.html') $r 500
    $encoded=[IO.File]::ReadAllText((Join-Path $work 'encoded.html'));Assert-True ($encoded -match '&lt;script&gt;' -and $encoded -match '&lt;img') 'XSS content encoded'
    $bad=Join-Path $work 'bad.json';Write-HvUtf8 $bad '{"SchemaVersion":999,"Tool":"Hyper-V Health Report"}'
    Assert-Throws {Read-HvOfflineReport $bad pt-BR} 'Unsupported schema rejected'
    Write-HvUtf8 $bad '{"SchemaVersion":1,"Tool":"Hyper-V Health Report","Status":"Completed","Datasets":{"VMs":[{"Notes":{"nested":"x"}}]}}'
    Assert-Throws {Read-HvOfflineReport $bad pt-BR} 'Nested values rejected'
    Assert-Throws {Assert-HvLocalPath '\\server\share\input.json'} 'UNC input/output rejected'
    Assert-Throws {Assert-HvLocalPath $work -File} 'Input directory rejected'
    Assert-Throws {Assert-HvLocalPath $result.Json -File -MaximumBytes 10} 'Input size limit'
    $u=New-HvReport en-US;$u.Parameters=$r.Parameters
    Add-HvPacket $u ([pscustomobject]@{Dataset='VMs';Host='Denied';Scope='Worker';Status='Failed';Rows=@();Error='Denied';ErrorType='Test'})
    Invoke-HvAssessment $u
    Assert-True ($u.Datasets.Coverage[0].Rows -eq 0) 'Failed empty result has zero exported rows'
    Assert-True ($u.Status -eq 'CompletedWithIssues' -and $null -eq $u.Datasets.HostSummary[0].RunningVMRows) 'Failed inventory never means zero running VMs'
    Assert-True ($u.Datasets.HostSummary[0].InventoryStatus -eq 'Failed') 'Failed inventory visible'
    Assert-True ($null -eq (Get-HvNumberSum @([pscustomobject]@{X=1},[pscustomobject]@{X=$null}) X)) 'Incomplete sums stay unknown'
    Add-HvPacket $u ([pscustomobject]@{Dataset='VMs';Host='Empty';Scope='Worker';Status='Empty';Rows=@()})
    Invoke-HvAssessment $u
    Assert-True (@($u.Datasets.HostSummary | Where-Object {$_.Host -eq 'Empty'})[0].RunningVMRows -eq 0) 'Successfully empty inventory has known zero'
    $result2=Write-HvDeliverables $loaded $work 2
    Assert-True ($result2.ReportDirectory -ne $result.ReportDirectory) 'Unique output directories'
    $engine=(Get-Process -Id $PID).Path
    $cli=@(& $engine -NoProfile -File $source -CreateExample -Language en-US -OutputPath $work 2>&1)
    Assert-True ($LASTEXITCODE -eq 0 -and (($cli | Out-String) -match 'SyntheticExample')) 'Standalone CLI example'
    $cli=@(& $engine -NoProfile -File $source -InputJson $result.Json -Language pt-BR -OutputPath $work 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) 'Standalone CLI offline rendering'
    $ErrorActionPreference='Continue'
    $badParameters=@(& $engine -NoProfile -File $source -CreateExample -VolumeCriticalPercent 20 -VolumeWarningPercent 10 -OutputPath $work 2>&1)
    $ErrorActionPreference='Stop'
    Assert-True ($LASTEXITCODE -ne 0) 'Invalid relative thresholds fail'
    Write-Output "PASS: $script:checks checks; serialization, assessment, files, security and CLI. Runtime: $($PSVersionTable.PSVersion)"
}finally{Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue}
