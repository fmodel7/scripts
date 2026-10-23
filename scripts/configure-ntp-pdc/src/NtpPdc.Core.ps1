#requires -Version 5.1
# FMODEL | Configure NTP PDC 1.0.0. Functions only; no work at import time.
Set-StrictMode -Version 2.0

function ConvertTo-PdcPeerName {
    param([Parameter(Mandatory=$true)][string]$Name)
    $value=$Name.Trim().TrimEnd('.')
    if (-not $value -or $value -match '[\s,"/\\%\x00-\x1f\x7f]' -or $value.Length -gt 253) { throw 'Use a DNS name or IP address without flags, URL, whitespace or zone ID.' }
    $ip=$null
    if ([Net.IPAddress]::TryParse($value,[ref]$ip)) {
        if($ip.IsIPv4MappedToIPv6){$ip=$ip.MapToIPv4()}
        $bytes=$ip.GetAddressBytes()
        if ([Net.IPAddress]::IsLoopback($ip) -or $ip.Equals([Net.IPAddress]::Any) -or $ip.Equals([Net.IPAddress]::IPv6Any) -or
            ($ip.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and ($bytes[0] -ge 224 -or $bytes[0] -eq 0 -or $ip.ToString() -eq '255.255.255.255')) -or
            ($ip.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6 -and $ip.IsIPv6Multicast)) { throw 'Loopback, unspecified and multicast/broadcast addresses are not valid upstream peers.' }
        return $ip.ToString().ToLowerInvariant()
    }
    try { $value=([Globalization.IdnMapping]::new()).GetAscii($value).ToLowerInvariant() } catch { throw 'Invalid DNS peer name.' }
    if ($value.Length -gt 253 -or $value -eq 'localhost') { throw 'Invalid DNS peer name.' }
    foreach ($label in $value.Split('.')) {
        if ($label.Length -lt 1 -or $label.Length -gt 63 -or $label -notmatch '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$') { throw 'Invalid DNS peer name.' }
    }
    return $value
}

function Get-PdcPeerPlan {
    param([string[]]$Servers=@(),[ValidateSet('Automatic','Always')][string]$ReliabilityMode='Automatic')
    $names=[Collections.Generic.List[string]]::new()
    foreach ($server in $Servers) {
        $name=ConvertTo-PdcPeerName $server
        if (-not $names.Contains($name)) { $names.Add($name) }
    }
    if ($names.Count -gt 10) { throw 'At most ten distinct upstream peers are supported.' }
    $entries=@()
    for($i=0;$i -lt $names.Count;$i++) {
        $flag=if($names.Count -eq 2 -and $i -eq 1){'0xA'}else{'0x8'}
        $entries += $names[$i]+','+$flag
    }
    [pscustomobject]@{Servers=@($names.ToArray());PeerList=($entries -join ' ');ReliabilityMode=$ReliabilityMode;AnnounceFlags=$(if($ReliabilityMode -eq 'Automatic'){10}else{5});Type='NTP';NtpClientEnabled=1;NtpServerEnabled=1}
}

function Invoke-PdcNative {
    param([Parameter(Mandatory=$true)][string]$FilePath,[string[]]$Arguments=@(),[int]$TimeoutSeconds=20)
    $quoted=@(foreach($argument in $Arguments){
        # Only internal, validated arguments are accepted. None of the commands need quotes within an argument.
        if($argument -match '["\r\n\x00]'){throw 'Native arguments must not contain quotes or line breaks.'}
        if($argument -match '\s'){
            if($argument.EndsWith('\')){throw 'A quoted native argument must not end in a backslash.'}
            '"'+$argument+'"'
        }elseif($argument.Length -eq 0){'""'}else{$argument}
    })
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$FilePath; $info.Arguments=$quoted -join ' '
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $info.StandardOutputEncoding=[Console]::OutputEncoding; $info.StandardErrorEncoding=[Console]::OutputEncoding
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info
    try{
        if(-not $process.Start()){throw 'Unable to start native process.'}
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        $timedOut=-not $process.WaitForExit($TimeoutSeconds*1000)
        if($timedOut){try{$process.Kill()}catch{};$null=$process.WaitForExit(5000)}
        $out='';$err=''
        if($stdout.Wait(2000)){$out=$stdout.Result};if($stderr.Wait(2000)){$err=$stderr.Result}
        $code=if($process.HasExited){$process.ExitCode}else{-1}
        [pscustomobject]@{Executable=[IO.Path]::GetFileName($FilePath);Arguments=@($Arguments);ExitCode=$code;TimedOut=$timedOut;Output=($out+$err).Trim();ObservedUtc=[DateTime]::UtcNow.ToString('o')}
    }finally{$process.Dispose()}
}

function Assert-PdcNativeSuccess {
    param($Result,[string]$Operation)
    if($Result.TimedOut){throw "$Operation timed out; the Windows service may still have processed the request. Do not blindly repeat it."}
    if($Result.ExitCode -ne 0){throw "$Operation returned native exit code $($Result.ExitCode). See the saved native output."}
}

function Test-PdcRuntime {
    if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT){throw 'This entry point requires Windows. Use the separate offline tests on other platforms.'}
    if(-not [Environment]::Is64BitProcess){throw 'Use 64-bit PowerShell.'}
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try{
        $principal=[Security.Principal.WindowsPrincipal]::new($identity)
        if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Open an elevated PowerShell session, including for local w32tm diagnostics.'}
    }finally{$identity.Dispose()}
}

function Get-PdcOperatorIdentity {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try{[pscustomobject]@{Name=$identity.Name;Sid=$identity.User.Value}}finally{$identity.Dispose()}
}

function Get-PdcNativePaths {
    $directory=[Environment]::SystemDirectory
    $w32tm=Join-Path $directory 'w32tm.exe';$reg=Join-Path $directory 'reg.exe'
    if(-not [IO.File]::Exists($w32tm) -or -not [IO.File]::Exists($reg)){throw 'Required native Windows tools are missing.'}
    [pscustomobject]@{W32tm=$w32tm;Reg=$reg}
}

function Get-PdcContext {
    $computer=Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $os=Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $context=[ordered]@{
        ComputerName=[string]$computer.Name;LocalFqdn='';Domain=[string]$computer.Domain
        DomainRole=[int]$computer.DomainRole;PartOfDomain=[bool]$computer.PartOfDomain
        ForestRoot='';ForestRootPdc='';IsForestRootPdc=$false
        OSCaption=[string]$os.Caption;OSBuild=[int]$os.BuildNumber;ProductType=[int]$os.ProductType
        Manufacturer=[string]$computer.Manufacturer;Model=[string]$computer.Model
        VirtualizationHint='NotDetected';LocalAddresses=@()
    }
    if($context.Model -match 'Virtual Machine|VMware|VirtualBox|KVM|HVM|Xen|Amazon EC2' -or $context.Manufacturer -match 'VMware|innotek|QEMU|Xen|Amazon EC2'){$context.VirtualizationHint='PossibleVirtualMachine'}
    $context.LocalAddresses=@(foreach($nic in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()){
        foreach($unicast in $nic.GetIPProperties().UnicastAddresses){$unicast.Address.ToString()}
    })
    if($context.PartOfDomain -and $context.DomainRole -in @(4,5)){
        $domain=$null;$forest=$null;$root=$null;$pdc=$null
        try{
            # The COMPUTER domain is used, never the operator's current logon domain.
            Add-Type -AssemblyName System.DirectoryServices -ErrorAction Stop
            $domain=[DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()
            $forest=$domain.Forest;$root=$forest.RootDomain;$pdc=$root.PdcRoleOwner
            if(-not ([string]$computer.Domain).Equals($domain.Name,[StringComparison]::OrdinalIgnoreCase)){throw 'CIM and directory disagree about the computer domain.'}
            $context.Domain=$domain.Name;$context.ForestRoot=$root.Name;$context.ForestRootPdc=$pdc.Name.TrimEnd('.')
            $dnsHost=[string]$computer.DNSHostName
            if(-not $dnsHost){throw 'The local DNS host name is unavailable.'}
            $context.LocalFqdn=if($dnsHost.Contains('.')){$dnsHost.TrimEnd('.')}else{$dnsHost+'.'+$domain.Name}
            $context.IsForestRootPdc=($context.Domain.Equals($context.ForestRoot,[StringComparison]::OrdinalIgnoreCase) -and $context.LocalFqdn.Equals($context.ForestRootPdc,[StringComparison]::OrdinalIgnoreCase))
        }finally{
            foreach($object in @($pdc,$root,$forest,$domain)){if($null -ne $object -and $object -is [IDisposable]){$object.Dispose()}}
        }
    }
    [pscustomobject]$context
}

function Get-PdcPolicyState {
    $path='HKLM:\SOFTWARE\Policies\Microsoft\W32Time'
    $present=Test-Path -LiteralPath $path -ErrorAction Stop
    # Fail closed even for an empty policy branch; do not erase or bypass it.
    [pscustomobject]@{Path=$path;Present=[bool]$present}
}

function Get-PdcSettings {
    $root='HKLM:\SYSTEM\CurrentControlSet\Services\W32Time'
    $spec=@(
        @('Type',"$root\Parameters",'Type'),@('PeerList',"$root\Parameters",'NtpServer'),
        @('AnnounceFlags',"$root\Config",'AnnounceFlags'),
        @('NtpClientEnabled',"$root\TimeProviders\NtpClient",'Enabled'),
        @('NtpServerEnabled',"$root\TimeProviders\NtpServer",'Enabled'),
        @('VmIcProviderEnabled',"$root\TimeProviders\VMICTimeProvider",'Enabled'),
        @('MaxPosPhaseCorrection',"$root\Config",'MaxPosPhaseCorrection'),
        @('MaxNegPhaseCorrection',"$root\Config",'MaxNegPhaseCorrection')
    )
    $values=[ordered]@{};$details=@()
    foreach($item in $spec){
        $value=$null;$kind='Missing';$exists=Test-Path -LiteralPath $item[1] -ErrorAction Stop
        if($exists){
            $key=Get-Item -LiteralPath $item[1] -ErrorAction Stop
            try{if($key.GetValueNames() -contains $item[2]){$value=$key.GetValue($item[2]);$kind=$key.GetValueKind($item[2]).ToString()}}finally{$key.Close()}
        }
        $values[$item[0]]=$value
        $details += [pscustomobject]@{Field=$item[0];Path=$item[1];Name=$item[2];KeyExists=$exists;ValueKind=$kind;Value=$value}
    }
    $service=Get-CimInstance -ClassName Win32_Service -Filter "Name='W32Time'" -ErrorAction Stop
    if($null -eq $service){throw 'W32Time service is not installed.'}
    [pscustomobject]@{Values=[pscustomobject]$values;Registry=$details;ServiceState=[string]$service.State;ServiceStartMode=[string]$service.StartMode}
}

function Resolve-PdcPeers {
    param([string[]]$Servers,$Context)
    $results=@()
    foreach($server in $Servers){
        if($server -eq $Context.ComputerName -or $server -eq $Context.LocalFqdn){throw 'An upstream peer must not be this computer.'}
        $parsed=$null
        $addresses=if([Net.IPAddress]::TryParse($server,[ref]$parsed)){@($parsed)}else{@([Net.Dns]::GetHostAddresses($server))}
        if($addresses.Count -eq 0){throw "DNS returned no IP addresses for peer $server."}
        $ipStrings=@(foreach($address in $addresses){ConvertTo-PdcPeerName $address.ToString()})
        foreach($ip in $ipStrings){if($Context.LocalAddresses -contains $ip){throw 'An upstream peer resolves to a local interface; possible synchronization loop.'}}
        $results += [pscustomobject]@{Server=$server;Addresses=$ipStrings;ResolvedUtc=[DateTime]::UtcNow.ToString('o')}
    }
    return $results
}

function Get-PdcDiagnostics {
    param([string]$W32tmPath,[int]$NativeTimeoutSeconds)
    $result=[ordered]@{}
    foreach($query in @('source','status','configuration','peers')){
        $args=@('/query',('/'+$query));if($query -eq 'status'){$args+='/verbose'}
        $result[$query]=Invoke-PdcNative -FilePath $W32tmPath -Arguments $args -TimeoutSeconds $NativeTimeoutSeconds
    }
    [pscustomobject]$result
}

function ConvertFrom-PdcStatus {
    param([string]$Text)
    # Recognized labels only; unknown/localized output stays unverified, never inferred as success.
    $patterns=@{
        LeapIndicator='(?im)^\s*(?:Leap Indicator|Indicador de salto)\s*:\s*(\d+)\b'
        Stratum='(?im)^\s*(?:Stratum|Estrato)\s*:\s*(\d+)\b'
        AgeSeconds='(?im)^\s*(?:Time since Last Good Sync Time|Tempo desde a [uú]ltima sincroniza[cç][aã]o (?:bem-sucedida|v[aá]lida))\s*:\s*(\d+(?:[.,]\d+)?)\s*s\b'
    }
    $value=[ordered]@{LeapIndicator=$null;Stratum=$null;AgeSeconds=$null;Parser='RecognizedLabelsOnly'}
    foreach($key in $patterns.Keys){
        $matches=[regex]::Matches($Text,$patterns[$key],[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(2))
        if($matches.Count -eq 1){$value[$key]=[double]::Parse($matches[0].Groups[1].Value.Replace(',','.'),[Globalization.CultureInfo]::InvariantCulture)}
    }
    [pscustomobject]$value
}

function Test-PdcTimeEvidence {
    param($SourceResult,$StatusResult,[object[]]$ResolvedPeers,[int]$MaxSyncAgeSeconds=300)
    $status=ConvertFrom-PdcStatus $StatusResult.Output
    $source=([string]$SourceResult.Output).Trim().TrimEnd('.')
    $source=$source -replace ',0x[0-9a-fA-F]+$',''
    $allowed=@(foreach($peer in $ResolvedPeers){$peer.Server;foreach($address in $peer.Addresses){$address}})
    $sourceMatches=($source -notmatch '[\r\n]' -and $allowed -contains $source)
    $numeric=($null -ne $status.LeapIndicator -and $null -ne $status.Stratum -and $null -ne $status.AgeSeconds)
    $healthy=($numeric -and $status.LeapIndicator -in @(0,1,2) -and $status.Stratum -ge 1 -and $status.Stratum -le 15 -and $status.AgeSeconds -ge 0 -and $status.AgeSeconds -le $MaxSyncAgeSeconds)
    [pscustomobject]@{
        MeetsCriteria=([bool]$sourceMatches -and [bool]$healthy -and -not $SourceResult.TimedOut -and -not $StatusResult.TimedOut -and $SourceResult.ExitCode -eq 0 -and $StatusResult.ExitCode -eq 0)
        Source=$source;SourceMatchesRequestedPeer=[bool]$sourceMatches;NumericStatusRecognized=$numeric
        LeapIndicator=$status.LeapIndicator;Stratum=$status.Stratum;LastGoodSyncAgeSeconds=$status.AgeSeconds
        MaxSyncAgeSeconds=$MaxSyncAgeSeconds;Note='Observed W32Time status only; not independent accuracy, authentication or fresh-packet proof.'
    }
}

function Test-PdcConfiguration {
    param($Settings,$Plan)
    $actual=@(([string]$Settings.Values.PeerList).Trim() -split '\s+' | Where-Object{$_} | ForEach-Object{$_.ToLowerInvariant()} | Sort-Object)
    $expected=@($Plan.PeerList -split '\s+' | Where-Object{$_} | ForEach-Object{$_.ToLowerInvariant()} | Sort-Object)
    return ($Settings.Values.Type -eq 'NTP' -and (($actual -join ' ') -ceq ($expected -join ' ')) -and
        $Settings.Values.AnnounceFlags -eq $Plan.AnnounceFlags -and $Settings.Values.NtpClientEnabled -eq 1 -and
        $Settings.Values.NtpServerEnabled -eq 1 -and $Settings.ServiceState -eq 'Running')
}

function Wait-PdcTimeEvidence {
    param([string]$W32tmPath,[object[]]$ResolvedPeers,[int]$MaxSyncAgeSeconds,[int]$TimeoutSeconds,[int]$IntervalSeconds,[int]$NativeTimeoutSeconds)
    $clock=[Diagnostics.Stopwatch]::StartNew();$attempts=0
    do{
        $attempts++
        $source=Invoke-PdcNative $W32tmPath @('/query','/source') $NativeTimeoutSeconds
        $status=Invoke-PdcNative $W32tmPath @('/query','/status','/verbose') $NativeTimeoutSeconds
        $evidence=Test-PdcTimeEvidence $source $status $ResolvedPeers $MaxSyncAgeSeconds
        if($evidence.MeetsCriteria -or $clock.Elapsed.TotalSeconds -ge $TimeoutSeconds){break}
        Start-Sleep -Seconds ([math]::Min($IntervalSeconds,[math]::Max(1,[math]::Ceiling($TimeoutSeconds-$clock.Elapsed.TotalSeconds))))
    }while($clock.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    [pscustomobject]@{Evidence=$evidence;Attempts=$attempts;ElapsedSeconds=[math]::Round($clock.Elapsed.TotalSeconds,2);SourceResult=$source;StatusResult=$status}
}

function Enter-PdcConfigurationLock {
    $mutex=[Threading.Mutex]::new($false,'Global\FMODEL.ConfigureNtpPdc')
    try{
        $acquired=$false
        try{$acquired=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$acquired=$true}
        if(-not $acquired){throw 'Another configuration run already holds the machine lock.'}
        return $mutex
    }catch{$mutex.Dispose();throw}
}

function Exit-PdcConfigurationLock {
    param($Mutex)
    if($null -ne $Mutex){try{$Mutex.ReleaseMutex()}finally{$Mutex.Dispose()}}
}

function Write-PdcAction {
    param([string]$Path,[string]$Action,[string]$Phase)
    $entry=[pscustomobject]@{Utc=[DateTime]::UtcNow.ToString('o');Action=$Action;Phase=$Phase}
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($entry|ConvertTo-Json -Compress)+[Environment]::NewLine)
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}

function Write-PdcAtomicText {
    param([string]$Path,[string]$Text)
    $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try{
        [IO.File]::WriteAllText($temp,$Text,[Text.UTF8Encoding]::new($false))
        if([IO.File]::Exists($Path)){[IO.File]::Replace($temp,$Path,[NullString]::Value)}else{[IO.File]::Move($temp,$Path)}
    }finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
}

function ConvertTo-PdcHtml {
    param($Report,[ValidateSet('pt-BR','en-US')][string]$Language)
    $pt=$Language -eq 'pt-BR'
    $title=if($pt){'NTP do PDC raiz da floresta'}else{'Forest-root PDC time configuration'}
    $intro=if($pt){'Estado observado, não uma certificação de precisão. Consultas e simulação não mudam W32Time; os relatórios são gravados localmente.'}else{'Observed state, not an accuracy certification. Audit and WhatIf do not change W32Time; reports are written locally.'}
    $h={param($x)[Net.WebUtility]::HtmlEncode([string]$x)}
    $rows=[Text.StringBuilder]::new()
    foreach($pair in @(@('State',$Report.State),@('Mode',$Report.Mode),@('RunId',$Report.RunId),@('Operator',$Report.Operator),@('Computer',$Report.Context.LocalFqdn),@('Domain',$Report.Context.Domain),@('Forest root',$Report.Context.ForestRoot),@('Forest-root PDC',$Report.Context.ForestRootPdc),@('Eligible target',$Report.Context.IsForestRootPdc),@('Requested peers',$Report.Plan.PeerList),@('AnnounceFlags',$Report.Plan.AnnounceFlags),@('Configuration verified',$Report.ConfigurationVerified),@('Mutation attempted',$Report.MutationAttempted),@('Error',$Report.Error))){
        [void]$rows.Append('<tr><th>'+(& $h $pair[0])+'</th><td>'+(& $h $pair[1])+'</td></tr>')
    }
    $warningText=(@($Report.Warnings)|ForEach-Object{'<li>'+(& $h $_)+'</li>'}) -join ''
    $evidence=if($null -ne $Report.Verification){$Report.Verification|ConvertTo-Json -Depth 8}else{'No time verification result.'}
    @"
<!doctype html><html lang="$Language"><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FMODEL | $title</title><style>body{font:16px Segoe UI,Arial,sans-serif;background:#f2f6fa;color:#183b54;margin:0;padding:24px}main{max-width:1100px;margin:auto}header,section{background:white;padding:22px;margin-bottom:18px;border-radius:10px}h1,h2{color:#006ca8}table{border-collapse:collapse;width:100%;table-layout:fixed}th,td{padding:10px;border:1px solid #c6d5e0;text-align:left;overflow-wrap:anywhere}th{width:32%;background:#eaf4fb}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f4f6f8;padding:14px}.notice{border-left:5px solid #deaa34}li{margin-bottom:8px}</style></head><body><main><header><strong>FMODEL - IT</strong><h1>$title</h1><p>$intro</p><p>Version $($Report.Version) | FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO | fmodel@fmodel.com.br</p></header><section><table>$rows</table></section><section class="notice"><h2>$(if($pt){'Observações e limites'}else{'Notes and limitations'})</h2><ul>$warningText</ul></section><section><h2>$(if($pt){'Evidência de horário'}else{'Time evidence'})</h2><pre>$(& $h $evidence)</pre></section><section><h2>$(if($pt){'Plano e arquivos técnicos'}else{'Plan and technical files'})</h2><p>report.json | before-settings.json | actions.jsonl | w32time-before.reg (Apply only) | diagnostics-*.txt</p><p>$(if($pt){'O backup do Registro não desfaz alterações do relógio. Não há rollback automático. Não publicar dados reais deste relatório no Git.'}else{'A registry export does not undo clock changes. No automatic rollback is implemented. Do not publish real report data to Git.'})</p></section></main></body></html>
"@
}

function Save-PdcReport {
    param($Report,[string]$RunFolder)
    Write-PdcAtomicText (Join-Path $RunFolder 'report.json') ($Report|ConvertTo-Json -Depth 14)
    foreach($language in @('pt-BR','en-US')){Write-PdcAtomicText (Join-Path $RunFolder ("Report.$language.html")) (ConvertTo-PdcHtml $Report $language)}
}

function Set-PdcProviderSettings {
    param($Plan,[string]$Journal)
    $root='HKLM:\SYSTEM\CurrentControlSet\Services\W32Time'
    foreach($entry in @(@("$root\Config",'AnnounceFlags',$Plan.AnnounceFlags),@("$root\TimeProviders\NtpClient",'Enabled',1),@("$root\TimeProviders\NtpServer",'Enabled',1))){
        $label=$entry[0]+'\'+$entry[1]
        Write-PdcAction $Journal $label 'INTENT'
        $null=New-ItemProperty -Path $entry[0] -Name $entry[1] -Value $entry[2] -PropertyType DWord -Force -ErrorAction Stop -WhatIf:$false -Confirm:$false
        Write-PdcAction $Journal $label 'COMPLETED'
    }
}

function Restart-PdcTimeService {
    $service=Get-Service -Name W32Time -ErrorAction Stop
    if($service.Status -eq 'Running'){Restart-Service -Name W32Time -ErrorAction Stop -WhatIf:$false -Confirm:$false}
    else{Start-Service -Name W32Time -ErrorAction Stop -WhatIf:$false -Confirm:$false}
    $service=Get-Service -Name W32Time -ErrorAction Stop
    $service.WaitForStatus('Running',[TimeSpan]::FromSeconds(30))
}

function Assert-PdcApplyTarget {
    param($Context,$Settings,$Policy)
    if(-not $Context.IsForestRootPdc -or $Context.ProductType -ne 2 -or $Context.OSBuild -lt 14393){throw 'Apply requires the current forest-root PDC Emulator on Windows Server 2016 or later.'}
    if($Policy.Present){throw 'A W32Time policy registry branch exists. Review the managing policy; local Apply does not bypass or delete policy.'}
    if($Settings.ServiceStartMode -eq 'Disabled'){throw 'W32Time is disabled. Review service policy/startup separately.'}
    foreach($field in @('Type','PeerList','AnnounceFlags','NtpClientEnabled','NtpServerEnabled')){
        $entry=@($Settings.Registry|Where-Object{$_.Field -eq $field})
        if($entry.Count -ne 1 -or -not $entry[0].KeyExists){throw "Required W32Time registry key missing for $field; repair is outside this script."}
    }
}

function Invoke-PdcTimeConfiguration {
    param([string[]]$NtpServers=@(),[switch]$Apply,[switch]$WhatIfRequested,[string]$ReliabilityMode='Automatic',
        [string]$OutputPath,[int]$NativeTimeoutSeconds=20,[int]$VerificationTimeoutSeconds=120,
        [int]$VerificationIntervalSeconds=5,[int]$MaxSyncAgeSeconds=300,[switch]$ProbePeers,[scriptblock]$Approve)
    Test-PdcRuntime
    $operator=Get-PdcOperatorIdentity
    $plan=Get-PdcPeerPlan $NtpServers $ReliabilityMode
    if($Apply -and $plan.Servers.Count -eq 0){throw 'Specify NtpServers explicitly with Apply; no upstream provider is selected automatically.'}
    if($ProbePeers -and $plan.Servers.Count -eq 0){throw 'Specify NtpServers when requesting ProbePeers.'}
    if(-not $OutputPath){
        $base=[Environment]::GetFolderPath('LocalApplicationData')
        if(-not $base){throw 'LocalApplicationData is unavailable; specify OutputPath.'}
        $OutputPath=Join-Path $base 'FMODEL/NtpPdc'
    }
    if((Get-Location).Provider.Name -ne 'FileSystem'){throw 'Run from a filesystem directory.'}
    if($OutputPath.StartsWith('\\')){throw 'Use a local output directory for the pre-change backup.'}
    $basePath=[IO.Path]::GetFullPath($OutputPath)
    if($basePath.StartsWith('\\') -or ([IO.DriveInfo]::new([IO.Path]::GetPathRoot($basePath))).DriveType -eq [IO.DriveType]::Network){throw 'OutputPath must use local storage.'}
    $runId=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
    $folder=Join-Path $basePath ('Run-'+$runId);$null=[IO.Directory]::CreateDirectory($folder)
    $report=[pscustomobject][ordered]@{
        SchemaVersion=1;Version='1.0.0';Operator=$operator.Name;OperatorSid=$operator.Sid;RunId=$runId;StartedUtc=[DateTime]::UtcNow.ToString('o');EndedUtc=''
        Mode=$(if($Apply){'Apply'}else{'Audit'});State='Started';RunFolder=$folder
        Context=[pscustomobject]@{LocalFqdn='';Domain='';ForestRoot='';ForestRootPdc='';IsForestRootPdc=$false}
        Plan=$plan;Policy=$null;Before=$null;After=$null;ResolvedPeers=@();BeforeDiagnostics=$null;AfterDiagnostics=$null
        ConfigurationVerified=$false;Verification=$null;ProbeResults=@();MutationAttempted=$false;Error=''
        Warnings=@('No automatic rollback. A registry backup cannot undo a clock adjustment.','Reports use normal filesystem ACLs and can contain internal domain/host/IP information.','Manual upstream NTP is not cryptographically authenticated by this script.','Virtualization hints are heuristic; hypervisor/cloud integration is not changed.')
    }
    $mutex=$null;$w32tm='';$journal=Join-Path $folder 'actions.jsonl'
    try{
        $native=Get-PdcNativePaths;$w32tm=$native.W32tm
        $report.Context=Get-PdcContext;$report.Policy=Get-PdcPolicyState;$report.Before=Get-PdcSettings
        $report.BeforeDiagnostics=Get-PdcDiagnostics $w32tm $NativeTimeoutSeconds
        Write-PdcAtomicText (Join-Path $folder 'before-settings.json') ($report.Before|ConvertTo-Json -Depth 8)
        if($plan.Servers.Count -gt 0){
            $report.ResolvedPeers=@(Resolve-PdcPeers $plan.Servers $report.Context)
            if($plan.Servers.Count -lt 3){$report.Warnings+='Fewer than three distinct peer names. With two peers, the second is client/fallback-only (0xA). Distinct names do not guarantee independent clocks.'}
        }
        if($ProbePeers){
            foreach($peer in $plan.Servers){$report.ProbeResults+=Invoke-PdcNative $w32tm @('/stripchart',('/computer:'+$peer),'/samples:3','/period:1','/dataonly') $NativeTimeoutSeconds}
            $report.Warnings+='stripchart uses an ephemeral UDP source port; its result does not prove the W32Time UDP source-123 path or successful synchronization.'
        }
        foreach($entry in $report.BeforeDiagnostics.PSObject.Properties){Write-PdcAtomicText (Join-Path $folder ('diagnostics-before-'+$entry.Name+'.txt')) $entry.Value.Output}
        if(-not $Apply){
            $report.State='AuditCompleted'
            if(-not $report.Context.IsForestRootPdc){$report.Warnings+='This computer is not confirmed as the forest-root PDC; Apply would be blocked.'}
            if($report.Policy.Present){$report.Warnings+='W32Time policy registry branch present; use the managing policy rather than local Apply.'}
        }else{
            Assert-PdcApplyTarget $report.Context $report.Before $report.Policy
            if($null -eq $Approve){throw 'A ShouldProcess approval callback is required.'}
            $approved=& $Approve $report.Context.LocalFqdn ('Configure W32Time, restart/start service and request resync with '+$plan.PeerList)
            if($WhatIfRequested -or -not $approved){
                $report.State=if($WhatIfRequested){'WhatIf'}else{'Declined'}
            }else{
                $mutex=Enter-PdcConfigurationLock
                $fresh=Get-PdcContext;$policy=Get-PdcPolicyState;$settings=Get-PdcSettings
                Assert-PdcApplyTarget $fresh $settings $policy
                if($fresh.LocalFqdn -ne $report.Context.LocalFqdn -or $fresh.ForestRoot -ne $report.Context.ForestRoot){throw 'Target/domain identity changed after confirmation.'}
                $report.Before=$settings
                Write-PdcAtomicText (Join-Path $folder 'before-settings.json') ($settings|ConvertTo-Json -Depth 8)
                $backup=Invoke-PdcNative $native.Reg @('export','HKLM\SYSTEM\CurrentControlSet\Services\W32Time',(Join-Path $folder 'w32time-before.reg'),'/y') $NativeTimeoutSeconds
                Assert-PdcNativeSuccess $backup 'Registry export'
                if(-not [IO.File]::Exists((Join-Path $folder 'w32time-before.reg')) -or ([IO.FileInfo](Join-Path $folder 'w32time-before.reg')).Length -eq 0){throw 'Registry backup file is missing or empty.'}
                $report.State='BackupSaved';Save-PdcReport $report $folder
                # Confirm target/policy again after persistence; backup success alone is not authorization.
                $lastContext=Get-PdcContext;$lastPolicy=Get-PdcPolicyState;$lastSettings=Get-PdcSettings
                Assert-PdcApplyTarget $lastContext $lastSettings $lastPolicy
                if($lastContext.LocalFqdn -ne $fresh.LocalFqdn -or $lastContext.ForestRoot -ne $fresh.ForestRoot){throw 'Target changed after backup.'}
                foreach($field in @('Type','PeerList','AnnounceFlags','NtpClientEnabled','NtpServerEnabled')){
                    if($lastSettings.Values.$field -ne $settings.Values.$field){throw 'W32Time settings changed while the backup was being prepared. Review and rerun from a new snapshot.'}
                }
                if($lastSettings.ServiceState -ne 'Running'){
                    Write-PdcAction $journal 'Start W32Time before configuration' 'INTENT'
                    $report.MutationAttempted=$true
                    Restart-PdcTimeService
                    Write-PdcAction $journal 'Start W32Time before configuration' 'COMPLETED'
                }
                Write-PdcAction $journal 'Configure manual NTP peers/Type' 'INTENT'
                $report.MutationAttempted=$true
                $config=Invoke-PdcNative $w32tm @('/config',('/manualpeerlist:'+$plan.PeerList),'/syncfromflags:manual','/update') $NativeTimeoutSeconds
                Write-PdcAtomicText (Join-Path $folder 'config-command.txt') $config.Output
                Assert-PdcNativeSuccess $config 'w32tm config';Write-PdcAction $journal 'Configure manual NTP peers/Type' 'COMPLETED'
                Set-PdcProviderSettings $plan $journal
                Write-PdcAction $journal 'Notify W32Time settings update' 'INTENT'
                $update=Invoke-PdcNative $w32tm @('/config','/update') $NativeTimeoutSeconds
                Assert-PdcNativeSuccess $update 'w32tm update';Write-PdcAction $journal 'Notify W32Time settings update' 'COMPLETED'
                Write-PdcAction $journal 'Restart/start W32Time' 'INTENT'
                Restart-PdcTimeService;Write-PdcAction $journal 'Restart/start W32Time' 'COMPLETED'
                Write-PdcAction $journal 'Request W32Time resync/rediscover' 'INTENT'
                $resync=Invoke-PdcNative $w32tm @('/resync','/rediscover') $NativeTimeoutSeconds
                Write-PdcAtomicText (Join-Path $folder 'resync-command.txt') $resync.Output
                Assert-PdcNativeSuccess $resync 'w32tm resync';Write-PdcAction $journal 'Request W32Time resync/rediscover' 'COMPLETED'
                $report.Verification=Wait-PdcTimeEvidence $w32tm $report.ResolvedPeers $MaxSyncAgeSeconds $VerificationTimeoutSeconds $VerificationIntervalSeconds $NativeTimeoutSeconds
                $report.After=Get-PdcSettings;$report.ConfigurationVerified=Test-PdcConfiguration $report.After $plan
                $afterContext=Get-PdcContext;$afterPolicy=Get-PdcPolicyState
                if(-not $afterContext.IsForestRootPdc -or $afterContext.LocalFqdn -ne $fresh.LocalFqdn -or $afterPolicy.Present){$report.ConfigurationVerified=$false;$report.Warnings+='PDC identity or policy changed during the run. Review the current role and effective configuration.'}
                $report.AfterDiagnostics=Get-PdcDiagnostics $w32tm $NativeTimeoutSeconds
                foreach($entry in $report.AfterDiagnostics.PSObject.Properties){Write-PdcAtomicText (Join-Path $folder ('diagnostics-after-'+$entry.Name+'.txt')) $entry.Value.Output}
                $report.State=if($report.ConfigurationVerified -and $report.Verification.Evidence.MeetsCriteria){'AppliedVerified'}else{'AppliedNeedsReview'}
                if($report.State -eq 'AppliedNeedsReview'){$report.Warnings+='Configuration or time evidence did not meet all verification criteria. Inspect diagnostics and service events; do not treat this as synchronization success.'}
            }
        }
    }catch{
        $report.Error=$_.Exception.Message
        $report.State=if($report.MutationAttempted){'FailedAfterMutationPossible'}else{'Blocked'}
    }finally{
        try{
            $report.EndedUtc=[DateTime]::UtcNow.ToString('o');Save-PdcReport $report $folder
        }finally{Exit-PdcConfigurationLock $mutex}
    }
    return $report
}
