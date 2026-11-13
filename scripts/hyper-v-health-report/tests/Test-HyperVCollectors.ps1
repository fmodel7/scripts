#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop';$script:checks=0
function Assert-True {param([bool]$Condition,[string]$Message);$script:checks++;if(-not $Condition){throw "FAIL: $Message"}}
$root=Split-Path $PSScriptRoot -Parent;. (Join-Path $root 'Export-HyperVHealthReport.ps1')
function Invoke-WorkerScenario {
    param([string]$Scenario,[string]$Mode='Collect')
    $vm=[pscustomobject]@{Id=[guid]'11111111-1111-4111-8111-111111111111';Name='LAB-VM';Generation=2;Version=[version]'12.0';State='Running';Status='Operating normally';Uptime=[timespan]::FromHours(5);ProcessorCount=4;MemoryAssigned=8GB;MemoryDemand=4GB;MemoryStartup=4GB;DynamicMemoryEnabled=$true;ReplicationState='Replicating';ReplicationHealth='Normal';ResourceMeteringEnabled=$true}
    if($Scenario -eq 'Gen1'){$vm.Generation=1;$vm.ReplicationState='Disabled';$vm.ResourceMeteringEnabled=$false;$vm.State='Off'}
    $calls=New-Object 'Collections.Generic.List[string]'
    function Import-Module {[CmdletBinding()]param([string]$Name);$calls.Add('Import-Module '+$Name)}
    function Get-CimInstance {
        [CmdletBinding()]param([string]$ClassName,[string]$Namespace,[string]$Filter)
        switch($ClassName){
            Win32_OperatingSystem {[pscustomobject]@{Caption='Microsoft Windows Server 2025';Version='10.0';BuildNumber='26100';LastBootUpTime=[datetime]::Now.AddHours(-48);TotalVisibleMemorySize=134217728;FreePhysicalMemory=33554432}}
            Win32_ComputerSystem {[pscustomobject]@{Manufacturer='Lab';Model='Server';Domain='lab.example';NumberOfLogicalProcessors=32;NumberOfProcessors=2;HypervisorPresent=$true}}
            Win32_Processor {[pscustomobject]@{DeviceID='CPU0';Name='Lab CPU';NumberOfCores=16;NumberOfLogicalProcessors=32;MaxClockSpeed=3000}}
            Win32_Service {[pscustomobject]@{Name='vmms';State='Running';StartMode='Auto';Status='OK'}}
            Win32_QuickFixEngineering {[pscustomobject]@{HotFixID='KB0000000';Description='Synthetic patch';InstalledOn=[datetime]'2026-11-01'}}
            Win32_DeviceGuard {[pscustomobject]@{VirtualizationBasedSecurityStatus=2;SecurityServicesRunning=@(1,2)}}
            default {throw "Unexpected CIM class $ClassName"}
        }
    }
    function Get-Item {[CmdletBinding()]param([string]$LiteralPath);[pscustomobject]@{Name=$LiteralPath}}
    function Get-ItemProperty {[CmdletBinding()]param([string]$LiteralPath);[pscustomobject]@{PendingFileRenameOperations=@('old','new')}}
    function Get-VM {[CmdletBinding()]param();if($Scenario -eq 'Denied'){throw [UnauthorizedAccessException]::new('Access denied')};if($Scenario -eq 'Empty'){return};$vm;if($Scenario -eq 'Truncated'){[pscustomobject]@{Id=[guid]::NewGuid();Name='EXTRA'}}}
    function Get-VMHost {[CmdletBinding()]param();[pscustomobject]@{VirtualMachinePath='C:\VMs';VirtualHardDiskPath='C:\VHD';VirtualMachineMigrationEnabled=$true;VirtualMachineMigrationAuthenticationType='Kerberos'}}
    function Get-VMHostNumaNode {[CmdletBinding()]param();[pscustomobject]@{NodeId=0;ProcessorCount=32;MemoryTotal=131072;MemoryAvailable=32768}}
    function Get-VMHostSupportedVersion {[CmdletBinding()]param();[pscustomobject]@{Name='Windows Server 2025';Version=[version]'12.0';IsDefault=$true}}
    function Get-Volume {[CmdletBinding()]param();[pscustomobject]@{Path='\\?\Volume{lab}\';DriveLetter='C';Size=1TB;SizeRemaining=400GB;DriveType='Fixed';HealthStatus='Healthy';FileSystemType='ReFS'}}
    function Get-PhysicalDisk {[CmdletBinding()]param();[pscustomobject]@{FriendlyName='Disk0';HealthStatus='Healthy';Size=1TB;MediaType='SSD'}}
    function Get-StoragePool {[CmdletBinding()]param();[pscustomobject]@{FriendlyName='Pool0';HealthStatus='Healthy';Size=1TB;AllocatedSize=500GB;IsPrimordial=$false}}
    function Get-NetAdapter {[CmdletBinding()]param([switch]$IncludeHidden);[pscustomobject]@{Name='Ethernet';Status='Up';LinkSpeed='10 Gbps';MacAddress='00155D111111'}}
    function Get-NetIPAddress {[CmdletBinding()]param();[pscustomobject]@{InterfaceAlias='Ethernet';AddressFamily='IPv4';IPAddress='192.0.2.11';PrefixLength=24}}
    function Get-VMSwitch {[CmdletBinding()]param();[pscustomobject]@{Name='SET';SwitchType='External';EmbeddedTeamingEnabled=$true;AllowManagementOS=$true}}
    function Get-VMSwitchTeam {[CmdletBinding()]param($Name);[pscustomobject]@{Name=$Name;TeamingMode='SwitchIndependent';LoadBalancingAlgorithm='Dynamic'}}
    function Get-VMMigrationNetwork {[CmdletBinding()]param();[pscustomobject]@{Subnet='192.0.2.0/24';Priority=1}}
    function Get-VMReplicationServer {[CmdletBinding()]param();[pscustomobject]@{ReplicationEnabled=$true;AllowedAuthenticationType='Kerberos'}}
    function Get-SmbClientConfiguration {[CmdletBinding()]param();[pscustomobject]@{EnableSecuritySignature=$true;RequireSecuritySignature=$true;EnableMultiChannel=$true}}
    function Get-SmbServerConfiguration {[CmdletBinding()]param();[pscustomobject]@{EnableSMB1Protocol=$false;EnableSMB2Protocol=$true;RequireSecuritySignature=$true;EncryptData=$true}}
    function Get-SmbConnection {[CmdletBinding()]param();[pscustomobject]@{ServerName='SOFS-LAB';ShareName='VMs';Dialect='3.1.1';Encrypted=$true}}
    function Get-NetAdapterRdma {[CmdletBinding()]param();[pscustomobject]@{Name='Ethernet';Enabled=$true;OperationalState='Up'}}
    function Get-NetAdapterVmq {[CmdletBinding()]param();[pscustomobject]@{Name='Ethernet';Enabled=$true;NumberOfReceiveQueues=8}}
    function Get-NetAdapterSriov {[CmdletBinding()]param();[pscustomobject]@{Name='Ethernet';Enabled=$true;SriovSupport='Supported'}}
    function Get-VMProcessor {[CmdletBinding()]param($VM);$calls.Add('Get-VMProcessor');if($Scenario -eq 'OneProbeFails'){throw 'Processor read failed'};[pscustomobject]@{Count=4;Reserve=0;Maximum=100;RelativeWeight=100;ExposeVirtualizationExtensions=$false}}
    function Get-VMMemory {[CmdletBinding()]param($VM);[pscustomobject]@{DynamicMemoryEnabled=$true;Startup=4GB;Minimum=2GB;Maximum=16GB;Priority=50}}
    function Get-VMHardDiskDrive {[CmdletBinding()]param($VM);[pscustomobject]@{Path='C:\VMs\disk.avhdx';ControllerType='SCSI';ControllerNumber=0;ControllerLocation=0}}
    function Get-VHD {
        [CmdletBinding()]param([string]$Path)
        $calls.Add('Get-VHD '+$Path);if($Scenario -eq 'VhdDenied'){throw [UnauthorizedAccessException]::new('SMB or owning-host restriction')}
        $parent=$null;if($Path.EndsWith('.avhdx')){$parent='C:\VMs\base.vhdx'};if($Scenario -eq 'VhdCycle'){$parent=$Path}
        [pscustomobject]@{Path=$Path;ParentPath=$parent;VhdFormat='VHDX';VhdType='Dynamic';FileSize=16GB;Size=128GB;FragmentationPercentage=2}
    }
    function Get-VMNetworkAdapter {[CmdletBinding()]param($VM,[switch]$ManagementOS);[pscustomobject]@{Name='Network Adapter';Id='nic1';SwitchName='SET';Status=@('Ok');IPAddresses=@('192.0.2.20','2001:db8::20');MacAddress='00155D222222';ManagementOS=[bool]$ManagementOS}}
    function Get-VMNetworkAdapterVlan {[CmdletBinding()]param($VMNetworkAdapter);[pscustomobject]@{OperationMode='Access';AccessVlanId=100}}
    function Get-VMIntegrationService {[CmdletBinding()]param($VM);[pscustomobject]@{Name='Heartbeat';Id='84EAAE65-2F2E-45F5-9BB5-0E857DC8EB47';Enabled=$true;PrimaryOperationalStatus='Ok'}}
    function Get-VMSnapshot {[CmdletBinding()]param($VM);[pscustomobject]@{Name='Lab checkpoint';Id=[guid]::NewGuid();CreationTime=[datetime]::Now.AddDays(-10);SnapshotType='Standard'}}
    function Get-VMReplication {[CmdletBinding()]param($VM);$calls.Add('Get-VMReplication');[pscustomobject]@{State='Replicating';Health='Normal';Mode='Primary';FrequencySec=300;LastReplicationTime=[datetime]::Now;AuthType='Kerberos'}}
    function Measure-VMReplication {[CmdletBinding()]param($VM);[pscustomobject]@{ReplicationHealth='Normal';SuccessfulReplicationCount=10;MissedReplicationCount=0}}
    function Get-VMFirmware {[CmdletBinding()]param($VM);$calls.Add('Get-VMFirmware');[pscustomobject]@{SecureBoot='On';SecureBootTemplate='MicrosoftWindows'}}
    function Get-VMSecurity {[CmdletBinding()]param($VM);[pscustomobject]@{TpmEnabled=$true;Shielded=$false}}
    function Measure-VM {[CmdletBinding()]param($VM);$calls.Add('Measure-VM');[pscustomobject]@{MeteringDuration=[timespan]::FromHours(1);AverageProcessorUsage=200;AverageMemoryUsage=4096}}
    function Get-VMDvdDrive {[CmdletBinding()]param($VM);[pscustomobject]@{ControllerNumber=0;ControllerLocation=1;Path='C:\ISO\lab.iso'}}
    function Get-VMAssignableDevice {[CmdletBinding()]param($VM)}
    function Get-VMFibreChannelHba {[CmdletBinding()]param($VM)}
    function Get-WinEvent {
        [CmdletBinding()]param($ListLog,$FilterHashtable,[int]$MaxEvents)
        if($Scenario -eq 'EventDenied'){throw 'Event access denied'}
        if($null -ne $ListLog){[pscustomobject]@{IsEnabled=$true};return}
        if($Scenario -eq 'NoEvents'){Write-Error 'No events' -ErrorId NoMatchingEventsFound -ErrorAction Stop}
        $count=1;if($Scenario -eq 'EventTruncated'){$count=$MaxEvents}
        for($i=0;$i -lt $count;$i++){[pscustomobject]@{Id=100;Level=2;ProviderName='Synthetic';RecordId=$i+1;TimeCreated=[datetime]::Now;Message='Synthetic event'}}
    }
    function Get-BpaResult {[CmdletBinding()]param($ModelId);[pscustomobject]@{ModelId=$ModelId;Severity='Warning';Title='Synthetic existing result';Compliance=$false}}
    function Get-Cluster {[CmdletBinding()]param();[pscustomobject]@{Name='LAB-CLUSTER';ClusterFunctionalLevel=12;DynamicQuorum=1}}
    function Get-ClusterNode {[CmdletBinding()]param();[pscustomobject]@{Name='HV-LAB01';State='Up';NodeWeight=1};[pscustomobject]@{Name='HV-LAB02';State='Down';NodeWeight=1}}
    function Get-ClusterGroup {[CmdletBinding()]param();[pscustomobject]@{Name='LAB-VM';State='Online';OwnerNode='HV-LAB01';GroupType='VirtualMachine'}}
    function Get-ClusterResource {[CmdletBinding()]param();[pscustomobject]@{Name='LAB-VM';State='Online';ResourceType='Virtual Machine';OwnerNode='HV-LAB01'}}
    function Get-ClusterSharedVolume {[CmdletBinding()]param();[pscustomobject]@{Name='Cluster Disk1';OwnerNode='HV-LAB01';State='Online';SharedVolumeInfo=@([pscustomobject]@{FriendlyVolumeName='C:\ClusterStorage\Volume1';RedirectedAccess=$true;FaultState='NoFaults';Partition=[pscustomobject]@{Name='\\?\Volume{csv}\';FileSystem='ReFS';Size=2TB;FreeSpace=1TB;PercentFree=50}})}}
    function Get-ClusterNetwork {[CmdletBinding()]param();[pscustomobject]@{Name='Cluster';Role='ClusterAndClient';State='Up';Address='192.0.2.0'}}
    function Get-ClusterQuorum {[CmdletBinding()]param();[pscustomobject]@{Cluster='LAB-CLUSTER';QuorumType='NodeAndFileShareMajority';QuorumResource='File Share Witness'}}
    $options=@{MaxRowsPerProbe=100;MaxVMsPerHost=1;MaxVhdDepth=8;SkipEvents=$false;EventDays=7;MaxEventsPerLog=2;IncludeBpa=$true}
    if($Scenario -eq 'Depth'){$options.MaxVhdDepth=1}
    if($Scenario -eq 'Skipped'){$options.SkipEvents=$true;$options.IncludeBpa=$false}
    $packets=@(Invoke-HvWorker $options $Mode)
    [pscustomobject]@{Packets=$packets;Calls=$calls.ToArray()}
}
$normal=Invoke-WorkerScenario Normal
$failures=@($normal.Packets | Where-Object {$_.Status -eq 'Failed'})
Assert-True ($failures.Count -eq 0) ('Normal worker: '+($failures | ConvertTo-Json -Depth 5))
$report=New-HvReport en-US
foreach($packet in $normal.Packets){Add-HvPacket $report $packet}
Assert-True ($report.Datasets.VMs.Count -eq 1 -and $report.Datasets.VMs[0].UptimeHours -eq 5) 'VM enumeration and uptime'
Assert-True ($report.Datasets.Hosts[0].MemoryTotalBytes -eq 128GB -and $report.Datasets.Hosts[0].MemoryFreePercent -eq 25) 'CIM KiB converted accurately'
Assert-True ($report.Datasets.Volumes[0].FreePercent -gt 39 -and $report.Datasets.Volumes[0].FreePercent -lt 40) 'Volume free percentage'
Assert-True ($report.Datasets.VHDChains.Count -eq 2 -and $report.Datasets.VHDChains[1].Depth -eq 1) 'VHD parent traversal'
Assert-True ($report.Datasets.Checkpoints[0].AgeDays -ge 10) 'Checkpoint age'
Assert-True ($report.Datasets.VMNetworkAdapters[0].IPAddresses -eq '192.0.2.20; 2001:db8::20') 'Multi-value normalization'
Assert-True ($report.Datasets.AdapterOffloads.Count -eq 3) 'Offload families'
Assert-True ($report.Datasets.VMVlans[0].AccessVlanId -eq 100) 'VLAN read'
Assert-True ($report.Datasets.BpaResults.Count -eq 1) 'Existing BPA results only'
Assert-True ($report.Datasets.EventCoverage.Count -eq 6 -and $report.Datasets.Events.Count -eq 6) 'Explicit event logs'
$cluster=Invoke-WorkerScenario Normal Discover
foreach($key in @('Cluster','ClusterNodes','ClusterGroups','ClusterResources','ClusterVolumes','ClusterNetworks','ClusterQuorum')){Assert-True (@($cluster.Packets | Where-Object {$_.Dataset -eq $key -and $_.Status -eq 'Collected'}).Count -eq 1) "Cluster dataset $key"}
Assert-True (@($cluster.Packets | Where-Object {$_.Dataset -eq 'ClusterVolumes'})[0].Rows[0].RedirectedAccess -eq $true) 'CSV details preserve redirect mode'
foreach($scenario in @('Gen1','Denied','Empty','Truncated','OneProbeFails','VhdDenied','VhdCycle','Depth','EventDenied','NoEvents','EventTruncated','Skipped')){
    $result=Invoke-WorkerScenario $scenario;$packets=$result.Packets
    switch($scenario){
        Gen1 {foreach($key in @('VMFirmware','VMSecurity')){Assert-True (@($packets | Where-Object {$_.Dataset -eq $key})[0].Status -eq 'NotApplicable') 'Gen1 applicability'};Assert-True ('Get-VMFirmware' -notin $result.Calls -and 'Measure-VM' -notin $result.Calls -and 'Get-VMReplication' -notin $result.Calls) 'No incompatible or disabled calls'}
        Denied {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VMs'})[0].Status -eq 'Failed') 'Denied inventory explicit';Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VMProcessors'}).Count -eq 0) 'Denied inventory not iterated'}
        Empty {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VMs'})[0].Status -eq 'Empty') 'Empty inventory distinguished'}
        Truncated {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VMs'})[0].Status -eq 'Truncated') 'VM cap explicit';Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VMProcessors'}).Count -eq 1) 'VM cap respected'}
        OneProbeFails {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VMProcessors'})[0].Status -eq 'Failed') 'Independent probe failure';Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VMMemory'})[0].Status -eq 'Collected') 'Other probe continues'}
        VhdDenied {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VHDChains'})[0].Status -eq 'Partial') 'VHD access failure preserves explicit unknown';Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VHDChains'})[0].Rows[0].ReadStatus -eq 'Error') 'Read failure not missing-file verdict'}
        VhdCycle {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VHDChains'})[0].Rows[-1].ReadStatus -eq 'CycleDetected') 'VHD cycles bounded'}
        Depth {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'VHDChains'})[0].Rows[-1].ReadStatus -eq 'DepthLimit') 'VHD depth bounded'}
        EventDenied {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'Events' -and $_.Status -eq 'Failed'}).Count -eq 6) 'Event access denied never means no events'}
        NoEvents {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'Events' -and $_.Status -eq 'Empty'}).Count -eq 6) 'No matching events handled separately'}
        EventTruncated {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'EventCoverage'})[0].Rows[0].Truncated -eq $true) 'Event cap visible'}
        Skipped {Assert-True (@($packets | Where-Object {$_.Dataset -eq 'Events'})[0].Status -eq 'NotRequested') 'Events skipped explicitly';Assert-True (@($packets | Where-Object {$_.Dataset -eq 'BpaResults'})[0].Status -eq 'NotRequested') 'BPA is opt-in'}
    }
}
function Invoke-BoundScenario {
    param([bool]$Timeout,[bool]$Remote)
    $tracking=@{Stopped=0;Removed=0;Started=0;Received=0;Options=$null};$fake=[pscustomobject]@{State='Completed';Id=191}
    function Start-Job {[CmdletBinding()]param($ScriptBlock,$ArgumentList);$tracking.Started++;$tracking.Options=$ArgumentList;$fake}
    function New-PSSessionOption {[CmdletBinding()]param($OpenTimeout,$OperationTimeout);[pscustomobject]@{OpenTimeout=$OpenTimeout}}
    function Invoke-Command {[CmdletBinding()]param($ComputerName,$ScriptBlock,$ArgumentList,[switch]$AsJob,$SessionOption,$Credential);if(-not $AsJob){throw 'Expected owned job'};$tracking.Started++;$tracking.Options=$ArgumentList;$fake}
    function Wait-Job {[CmdletBinding()]param($Job,$Timeout);if($Job -ne $fake){throw 'Wrong job'};if(-not $Timeout){$fake}}
    # Override Wait-Job again with a distinct parameter name from the enclosing flag.
    $timeoutFlag=$Timeout
    function Wait-Job {[CmdletBinding()]param($Job,$Timeout);if($Job -ne $fake){throw 'Wrong job'};if(-not $timeoutFlag){$fake}}
    function Receive-Job {[CmdletBinding()]param($Job);$tracking.Received++;[pscustomobject]@{PacketType='HvProbe';Dataset='VMs';Status='Empty';Rows=@()}}
    function Stop-Job {[CmdletBinding()]param($Job);if($Job -ne $fake){throw 'Wrong job'};$tracking.Stopped++}
    function Remove-Job {[CmdletBinding()]param($Job,[switch]$Force);if($Job -ne $fake){throw 'Wrong job'};$tracking.Removed++}
    $target='localhost';if($Remote){$target='hv01.lab.example'}
    $result=Invoke-HvBoundedWorker $target @{Marker='test'} Collect 30 $null
    [pscustomobject]@{Result=$result;Tracking=$tracking}
}
foreach($remote in @($false,$true)){foreach($timeout in @($false,$true)){
    $bound=Invoke-BoundScenario $timeout $remote
    Assert-True ($bound.Tracking.Removed -eq 1 -and $bound.Tracking.Started -eq 1 -and $bound.Tracking.Received -eq 1) 'Owned job received and removed once'
    Assert-True ($bound.Result.TimedOut -eq $timeout -and $null -eq $bound.Result.Error) 'Bounded worker timeout state'
    Assert-True ($bound.Result.Packets.Count -eq 1) 'Completed packets preserved after timeout'
    Assert-True ($bound.Tracking.Stopped -eq [int]$timeout) 'Only timed-out job stopped'
}}
Write-Output "PASS: $script:checks collector/transport checks; 13 host scenarios + cluster + 4 job paths, all synthetic. Runtime: $($PSVersionTable.PSVersion)"
