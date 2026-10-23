# Test fixture only. Dot-source AFTER Core in an isolated test process.
$script:scenario='Healthy';$script:contextReads=0;$script:policyReads=0
$script:calls=@{Config=0;Update=0;Resync=0;Backup=0;Registry=0;Restart=0;Start=0;Lock=0;Unlock=0;Dns=0}
$script:seed=[pscustomobject]@{
    Values=[pscustomobject]@{Type='NT5DS';PeerList='old.example,0x8';AnnounceFlags=10;NtpClientEnabled=1;NtpServerEnabled=1;VmIcProviderEnabled=1;MaxPosPhaseCorrection=172800;MaxNegPhaseCorrection=172800}
    Registry=@('Type','PeerList','AnnounceFlags','NtpClientEnabled','NtpServerEnabled'|ForEach-Object{[pscustomobject]@{Field=$_;KeyExists=$true;ValueKind='Synthetic'}})
    ServiceState='Running';ServiceStartMode='Auto'
}
function Test-PdcRuntime {}
function Get-PdcNativePaths {[pscustomobject]@{W32tm='mock-w32tm';Reg='mock-reg'}}
function Get-PdcContext {
    $script:contextReads++
    if($script:scenario -eq 'DirectoryFailure'){throw 'SYNTHETIC directory unavailable <script>alert(1)</script>'}
    [pscustomobject]@{
        LocalFqdn='dc1.forest.example';ComputerName='dc1';Domain='forest.example';ForestRoot='forest.example';ForestRootPdc='dc1.forest.example'
        IsForestRootPdc=($script:scenario -ne 'WrongPdc' -and -not (($script:scenario -eq 'RoleMoved' -and $script:contextReads -ge 2) -or ($script:scenario -eq 'RoleMovedAfterBackup' -and $script:contextReads -ge 3)))
        ProductType=2;OSBuild=20348;DomainRole=5;PartOfDomain=$true;Manufacturer='Synthetic';Model='Test VM';VirtualizationHint='PossibleVirtualMachine';LocalAddresses=@('192.0.2.1')
    }
}
function Get-PdcPolicyState {$script:policyReads++;[pscustomobject]@{Present=($script:scenario -eq 'PolicyBefore' -or (($script:scenario -eq 'PolicyAppears' -and $script:policyReads -ge 2) -or ($script:scenario -eq 'PolicyAfterBackup' -and $script:policyReads -ge 3)));Path='SYNTHETIC policy path'}}
function Get-PdcSettings { $script:seed|ConvertTo-Json -Depth 8|ConvertFrom-Json }
function Resolve-PdcPeers {
    param($Servers,$Context)
    $script:calls.Dns++
    @(foreach($server in $Servers){[pscustomobject]@{Server=$server;Addresses=@('192.0.2.123');ResolvedUtc='2026-10-23T00:00:00Z'}})
}
function Enter-PdcConfigurationLock {$script:calls.Lock++;return 'SYNTHETIC-MUTEX'}
function Exit-PdcConfigurationLock {param($Mutex) if($Mutex){$script:calls.Unlock++}}
function Assert-MockIntent {
    if(-not $script:journalPath -or -not [IO.File]::Exists($script:journalPath)){throw 'Mutation without persisted intent'}
    $last=Get-Content $script:journalPath|Select-Object -Last 1|ConvertFrom-Json
    if($last.Phase -ne 'INTENT'){throw 'Last journal event is not intent'}
}
function Invoke-PdcNative {
    param($FilePath,$Arguments,$TimeoutSeconds)
    $output='SYNTHETIC native output';$code=0;$timedOut=$false
    if($Arguments[0] -eq 'export'){
        $script:calls.Backup++;$script:journalPath=Join-Path (Split-Path $Arguments[2] -Parent) 'actions.jsonl'
        if($script:scenario -eq 'BackupFail'){$code=5}
        else{
            $text=if($script:scenario -eq 'BackupEmpty'){''}else{"Windows Registry Editor Version 5.00`r`n; SYNTHETIC TEST ONLY - DO NOT IMPORT`r`n"}
            [IO.File]::WriteAllText($Arguments[2],$text)
            if($script:scenario -eq 'JournalFail'){$null=[IO.Directory]::CreateDirectory($script:journalPath)}
        }
    }elseif($Arguments[0] -eq '/config'){
        Assert-MockIntent
        $peerArg=@($Arguments|Where-Object{$_ -like '/manualpeerlist:*'})
        if($peerArg.Count){
            $script:calls.Config++;$script:seed.Values.Type='NTP';$script:seed.Values.PeerList=$peerArg[0].Substring('/manualpeerlist:'.Length)
            if($script:scenario -eq 'ConfigFail'){$code=5}
        }else{$script:calls.Update++}
    }elseif($Arguments[0] -eq '/resync'){
        Assert-MockIntent;$script:calls.Resync++
        if($script:scenario -eq 'ResyncTimeout'){$timedOut=$true}
    }elseif($Arguments -contains '/source'){$output='ntp1.example'}
    elseif($Arguments -contains '/status'){
        $age=if($script:scenario -eq 'Unverified'){99999}else{4}
        $output="Leap Indicator: 0(no warning)`nStratum: 2`nTime since Last Good Sync Time: ${age}s"
    }
    [pscustomobject]@{Executable=$FilePath;Arguments=$Arguments;ExitCode=$code;TimedOut=$timedOut;Output=$output;ObservedUtc='2026-10-23T00:00:00Z'}
}
function New-ItemProperty {
    [CmdletBinding(SupportsShouldProcess=$true)]param($Path,$Name,$Value,$PropertyType,[switch]$Force)
    Assert-MockIntent;$script:calls.Registry++
    if($Name -eq 'AnnounceFlags'){$script:seed.Values.AnnounceFlags=$Value}
    elseif($Path -like '*NtpClient'){$script:seed.Values.NtpClientEnabled=$Value}
    elseif($Path -like '*NtpServer'){$script:seed.Values.NtpServerEnabled=$Value}
    else{throw 'Unexpected registry write'}
}
function Get-Service {
    param($Name)
    $object=[pscustomobject]@{Status=$script:seed.ServiceState}
    $object|Add-Member -MemberType ScriptMethod -Name WaitForStatus -Value {param($Status,$Timeout) if($script:seed.ServiceState -ne 'Running'){throw 'Service did not reach Running'}}
    $object
}
function Restart-Service {[CmdletBinding(SupportsShouldProcess=$true)]param($Name) Assert-MockIntent;$script:calls.Restart++;$script:seed.ServiceState='Running'}
function Start-Service {[CmdletBinding(SupportsShouldProcess=$true)]param($Name) Assert-MockIntent;$script:calls.Start++;$script:seed.ServiceState='Running'}
