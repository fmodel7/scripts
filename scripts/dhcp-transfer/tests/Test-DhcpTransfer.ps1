#Requires -Version 5.1
# Offline tests. Never run operational entry points or real DHCP cmdlets.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
$script:checks=0; $script:cases=0
function Assert($Condition,[string]$Message) { if(-not $Condition){throw "FAIL: $Message"};$script:checks++ }
function Assert-Throws([scriptblock]$Body,[string]$Message) { $failed=$false;try{& $Body|Out-Null}catch{$failed=$true};Assert $failed $Message }
$definitions=@();$workerText=$null
foreach($name in @('Export-DHCP.ps1','Import-DHCP.ps1')) {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $name),[ref]$tokens,[ref]$errors)
    Assert ($errors.Count -eq 0) "$name parses"
    Assert ($ast.ScriptRequirements.RequiredPSVersion.Major -eq 5) "$name requires PS5+"
    Assert ($ast.ParamBlock.Attributes.Extent.Text -match 'SupportsShouldProcess') "$name supports WhatIf/Confirm"
    $worker=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-DhcpWorker'},$true)
    $definitions+= $worker.Extent.Text
    foreach($function in $ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)) {
        . ([scriptblock]::Create($function.Extent.Text))
    }
    if($name -eq 'Export-DHCP.ps1'){$workerText=$worker.Extent.Text}
}
Assert ($definitions[0] -ceq $definitions[1]) 'identical embedded worker engines'
foreach($name in @('sample.xml','DHCP-Export-2026_01.xml')){Test-DhcpFileName $name;Assert $true 'valid XML leaf name'}
foreach($name in @('../x.xml','C:\x.xml','x.txt','CON.xml','lpt1.xml','x y.xml',('a'*151+'.xml'),'x.xml:stream')){Assert-Throws {Test-DhcpFileName $name} "reject filename $name"}
foreach($path in @('relative.xml','\\server\share\file.xml','C:relative','C:\x*.xml','C:\dir[1]\file.xml','C:\file.xml:stream')){Assert-Throws {Resolve-DhcpPath $path} "reject path $path"}
if([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT){
    Assert ((Resolve-DhcpPath ($env:SystemDrive+'\')) -eq ($env:SystemDrive+'\')) 'Windows local drive root accepted'
    Assert ((Resolve-DhcpPath ([IO.Path]::GetTempPath())).TrimEnd('\') -ieq ([IO.Path]::GetFullPath([IO.Path]::GetTempPath())).TrimEnd('\')) 'Windows existing temp directory accepted'
}

$temp=Join-Path ([IO.Path]::GetTempPath()) ('fmodel-dhcp-tests-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory $temp
try {
    $xml=Join-Path $temp 'input.xml'
    [IO.File]::WriteAllText($xml,'<DHCPServer><IPv4/><IPv6/></DHCPServer>')
    $info=Get-DhcpXmlInfo $xml
    Assert ($info.SHA256 -eq (Get-FileHash $xml -Algorithm SHA256).Hash.ToLowerInvariant()) 'XML streaming hash'
    Assert ($info.Bytes -gt 0) 'XML bytes'
    foreach($text in @('', '<wrong/>','<DHCPServer>','<!DOCTYPE DHCPServer [<!ENTITY x SYSTEM "file:///nonexistent">]><DHCPServer>&x;</DHCPServer>')) {
        $bad=Join-Path $temp 'bad.xml';[IO.File]::WriteAllText($bad,$text)
        Assert-Throws {Get-DhcpXmlInfo $bad} 'empty, malformed, wrong-root or DTD XML rejected'
    }
    $copy=Join-Path $temp 'copy.xml';Copy-DhcpSnapshot $xml $copy
    Assert ((Get-FileHash $copy).Hash -eq (Get-FileHash $xml).Hash) 'snapshot bytes preserved'
    Assert-Throws {Copy-DhcpSnapshot $xml $copy} 'snapshot never overwrites'
    $held=[IO.File]::Open($copy,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try {Assert-Throws {$writer=[IO.File]::OpenWrite($copy);$writer.Dispose()} 'snapshot read lock denies writer'} finally {$held.Dispose()}

    # A synthetic module checks the REAL adapter parameter binding, without DHCP.
    $fakeModule=New-Module -Name DhcpServer -ScriptBlock {
        function Export-DhcpServer {
            [CmdletBinding(SupportsShouldProcess)]param([string]$File,[switch]$Leases,[switch]$Force)
            $global:DhcpTestBinding=[pscustomobject]@{File=$File;Leases=[bool]$Leases;Force=[bool]$Force}
        }
        function Import-DhcpServer {
            [CmdletBinding(SupportsShouldProcess)]param([string]$File,[string]$BackupPath,[switch]$Leases,[switch]$ScopeOverwrite,[switch]$Force)
            $global:DhcpTestBinding=[pscustomobject]@{File=$File;Backup=$BackupPath;Leases=[bool]$Leases;Overwrite=[bool]$ScopeOverwrite;Force=[bool]$Force}
            Write-Warning 'SYNTHETIC WARNING'
        }
        function Backup-DhcpServer {
            [CmdletBinding(SupportsShouldProcess)]param([string]$Path)
            $global:DhcpTestBinding=$Path
        }
        Export-ModuleMember -Function *-DhcpServer
    }
    $fakeModule|Import-Module -Force
    Invoke-DhcpExport 'synthetic.xml' $true
    Assert ($global:DhcpTestBinding.Leases -and -not $global:DhcpTestBinding.Force) 'export leases included; no Force overwrite'
    Invoke-DhcpExport 'synthetic.xml' $false
    Assert (-not $global:DhcpTestBinding.Leases) 'configuration-only export'
    $warningResult=@(Invoke-DhcpImport 'synthetic.xml' 'synthetic-backup' $true $false)
    Assert ($global:DhcpTestBinding.Leases -and -not $global:DhcpTestBinding.Overwrite -and $global:DhcpTestBinding.Force) 'import default no ScopeOverwrite; native Force only handles confirmation'
    Assert ($warningResult.Count -eq 1) 'native import warning preserved'
    $null=Invoke-DhcpImport 'synthetic.xml' 'synthetic-backup' $false $true
    Assert ($global:DhcpTestBinding.Overwrite -and -not $global:DhcpTestBinding.Leases) 'explicit overwrite; configuration-only import'
    Invoke-DhcpBackup 'synthetic-backup'
    Assert ($global:DhcpTestBinding -eq 'synthetic-backup') 'backup adapter path'
    Remove-Module DhcpServer -Force
    Remove-Variable DhcpTestBinding -Scope Global

    # Replace only I/O adapter function definitions inside the actual worker AST.
    # No test hooks, flags or mock modules are installed in operational scripts.
    $mockDefinitions=@{
        'Get-DhcpContext'= @'
function Get-DhcpContext {
    $script:reads++
    if($script:case -eq 'runtime-failure'){throw 'SYNTHETIC RUNTIME FAILURE'}
    $c=$script:context|ConvertTo-Json -Depth 8|ConvertFrom-Json
    if($script:case -eq 'identity-race' -and $script:reads -ge 2){$c.Identity='changed'}
    if($script:case -eq 'backup-race' -and $script:reads -ge 4){$c.Scopes4=@([pscustomobject]@{ScopeId='192.0.2.0';Name='changed'})}
    $c
}
'@
        'Resolve-DhcpPath'= @'
function Resolve-DhcpPath {param([string]$Path) [IO.Path]::GetFullPath($Path)}
'@
        'Invoke-DhcpExport'= @'
function Invoke-DhcpExport {
    param([string]$Path,[bool]$IncludeLeases)
    $script:ops.Add('Export')
    if($script:case -eq 'export-failure'){throw 'SYNTHETIC EXPORT FAILURE'}
    $text=if($script:case -eq 'invalid-export'){'<wrong/>'}else{'<DHCPServer><IPv4/><IPv6/></DHCPServer>'}
    [IO.File]::WriteAllText($Path,$text)
}
'@
        'Invoke-DhcpBackup'= @'
function Invoke-DhcpBackup {
    param([string]$Path)
    $script:ops.Add('Backup')
    if($script:case -eq 'backup-failure'){throw 'SYNTHETIC BACKUP FAILURE'}
    if($script:case -ne 'empty-backup'){[IO.File]::WriteAllText((Join-Path $Path 'SYNTHETIC.bak'),'SYNTHETIC BACKUP - NOT RESTORABLE')}
}
'@
        'Invoke-DhcpImport'= @'
function Invoke-DhcpImport {
    param([string]$Path,[string]$Backup,[bool]$IncludeLeases,[bool]$Overwrite)
    $script:ops.Add('Import')
    $script:importArgs=[pscustomobject]@{Path=$Path;Backup=$Backup;Leases=$IncludeLeases;Overwrite=$Overwrite}
    if($script:case -eq 'import-failure'){throw 'SYNTHETIC IMPORT FAILURE'}
    if($script:case -eq 'warning'){'SYNTHETIC SKIPPED SCOPE'}
}
'@
        'Restart-DhcpLocalService'= @'
function Restart-DhcpLocalService {
    $script:ops.Add('Restart')
    if($script:case -eq 'restart-failure'){throw 'SYNTHETIC RESTART FAILURE'}
}
'@
    }
    foreach($key in $mockDefinitions.Keys){
        $tokens=$null;$errors=$null
        $workerAst=[Management.Automation.Language.Parser]::ParseInput($workerText,[ref]$tokens,[ref]$errors)
        $node=$workerAst.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $key},$true)
        Assert ($null -ne $node) "mock adapter exists: $key"
        $workerText=$workerText.Replace($node.Extent.Text,$mockDefinitions[$key])
    }
    . ([scriptblock]::Create($workerText))

    function Invoke-Case {
        param([string]$Case,[string]$Mode,[string]$Expected,[int]$Exit,[bool]$ImportExpected)
        $script:case=$Case;$script:reads=0;$script:ops=New-Object 'Collections.Generic.List[string]'
        $script:context=[pscustomobject]@{Computer='SYNTHETIC-DHCP';Domain='example.test';Operator='<SYNTHETIC>&operator';OperatorSid='S-1-0-0';Identity='synthetic-guid';OS='SYNTHETIC';Build='20348';Service='Running';Scopes4=@();Scopes6=@();Failover=@()}
        if($Case -eq 'failover'){$script:context.Failover=@([pscustomobject]@{Name='SYNTHETIC'})}
        $folder=Join-Path $temp ([guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory $folder
        $source=Join-Path $folder 'source.xml';[IO.File]::WriteAllText($source,'<DHCPServer><IPv4/><IPv6/></DHCPServer>')
        $request=[pscustomobject]@{Mode=$Mode;Stage='Plan';BasePath=$folder;FileName='export.xml';ImportFile=$source;IncludeLeases=($Case -ne 'configuration-only');ScopeOverwrite=($Case -eq 'overwrite');RestartService=($Case -in @('restart','restart-failure'));ExpectedSha256='';Plan=$null}
        if($Case -eq 'hash-mismatch'){$request.ExpectedSha256='0'*64}
        if($Case -eq 'invalid-hash'){$request.ExpectedSha256='invalid'}
        if($Case -eq 'exists'){[IO.File]::WriteAllText((Join-Path $folder 'export.xml'),'KEEP')}
        if($Case -eq 'sidecar-exists'){[IO.File]::WriteAllText((Join-Path $folder 'export.xml.sha256'),'KEEP')}
        $caller=[pscustomobject]@{Allow=($Case -notin @('whatif','decline'))}
        $caller|Add-Member ScriptMethod ShouldProcess {param($Target,$Action) $this.Allow}
        $result=$null;$failed=$false
        try{$result=Invoke-DhcpTransfer '.' $request $caller}catch{$failed=$true}
        if($Expected -eq 'PreflightBlocked'){Assert $failed "$Case preflight rejection"}
        else{
            Assert (-not $failed) "$Case returned"
            Assert ($result.Status -eq $Expected) "$Case status $($result.Status) expected $Expected"
            Assert ($result.ExitCode -eq $Exit) "$Case exit"
        }
        Assert (($script:ops -contains 'Import') -eq $ImportExpected) "$Case import boundary"
        if($Case -in @('whatif','decline','failover','hash-mismatch','invalid-hash','exists','sidecar-exists','runtime-failure','identity-race')){Assert ($script:ops.Count -eq 0) "$Case no DHCP mutation/backup"}
        if($result -and $result.RunFolder){
            $report=Get-Content (Join-Path $result.RunFolder 'report.json') -Raw|ConvertFrom-Json
            Assert ($report.Status -eq $Expected) "$Case final JSON"
            $html=Get-Content (Join-Path $result.RunFolder 'Report.html') -Raw
            Assert ($html -notmatch '<SYNTHETIC>') "$Case HTML encoded"
            $lines=@(Get-Content (Join-Path $result.RunFolder 'actions.jsonl')|ForEach-Object{$_|ConvertFrom-Json})
            Assert ($lines[0].State -eq 'STARTED') "$Case journal started"
        }
        if($Expected -eq 'Exported'){
            Assert (Test-Path -LiteralPath $result.File) "$Case XML published"
            Assert (Test-Path -LiteralPath ($result.File+'.sha256')) "$Case hash sidecar"
        }
        if($ImportExpected){
            Assert ($script:ops.IndexOf('Backup') -lt $script:ops.IndexOf('Import')) "$Case native backup precedes import"
            Assert ([IO.Path]::GetFileName($script:importArgs.Path) -eq 'InputSnapshot.xml') "$Case imports stable snapshot"
            Assert ($script:importArgs.Overwrite -eq ($Case -eq 'overwrite')) "$Case overwrite explicit"
            Assert (($script:ops -contains 'Restart') -eq ($Case -in @('restart','restart-failure'))) "$Case restart opt-in"
        }
        if($Case -eq 'exists'){Assert ((Get-Content (Join-Path $folder 'export.xml') -Raw) -eq 'KEEP') 'existing export unchanged'}
        $script:cases++
    }
    Invoke-Case 'export' 'Export' 'Exported' 0 $false
    Invoke-Case 'configuration-only' 'Export' 'Exported' 0 $false
    foreach($case in @('exists','sidecar-exists','runtime-failure')){Invoke-Case $case 'Export' 'PreflightBlocked' 1 $false}
    foreach($case in @('whatif','decline')){Invoke-Case $case 'Export' 'NotApplied' 0 $false;Invoke-Case $case 'Import' 'NotApplied' 0 $false}
    foreach($case in @('export-failure','invalid-export')){Invoke-Case $case 'Export' 'ExportFailed' 1 $false}
    foreach($case in @('failover','hash-mismatch','invalid-hash','identity-race')){Invoke-Case $case 'Import' 'PreflightBlocked' 1 $false}
    foreach($case in @('backup-failure','empty-backup','backup-race')){Invoke-Case $case 'Import' 'Blocked' 1 $false}
    Invoke-Case 'export-failure' 'Import' 'Blocked' 1 $false
    foreach($case in @('import','overwrite','restart','configuration-only')){Invoke-Case $case 'Import' 'ImportedAwaitingValidation' 0 $true}
    Invoke-Case 'warning' 'Import' 'NeedsReview' 2 $true
    foreach($case in @('import-failure','restart-failure')){Invoke-Case $case 'Import' 'FailedAfterImportPossible' 1 $true}

    # Test remote dispatch without connecting to a host.
    function Invoke-Command {
        param([string]$ComputerName,[scriptblock]$ScriptBlock,$ArgumentList,$ErrorAction)
        $script:remoteName=$ComputerName
        [pscustomobject]@{Synthetic=$true;Stage=$ArgumentList.Stage}
    }
    $dispatch=Invoke-DhcpTarget 'synthetic.example.test' ([pscustomobject]@{Stage='Plan'})
    Assert ($script:remoteName -eq 'synthetic.example.test' -and $dispatch.Stage -eq 'Plan') 'remote dispatch preserves chosen server and stage'
    function Test-ActualConfirmation {
        [CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]param()
        $PSCmdlet.ShouldProcess('SYNTHETIC','SYNTHETIC')
    }
    Assert (-not (Test-ActualConfirmation -WhatIf)) 'actual ShouldProcess WhatIf'
    Write-Host "PASS: $checks assertions; $cases mocked workflows. No real DHCP operation or remote connection."
} finally {Remove-Item -LiteralPath $temp -Recurse -Force}
