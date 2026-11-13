#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
FMODEL Windows Time 2.0.0 - PDC.
.DESCRIPTION
Standalone. Run without parameters to apply AFTER confirmation. -WhatIf performs
read-only preflight (AD/DNS as applicable), without reports or W32Time mutation.
PDC: current forest-root PDC only. DOMHIER: other domain-joined servers only.
Requires 64-bit Windows Server 2016+, elevated Windows PowerShell 5.1 or PowerShell 7.
Configured means local settings checked, NOT proof of synchronized/accurate time.
.EXAMPLE
.\Configure-NTP-PDC.ps1 -WhatIf
.EXAMPLE
.\Configure-NTP-PDC.ps1
.NOTES
FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO
F. Model | fmodel@fmodel.com.br | Revision assistance: Akira (ChatGPT)
Backup cannot undo clock changes. No automatic rollback. See bilingual manuals.
Save as UTF-8 with BOM for Windows PowerShell 5.1. Do not dot-source this script.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# EDITE AQUI / EDIT HERE: organization-approved NTP hostnames, without flags or IPs.
# Original ntp.br sources; review location, availability and policy before use.
$NtpServers = @(
    'a.st1.ntp.br'
    'c.st1.ntp.br'
    'd.st1.ntp.br'
    'e.st1.ntp.br'
)

function Get-TimeNativePath {
    param([ValidateSet('w32tm.exe','reg.exe')][string]$Tool)
    Join-Path ([Environment]::SystemDirectory) $Tool
}

function Invoke-TimeNative {
    param([ValidateSet('w32tm.exe','reg.exe')][string]$Tool, [string[]]$Arguments)
    foreach ($argument in $Arguments) {
        if ($argument -match '["\r\n\x00]' -or $argument.EndsWith('\')) {
            throw 'Argumento nativo invalido / Invalid native argument.'
        }
    }
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = Get-TimeNativePath $Tool
    $start.Arguments = ($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            try { $process.Kill() } catch { }
            throw "Timeout de 30 s / 30 s timeout: $Tool. A operacao pode ter ocorrido / Operation may have occurred."
        }
        $output = $stdout.GetAwaiter().GetResult()
        $errorText = $stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw "$Tool exit=$($process.ExitCode): $output $errorText"
        }
        return ($output + $errorText).Trim()
    } finally { $process.Dispose() }
}

function Get-TimeSettings {
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time'
    [pscustomobject][ordered]@{
        Type = (Get-ItemProperty "$base\Parameters" -ErrorAction Stop).Type
        NtpServer = (Get-ItemProperty "$base\Parameters" -ErrorAction Stop).NtpServer
        AnnounceFlags = (Get-ItemProperty "$base\Config" -ErrorAction Stop).AnnounceFlags
        NtpClientEnabled = (Get-ItemProperty "$base\TimeProviders\NtpClient" -ErrorAction Stop).Enabled
        NtpServerEnabled = (Get-ItemProperty "$base\TimeProviders\NtpServer" -ErrorAction Stop).Enabled
    }
}

function Get-TimeContext {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or -not [Environment]::Is64BitProcess) {
        throw 'Use Windows e PowerShell 64 bits / Use Windows and 64-bit PowerShell.'
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Abra como Administrador / Run as Administrator.'
    }
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    if (-not $computer.PartOfDomain -or $os.ProductType -eq 1 -or [int]$os.BuildNumber -lt 14393) {
        throw 'Requer servidor de dominio Windows Server 2016+ / Requires domain-joined Windows Server 2016+.'
    }
    Add-Type -AssemblyName System.DirectoryServices
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()
    # The forest belongs to this computer's domain, not the interactive user's domain.
    $rootPdc = $domain.Forest.RootDomain.PdcRoleOwner.Name.TrimEnd('.')
    $fqdn = ('{0}.{1}' -f $computer.DNSHostName.Split('.')[0], $domain.Name).TrimEnd('.')
    $service = Get-CimInstance Win32_Service -Filter "Name='W32Time'" -ErrorAction Stop
    if (-not $service) { throw 'W32Time ausente / W32Time missing.' }
    $addresses = foreach ($nic in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        foreach ($unicast in $nic.GetIPProperties().UnicastAddresses) { $unicast.Address.ToString() }
    }
    [pscustomobject]@{
        Computer=$fqdn; RootPdc=$rootPdc; IsDC=($os.ProductType -eq 2)
        PolicyPresent=(Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\W32Time')
        StartMode=$service.StartMode; ServiceState=$service.State
        Domain=$domain.Name; Operator=$identity.Name; OperatorSid=$identity.User.Value
        Manufacturer=$computer.Manufacturer; Model=$computer.Model
        LocalAddresses=@($addresses); Settings=(Get-TimeSettings)
    }
}

function Assert-TimeTarget {
    param($Context, [ValidateSet('PDC','DOMHIER')][string]$Mode)
    if ($Context.PolicyPresent) { throw 'Politica W32Time presente: revisar GPO / W32Time policy exists: review GPO.' }
    if ($Context.StartMode -eq 'Disabled') { throw 'W32Time desabilitado / W32Time disabled.' }
    $isRootPdc = $Context.Computer.TrimEnd('.') -ieq $Context.RootPdc.TrimEnd('.')
    if ($Mode -eq 'PDC' -and (-not $Context.IsDC -or -not $isRootPdc)) {
        throw "Use o PDC raiz / Use forest-root PDC: $($Context.RootPdc)"
    }
    if ($Mode -eq 'DOMHIER' -and $isRootPdc) { throw 'DOMHIER bloqueado no PDC raiz / DOMHIER blocked on forest-root PDC.' }
}

function Resolve-TimeAddresses {
    param([string]$Name)
    [Net.Dns]::GetHostAddresses($Name)
}

function Get-TimePeerList {
    param([string[]]$Servers, $Context)
    $names = @($Servers | ForEach-Object { $_.Trim().ToLowerInvariant() } | Select-Object -Unique)
    if ($names.Count -lt 1 -or $names.Count -gt 10) { throw 'Informe 1 a 10 nomes NTP / Supply 1 to 10 NTP hostnames.' }
    foreach ($name in $names) {
        if ($name.Length -gt 253 -or $name -notmatch '^[a-z0-9][a-z0-9.-]*[a-z0-9]$' -or
            [Uri]::CheckHostName($name) -ne [UriHostNameType]::Dns -or $name -match '\.\.') {
            throw "Nome NTP invalido (sem IP, flags ou URL) / Invalid NTP hostname: $name"
        }
        if ($name -ieq $Context.Computer -or $name -ieq $Context.Computer.Split('.')[0]) { throw 'Peer aponta para o proprio servidor / Peer is this server.' }
        $addresses = @(Resolve-TimeAddresses $name)
        if ($addresses.Count -eq 0) { throw "DNS sem enderecos / DNS returned no addresses: $name" }
        foreach ($address in $addresses) {
            $ip = [Net.IPAddress]::Parse($address.ToString())
            if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
            $bytes = $ip.GetAddressBytes()
            if ([Net.IPAddress]::IsLoopback($ip) -or $ip.Equals([Net.IPAddress]::Any) -or
                $ip.Equals([Net.IPAddress]::IPv6Any) -or $ip.IsIPv6Multicast -or
                ($bytes.Length -eq 4 -and $bytes[0] -ge 224) -or $ip.ToString() -in $Context.LocalAddresses) {
                throw "Endereco NTP inadequado ou local / Invalid or local NTP address: $ip"
            }
        }
    }
    $peers = for ($i=0; $i -lt $names.Count; $i++) {
        # With exactly two peers, make the second fallback-only (0x2 + client 0x8).
        $flag = if ($names.Count -eq 2 -and $i -eq 1) { '0xA' } else { '0x8' }
        '{0},{1}' -f $names[$i], $flag
    }
    $peers -join ' '
}

function New-TimeRunFolder {
    $base = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($base)) { throw 'LocalApplicationData indisponivel / unavailable.' }
    $path = Join-Path $base ('FMODEL\WindowsTime\Run-{0}-{1}' -f [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N'))
    $null = New-Item -Path $path -ItemType Directory -ErrorAction Stop
    $path
}

function Write-TimeJournal {
    param([string]$Folder, [string]$State, [string]$Action)
    $line = [ordered]@{Utc=[DateTime]::UtcNow.ToString('o'); State=$State; Action=$Action} | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($line + [Environment]::NewLine)
    $stream = [IO.File]::Open((Join-Path $Folder 'actions.jsonl'), [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) } finally { $stream.Dispose() }
}

function Invoke-TimeMutation {
    param([string]$Folder, [string]$Action, [scriptblock]$Body)
    Write-TimeJournal $Folder 'INTENT' $Action
    & $Body | Out-Null
    Write-TimeJournal $Folder 'COMPLETED' $Action
}

function Backup-TimeRegistry {
    param([string]$Folder)
    $path = Join-Path $Folder 'W32Time-before.reg'
    $null = Invoke-TimeNative 'reg.exe' @('export','HKLM\SYSTEM\CurrentControlSet\Services\W32Time',$path,'/y')
    if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) { throw 'Backup ausente ou vazio / Missing or empty backup.' }
    $path
}

function Set-TimeRegistry {
    param([string]$Mode)
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time'
    $null = New-ItemProperty "$base\TimeProviders\NtpClient" -Name Enabled -Value 1 -PropertyType DWord -Force -ErrorAction Stop
    $null = New-ItemProperty "$base\Config" -Name AnnounceFlags -Value 10 -PropertyType DWord -Force -ErrorAction Stop
    if ($Mode -eq 'PDC') {
        $null = New-ItemProperty "$base\TimeProviders\NtpServer" -Name Enabled -Value 1 -PropertyType DWord -Force -ErrorAction Stop
    }
}

function Set-TimeService {
    param([ValidateSet('Start','Restart')][string]$Action)
    if ($Action -eq 'Start') { Start-Service W32Time -ErrorAction Stop }
    else { Restart-Service W32Time -ErrorAction Stop }
    (Get-Service W32Time -ErrorAction Stop).WaitForStatus('Running',[TimeSpan]::FromSeconds(30))
}

function Get-TimeDiagnostics {
    $result = [ordered]@{}
    foreach ($query in @('configuration','source','status','peers')) {
        try {
            $arguments = @('/query',"/$query")
            if ($query -eq 'status') { $arguments += '/verbose' }
            $result[$query] = Invoke-TimeNative 'w32tm.exe' $arguments
        } catch { $result[$query] = "QUERY FAILED / CONSULTA FALHOU: $($_.Exception.Message)" }
    }
    [pscustomobject]$result
}

function Test-TimeConfiguration {
    param($Context, [string]$Mode, [string]$Peers)
    $settings = $Context.Settings
    if ($Context.ServiceState -ne 'Running' -or $settings.NtpClientEnabled -ne 1 -or $settings.AnnounceFlags -ne 10) { return $false }
    if ($Mode -eq 'DOMHIER') { return $settings.Type -ieq 'NT5DS' }
    $expected = @($Peers.ToLowerInvariant() -split '\s+' | Sort-Object) -join ' '
    $actual = @($settings.NtpServer.ToLowerInvariant().Trim() -split '\s+' | Sort-Object) -join ' '
    return ($settings.Type -ieq 'NTP' -and $settings.NtpServerEnabled -eq 1 -and $actual -eq $expected)
}

function Write-TimeReport {
    param([string]$Folder, $Report)
    $json = $Report | ConvertTo-Json -Depth 12
    $encoding = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $Folder 'report.json'), $json, $encoding)
    $encode = { param($value) [Net.WebUtility]::HtmlEncode([string]$value) }
    $status = & $encode $Report.Status
    $mode = & $encode $Report.Mode
    $details = & $encode $json
    $html = @"
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'">
<title>FMODEL | Windows Time</title><style>
body{font:17px system-ui,sans-serif;background:#f1f5f9;color:#14243a;margin:0}
main{max-width:1000px;margin:28px auto;padding:28px;background:white;border-radius:12px}
h1{color:#17477c} .card{padding:18px;background:#eaf3ff;border-left:5px solid #1769aa;margin:18px 0}
pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f3f5f7;padding:16px;font-size:13px}
</style></head><body><main><h1>FMODEL | Windows Time 2.0.0</h1>
<p>FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO<br>fmodel@fmodel.com.br</p>
<div class="card"><b>Resultado / Result: $status</b><br>Modo / Mode: $mode</div>
<p><b>Configurado não significa sincronismo comprovado.</b> Confira a fonte, o último sincronismo, o leap indicator e o stratum nos diagnósticos.</p>
<p><b>Configured does not certify synchronization.</b> Review source, last successful sync, leap indicator and stratum in diagnostics.</p>
<p>Configured = configuração local confirmada / local configuration confirmed. NeedsReview = revisar / review required.
FailedAfterMutationPossible = alteração parcial possível / partial change possible. Blocked = sem alteração W32Time iniciada / no W32Time mutation started.</p>
<p>O backup do Registro não desfaz ajustes do relógio. / Registry backup cannot undo clock changes.</p>
<details><summary>Detalhes técnicos / Technical details</summary><pre>$details</pre></details>
</main></body></html>
"@
    [IO.File]::WriteAllText((Join-Path $Folder 'Report.html'), $html, $encoding)
}

function Invoke-TimeSetup {
    param([ValidateSet('PDC','DOMHIER')][string]$Mode, [string[]]$Servers, $Caller)
    $context = Get-TimeContext
    Assert-TimeTarget $context $Mode
    $peers = if ($Mode -eq 'PDC') { Get-TimePeerList $Servers $context } else { '' }
    Write-Host "FMODEL | $Mode | $($context.Computer)" -ForegroundColor Cyan
    if ($peers) { Write-Host "NTP: $peers" }
    if (-not $Caller.ShouldProcess($context.Computer,"$Mode : configure Windows Time, restart service and request resync")) {
        return [pscustomobject]@{Status='NotApplied'; ExitCode=0; RunFolder=$null}
    }
    $mutex = New-Object Threading.Mutex($false,'Global\FMODEL.WindowsTime.Setup')
    $locked = $false
    $folder = $null
    $changed = $false
    $report = [ordered]@{Version='2.0.0'; Mode=$Mode; StartedUtc=[DateTime]::UtcNow.ToString('o'); Status='Blocked'; Before=$context; Peers=$peers; After=$null; Backup=$null; Resync=$null; DiagnosticsBefore=$null; DiagnosticsAfter=$null; Error=$null; ExitCode=1}
    try {
        try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
        if (-not $locked) { throw 'Outra execucao local ativa / Another local run is active.' }
        $context = Get-TimeContext
        Assert-TimeTarget $context $Mode
        if ($context.Computer -ine $report.Before.Computer -or $context.RootPdc -ine $report.Before.RootPdc) { throw 'Alvo mudou / Target changed.' }
        $report.Before = $context
        $folder = New-TimeRunFolder
        $report.Backup = Backup-TimeRegistry $folder
        $report.DiagnosticsBefore = Get-TimeDiagnostics
        $report.Status = 'BackupSaved'
        Write-TimeReport $folder $report
        $latest = Get-TimeContext
        Assert-TimeTarget $latest $Mode
        if ($latest.Computer -ine $context.Computer -or $latest.RootPdc -ine $context.RootPdc -or
            ($latest.Settings | ConvertTo-Json -Compress) -cne ($context.Settings | ConvertTo-Json -Compress)) {
            throw 'Alvo/configuracao mudou apos backup / Target or settings changed after backup.'
        }
        # From here, failure may leave partial changes. Never retry automatically.
        $changed = $true
        if ($latest.ServiceState -ne 'Running') { Invoke-TimeMutation $folder 'Start W32Time' { Set-TimeService 'Start' } }
        Invoke-TimeMutation $folder 'Set provider DWORDs and AnnounceFlags=10' { Set-TimeRegistry $Mode }
        $arguments = if ($Mode -eq 'PDC') { @('/config',"/manualpeerlist:$peers",'/syncfromflags:manual','/update') }
                     else { @('/config','/syncfromflags:domhier','/update') }
        Invoke-TimeMutation $folder "w32tm $($arguments -join ' ')" { Invoke-TimeNative 'w32tm.exe' $arguments }
        Invoke-TimeMutation $folder 'Restart W32Time' { Set-TimeService 'Restart' }
        try {
            Invoke-TimeMutation $folder 'w32tm /resync /rediscover' { Invoke-TimeNative 'w32tm.exe' @('/resync','/rediscover') }
            $report.Resync = 'RequestAccepted'
        } catch { $report.Resync = "FailedOrUnknown: $($_.Exception.Message)" }
        $report.After = Get-TimeContext
        Assert-TimeTarget $report.After $Mode
        if ($report.After.Computer -ine $context.Computer -or $report.After.RootPdc -ine $context.RootPdc) { throw 'Alvo mudou durante aplicacao / Target changed during application.' }
        $report.DiagnosticsAfter = Get-TimeDiagnostics
        $queriesOk = @($report.DiagnosticsAfter.PSObject.Properties | Where-Object { $_.Value -like 'QUERY FAILED*' }).Count -eq 0
        $valid = Test-TimeConfiguration $report.After $Mode $peers
        if ($valid -and $queriesOk -and $report.Resync -eq 'RequestAccepted') {
            $report.Status = 'Configured'; $report.ExitCode = 0
        } else { $report.Status = 'ConfiguredNeedsReview'; $report.ExitCode = 2 }
    } catch {
        $report.Error = $_.Exception.Message
        $report.Status = if ($changed) { 'FailedAfterMutationPossible' } else { 'Blocked' }
        $report.ExitCode = 1
        Write-Warning $report.Error
    } finally {
        try {
            $report['EndedUtc'] = [DateTime]::UtcNow.ToString('o')
            if ($folder) { Write-TimeReport $folder $report }
        } finally { if ($locked) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
    }
    [pscustomobject]@{Status=$report.Status; ExitCode=$report.ExitCode; RunFolder=$folder}
}

try {
    $result = Invoke-TimeSetup -Mode 'PDC' -Servers $NtpServers -Caller $PSCmdlet
    Write-Host ("Resultado / Result: {0}" -f $result.Status)
    if ($result.RunFolder) { Write-Host ("Relatorio / Report: {0}" -f (Join-Path $result.RunFolder 'Report.html')) }
    Write-Host 'Confira sincronismo nos diagnosticos / Review time synchronization in diagnostics.'
    exit $result.ExitCode
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
