#Requires -Version 5.1
<#
.SYNOPSIS
FMODEL DHCP Transfer 1.0.0 - Import.
.DESCRIPTION
Standalone. Confirm before applying. -WhatIf performs target-side read-only preflight.
All paths are LOCAL TO THE CHOSEN SERVER. Remote operation requires existing WinRM.
Worker: elevated 64-bit Windows PowerShell 5.1, Windows Server 2016+, DHCP Server role.
Use powershell.exe for operations; pwsh can run offline tests only.
No automatic authorization, source shutdown, failover migration or rollback.
.EXAMPLE
.\Import-DHCP.ps1 -ImportFile C:\DHCP-Backup\DHCP-Export.xml -WhatIf
.NOTES
FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO
F. Model | fmodel@fmodel.com.br | Revision assistance: Akira (ChatGPT)
See PT-BR/EN-US manuals. Save UTF-8 with BOM for Windows PowerShell 5.1.
Run as a file, not by dot-sourcing. No real DHCP migration was tested in development.
#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [string]$DhcpServer = '.',
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ImportFile,
    [string]$BackupPath = 'C:\DHCP-Backup',
    [switch]$ConfigurationOnly,
    [switch]$ScopeOverwrite,
    [switch]$RestartService,
    [string]$ExpectedSha256 = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Invoke-DhcpWorker {
    param($Request)
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    function Get-DhcpContext {
        if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or -not [Environment]::Is64BitProcess -or $PSVersionTable.PSEdition -ne 'Desktop') {
            throw 'Use Windows PowerShell 5.1 de 64 bits / Use 64-bit Windows PowerShell 5.1 (powershell.exe).'
        }
        $id=[Security.Principal.WindowsIdentity]::GetCurrent()
        $principal=New-Object Security.Principal.WindowsPrincipal($id)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Requer Administrador elevado no alvo / Elevated target administration required.' }
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        if ($os.ProductType -eq 1 -or [int]$os.BuildNumber -lt 14393) { throw 'Requer Windows Server 2016+ / Windows Server 2016+ required.' }
        Import-Module DhcpServer -ErrorAction Stop
        $service=Get-Service DHCPServer -ErrorAction Stop
        if ($service.Status -ne 'Running') { throw 'DHCPServer deve estar Running / DHCPServer must be Running.' }
        $cs=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $scopes4=@(DhcpServer\Get-DhcpServerv4Scope -ErrorAction Stop | Select-Object ScopeId,Name,State,StartRange,EndRange,SubnetMask)
        $scopes6=@(DhcpServer\Get-DhcpServerv6Scope -ErrorAction Stop | Select-Object Prefix,Name,State)
        $failover=@(DhcpServer\Get-DhcpServerv4Failover -ErrorAction Stop | Select-Object Name,PartnerServer,State)
        [pscustomobject]@{
            Computer=$cs.DNSHostName; Domain=$cs.Domain; Operator=$id.Name; OperatorSid=$id.User.Value
            Identity=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -ErrorAction Stop).MachineGuid
            OS=$os.Caption; Build=$os.BuildNumber; Service=$service.Status.ToString()
            Scopes4=$scopes4; Scopes6=$scopes6; Failover=$failover
        }
    }

    function Resolve-DhcpPath {
        param([string]$Path)
        if ($Path -notmatch '^[a-zA-Z]:\\' -or $Path -match '[\x00-\x1F*?"<>|]' -or $Path.Substring(2).Contains(':')) {
            throw 'Use caminho absoluto local no servidor (C:\...) / Use an absolute local server path.'
        }
        $full=[IO.Path]::GetFullPath($Path)
        $drive=New-Object IO.DriveInfo($full.Substring(0,3))
        if ($drive.DriveType -eq 'Network') { throw 'Unidade de rede nao suportada / Network drive unsupported.' }
        $current=$full
        while ($current) {
            if (Test-Path -LiteralPath $current) {
                $item=Get-Item -LiteralPath $current -Force -ErrorAction Stop
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse point/junction nao suportado / Reparse point unsupported.' }
                if ($current -ne $full -and -not $item.PSIsContainer) { throw 'Pasta ancestral invalida / Parent is not a directory.' }
            }
            $parent=[IO.Path]::GetDirectoryName($current.TrimEnd('\'))
            if ($parent -eq $current) { break }; $current=$parent
        }
        $full
    }

    function Test-DhcpFileName {
        param([string]$Name)
        if ($Name.Length -gt 150 -or $Name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*\.xml$' -or
            $Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\.' ) {
            throw 'FileName deve ser um nome XML simples / FileName must be a simple XML filename.'
        }
    }

    function Get-DhcpXmlInfo {
        param([string]$Path)
        $settings=New-Object Xml.XmlReaderSettings
        $settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver=$null
        $settings.MaxCharactersFromEntities=1024
        $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try {
            if ($stream.Length -eq 0) { throw 'XML vazio / Empty XML.' }
            $reader=[Xml.XmlReader]::Create($stream,$settings)
            try {
                $null=$reader.MoveToContent()
                if ($reader.LocalName -cne 'DHCPServer') { throw 'Raiz XML deve ser DHCPServer / XML root must be DHCPServer.' }
                while ($reader.Read()) { }
            } finally { $reader.Dispose() }
            $stream.Position=0
            $sha=[Security.Cryptography.SHA256]::Create()
            try { $hash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
            finally { $sha.Dispose() }
            [pscustomobject]@{Path=$Path; Bytes=$stream.Length; SHA256=$hash}
        } finally { $stream.Dispose() }
    }

    function Invoke-DhcpExport {
        param([string]$Path,[bool]$IncludeLeases)
        # No Force: existing export files must never be silently overwritten.
        DhcpServer\Export-DhcpServer -File $Path -Leases:$IncludeLeases -Confirm:$false -ErrorAction Stop -WarningAction Stop
    }

    function Invoke-DhcpBackup {
        param([string]$Path)
        DhcpServer\Backup-DhcpServer -Path $Path -Confirm:$false -ErrorAction Stop -WarningAction Stop
    }

    function Invoke-DhcpImport {
        param([string]$Path,[string]$Backup,[bool]$IncludeLeases,[bool]$Overwrite)
        $warnings=@()
        DhcpServer\Import-DhcpServer -File $Path -BackupPath $Backup -Leases:$IncludeLeases -ScopeOverwrite:$Overwrite -Force -Confirm:$false -ErrorAction Stop -WarningVariable warnings
        # Force suppresses the native prompt AFTER the wrapper's High-impact approval.
        @($warnings | ForEach-Object { $_.ToString() })
    }

    function Restart-DhcpLocalService {
        Restart-Service -Name DHCPServer -ErrorAction Stop
        (Get-Service DHCPServer -ErrorAction Stop).WaitForStatus('Running',[TimeSpan]::FromSeconds(30))
    }

    function Write-DhcpJournal {
        param([string]$Folder,[string]$State,[string]$Action)
        $line=[ordered]@{Utc=[DateTime]::UtcNow.ToString('o');State=$State;Action=$Action}|ConvertTo-Json -Compress
        $bytes=[Text.Encoding]::UTF8.GetBytes($line+[Environment]::NewLine)
        $file=[IO.File]::Open((Join-Path $Folder 'actions.jsonl'),[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
        try { $file.Write($bytes,0,$bytes.Length);$file.Flush($true) } finally { $file.Dispose() }
    }

    function Write-DhcpReport {
        param([string]$Folder,$Report)
        $encoding=New-Object Text.UTF8Encoding($false)
        $json=$Report|ConvertTo-Json -Depth 15
        [IO.File]::WriteAllText((Join-Path $Folder 'report.json'),$json,$encoding)
        $status=[Net.WebUtility]::HtmlEncode([string]$Report.Status)
        $hostName=[Net.WebUtility]::HtmlEncode([string]$Report.Before.Computer)
        $details=[Net.WebUtility]::HtmlEncode($json)
        $artifact=[Net.WebUtility]::HtmlEncode([string]$Report.Artifact)
        $errorText=[Net.WebUtility]::HtmlEncode([string]$Report.Error)
        $html=@"
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none';style-src 'unsafe-inline';base-uri 'none'">
<title>FMODEL | DHCP Transfer</title><style>body{font:17px system-ui;background:#eef3f8;color:#16314d}main{max-width:1000px;margin:25px auto;background:white;padding:28px;border-radius:12px}h1{color:#164a7c}.box{padding:18px;background:#e5f1ff;border-left:5px solid #1768a0;overflow-wrap:anywhere}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f2f5f8;padding:15px;font-size:13px}</style></head>
<body><main><h1>FMODEL | DHCP Transfer 1.0.0</h1><p>FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO<br>fmodel@fmodel.com.br</p>
<div class="box"><b>Resultado / Result: $status</b><p>Servidor / Server: $hostName</p><p>Arquivo no servidor / File on server: $artifact</p></div>
<p><b>Exported:</b> XML e hash gerados / XML and hash generated.</p><p><b>ImportedAwaitingValidation:</b> cmdlet retornou; validar escopos, opções e clientes / cmdlet returned; validate scopes, options and clients.</p>
<p><b>NeedsReview:</b> revisar avisos/diagnóstico / review warnings/diagnostics. <b>FailedAfterImportPossible:</b> pode haver alterações parciais / partial changes possible.</p>
<p>Não é migração completa nem prova de atendimento DHCP. / Not a complete migration or proof of DHCP client service.</p><p>$errorText</p>
<details><summary>Detalhes técnicos / Technical details</summary><pre>$details</pre></details></main></body></html>
"@
        [IO.File]::WriteAllText((Join-Path $Folder 'Report.html'),$html,$encoding)
    }

    function Copy-DhcpSnapshot {
        param([string]$Source,[string]$Destination)
        $inputStream=[IO.File]::Open($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try {
            $outputStream=[IO.File]::Open($Destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try { $inputStream.CopyTo($outputStream);$outputStream.Flush($true) } finally { $outputStream.Dispose() }
        } finally { $inputStream.Dispose() }
    }

    function Get-DhcpPlan {
        param($Request)
        $context=Get-DhcpContext
        if ($Request.Mode -eq 'Import' -and @($context.Failover).Count -gt 0) { throw 'Destino com failover: use procedimento especifico / Failover destination requires a dedicated procedure.' }
        $base=Resolve-DhcpPath $Request.BasePath
        if ((Test-Path -LiteralPath $base) -and -not (Get-Item -LiteralPath $base).PSIsContainer) { throw 'Diretorio base e um arquivo / Base directory is a file.' }
        $file=$null; $info=$null
        if ($Request.Mode -eq 'Export') {
            Test-DhcpFileName $Request.FileName
            $file=Resolve-DhcpPath (Join-Path $base $Request.FileName)
            if ((Test-Path -LiteralPath $file) -or (Test-Path -LiteralPath ($file+'.sha256'))) { throw 'Exportacao existente: escolha outro FileName / Export exists: choose another FileName.' }
        } else {
            $file=Resolve-DhcpPath $Request.ImportFile
            $info=Get-DhcpXmlInfo $file
            if ($Request.ExpectedSha256 -and $Request.ExpectedSha256 -ine $info.SHA256) { throw 'SHA256 divergente / SHA256 mismatch.' }
        }
        [pscustomobject]@{Context=$context; BasePath=$base; File=$file; Xml=$info}
    }

    if ($Request.Mode -notin @('Export','Import') -or $Request.Stage -notin @('Plan','Apply')) { throw 'Requisicao invalida / Invalid request.' }
    $plan=Get-DhcpPlan $Request
    if ($Request.Stage -eq 'Plan') { return $plan }
    if ($plan.Context.Identity -cne $Request.Plan.Context.Identity -or $plan.File -ine $Request.Plan.File -or $plan.BasePath -ine $Request.Plan.BasePath) { throw 'Alvo/caminho mudou apos aprovacao / Target or path changed after approval.' }
    if ($Request.Mode -eq 'Import' -and $plan.Xml.SHA256 -ine $Request.Plan.Xml.SHA256) { throw 'XML mudou apos aprovacao / XML changed after approval.' }
    $mutex=New-Object Threading.Mutex($false,'Global\FMODEL.DhcpTransfer')
    $locked=$false; $folder=$null; $importStarted=$false; $inputLock=$null
    $report=[ordered]@{Version='1.0.0'; Mode=$Request.Mode; Status='Blocked'; StartedUtc=[DateTime]::UtcNow.ToString('o'); Before=$plan.Context; After=$null; Artifact=$plan.File; IncludeLeases=[bool]$Request.IncludeLeases; ScopeOverwrite=[bool]$Request.ScopeOverwrite; RestartRequested=[bool]$Request.RestartService; InputSHA256=$null; Backups=@(); Warnings=@(); Error=$null; ExitCode=1}
    try {
        try { $locked=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked=$true }
        if (-not $locked) { throw 'Outra operacao DHCP local ativa / Another local DHCP operation is active.' }
        $latest=Get-DhcpPlan $Request
        if ($latest.Context.Identity -cne $plan.Context.Identity -or ($latest.Context | ConvertTo-Json -Depth 8 -Compress) -cne ($plan.Context | ConvertTo-Json -Depth 8 -Compress)) { throw 'Estado do destino mudou / Target state changed.' }
        $runName='{0}-{1}-{2}' -f $Request.Mode,[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'),[guid]::NewGuid().ToString('N')
        $folder=Join-Path $plan.BasePath $runName
        $null=New-Item -Path $folder -ItemType Directory -Force -ErrorAction Stop
        Write-DhcpJournal $folder 'STARTED' $Request.Mode
        Write-DhcpReport $folder $report
        if ($Request.Mode -eq 'Export') {
            $temporary=Join-Path $folder 'Export.partial.xml'
            Write-DhcpJournal $folder 'INTENT' 'Export XML'
            Invoke-DhcpExport $temporary ([bool]$Request.IncludeLeases) | Out-Null
            $info=Get-DhcpXmlInfo $temporary
            # File.Move refuses to overwrite; both paths are on the selected local volume.
            [IO.File]::Move($temporary,$plan.File)
            $hashPath=$plan.File+'.sha256'
            $hashBytes=[Text.Encoding]::UTF8.GetBytes($info.SHA256+'  '+[IO.Path]::GetFileName($plan.File)+[Environment]::NewLine)
            $hashStream=[IO.File]::Open($hashPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
            try { $hashStream.Write($hashBytes,0,$hashBytes.Length);$hashStream.Flush($true) } finally { $hashStream.Dispose() }
            $report.InputSHA256=$info.SHA256
            Write-DhcpJournal $folder 'COMPLETED' 'Export XML and SHA256'
            $report.Status='Exported';$report.ExitCode=0
        } else {
            $snapshot=Join-Path $folder 'InputSnapshot.xml'
            Copy-DhcpSnapshot $plan.File $snapshot
            $inputLock=[IO.File]::Open($snapshot,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
            $snapshotInfo=Get-DhcpXmlInfo $snapshot
            if ($snapshotInfo.SHA256 -ine $Request.Plan.Xml.SHA256) { throw 'Snapshot XML divergente / XML snapshot mismatch.' }
            $report.InputSHA256=$snapshotInfo.SHA256
            $nativeBackup=Join-Path $folder 'PreImportNative'
            $null=New-Item -Path $nativeBackup -ItemType Directory -ErrorAction Stop
            Write-DhcpJournal $folder 'INTENT' 'Native destination backup'
            Invoke-DhcpBackup $nativeBackup | Out-Null
            $backupFiles=@(Get-ChildItem -LiteralPath $nativeBackup -File -Recurse -ErrorAction Stop | Where-Object {$_.Length -gt 0})
            if ($backupFiles.Count -eq 0) { throw 'Backup nativo vazio / Empty native backup.' }
            $report.Backups+= $nativeBackup
            Write-DhcpJournal $folder 'COMPLETED' 'Native destination backup'
            $beforeXml=Join-Path $folder 'DestinationBefore.xml'
            Invoke-DhcpExport $beforeXml $true | Out-Null
            $null=Get-DhcpXmlInfo $beforeXml
            $report.Backups+= $beforeXml
            $report.Status='BackupSaved';Write-DhcpReport $folder $report
            $check=Get-DhcpContext
            if (($check | ConvertTo-Json -Depth 8 -Compress) -cne ($plan.Context | ConvertTo-Json -Depth 8 -Compress)) { throw 'Destino mudou apos backup / Target changed after backup.' }
            $importBackup=Join-Path $folder 'ImportCmdletBackup'
            $null=New-Item -Path $importBackup -ItemType Directory -ErrorAction Stop
            Write-DhcpJournal $folder 'INTENT' 'Import DHCP configuration'
            $importStarted=$true
            $report.Warnings=@(Invoke-DhcpImport $snapshot $importBackup ([bool]$Request.IncludeLeases) ([bool]$Request.ScopeOverwrite))
            $report.Backups+= $importBackup
            Write-DhcpJournal $folder 'COMPLETED' 'Import DHCP configuration'
            if ($Request.RestartService) {
                Write-DhcpJournal $folder 'INTENT' 'Restart local DHCPServer'
                Restart-DhcpLocalService
                Write-DhcpJournal $folder 'COMPLETED' 'Restart local DHCPServer'
            }
            $report.After=Get-DhcpContext
            if ($report.After.Identity -cne $plan.Context.Identity) { throw 'Identidade do destino mudou / Target identity changed.' }
            if ($report.Warnings.Count -gt 0) { $report.Status='NeedsReview';$report.ExitCode=2 }
            else { $report.Status='ImportedAwaitingValidation';$report.ExitCode=0 }
        }
    } catch {
        $report.Error=$_.Exception.Message
        $report.Status=if ($importStarted) {'FailedAfterImportPossible'} elseif ($Request.Mode -eq 'Export') {'ExportFailed'} else {'Blocked'}
        $report.ExitCode=1
        Write-Warning $report.Error
    } finally {
        try {
            if ($inputLock) { $inputLock.Dispose() }
            $report['EndedUtc']=[DateTime]::UtcNow.ToString('o')
            if ($folder) { Write-DhcpReport $folder $report }
        } finally { if ($locked) {$mutex.ReleaseMutex()};$mutex.Dispose() }
    }
    [pscustomobject]@{Status=$report.Status;ExitCode=$report.ExitCode;Computer=$plan.Context.Computer;File=$plan.File;SHA256=$report.InputSHA256;RunFolder=$folder;Error=$report.Error}
}

function Invoke-DhcpTarget {
    param([string]$Server,$Request)
    if ($Server -eq '.' -or $Server -ieq $env:COMPUTERNAME) { Invoke-DhcpWorker $Request }
    else {
        # All file paths and the optional restart are interpreted ON the chosen target.
        Invoke-Command -ComputerName $Server -ScriptBlock ${function:Invoke-DhcpWorker} -ArgumentList $Request -ErrorAction Stop
    }
}

function Invoke-DhcpTransfer {
    param([string]$Server,$Request,$Caller)
    if ([string]::IsNullOrWhiteSpace($Server) -or ($Server -ne '.' -and ($Server.Length -gt 253 -or [Uri]::CheckHostName($Server) -ne [UriHostNameType]::Dns -or $Server -match '[^a-zA-Z0-9.-]'))) { throw 'Use nome DNS do servidor ou ponto local / Use a server DNS name or local dot.' }
    if ($Request.ExpectedSha256 -and $Request.ExpectedSha256 -notmatch '^[a-fA-F0-9]{64}$') { throw 'SHA256 esperado invalido / Invalid expected SHA256.' }
    $Request.Stage='Plan'
    $plan=Invoke-DhcpTarget $Server $Request
    $action='{0}: file={1}; leases={2}; ScopeOverwrite={3}; restart={4}' -f $Request.Mode,$plan.File,$Request.IncludeLeases,$Request.ScopeOverwrite,$Request.RestartService
    Write-Host "FMODEL | $($plan.Context.Computer) | $action" -ForegroundColor Cyan
    if (-not $Caller.ShouldProcess("$Server / $($plan.Context.Computer)",$action)) { return [pscustomobject]@{Status='NotApplied';ExitCode=0;Computer=$plan.Context.Computer;File=$plan.File;SHA256=$null;RunFolder=$null;Error=$null} }
    $Request.Stage='Apply';$Request.Plan=$plan
    Invoke-DhcpTarget $Server $Request
}

$request=[pscustomobject]@{Mode='Import';Stage='Plan';BasePath=$BackupPath;FileName='';ImportFile=$ImportFile;IncludeLeases=(-not $ConfigurationOnly);ScopeOverwrite=[bool]$ScopeOverwrite;RestartService=[bool]$RestartService;ExpectedSha256=$ExpectedSha256;Plan=$null}

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or $PSVersionTable.PSEdition -ne 'Desktop' -or -not [Environment]::Is64BitProcess) { throw 'Execute com Windows PowerShell 5.1 de 64 bits (powershell.exe) / Run with 64-bit Windows PowerShell 5.1.' }
    $result=Invoke-DhcpTransfer -Server $DhcpServer -Request $request -Caller $PSCmdlet
    $result | Format-List Status,Computer,File,SHA256,RunFolder,Error | Out-Host
    exit $result.ExitCode
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
