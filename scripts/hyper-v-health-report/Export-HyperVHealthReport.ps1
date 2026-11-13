#requires -Version 5.1
<#
.SYNOPSIS
Read-only Hyper-V inventory and review report by FMODEL.
.DESCRIPTION
Collects host/VM/cluster evidence; exports HTML, CSV, JSON and SHA256 manifest.
Live: Windows PowerShell 5.1 x64. Offline example/rendering: PowerShell 5.1/7.
No repairs, feature installation, credential persistence or email delivery.
.EXAMPLE
.\Export-HyperVHealthReport.ps1 -ComputerName HV01 -OutputPath C:\Reports
.EXAMPLE
.\Export-HyperVHealthReport.ps1 -ClusterNode HV01 -CreateZip
.EXAMPLE
.\Export-HyperVHealthReport.ps1 -CreateExample -Language pt-BR
.NOTES
FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO
F. Model | fmodel@fmodel.com.br | Version 1.0.0
Independent FMODEL implementation. Scope informed by the user-provided
Get-HyperVReport.ps1 v1.5 (2015), attributed to Serhat AKINCI.
No legacy source is bundled. No reuse license has been selected for this library.
#>
[CmdletBinding(DefaultParameterSetName='Hosts')]
param(
    [Parameter(ParameterSetName='Hosts')][ValidateNotNullOrEmpty()][string[]]$ComputerName=@([Environment]::MachineName),
    [Parameter(Mandatory,ParameterSetName='Cluster')][ValidateNotNullOrEmpty()][string]$ClusterNode,
    [Parameter(Mandatory,ParameterSetName='Offline')][ValidateNotNullOrEmpty()][string]$InputJson,
    [Parameter(Mandatory,ParameterSetName='Example')][switch]$CreateExample,
    [Parameter(ParameterSetName='Hosts')][Parameter(ParameterSetName='Cluster')][pscredential]$Credential,
    [ValidateNotNullOrEmpty()][string]$OutputPath=(Join-Path (Get-Location).Path 'HyperV-Reports'),
    [ValidateSet('pt-BR','en-US')][string]$Language='pt-BR',
    [ValidateRange(1,5000)][int]$MaxHtmlRows=500,
    [switch]$CreateZip,
    [ValidateRange(30,7200)][int]$HostTimeoutSeconds=600,
    [ValidateRange(1,512)][int]$MaxHosts=128,
    [ValidateRange(1,20000)][int]$MaxVMsPerHost=2000,
    [ValidateRange(1,50000)][int]$MaxRowsPerProbe=5000,
    [ValidateRange(1,128)][int]$MaxVhdDepth=32,
    [ValidateRange(1,90)][int]$EventDays=7,
    [ValidateRange(1,5000)][int]$MaxEventsPerLog=200,
    [switch]$SkipEvents,
    [switch]$IncludeBpaResults,
    [ValidateRange(1,99)][double]$VolumeWarningPercent=15,
    [ValidateRange(0.1,98)][double]$VolumeCriticalPercent=5,
    [ValidateRange(1,99)][double]$MemoryWarningPercent=10,
    [ValidateRange(0.1,98)][double]$MemoryCriticalPercent=5,
    [ValidateRange(0,3650)][double]$CheckpointWarningDays=7,
    [ValidateRange(1,128)][double]$VcpuRatioWarning=8
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
function Get-HvSchemas {
    [ordered]@{
        Hosts='Host,CollectedUtc,Manufacturer,Model,Domain,OSCaption,OSVersion,Build,LastBootUtc,UptimeHours,MemoryTotalBytes,MemoryFreeBytes,MemoryFreePercent,LogicalProcessors,PhysicalProcessors,HypervisorPresent'
        HostSettings='Host,VirtualMachinePath,VirtualHardDiskPath,NumaSpanningEnabled,VirtualMachineMigrationEnabled,VirtualMachineMigrationAuthenticationType,VirtualMachineMigrationPerformanceOption,MaximumVirtualMachineMigrations,MaximumStorageMigrations,UseAnyNetworkForMigration,MacAddressMinimum,MacAddressMaximum,EnableEnhancedSessionMode'
        Processors='Host,DeviceID,Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,LoadPercentage,VirtualizationFirmwareEnabled,SecondLevelAddressTranslationExtensions'
        NumaNodes='Host,NodeId,ProcessorCount,MemoryTotal,MemoryAvailable'
        SupportedVersions='Host,Name,Version,IsDefault'
        Services='Host,Name,State,StartMode,Status'
        Hotfixes='Host,HotFixID,Description,InstalledOn'
        RebootSignals='Host,Signal,Present,Detail'
        Volumes='Host,Path,UniqueId,DriveLetter,FileSystemLabel,FileSystemType,HealthStatus,OperationalStatus,DriveType,SizeBytes,FreeBytes,FreePercent'
        PhysicalDisks='Host,FriendlyName,UniqueId,MediaType,BusType,HealthStatus,OperationalStatus,Size,CanPool,Usage'
        StoragePools='Host,FriendlyName,UniqueId,IsPrimordial,HealthStatus,OperationalStatus,Size,AllocatedSize'
        NetworkAdapters='Host,Name,InterfaceDescription,InterfaceIndex,Status,MacAddress,LinkSpeed,DriverInformation,DriverVersion,DriverDate,NdisVersion,Virtual,HardwareInterface'
        NetworkIPs='Host,InterfaceAlias,InterfaceIndex,AddressFamily,IPAddress,PrefixLength,AddressState,PrefixOrigin,SuffixOrigin'
        Switches='Host,Name,Id,SwitchType,NetAdapterInterfaceDescription,AllowManagementOS,EmbeddedTeamingEnabled,IovEnabled,IovSupport,BandwidthReservationMode'
        SwitchTeams='Host,Name,NetAdapterInterfaceDescription,TeamingMode,LoadBalancingAlgorithm'
        MigrationNetworks='Host,Subnet,Priority'
        HostReplica='Host,ReplicationEnabled,AllowedAuthenticationType,KerberosAuthenticationPort,CertificateAuthenticationPort,DefaultStorageLocation,ReplicationAllowedFromAnyServer'
        VMs='Host,VMId,VMName,Generation,Version,State,Status,OperationalStatus,UptimeHours,CPUUsage,ProcessorCount,MemoryAssigned,MemoryDemand,MemoryStatus,DynamicMemoryEnabled,MemoryStartup,AutomaticStartAction,AutomaticStopAction,AutomaticStartDelay,CheckpointType,AutomaticCheckpointsEnabled,ReplicationState,ReplicationHealth,IntegrationServicesState,IntegrationServicesVersion,ResourceMeteringEnabled,IsClustered,ConfigurationLocation,SnapshotFileLocation,SmartPagingFilePath,Notes'
        VMProcessors='Host,VMId,VMName,Count,Reserve,Maximum,RelativeWeight,CompatibilityForMigrationEnabled,CompatibilityForOlderOperatingSystemsEnabled,ExposeVirtualizationExtensions,HwThreadCountPerCore,MaximumCountPerNumaNode,MaximumCountPerNumaSocket,EnableHostResourceProtection'
        VMMemory='Host,VMId,VMName,DynamicMemoryEnabled,Startup,Minimum,Maximum,Buffer,Priority,MaximumAmountPerNumaNode'
        VMDisks='Host,VMId,VMName,ControllerType,ControllerNumber,ControllerLocation,Path,DiskNumber,SupportPersistentReservations,MaximumIOPS,MinimumIOPS,QoSPolicyID'
        VHDChains='Host,VMId,VMName,RootPath,Depth,Path,ParentPath,VhdFormat,VhdType,FileSizeBytes,VirtualSizeBytes,MinimumSizeBytes,FragmentationPercentage,LogicalSectorSize,PhysicalSectorSize,BlockSize,Attached,DiskIdentifier,ReadStatus,Error'
        VMNetworkAdapters='Host,VMId,VMName,Name,Id,IsLegacy,SwitchName,SwitchId,Status,MacAddress,DynamicMacAddressEnabled,IPAddresses,MacAddressSpoofing,DhcpGuard,RouterGuard,PortMirroring,ProtectedNetwork,IovWeight,VmqWeight,MinimumBandwidthAbsolute,MinimumBandwidthWeight,MaximumBandwidth'
        VMVlans='Host,VMId,VMName,AdapterName,OperationMode,AccessVlanId,NativeVlanId,AllowedVlanIdList,PrimaryVlanId,SecondaryVlanId,SecondaryVlanIdList'
        IntegrationServices='Host,VMId,VMName,Name,Id,Enabled,PrimaryStatusDescription,SecondaryStatusDescription,PrimaryOperationalStatus,SecondaryOperationalStatus'
        Checkpoints='Host,VMId,VMName,Name,Id,ParentSnapshotId,ParentSnapshotName,CreationTimeUtc,AgeDays,SnapshotType'
        Replication='Host,VMId,VMName,State,Health,Mode,RelationshipType,PrimaryServer,ReplicaServer,ReplicaPort,AuthenticationType,FrequencySec,LastReplicationTimeUtc,RecoveryHistory,AutoResynchronizeEnabled,ResynchronizeStartTime,ResynchronizeEndTime'
        ReplicationStats='Host,VMId,VMName,ReplicationHealth,ReplicationState,LastReplicationTime,LastApplyTime,AverageReplicationLatency,AverageReplicationSize,PendingReplicationSize,MissedReplicationCount,SuccessfulReplicationCount,MonitoringStartTime,MonitoringInterval'
        VMFirmware='Host,VMId,VMName,SecureBoot,SecureBootTemplate,PreferredNetworkBootProtocol,ConsoleMode'
        VMSecurity='Host,VMId,VMName,TpmEnabled,Shielded,EncryptStateAndVmMigrationTraffic,VirtualizationBasedSecurityOptOut,KsdEnabled'
        VMResources='Host,VMId,VMName,MeteringDuration,AverageProcessorUsage,AverageMemoryUsage,MaximumMemoryUsage,MinimumMemoryUsage,TotalDiskAllocation,AggregatedAverageNormalizedIOPS,AggregatedAverageLatency,AggregatedDiskDataRead,AggregatedDiskDataWritten'
        DVDDrives='Host,VMId,VMName,ControllerNumber,ControllerLocation,Path,DvdMediaType'
        AssignedDevices='Host,VMId,VMName,Name,InstanceID,LocationPath'
        FibreChannel='Host,VMId,VMName,Name,SanName,WorldWideNodeNameSetA,WorldWideNodeNameSetB,WorldWidePortNameSetA,WorldWidePortNameSetB'
        Cluster='Host,Name,Domain,ClusterFunctionalLevel,DynamicQuorum,DynamicWitness,QuarantineThreshold,QuarantineDuration,SameSubnetDelay,SameSubnetThreshold,CrossSubnetDelay,CrossSubnetThreshold'
        ClusterNodes='Host,Name,Id,State,NodeWeight,DynamicWeight,DrainStatus,FaultDomain'
        ClusterGroups='Host,Name,Id,State,OwnerNode,GroupType,Priority,FailoverThreshold,FailoverPeriod'
        ClusterResources='Host,Name,Id,State,OwnerGroup,OwnerNode,ResourceType,IsCoreResource'
        ClusterVolumes='Host,Name,OwnerNode,State,Path,PartitionName,FileSystem,SizeBytes,FreeBytes,FreePercent,RedirectedAccess,FaultState'
        ClusterNetworks='Host,Name,Address,AddressMask,Role,State,Metric,AutoMetric'
        ClusterQuorum='Host,Cluster,QuorumType,QuorumResource'
        Events='Host,LogName,TimeCreatedUtc,EventId,Level,Provider,RecordId,Message'
        EventCoverage='Host,LogName,StartUtc,EndUtc,Status,Rows,Truncated,Limit,Error'
        BpaResults='Host,ModelId,ResultNumber,Severity,Category,Title,Problem,Impact,Resolution,Compliance,Excluded'
        DeviceGuard='Host,VirtualizationBasedSecurityStatus,SecurityServicesConfigured,SecurityServicesRunning,RequiredSecurityProperties,AvailableSecurityProperties'
        SmbSettings='Host,Component,EnableSecuritySignature,RequireSecuritySignature,EnableSMB1Protocol,EnableSMB2Protocol,EncryptData,RejectUnencryptedAccess,EnableMultiChannel'
        SmbConnections='Host,ServerName,ShareName,Dialect,Encrypted,Signed,ContinuouslyAvailable,NumOpens'
        AdapterOffloads='Host,Kind,Name,InterfaceDescription,Enabled,OperationalState,SriovSupport,NumberOfReceiveQueues,NumberOfVMQs,BaseProcessorNumber,MaxProcessors'
        ManagementAdapters='Host,Name,SwitchName,SwitchId,Status,MacAddress,IPAddresses,ManagementOS'
        HostSummary='Host,CollectedVMRows,RunningVMRows,LogicalProcessors,ConfiguredVcpu,RunningVcpu,RunningVcpuPerLogicalProcessor,AssignedMemoryBytes,ConfiguredStartupMemoryBytes,HostFreeMemoryPercent,OldCheckpointRows,WarningFindings,CriticalFindings,CollectionProblems,InventoryStatus,Observation'
        StorageCapacity='Host,VolumePath,VolumeSizeBytes,VolumeFreeBytes,UniqueVhdPaths,ObservedFileSizeBytes,ObservedVirtualSizeBytes,NominalGrowthBytes,Observation'
        Findings='Severity,RuleId,Host,Target,Evidence,Recommendation,SourceId'
        Coverage='Host,Dataset,Scope,Status,Rows,StartedUtc,EndedUtc,DurationSeconds,Detail'
        Errors='Host,Dataset,Scope,ErrorType,Message'
    }
}
function Get-HvLabels {
    @{
        Hosts='Hosts / Hosts'
        HostSettings='Configuração dos hosts / Host configuration'
        Processors='Processadores / Processors'
        NumaNodes='NUMA / NUMA'
        SupportedVersions='Versões de VM aceitas / Supported VM versions'
        Services='Serviços / Services'
        Hotfixes='Atualizações QFE / QFE updates'
        RebootSignals='Indícios de reinicialização / Reboot signals'
        Volumes='Volumes / Volumes'
        PhysicalDisks='Discos físicos / Physical disks'
        StoragePools='Pools de armazenamento / Storage pools'
        NetworkAdapters='Interfaces do host / Host adapters'
        NetworkIPs='Endereços do host / Host IP addresses'
        Switches='Switches virtuais / Virtual switches'
        SwitchTeams='Switch Embedded Teaming / Switch Embedded Teaming'
        MigrationNetworks='Redes de Live Migration / Live Migration networks'
        HostReplica='Serviço Hyper-V Replica / Hyper-V Replica service'
        VMs='Máquinas virtuais / Virtual machines'
        VMProcessors='CPU das VMs / VM CPU settings'
        VMMemory='Memória das VMs / VM memory settings'
        VMDisks='Discos conectados / Attached disks'
        VHDChains='VHD e cadeia de pais / VHD parent chains'
        VMNetworkAdapters='Rede das VMs / VM networking'
        VMVlans='VLAN das VMs / VM VLAN settings'
        IntegrationServices='Serviços de integração / Integration services'
        Checkpoints='Checkpoints / Checkpoints'
        Replication='Replicação / Replication'
        ReplicationStats='Estatísticas Replica / Replica statistics'
        VMFirmware='Firmware das VMs / VM firmware'
        VMSecurity='Segurança das VMs / VM security settings'
        VMResources='Medição já habilitada / Existing resource metering'
        DVDDrives='Mídia óptica / Optical media'
        AssignedDevices='Dispositivos DDA / DDA devices'
        FibreChannel='Fibre Channel virtual / Virtual Fibre Channel'
        Cluster='Cluster / Cluster'
        ClusterNodes='Nós do cluster / Cluster nodes'
        ClusterGroups='Grupos do cluster / Cluster roles'
        ClusterResources='Recursos do cluster / Cluster resources'
        ClusterVolumes='CSV do cluster / Cluster shared volumes'
        ClusterNetworks='Redes do cluster / Cluster networks'
        ClusterQuorum='Quorum / Quorum'
        Events='Eventos recentes / Recent events'
        EventCoverage='Cobertura dos eventos / Event coverage'
        BpaResults='Resultados BPA existentes / Existing BPA results'
        DeviceGuard='Segurança baseada em virtualização / Virtualization-based security'
        SmbSettings='Configuração SMB / SMB configuration'
        SmbConnections='Conexões SMB / SMB connections'
        AdapterOffloads='Offloads de rede / Network offloads'
        ManagementAdapters='Rede do sistema de gerenciamento / Management OS networking'
        HostSummary='Resumo dos hosts / Host summary'
        StorageCapacity='Capacidade de VHD por volume / VHD capacity per volume'
        Findings='Achados para revisão / Findings for review'
        Coverage='Cobertura da coleta / Collection coverage'
        Errors='Falhas de coleta / Collection failures'
    }
}
function Get-HvField {
    param($Object,[string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [Collections.IDictionary]) { return $Object[$Name] }
    $p=$Object.PSObject.Properties[$Name]
    if ($null -ne $p) { return $p.Value }
    return $null
}
function Convert-HvDate {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    try { ([datetime]$Value).ToUniversalTime().ToString('o') } catch { return $null }
}
function Convert-HvScalar {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) { return Convert-HvDate $Value }
    if ($Value -is [timespan]) { return $Value.ToString() }
    if ($Value -is [guid] -or $Value -is [enum]) { return [string]$Value }
    if ($Value -is [array]) { return (($Value | ForEach-Object { Convert-HvScalar $_ }) -join '; ') }
    if ($Value -is [string] -or $Value -is [ValueType]) { return $Value }
    return [string]$Value
}
function New-HvReport {
    param([string]$Language='pt-BR')
    $sets=[ordered]@{};foreach($key in (Get-HvSchemas).Keys){$sets[$key]=New-Object 'Collections.Generic.List[object]'}
    [pscustomobject]@{SchemaVersion=1;Tool='Hyper-V Health Report';Version='1.0.0';Brand='FMODEL';Author='F. Model';Contact='fmodel@fmodel.com.br';Language=$Language;RunId=[guid]::NewGuid().ToString('N');StartedUtc=[datetime]::UtcNow.ToString('o');EndedUtc=$null;Status='Collecting';Synthetic=$false;Parameters=[ordered]@{};Datasets=$sets}
}
function Add-HvRows {
    param($Report,[string]$Dataset,[object[]]$Rows)
    $columns=(Get-HvSchemas)[$Dataset] -split ','
    foreach($row in $Rows){if($null -ne $row){$normalized=[ordered]@{};foreach($col in $columns){$normalized[$col]=Convert-HvScalar (Get-HvField $row $col)};$Report.Datasets[$Dataset].Add([pscustomobject]$normalized)}}
}
function Add-HvPacket {
    param($Report,$Packet)
    $dataset=[string](Get-HvField $Packet 'Dataset')
    if (-not $Report.Datasets.Contains($dataset)) { throw "Unknown dataset in worker packet: $dataset" }
    $before=$Report.Datasets[$dataset].Count
    Add-HvRows $Report $dataset @((Get-HvField $Packet 'Rows'))
    Add-HvRows $Report Coverage @([pscustomobject]@{Host=Get-HvField $Packet Host;Dataset=$dataset;Scope=Get-HvField $Packet Scope;Status=Get-HvField $Packet Status;Rows=($Report.Datasets[$dataset].Count-$before);StartedUtc=Get-HvField $Packet StartedUtc;EndedUtc=Get-HvField $Packet EndedUtc;DurationSeconds=Get-HvField $Packet DurationSeconds;Detail=Get-HvField $Packet Detail})
    $message=Get-HvField $Packet 'Error'
    if($message){Add-HvRows $Report Errors @([pscustomobject]@{Host=Get-HvField $Packet Host;Dataset=$dataset;Scope=Get-HvField $Packet Scope;ErrorType=Get-HvField $Packet ErrorType;Message=$message})}
}
function Test-HvLocalTarget {
    param([string]$Name)
    $Name -in @('.','localhost','127.0.0.1','::1',$env:COMPUTERNAME,[Environment]::MachineName)
}
function Assert-HvTarget {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Length -gt 255 -or $Name -notmatch '^(?:[A-Za-z0-9][A-Za-z0-9._-]*|\.|::1)$') { throw "Invalid computer name: $Name" }
}
function Invoke-HvBoundedWorker {
    param([string]$Target,[hashtable]$Options,[ValidateSet('Collect','Discover')][string]$Mode,[int]$TimeoutSeconds,[pscredential]$Credential)
    $job=$null;$packets=New-Object 'Collections.Generic.List[object]';$errorMessage=$null;$timedOut=$false
    try {
        $block=[scriptblock]::Create((Get-Command Invoke-HvWorker).Definition)
        if(Test-HvLocalTarget $Target){
            if($null -ne $Credential){throw 'Credential cannot be applied to a local background job. Run as the intended account or use an explicit remote host.'}
            $job=Start-Job -ScriptBlock $block -ArgumentList $Options,$Mode -ErrorAction Stop
        }else{
            $invoke=@{ComputerName=$Target;ScriptBlock=$block;ArgumentList=@($Options,$Mode);AsJob=$true;ErrorAction='Stop';SessionOption=(New-PSSessionOption -OpenTimeout 30000 -OperationTimeout 120000)}
            if($null -ne $Credential){$invoke.Credential=$Credential}
            $job=Invoke-Command @invoke
        }
        $finished=Wait-Job -Job $job -Timeout $TimeoutSeconds -ErrorAction Stop
        $timedOut=($null -eq $finished)
        if($timedOut){Stop-Job -Job $job -ErrorAction SilentlyContinue}
        $receiveErrors=@();$items=@(Receive-Job -Job $job -ErrorAction SilentlyContinue -ErrorVariable receiveErrors)
        foreach($item in $items){if((Get-HvField $item 'PacketType') -eq 'HvProbe'){$packets.Add($item)}}
        if($receiveErrors.Count -gt 0){$errorMessage=($receiveErrors | ForEach-Object {$_.ToString()}) -join ' | '}
        if($job.State -eq 'Failed' -and -not $errorMessage){$errorMessage='Worker failed before completing. Check transport and module access.'}
    }catch{$errorMessage=$_.Exception.Message}
    finally{if($null -ne $job){if($job.State -in @('Running','NotStarted','Blocked')){Stop-Job -Job $job -ErrorAction SilentlyContinue};Remove-Job -Job $job -Force -ErrorAction SilentlyContinue}}
    [pscustomobject]@{Packets=$packets.ToArray();TimedOut=$timedOut;Error=$errorMessage}
}
function Assert-HvLocalPath {
    param([string]$Path,[switch]$File,[long]$MaximumBytes=104857600)
    if([string]::IsNullOrWhiteSpace($Path)){throw 'Path is empty.'}
    if($Path.StartsWith('\\') -or $Path.StartsWith('//')){throw 'Use a local filesystem path, not a UNC share.'}
    $full=[IO.Path]::GetFullPath($Path)
    if($full.StartsWith('\\') -or $full.StartsWith('//')){throw 'Use a local filesystem path, not a UNC share.'}
    $item=$full
    while($item){
        if(Test-Path -LiteralPath $item){$entry=Get-Item -LiteralPath $item -Force -ErrorAction Stop;if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "Reparse point is not accepted: $item"}}
        $parent=[IO.Path]::GetDirectoryName($item);if($parent -eq $item){break};$item=$parent
    }
    if($File){$f=Get-Item -LiteralPath $full -Force -ErrorAction Stop;if($f -isnot [IO.FileInfo] -or $f.Length -gt $MaximumBytes){throw 'Input must be a regular file within the size limit.'}}
    $full
}
function Write-HvUtf8 {
    param([string]$Path,[string]$Text,[switch]$Bom)
    [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding([bool]$Bom)))
}
function Convert-HvCsvCell {
    param($Value)
    $text=[string](Convert-HvScalar $Value)
    # Preserve typed negative numbers; guard spreadsheet formulas in text cells.
    if($Value -is [string] -and ($text -match '^[\s\x00-\x1f]*[=+@-]' -or $text -match '^[\t\r\n]')){$text="'"+$text}
    '"'+$text.Replace('"','""')+'"'
}
function Write-HvCsv {
    param([string]$Path,[string[]]$Columns,[object[]]$Rows)
    $writer=New-Object IO.StreamWriter($Path,$false,(New-Object Text.UTF8Encoding($true)))
    try{$writer.WriteLine((($Columns | ForEach-Object {Convert-HvCsvCell $_}) -join ','));foreach($row in $Rows){$cells=foreach($col in $Columns){Convert-HvCsvCell (Get-HvField $row $col)};$writer.WriteLine(($cells -join ','))}}finally{$writer.Dispose()}
}
function Read-HvOfflineReport {
    param([string]$Path,[string]$Language)
    $full=Assert-HvLocalPath $Path -File
    $data=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($full)) -ErrorAction Stop
    if((Get-HvField $data 'SchemaVersion') -ne 1 -or (Get-HvField $data 'Tool') -ne 'Hyper-V Health Report'){throw 'Unsupported report schema or tool.'}
    $report=New-HvReport $Language
    foreach($key in @('RunId','StartedUtc','EndedUtc','Status','Synthetic','Parameters')){$value=Get-HvField $data $key;if($null -ne $value){$report.$key=$value}}
    if($report.Status -notin @('Completed','CompletedWithIssues','SyntheticExample')){throw 'Offline report is not a completed assessment.'}
    $sets=Get-HvField $data Datasets
    if($null -eq $sets){throw 'Missing Datasets.'}
    foreach($key in (Get-HvSchemas).Keys){
        $rows=Get-HvField $sets $key
        foreach($row in $rows){
            if($null -eq $row){continue};if($row -is [string] -or $row -is [ValueType]){throw "Invalid row in $key"}
            $normalized=[ordered]@{};foreach($col in ((Get-HvSchemas)[$key] -split ',')){$value=Get-HvField $row $col;if($null -ne $value -and $value -isnot [string] -and $value -isnot [ValueType]){throw "Nested field rejected: $key.$col"};$normalized[$col]=$value}
            Add-HvRows $report $key @([pscustomobject]$normalized)
            if($report.Datasets[$key].Count -gt 200000){throw "Offline dataset too large: $key"}
        }
    }
    $report
}
function Write-HvDeliverables {
    param($Report,[string]$OutputPath,[int]$MaxHtmlRows=500,[switch]$CreateZip)
    $root=Assert-HvLocalPath $OutputPath
    if(Test-Path -LiteralPath $root -PathType Leaf){throw 'OutputPath must be a directory.'}
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $folder=Join-Path $root ('HyperV-'+[datetime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    $csv=Join-Path $folder 'csv';[IO.Directory]::CreateDirectory($csv) | Out-Null
    $schemas=Get-HvSchemas
    foreach($key in $schemas.Keys){Write-HvCsv (Join-Path $csv ($key+'.csv')) ($schemas[$key] -split ',') $Report.Datasets[$key].ToArray()}
    Write-HvUtf8 (Join-Path $folder 'report.json') ($Report | ConvertTo-Json -Depth 14)
    Write-HvHtml (Join-Path $folder 'report.html') $Report $MaxHtmlRows
    $hashes=foreach($file in @(Get-ChildItem -LiteralPath $folder -File -Recurse | Sort-Object FullName)){
        $relative=$file.FullName.Substring($folder.Length+1).Replace('\','/');(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$relative
    }
    Write-HvUtf8 (Join-Path $folder 'MANIFEST-SHA256.txt') ($hashes -join "`n")
    if($CreateZip){Compress-Archive -Path (Join-Path $folder '*') -DestinationPath ($folder+'.zip') -CompressionLevel Optimal -ErrorAction Stop}
    [pscustomobject]@{Status=$Report.Status;ReportDirectory=$folder;Html=Join-Path $folder 'report.html';Json=Join-Path $folder 'report.json';CsvDirectory=$csv;Zip=$(if($CreateZip){$folder+'.zip'}else{$null})}
}

function Invoke-HvWorker {
    param([hashtable]$Options,[ValidateSet('Collect','Discover')][string]$Mode)
    Set-StrictMode -Version 2.0
    $ErrorActionPreference='Stop'
    $node=[Environment]::MachineName;$cache=@{};$probeState=@{}
    function Get-HvwField {param($o,[string]$n);if($null -eq $o){return $null};if($o -is [Collections.IDictionary]){return $o[$n]};$p=$o.PSObject.Properties[$n];if($null -ne $p){return $p.Value};return $null}
    function Convert-HvwScalar {param($v);if($null -eq $v){return $null};if($v -is [datetime]){return $v.ToUniversalTime().ToString('o')};if($v -is [array]){return (($v | ForEach-Object {Convert-HvwScalar $_}) -join '; ')};if($v -is [enum] -or $v -is [guid] -or $v -is [timespan]){return [string]$v};if($v -is [string] -or $v -is [ValueType]){return $v};[string]$v}
    function Convert-HvwDate {param($v);if($null -eq $v){return $null};try{([datetime]$v).ToUniversalTime().ToString('o')}catch{$null}}
    function Convert-HvwRow {
        param($Object,[string]$Fields,$VM)
        $row=[ordered]@{Host=$node}
        if($null -ne $VM){$row.VMId=Convert-HvwScalar (Get-HvwField $VM 'Id');$row.VMName=Get-HvwField $VM Name}
        foreach($pair in ($Fields -split ',')){
            $bits=$pair.Trim() -split '=',2;$key=$bits[0];$property=$key;if($bits.Count -gt 1){$property=$bits[1]}
            $value=$null;foreach($candidate in ($property -split '\|')){$value=Get-HvwField $Object $candidate;if($null -ne $value){break}}
            $row[$key]=Convert-HvwScalar $value
        }
        [pscustomobject]$row
    }
    function Invoke-HvwProbe {
        param([string]$Dataset,[string]$Scope,[scriptblock]$Read,[scriptblock]$Project,[string]$Command,[string]$Skip,[string]$Capture,[int]$Limit=$Options.MaxRowsPerProbe)
        $start=[datetime]::UtcNow;$watch=[Diagnostics.Stopwatch]::StartNew();$rows=New-Object 'Collections.Generic.List[object]';$status='Collected';$errorText=$null;$type=$null;$detail=''
        $probeState.Clear()
        try {
            if($Skip){$status=$Skip}
            elseif($Command -and -not (Get-Command $Command -ErrorAction SilentlyContinue)){$status='Unsupported';$detail="Cmdlet unavailable: $Command"}
            else{
                $raw=@(& $Read | Select-Object -First ($Limit+1))
                if($raw.Count -gt $Limit){$raw=@($raw | Select-Object -First $Limit);$status='Truncated';$detail="Limit $Limit reached; remaining items were not exported."}
                if($Capture){$cache[$Capture]=$raw}
                foreach($item in $raw){if($Project){foreach($mapped in @(& $Project $item)){if($null -ne $mapped){$rows.Add($mapped)}}}elseif($null -ne $item){$rows.Add($item)}}
                if($status -eq 'Collected' -and $rows.Count -eq 0){$status='Empty'}
                if($probeState.ContainsKey('Status')){$status=$probeState.Status;$detail=$probeState.Detail}
                if($probeState.ContainsKey('Error')){$errorText=$probeState.Error;$type='EvidenceReadFailure'}
            }
        }catch{$status='Failed';$errorText=$_.Exception.Message;$type=$_.Exception.GetType().FullName}
        [pscustomobject]@{PacketType='HvProbe';Host=$node;Dataset=$Dataset;Scope=$Scope;Status=$status;Rows=$rows.ToArray();StartedUtc=$start.ToString('o');EndedUtc=[datetime]::UtcNow.ToString('o');DurationSeconds=[Math]::Round($watch.Elapsed.TotalSeconds,3);Detail=$detail;Error=$errorText;ErrorType=$type}
    }
    function Get-HvwVhdChain {
        param($VM,[string]$RootPath)
        $path=$RootPath;$seen=@{};$depth=0
        while($path){
            $key=$path.ToLowerInvariant()
            if($seen.ContainsKey($key) -or $depth -ge $Options.MaxVhdDepth){
                $reason='DepthLimit';if($seen.ContainsKey($key)){$reason='CycleDetected'}
                [pscustomobject]@{Host=$node;VMId=Convert-HvwScalar (Get-HvwField $VM Id);VMName=Get-HvwField $VM Name;RootPath=$RootPath;Depth=$depth;Path=$path;ReadStatus=$reason;Error='Parent chain was not fully traversed.'}
                $probeState.Status='Partial';$probeState.Detail='VHD chain stopped at cycle/depth limit.';break
            }
            $seen[$key]=$true
            try{
                $v=Get-VHD -Path $path -ErrorAction Stop
                $r=Convert-HvwRow $v 'Path,ParentPath,VhdFormat,VhdType,FileSizeBytes=FileSize,VirtualSizeBytes=Size,MinimumSizeBytes=MinimumSize,FragmentationPercentage,LogicalSectorSize,PhysicalSectorSize,BlockSize,Attached,DiskIdentifier' $VM
                $r | Add-Member NoteProperty RootPath $RootPath;$r | Add-Member NoteProperty Depth $depth;$r | Add-Member NoteProperty ReadStatus 'Read';$r | Add-Member NoteProperty Error $null
                $r;$path=[string](Get-HvwField $v ParentPath);$depth++
            }catch{
                [pscustomobject]@{Host=$node;VMId=Convert-HvwScalar (Get-HvwField $VM Id);VMName=Get-HvwField $VM Name;RootPath=$RootPath;Depth=$depth;Path=$path;ReadStatus='Error';Error=$_.Exception.Message}
                $probeState.Status='Partial';$probeState.Detail='VHD inaccessible: check owner, permissions, SMB and VM movement.';$probeState.Error=$_.Exception.Message;break
            }
        }
    }
    if($Mode -eq 'Discover'){
        Invoke-HvwProbe Cluster $node {Import-Module FailoverClusters -ErrorAction Stop;Get-Cluster -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,Domain,ClusterFunctionalLevel,DynamicQuorum,DynamicWitness,QuarantineThreshold,QuarantineDuration,SameSubnetDelay,SameSubnetThreshold,CrossSubnetDelay,CrossSubnetThreshold'} -Capture Cluster
        Invoke-HvwProbe ClusterNodes $node {Get-ClusterNode -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,Id,State,NodeWeight,DynamicWeight,DrainStatus,FaultDomain'} -Command Get-ClusterNode
        Invoke-HvwProbe ClusterGroups $node {Get-ClusterGroup -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,Id,State,OwnerNode,GroupType,Priority,FailoverThreshold,FailoverPeriod'} -Command Get-ClusterGroup
        Invoke-HvwProbe ClusterResources $node {Get-ClusterResource -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,Id,State,OwnerGroup,OwnerNode,ResourceType,IsCoreResource'} -Command Get-ClusterResource
        Invoke-HvwProbe ClusterVolumes $node {Get-ClusterSharedVolume -ErrorAction Stop} {
            param($x)
            foreach($info in (Get-HvwField $x SharedVolumeInfo)){
                $part=Get-HvwField $info Partition
                $r=[ordered]@{Host=$node;Name=Get-HvwField $x Name;OwnerNode=Convert-HvwScalar (Get-HvwField $x OwnerNode);State=Convert-HvwScalar (Get-HvwField $x State);Path=Get-HvwField $info FriendlyVolumeName;PartitionName=Get-HvwField $part Name;FileSystem=Convert-HvwScalar (Get-HvwField $part FileSystem);SizeBytes=Get-HvwField $part Size;FreeBytes=Get-HvwField $part FreeSpace;FreePercent=Get-HvwField $part PercentFree;RedirectedAccess=Get-HvwField $info RedirectedAccess;FaultState=Convert-HvwScalar (Get-HvwField $info FaultState)}
                [pscustomobject]$r
            }
        } -Command Get-ClusterSharedVolume
        Invoke-HvwProbe ClusterNetworks $node {Get-ClusterNetwork -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,Address,AddressMask,Role,State,Metric,AutoMetric'} -Command Get-ClusterNetwork
        Invoke-HvwProbe ClusterQuorum $node {Get-ClusterQuorum -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Cluster,QuorumType,QuorumResource'} -Command Get-ClusterQuorum
        return
    }
    Invoke-HvwProbe Hosts $node {
        Import-Module Hyper-V -ErrorAction Stop
        $os=Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $cs=Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $total=Get-HvwField $os TotalVisibleMemorySize;$free=Get-HvwField $os FreePhysicalMemory;$boot=Get-HvwField $os LastBootUpTime
        [pscustomobject]@{Host=$node;CollectedUtc=[datetime]::UtcNow.ToString('o');Manufacturer=Get-HvwField $cs Manufacturer;Model=Get-HvwField $cs Model;Domain=Get-HvwField $cs Domain;OSCaption=Get-HvwField $os Caption;OSVersion=Get-HvwField $os Version;Build=Get-HvwField $os BuildNumber;LastBootUtc=Convert-HvwDate $boot;UptimeHours=$(if($null -ne $boot){[Math]::Round(([datetime]::Now-[datetime]$boot).TotalHours,2)}else{$null});MemoryTotalBytes=$(if($null -ne $total){[double]$total*1024}else{$null});MemoryFreeBytes=$(if($null -ne $free){[double]$free*1024}else{$null});MemoryFreePercent=$(if($total -gt 0 -and $null -ne $free){[Math]::Round(100.0*$free/$total,2)}else{$null});LogicalProcessors=Get-HvwField $cs NumberOfLogicalProcessors;PhysicalProcessors=Get-HvwField $cs NumberOfProcessors;HypervisorPresent=Get-HvwField $cs HypervisorPresent}
    }
    Invoke-HvwProbe HostSettings $node {Get-VMHost -ErrorAction Stop} {param($x);Convert-HvwRow $x 'VirtualMachinePath,VirtualHardDiskPath,NumaSpanningEnabled,VirtualMachineMigrationEnabled,VirtualMachineMigrationAuthenticationType,VirtualMachineMigrationPerformanceOption,MaximumVirtualMachineMigrations,MaximumStorageMigrations,UseAnyNetworkForMigration,MacAddressMinimum,MacAddressMaximum,EnableEnhancedSessionMode'} -Command Get-VMHost
    Invoke-HvwProbe Processors $node {Get-CimInstance Win32_Processor -ErrorAction Stop} {param($x);Convert-HvwRow $x 'DeviceID,Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,LoadPercentage,VirtualizationFirmwareEnabled,SecondLevelAddressTranslationExtensions'} -Command Get-CimInstance
    Invoke-HvwProbe NumaNodes $node {Get-VMHostNumaNode -ErrorAction Stop} {param($x);Convert-HvwRow $x 'NodeId,ProcessorCount,MemoryTotal,MemoryAvailable'} -Command Get-VMHostNumaNode
    Invoke-HvwProbe SupportedVersions $node {Get-VMHostSupportedVersion -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,Version,IsDefault'} -Command Get-VMHostSupportedVersion
    Invoke-HvwProbe Services $node {Get-CimInstance Win32_Service -Filter "Name='vmms' OR Name='vmcompute' OR Name='ClusSvc' OR Name='WinRM' OR Name='VSS' OR Name='swprv' OR Name='W32Time'" -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,State,StartMode,Status'}
    Invoke-HvwProbe Hotfixes $node {Get-CimInstance Win32_QuickFixEngineering -ErrorAction Stop} {param($x);Convert-HvwRow $x 'HotFixID,Description,InstalledOn'}
    Invoke-HvwProbe RebootSignals $node {
        foreach($entry in @(@('CBS','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'),@('WindowsUpdate','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'))){
            # Get-Item distinguishes access failures from missing keys.
            $present=$false
            try{$null=Get-Item -LiteralPath $entry[1] -ErrorAction Stop;$present=$true}catch [System.Management.Automation.ItemNotFoundException]{}
            [pscustomobject]@{Host=$node;Signal=$entry[0];Present=$present;Detail='Registry evidence; confirm maintenance state with Windows administrators.'}
        }
        $value=Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -ErrorAction Stop
        [pscustomobject]@{Host=$node;Signal='PendingFileRenameOperations';Present=(@((Get-HvwField $value PendingFileRenameOperations) | Where-Object {$_}).Count -gt 0);Detail='File operations may persist after restart; not a confirmed reboot requirement on their own.'}
    }
    Invoke-HvwProbe Volumes $node {Get-Volume -ErrorAction Stop} {
        param($x);$r=Convert-HvwRow $x 'Path,UniqueId,DriveLetter,FileSystemLabel,FileSystemType,HealthStatus,OperationalStatus,DriveType,SizeBytes=Size,FreeBytes=SizeRemaining';$size=Get-HvwField $x Size;$free=Get-HvwField $x SizeRemaining
        $r | Add-Member NoteProperty FreePercent $(if($size -gt 0 -and $null -ne $free){[Math]::Round(100.0*$free/$size,2)}else{$null});$r
    } -Command Get-Volume
    Invoke-HvwProbe PhysicalDisks $node {Get-PhysicalDisk -ErrorAction Stop} {param($x);Convert-HvwRow $x 'FriendlyName,UniqueId,MediaType,BusType,HealthStatus,OperationalStatus,Size,CanPool,Usage'} -Command Get-PhysicalDisk
    Invoke-HvwProbe StoragePools $node {Get-StoragePool -ErrorAction Stop} {param($x);Convert-HvwRow $x 'FriendlyName,UniqueId,IsPrimordial,HealthStatus,OperationalStatus,Size,AllocatedSize'} -Command Get-StoragePool
    Invoke-HvwProbe NetworkAdapters $node {Get-NetAdapter -IncludeHidden -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,InterfaceDescription,InterfaceIndex,Status,MacAddress,LinkSpeed,DriverInformation,DriverVersion,DriverDate,NdisVersion,Virtual,HardwareInterface'} -Command Get-NetAdapter
    Invoke-HvwProbe NetworkIPs $node {Get-NetIPAddress -ErrorAction Stop} {param($x);Convert-HvwRow $x 'InterfaceAlias,InterfaceIndex,AddressFamily,IPAddress,PrefixLength,AddressState,PrefixOrigin,SuffixOrigin'} -Command Get-NetIPAddress
    Invoke-HvwProbe Switches $node {Get-VMSwitch -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,Id,SwitchType,NetAdapterInterfaceDescription,AllowManagementOS,EmbeddedTeamingEnabled,IovEnabled,IovSupport,BandwidthReservationMode'} -Command Get-VMSwitch -Capture Switches
    $setSwitches=@();if($cache.ContainsKey('Switches')){$setSwitches=@($cache.Switches | Where-Object {(Get-HvwField $_ EmbeddedTeamingEnabled) -eq $true})}
    foreach($sw in $setSwitches){$swName=[string](Get-HvwField $sw Name);Invoke-HvwProbe SwitchTeams $swName {Get-VMSwitchTeam -Name $swName -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,NetAdapterInterfaceDescription,TeamingMode,LoadBalancingAlgorithm'} -Command Get-VMSwitchTeam}
    if($setSwitches.Count -eq 0){Invoke-HvwProbe SwitchTeams $node {} -Skip NotApplicable}
    Invoke-HvwProbe MigrationNetworks $node {Get-VMMigrationNetwork -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Subnet,Priority'} -Command Get-VMMigrationNetwork
    Invoke-HvwProbe HostReplica $node {Get-VMReplicationServer -ErrorAction Stop} {param($x);Convert-HvwRow $x 'ReplicationEnabled,AllowedAuthenticationType,KerberosAuthenticationPort,CertificateAuthenticationPort,DefaultStorageLocation,ReplicationAllowedFromAnyServer'} -Command Get-VMReplicationServer
    Invoke-HvwProbe DeviceGuard $node {Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop} {param($x);Convert-HvwRow $x 'VirtualizationBasedSecurityStatus,SecurityServicesConfigured,SecurityServicesRunning,RequiredSecurityProperties,AvailableSecurityProperties'}
    Invoke-HvwProbe SmbSettings ($node+'|Client') {Get-SmbClientConfiguration -ErrorAction Stop} {param($x);$r=Convert-HvwRow $x 'EnableSecuritySignature,RequireSecuritySignature,EnableMultiChannel';$r | Add-Member NoteProperty Component 'Client';$r} -Command Get-SmbClientConfiguration
    Invoke-HvwProbe SmbSettings ($node+'|Server') {Get-SmbServerConfiguration -ErrorAction Stop} {param($x);$r=Convert-HvwRow $x 'EnableSecuritySignature,RequireSecuritySignature,EnableSMB1Protocol,EnableSMB2Protocol,EncryptData,RejectUnencryptedAccess,EnableMultiChannel';$r | Add-Member NoteProperty Component 'Server';$r} -Command Get-SmbServerConfiguration
    Invoke-HvwProbe SmbConnections $node {Get-SmbConnection -ErrorAction Stop} {param($x);Convert-HvwRow $x 'ServerName,ShareName,Dialect,Encrypted,Signed,ContinuouslyAvailable,NumOpens'} -Command Get-SmbConnection
    foreach($offload in @(@('RDMA','Get-NetAdapterRdma'),@('VMQ','Get-NetAdapterVmq'),@('SRIOV','Get-NetAdapterSriov'))){
        $kind=$offload[0];$command=$offload[1]
        Invoke-HvwProbe AdapterOffloads ($node+'|'+$kind) {& $command -ErrorAction Stop} {param($x);$r=Convert-HvwRow $x 'Name,InterfaceDescription,Enabled,OperationalState,SriovSupport,NumberOfReceiveQueues,NumberOfVMQs,BaseProcessorNumber,MaxProcessors';$r | Add-Member NoteProperty Kind $kind;$r} -Command $command
    }
    Invoke-HvwProbe ManagementAdapters $node {Get-VMNetworkAdapter -ManagementOS -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,SwitchName,SwitchId,Status,MacAddress,IPAddresses,ManagementOS'} -Command Get-VMNetworkAdapter
    Invoke-HvwProbe VMs $node {Get-VM -ErrorAction Stop} {
        param($x);$r=Convert-HvwRow $x 'VMId=Id,VMName=Name,Generation,Version,State,Status,OperationalStatus,CPUUsage,ProcessorCount,MemoryAssigned,MemoryDemand,MemoryStatus,DynamicMemoryEnabled,MemoryStartup,AutomaticStartAction,AutomaticStopAction,AutomaticStartDelay,CheckpointType,AutomaticCheckpointsEnabled,ReplicationState,ReplicationHealth,IntegrationServicesState,IntegrationServicesVersion,ResourceMeteringEnabled,IsClustered,ConfigurationLocation,SnapshotFileLocation,SmartPagingFilePath,Notes'
        $up=Get-HvwField $x Uptime;$r | Add-Member NoteProperty UptimeHours $(if($null -ne $up){[Math]::Round($up.TotalHours,2)}else{$null});$r
    } -Command Get-VM -Capture VMs -Limit $Options.MaxVMsPerHost
    if($cache.ContainsKey('VMs')){foreach($vm in $cache.VMs){
        $scope=[string](Get-HvwField $vm Id)
        Invoke-HvwProbe VMProcessors $scope {Get-VMProcessor -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Count,Reserve,Maximum,RelativeWeight,CompatibilityForMigrationEnabled,CompatibilityForOlderOperatingSystemsEnabled,ExposeVirtualizationExtensions,HwThreadCountPerCore,MaximumCountPerNumaNode,MaximumCountPerNumaSocket,EnableHostResourceProtection' $vm} -Command Get-VMProcessor
        Invoke-HvwProbe VMMemory $scope {Get-VMMemory -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'DynamicMemoryEnabled,Startup,Minimum,Maximum,Buffer,Priority,MaximumAmountPerNumaNode' $vm} -Command Get-VMMemory
        Invoke-HvwProbe VMDisks $scope {Get-VMHardDiskDrive -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'ControllerType,ControllerNumber,ControllerLocation,Path,DiskNumber,SupportPersistentReservations,MaximumIOPS,MinimumIOPS,QoSPolicyID' $vm} -Command Get-VMHardDiskDrive -Capture Disks
        if($cache.ContainsKey('Disks')){
            foreach($disk in $cache.Disks){$path=[string](Get-HvwField $disk Path);if($path){Invoke-HvwProbe VHDChains ($scope+'|'+$path) {Get-HvwVhdChain $vm $path} -Command Get-VHD -Limit ($Options.MaxVhdDepth+1)}else{Invoke-HvwProbe VHDChains ($scope+'|passthrough') {} -Skip NotApplicable}}
            $cache.Remove('Disks')
        }
        Invoke-HvwProbe VMNetworkAdapters $scope {Get-VMNetworkAdapter -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,Id,IsLegacy,SwitchName,SwitchId,Status,MacAddress,DynamicMacAddressEnabled,IPAddresses,MacAddressSpoofing,DhcpGuard,RouterGuard,PortMirroring,ProtectedNetwork,IovWeight,VmqWeight,MinimumBandwidthAbsolute,MinimumBandwidthWeight,MaximumBandwidth' $vm} -Command Get-VMNetworkAdapter -Capture Adapters
        if($cache.ContainsKey('Adapters')){
            foreach($adapter in $cache.Adapters){Invoke-HvwProbe VMVlans ($scope+'|'+[string](Get-HvwField $adapter Id)) {Get-VMNetworkAdapterVlan -VMNetworkAdapter $adapter -ErrorAction Stop} {param($x);$r=Convert-HvwRow $x 'OperationMode,AccessVlanId,NativeVlanId,AllowedVlanIdList,PrimaryVlanId,SecondaryVlanId,SecondaryVlanIdList' $vm;$r | Add-Member NoteProperty AdapterName (Get-HvwField $adapter Name);$r} -Command Get-VMNetworkAdapterVlan}
            $cache.Remove('Adapters')
        }
        Invoke-HvwProbe IntegrationServices $scope {Get-VMIntegrationService -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,Id,Enabled,PrimaryStatusDescription,SecondaryStatusDescription,PrimaryOperationalStatus,SecondaryOperationalStatus' $vm} -Command Get-VMIntegrationService
        Invoke-HvwProbe Checkpoints $scope {Get-VMSnapshot -VM $vm -ErrorAction Stop} {
            param($x);$r=Convert-HvwRow $x 'Name,Id,ParentSnapshotId,ParentSnapshotName,SnapshotType' $vm;$time=Get-HvwField $x CreationTime;$r | Add-Member NoteProperty CreationTimeUtc (Convert-HvwDate $time);$r | Add-Member NoteProperty AgeDays $(if($null -ne $time){[Math]::Round(([datetime]::Now-[datetime]$time).TotalDays,2)}else{$null});$r
        } -Command Get-VMSnapshot
        $replicaSkip=$null;if([string](Get-HvwField $vm ReplicationState) -eq 'Disabled'){$replicaSkip='NotEnabled'}
        Invoke-HvwProbe Replication $scope {Get-VMReplication -VM $vm -ErrorAction Stop} {param($x);$r=Convert-HvwRow $x 'State,Health,Mode,RelationshipType,PrimaryServer,ReplicaServer,ReplicaPort,AuthenticationType,FrequencySec,RecoveryHistory,AutoResynchronizeEnabled,ResynchronizeStartTime,ResynchronizeEndTime' $vm;$r | Add-Member NoteProperty LastReplicationTimeUtc (Convert-HvwDate (Get-HvwField $x LastReplicationTime));$r} -Command Get-VMReplication -Skip $replicaSkip
        Invoke-HvwProbe ReplicationStats $scope {Measure-VMReplication -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'ReplicationHealth,ReplicationState,LastReplicationTime,LastApplyTime,AverageReplicationLatency,AverageReplicationSize,PendingReplicationSize,MissedReplicationCount,SuccessfulReplicationCount,MonitoringStartTime,MonitoringInterval' $vm} -Command Measure-VMReplication -Skip $replicaSkip
        $firmwareSkip=$null;if((Get-HvwField $vm Generation) -eq 1){$firmwareSkip='NotApplicable'}
        Invoke-HvwProbe VMFirmware $scope {Get-VMFirmware -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'SecureBoot,SecureBootTemplate,PreferredNetworkBootProtocol,ConsoleMode' $vm} -Command Get-VMFirmware -Skip $firmwareSkip
        Invoke-HvwProbe VMSecurity $scope {Get-VMSecurity -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'TpmEnabled,Shielded,EncryptStateAndVmMigrationTraffic,VirtualizationBasedSecurityOptOut,KsdEnabled' $vm} -Command Get-VMSecurity -Skip $firmwareSkip
        $meterSkip=$null;if((Get-HvwField $vm ResourceMeteringEnabled) -ne $true){$meterSkip='NotEnabled'}
        Invoke-HvwProbe VMResources $scope {Measure-VM -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'MeteringDuration,AverageProcessorUsage,AverageMemoryUsage,MaximumMemoryUsage,MinimumMemoryUsage,TotalDiskAllocation,AggregatedAverageNormalizedIOPS,AggregatedAverageLatency,AggregatedDiskDataRead,AggregatedDiskDataWritten' $vm} -Command Measure-VM -Skip $meterSkip
        Invoke-HvwProbe DVDDrives $scope {Get-VMDvdDrive -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'ControllerNumber,ControllerLocation,Path,DvdMediaType' $vm} -Command Get-VMDvdDrive
        Invoke-HvwProbe AssignedDevices $scope {Get-VMAssignableDevice -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,InstanceID,LocationPath' $vm} -Command Get-VMAssignableDevice
        Invoke-HvwProbe FibreChannel $scope {Get-VMFibreChannelHba -VM $vm -ErrorAction Stop} {param($x);Convert-HvwRow $x 'Name,SanName,WorldWideNodeNameSetA,WorldWideNodeNameSetB,WorldWidePortNameSetA,WorldWidePortNameSetB' $vm} -Command Get-VMFibreChannelHba
    }}
    if(-not $Options.SkipEvents){
        $end=[datetime]::Now;$start=$end.AddDays(-$Options.EventDays)
        foreach($log in @('System','Application','Microsoft-Windows-Hyper-V-VMMS-Admin','Microsoft-Windows-Hyper-V-Worker-Admin','Microsoft-Windows-Hyper-V-Hypervisor-Admin','Microsoft-Windows-FailoverClustering/Operational')){
            $events=@();$eventStatus='Collected';$message=$null;$truncated=$false
            try{
                $meta=Get-WinEvent -ListLog $log -ErrorAction Stop
                if(-not (Get-HvwField $meta IsEnabled)){$eventStatus='Disabled'}else{
                    try{$events=@(Get-WinEvent -FilterHashtable @{LogName=$log;StartTime=$start;EndTime=$end;Level=@(1,2,3)} -MaxEvents ($Options.MaxEventsPerLog+1) -ErrorAction Stop)}catch{if($_.FullyQualifiedErrorId -notmatch 'NoMatchingEventsFound'){throw}}
                    if($events.Count -gt $Options.MaxEventsPerLog){$events=@($events | Select-Object -First $Options.MaxEventsPerLog);$truncated=$true;$eventStatus='Truncated'}elseif($events.Count -eq 0){$eventStatus='Empty'}
                }
            }catch{$eventStatus='Failed';$message=$_.Exception.Message}
            Invoke-HvwProbe Events $log {$probeState.Status=$eventStatus;$probeState.Detail='Bounded event window; not an incident verdict.';if($message){$probeState.Error=$message};$events} {param($x);$r=Convert-HvwRow $x 'EventId=Id,Level,Provider=ProviderName,RecordId,Message';$r | Add-Member NoteProperty TimeCreatedUtc (Convert-HvwDate (Get-HvwField $x TimeCreated));$r | Add-Member NoteProperty LogName $log;$r} -Limit $Options.MaxEventsPerLog
            Invoke-HvwProbe EventCoverage $log { [pscustomobject]@{Host=$node;LogName=$log;StartUtc=$start.ToUniversalTime().ToString('o');EndUtc=$end.ToUniversalTime().ToString('o');Status=$eventStatus;Rows=$events.Count;Truncated=$truncated;Limit=$Options.MaxEventsPerLog;Error=$message} }
        }
    }else{Invoke-HvwProbe Events $node {} -Skip NotRequested;Invoke-HvwProbe EventCoverage $node {} -Skip NotRequested}
    $bpaSkip=$null;if(-not $Options.IncludeBpa){$bpaSkip='NotRequested'}
    Invoke-HvwProbe BpaResults $node {Get-BpaResult -ModelId 'Microsoft/Windows/Hyper-V' -ErrorAction Stop} {param($x);Convert-HvwRow $x 'ModelId,ResultNumber,Severity,Category,Title,Problem,Impact,Resolution,Compliance,Excluded'} -Command Get-BpaResult -Skip $bpaSkip
}

function Get-HvText {
    param($Report,[string]$Portuguese,[string]$English)
    if($Report.Language -eq 'en-US'){$English}else{$Portuguese}
}
function Add-HvFinding {
    param($Report,[string]$Severity,[string]$Rule,[string]$Node,[string]$Target,[string]$Evidence,[string]$Portuguese,[string]$English,[string]$Source='S01')
    Add-HvRows $Report Findings @([pscustomobject]@{Severity=$Severity;RuleId=$Rule;Host=$Node;Target=$Target;Evidence=$Evidence;Recommendation=Get-HvText $Report $Portuguese $English;SourceId=$Source})
}
function Get-HvNumberSum {
    param([object[]]$Rows,[string]$Property)
    $sum=0.0;$known=0
    foreach($row in $Rows){$value=Get-HvField $row $Property;if($null -ne $value){$sum+=[double]$value;$known++}}
    if($known -eq 0 -or $known -ne $Rows.Count){return $null};$sum
}
function Invoke-HvAssessment {
    param($Report)
    $d=$Report.Datasets;$p=$Report.Parameters
    $d.Findings.Clear();$d.HostSummary.Clear();$d.StorageCapacity.Clear()
    foreach($volume in $d.Volumes){
        if($null -ne $volume.FreePercent -and $volume.SizeBytes -gt 0 -and $volume.DriveType -in @('Fixed','3')){
            $severity=$null;if($volume.FreePercent -lt $p.VolumeCriticalPercent){$severity='Critical'}elseif($volume.FreePercent -lt $p.VolumeWarningPercent){$severity='Warning'}
            if($severity){Add-HvFinding $Report $severity 'HV001' $volume.Host $volume.Path ("FreePercent="+$volume.FreePercent) 'Revisar capacidade, crescimento e espaço necessário para backup/merge. Não apagar AVHDX manualmente.' 'Review capacity, growth and free space needed for backup/merge. Do not manually delete AVHDX files.' 'S03'}
        }
        if($volume.HealthStatus -and $volume.HealthStatus -ne 'Healthy'){Add-HvFinding $Report Warning 'HV002' $volume.Host $volume.Path $volume.HealthStatus 'Investigar o estado do volume com a equipe de armazenamento.' 'Investigate volume health with the storage team.' 'S04'}
    }
    foreach($hostRow in $d.Hosts){
        $free=$hostRow.MemoryFreePercent
        if($null -ne $free -and $free -lt $p.MemoryWarningPercent){$severity='Warning';if($free -lt $p.MemoryCriticalPercent){$severity='Critical'};Add-HvFinding $Report $severity 'HV003' $hostRow.Host $hostRow.Host ("MemoryFreePercent=$free") 'Correlacionar pressão de memória com carga, NUMA e reserva do sistema de gerenciamento.' 'Correlate memory pressure with workload, NUMA and management OS reserve.' 'S05'}
    }
    foreach($vm in $d.VMs){
        if($vm.State -match '(?i)critical|failed|pausedcritical|savedcritical'){Add-HvFinding $Report Critical 'HV004' $vm.Host $vm.VMName ("State="+$vm.State+'; Status='+$vm.Status) 'Revisar a VM, armazenamento e eventos no horário do problema.' 'Review VM state, storage and events around the incident.'}
        elseif($vm.State -eq 'Paused'){Add-HvFinding $Report Warning 'HV005' $vm.Host $vm.VMName 'State=Paused' 'Confirmar se a pausa é intencional e conferir armazenamento/eventos.' 'Confirm whether the pause is intentional and review storage/events.'}
        if($vm.CheckpointType -eq 'Standard'){Add-HvFinding $Report Info 'HV006' $vm.Host $vm.VMName 'CheckpointType=Standard' 'Avaliar checkpoints de produção conforme o sistema convidado e a carga. Checkpoint não comprova backup restaurável.' 'Evaluate production checkpoints against guest OS and workload requirements. A checkpoint does not prove restorable backup.' 'S02'}
        if($vm.ReplicationHealth -in @('Warning','Critical')){$severity=[string]$vm.ReplicationHealth;Add-HvFinding $Report $severity 'HV007' $vm.Host $vm.VMName ("ReplicationHealth="+$vm.ReplicationHealth) 'Conferir Replica, RPO, conectividade e teste de recuperação aprovado.' 'Review Replica, RPO, connectivity and an approved recovery test.' 'S06'}
        if($vm.MemoryStatus -match '(?i)^low$|^warning$'){Add-HvFinding $Report Warning 'HV008' $vm.Host $vm.VMName $vm.MemoryStatus 'Conferir demanda e limites de memória dinâmica; observar ao longo do tempo.' 'Review dynamic-memory demand and limits; observe over time.' 'S05'}
    }
    foreach($cp in $d.Checkpoints){if($null -ne $cp.AgeDays -and $cp.AgeDays -gt $p.CheckpointWarningDays){Add-HvFinding $Report Warning 'HV009' $cp.Host $cp.VMName ("Checkpoint="+$cp.Name+'; AgeDays='+$cp.AgeDays) 'Conferir política e software de backup; planejar remoção/merge por ferramenta suportada e com espaço livre.' 'Review policy and backup software; plan supported checkpoint removal/merge with sufficient free space.' 'S03'}}
    foreach($disk in $d.VHDChains){if($disk.ReadStatus -ne 'Read'){Add-HvFinding $Report Warning 'HV010' $disk.Host $disk.VMName ("Path="+$disk.Path+'; ReadStatus='+$disk.ReadStatus+'; '+$disk.Error) 'Confirmar host proprietário, permissões, SMB e movimento da VM. Falha de leitura não comprova arquivo ausente ou corrompido.' 'Confirm owning host, permissions, SMB and VM movement. A read failure does not prove a missing or corrupt disk.' 'S07'}}
    foreach($nic in $d.VMNetworkAdapters){
        $vm=@($d.VMs | Where-Object {$_.Host -eq $nic.Host -and $_.VMId -eq $nic.VMId} | Select-Object -First 1)
        if($vm.Count -and $vm[0].State -eq 'Running' -and [string]::IsNullOrWhiteSpace([string]$nic.SwitchName)){Add-HvFinding $Report Warning 'HV011' $nic.Host $nic.VMName ("Adapter="+$nic.Name+'; SwitchName empty') 'Confirmar se a interface deve estar desconectada e revisar o switch esperado.' 'Confirm whether the disconnected adapter is intentional and review the expected switch.' 'S08'}
    }
    # Duplicate MAC is an observation across different VM IDs, never a corruption verdict.
    $macGroups=@($d.VMNetworkAdapters | Where-Object {$_.MacAddress -and ($_.MacAddress -replace '[:-]','') -notmatch '^0+$'} | Group-Object {($_.MacAddress -replace '[:-]','').ToUpperInvariant()})
    foreach($group in $macGroups){$ids=@($group.Group | Select-Object -ExpandProperty VMId -Unique);if($ids.Count -gt 1){Add-HvFinding $Report Warning 'HV012' '' $group.Name (($group.Group | ForEach-Object {$_.Host+'/'+$_.VMName}) -join '; ') 'Investigar possível MAC duplicado; considerar réplicas isoladas, ambientes distintos e políticas de rede antes de alterar.' 'Investigate a possible duplicate MAC; consider isolated replicas, separate environments and network policy before changing anything.' 'S08'}}
    foreach($fw in $d.VMFirmware){if($null -ne $fw.SecureBoot -and [string]$fw.SecureBoot -in @('Off','False','0')){Add-HvFinding $Report Info 'HV013' $fw.Host $fw.VMName 'SecureBoot=Off' 'Validar requisitos do convidado e política de segurança; não habilitar sem confirmar compatibilidade.' 'Validate guest requirements and security policy; confirm compatibility before enabling.' 'S09'}}
    foreach($service in $d.Services){if($service.Name -eq 'vmms' -and $service.State -ne 'Running'){Add-HvFinding $Report Critical 'HV014' $service.Host 'vmms' $service.State 'Investigar serviço de gerenciamento e eventos; não reiniciar automaticamente.' 'Investigate the management service and events; do not restart automatically.'}}
    foreach($signal in $d.RebootSignals){if($signal.Present -eq $true){$rule='HV015';$sev='Warning';if($signal.Signal -eq 'PendingFileRenameOperations'){$rule='HV016';$sev='Info'};Add-HvFinding $Report $sev $rule $signal.Host $signal.Signal $signal.Detail 'Confirmar a necessidade de reinicialização e planejar manutenção. Este indício não bloqueia a coleta.' 'Confirm reboot requirements and plan maintenance. This signal does not block collection.' 'S10'}}
    foreach($node in $d.ClusterNodes){if($node.State -in @('Down','Joining')){Add-HvFinding $Report Warning 'HV017' $node.Host $node.Name ("State="+$node.State) 'Confirmar manutenção, comunicação e capacidade restante do cluster.' 'Confirm maintenance state, communication and remaining cluster capacity.' 'S11'}}
    foreach($resource in $d.ClusterResources){if($resource.State -eq 'Failed'){Add-HvFinding $Report Critical 'HV018' $resource.Host $resource.Name ("State=Failed; Type="+$resource.ResourceType) 'Investigar dependências e eventos do recurso; estado Offline pode ser intencional.' 'Investigate resource dependencies and events; Offline may be intentional.' 'S11'}}
    foreach($csv in $d.ClusterVolumes){if($csv.RedirectedAccess -eq $true -or ($csv.FaultState -and $csv.FaultState -ne 'NoFaults')){Add-HvFinding $Report Warning 'HV019' $csv.Host $csv.Path ("Redirected="+$csv.RedirectedAccess+'; FaultState='+$csv.FaultState) 'Investigar caminhos e rede CSV; acesso redirecionado pode ocorrer durante manutenção.' 'Investigate CSV storage paths and networking; redirected access can occur during maintenance.' 'S12'}}
    foreach($smb in $d.SmbSettings){if($smb.Component -eq 'Server' -and $smb.EnableSMB1Protocol -eq $true){Add-HvFinding $Report Warning 'HV020' $smb.Host 'SMB Server' 'EnableSMB1Protocol=True' 'Revisar dependências legadas e plano de desativação do SMB1 com a equipe responsável.' 'Review legacy dependencies and an SMB1 retirement plan with the owning team.' 'S13'}}
    foreach($eventGroup in @($d.Events | Group-Object Host)){
        $critical=@($eventGroup.Group | Where-Object {$_.Level -eq 1}).Count
        $errors=@($eventGroup.Group | Where-Object {$_.Level -eq 2}).Count
        if($critical -or $errors){Add-HvFinding $Report Info 'HV021' $eventGroup.Name 'Event logs' ("Critical=$critical; Error=$errors") 'Revisar eventos por horário/provedor e correlacionar com a carga. Contagens não provam falha atual.' 'Review events by time/provider and correlate with workload. Counts do not prove a current failure.' 'S14'}
    }
    $bad=@($d.Coverage | Where-Object {$_.Status -in @('Failed','TimedOut','Partial','Truncated','Unsupported')})
    foreach($group in @($bad | Group-Object Host)){Add-HvFinding $Report Warning 'HV022' $group.Name 'Collection coverage' ("IncompleteProbes="+$group.Count) 'Examinar cobertura e erros. Não interpretar tabelas vazias ou dados ausentes como ambiente saudável.' 'Review coverage and errors. Do not interpret empty tables or missing data as healthy infrastructure.'}
    $hostNames=@(@($d.Hosts | ForEach-Object {$_.Host})+@($d.Coverage | Where-Object {$_.Dataset -eq 'VMs'} | ForEach-Object {$_.Host}) | Sort-Object -Unique)
    foreach($nodeName in $hostNames){
        $hostRows=@($d.Hosts | Where-Object {$_.Host -eq $nodeName});$hostRow=$null;if($hostRows.Count){$hostRow=$hostRows[0]}
        $vms=@($d.VMs | Where-Object {$_.Host -eq $nodeName});$running=@($vms | Where-Object {$_.State -eq 'Running'})
        $inventory=@($d.Coverage | Where-Object {$_.Host -eq $nodeName -and $_.Dataset -eq 'VMs'} | Select-Object -Last 1);$inventoryStatus='Unknown';if($inventory.Count){$inventoryStatus=$inventory[0].Status}
        $known=$inventoryStatus -in @('Collected','Empty');$lp=Get-HvField $hostRow LogicalProcessors
        $configured=$null;$runCpu=$null;$assigned=$null;$startup=$null;$ratio=$null
        if($known){if($vms.Count){$configured=Get-HvNumberSum $vms ProcessorCount;$startup=Get-HvNumberSum $vms MemoryStartup}else{$configured=0;$startup=0};if($running.Count){$runCpu=Get-HvNumberSum $running ProcessorCount;$assigned=Get-HvNumberSum $running MemoryAssigned}else{$runCpu=0;$assigned=0}}
        if($lp -gt 0 -and $null -ne $runCpu){$ratio=[Math]::Round($runCpu/$lp,2)}
        if($null -ne $ratio -and $ratio -gt $p.VcpuRatioWarning){Add-HvFinding $Report Info 'HV023' $nodeName $nodeName ("RunningVcpuPerLogicalProcessor=$ratio") 'Razão configurada não mede contenção. Correlacionar CPU, tempo de espera e carga antes de redimensionar.' 'Configured ratio does not measure contention. Correlate CPU, wait time and workload before resizing.' 'S15'}
        $f=@($d.Findings | Where-Object {$_.Host -eq $nodeName})
        Add-HvRows $Report HostSummary @([pscustomobject]@{Host=$nodeName;CollectedVMRows=$vms.Count;RunningVMRows=$(if($known){$running.Count}else{$null});LogicalProcessors=$lp;ConfiguredVcpu=$configured;RunningVcpu=$runCpu;RunningVcpuPerLogicalProcessor=$ratio;AssignedMemoryBytes=$assigned;ConfiguredStartupMemoryBytes=$startup;HostFreeMemoryPercent=Get-HvField $hostRow MemoryFreePercent;OldCheckpointRows=@($d.Checkpoints | Where-Object {$_.Host -eq $nodeName -and $null -ne $_.AgeDays -and $_.AgeDays -gt $p.CheckpointWarningDays}).Count;WarningFindings=@($f | Where-Object {$_.Severity -eq 'Warning'}).Count;CriticalFindings=@($f | Where-Object {$_.Severity -eq 'Critical'}).Count;CollectionProblems=@($bad | Where-Object {$_.Host -eq $nodeName}).Count;InventoryStatus=$inventoryStatus;Observation=Get-HvText $Report 'Fotografia da coleta; totais podem mudar durante Live Migration. Zero linhas coletadas não prova ausência.' 'Point-in-time collection; totals may change during Live Migration. Zero collected rows does not prove absence.'})
    }
    # Deduplicate observed VHD paths per host; do not sum shared cluster storage across hosts.
    foreach($hostRow in $d.Hosts){
        $seen=@{};$vhds=@($d.VHDChains | Where-Object {$_.Host -eq $hostRow.Host -and $_.ReadStatus -eq 'Read'} | Where-Object {$key=$_.Path.ToLowerInvariant();if($seen.ContainsKey($key)){$false}else{$seen[$key]=$true;$true}})
        $volumes=@($d.Volumes | Where-Object {$_.Host -eq $hostRow.Host -and $_.SizeBytes -gt 0})
        foreach($volume in $volumes){
            $prefixes=@($volume.Path);if($volume.DriveLetter){$prefixes+=([string]$volume.DriveLetter+':\')}
            foreach($csv in $d.ClusterVolumes){if($csv.PartitionName -and $volume.Path -and $csv.PartitionName.TrimEnd('\') -eq $volume.Path.TrimEnd('\')){$prefixes+=($csv.Path.TrimEnd('\')+'\')}}
            $matched=@($vhds | Where-Object {$path=$_.Path;$ok=$false;foreach($prefix in $prefixes){if($prefix -and $path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){$ok=$true}};$ok})
            if($matched.Count){$file=Get-HvNumberSum $matched FileSizeBytes;$virtual=Get-HvNumberSum $matched VirtualSizeBytes;$growth=$null;if($null -ne $file -and $null -ne $virtual){$growth=[Math]::Max([double]0,[double]($virtual-$file))}
                Add-HvRows $Report StorageCapacity @([pscustomobject]@{Host=$hostRow.Host;VolumePath=$volume.Path;VolumeSizeBytes=$volume.SizeBytes;VolumeFreeBytes=$volume.FreeBytes;UniqueVhdPaths=$matched.Count;ObservedFileSizeBytes=$file;ObservedVirtualSizeBytes=$virtual;NominalGrowthBytes=$growth;Observation=Get-HvText $Report 'Soma observada por caminho, incluindo pais. Não representa alocação física, deduplicação, reserva, thin provisioning ou crescimento previsto; não somar entre hosts. SMB/caminhos não correlacionados ficam fora.' 'Observed path-based sum, including parents. This is not physical allocation, deduplication, reservation, thin provisioning or predicted growth; do not sum across hosts. Unmatched/SMB paths are excluded.'})
            }
        }
    }
    $Report.EndedUtc=[datetime]::UtcNow.ToString('o');$Report.Status='Completed'
    if($bad.Count -or @($d.Findings | Where-Object {$_.Severity -in @('Critical','Warning')}).Count){$Report.Status='CompletedWithIssues'}
    if($Report.Synthetic){$Report.Status='SyntheticExample'}
}

function Write-HvHtml {
    param([string]$Path,$Report,[int]$MaxHtmlRows=500)
    function Convert-HvHtmlText {param($v);[Net.WebUtility]::HtmlEncode([string]$v)}
    function Get-HvHtmlText {param([string]$pt,[string]$en);Get-HvText $Report $pt $en}
    $en=$Report.Language -eq 'en-US';$nonce=[guid]::NewGuid().ToString('N')
    $html=New-Object Text.StringBuilder
    $critical=@($Report.Datasets.Findings | Where-Object {$_.Severity -eq 'Critical'}).Count
    $warnings=@($Report.Datasets.Findings | Where-Object {$_.Severity -eq 'Warning'}).Count
    $problems=@($Report.Datasets.Coverage | Where-Object {$_.Status -in @('Failed','TimedOut','Truncated','Partial','Unsupported')}).Count
    $schemas=Get-HvSchemas;$labels=Get-HvLabels
    [void]$html.Append(@"
<!doctype html><html lang="$(Convert-HvHtmlText $Report.Language)"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'nonce-$nonce'; script-src 'nonce-$nonce'; img-src data:; base-uri 'none'; form-action 'none'">
<title>Hyper-V Health Report · FMODEL</title><style nonce="$nonce">
:root{--ink:#14293e;--muted:#4e6275;--blue:#006bb0;--line:#d6e1ea;--bg:#f3f7fa;--red:#a92327;--amber:#815600;--green:#20623a}*{box-sizing:border-box}body{margin:0;color:var(--ink);background:var(--bg);font:15px/1.55 system-ui,Segoe UI,Arial,sans-serif}a{color:#005a99;text-underline-offset:3px}header{background:linear-gradient(115deg,#092b49,#005d9d);color:white;padding:32px max(22px,calc((100vw - 1500px)/2))}header a{color:#d7eeff}.brand{letter-spacing:.16em;font-weight:800;font-size:17px}.eyebrow{font-size:12px;letter-spacing:.12em;text-transform:uppercase}h1{font-size:clamp(27px,4vw,42px);line-height:1.2;margin:12px 0}h2{font-size:23px}p{margin:.65em 0}.sub{max-width:1000px;opacity:.95}.meta{font-size:13px;color:#dfedf8}.wrap{max-width:1548px;margin:auto;padding:24px}.notice{border-left:5px solid var(--blue);background:#e6f2fb;padding:16px 20px;margin-bottom:20px}.synthetic{background:#fff2cf;border-color:#ac6c00}.cards{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:14px;margin:20px 0}.card{background:white;border:1px solid var(--line);border-radius:12px;padding:18px}.card strong{font-size:32px;display:block;line-height:1.2}.card span{display:block;color:var(--muted);font-size:13px;margin-top:8px}.red strong{color:var(--red)}.amber strong{color:var(--amber)}.tools{display:flex;flex-wrap:wrap;align-items:end;gap:12px;padding:16px;background:white;border:1px solid var(--line);border-radius:12px;margin:20px 0}label{font-size:13px;color:var(--muted);display:block}input,select,button{font:inherit;padding:10px 12px;border:1px solid #9eb2c3;border-radius:6px;background:white;color:var(--ink)}input{max-width:100%;width:340px}button{cursor:pointer}button:hover{background:#e8f3fa}.counts{color:var(--muted);font-size:13px}.legend{color:var(--muted);font-size:13px}details{background:white;border:1px solid var(--line);border-radius:12px;margin:16px 0;overflow:hidden}summary{cursor:pointer;padding:17px 20px;font-weight:700;background:#f9fcff}summary .num{float:right;font-size:12px;font-weight:400;color:var(--muted);margin-left:10px}.section-body{padding:0 18px 18px}.table-wrap{overflow:auto;max-height:660px;border:1px solid var(--line);margin-top:12px}table{border-collapse:separate;border-spacing:0;width:100%;font-size:13px}th,td{text-align:left;vertical-align:top;border-bottom:1px solid var(--line);padding:10px 12px;min-width:130px;max-width:440px;overflow-wrap:anywhere;white-space:pre-wrap}th{background:#eaf1f7;position:sticky;top:0;z-index:1;font-weight:650}td{line-height:1.5}tbody tr:nth-child(even){background:#f8fbfd}.badge{display:inline-block;border-radius:5px;padding:2px 7px;font-size:12px;font-weight:650;background:#e5edf4}.critical,.failed,.timedout{color:#861619;background:#ffeaeb}.warning,.partial,.truncated,.unsupported{color:#6c4700;background:#fff2cf}.collected{color:var(--green);background:#e4f5eb}.unknown{color:#677b8b}nav{display:flex;gap:8px;flex-wrap:wrap;margin:14px 0}nav a{font-size:13px;background:white;padding:6px 10px;border:1px solid var(--line);border-radius:20px}.mini{font-size:12px;color:var(--muted)}.empty{padding:14px 0;color:var(--muted)}footer{padding:24px;border-top:1px solid var(--line);font-size:13px}.section-search{width:260px;margin-left:10px}.statline{display:flex;gap:20px;flex-wrap:wrap}.statline div{min-width:180px}.sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0)}[hidden]{display:none!important}@media(max-width:950px){.cards{grid-template-columns:repeat(3,1fr)}}@media(max-width:540px){.wrap{padding:12px}header{padding:24px 16px}.cards{grid-template-columns:repeat(2,1fr);gap:8px}.card{padding:12px}.card strong{font-size:26px}.tools>*{max-width:100%}input{width:100%}.section-search{margin:10px 0 0;width:100%}summary{padding:14px}.section-body{padding:0 10px 12px}th,td{min-width:120px}.table-wrap{max-height:520px}summary .num{float:none;display:block;margin:4px 0 0}}@media print{header{background:white;color:#14293e}.tools,nav,.section-search{display:none}.table-wrap{max-height:none;overflow:visible}details{break-inside:avoid}.cards{grid-template-columns:repeat(3,1fr)}body{background:white}.meta{color:#14293e}}
</style></head><body><header><div class="brand">FMODEL <span class="eyebrow">· IT infrastructure</span></div><h1>Hyper-V Health Report</h1><p class="sub">$(Get-HvHtmlText 'Inventário, capacidade e evidências para decisões melhores.' 'Inventory, capacity and evidence for better decisions.')</p><div class="meta">v$(Convert-HvHtmlText $Report.Version) · $(Convert-HvHtmlText $Report.StartedUtc) UTC · $(Get-HvHtmlText 'Situação da coleta' 'Collection status'): $(Convert-HvHtmlText $Report.Status)</div></header><main class="wrap">
"@)
    if($Report.Synthetic){[void]$html.Append('<div class="notice synthetic"><strong>'+(Get-HvHtmlText 'EXEMPLO FICTÍCIO — não representa um ambiente real.' 'SYNTHETIC EXAMPLE — this is not a real environment.')+'</strong></div>')}
    [void]$html.Append('<div class="notice"><strong>'+(Get-HvHtmlText 'Leia o resumo e confira a cobertura.' 'Read the summary and check coverage.')+'</strong><p>'+(Get-HvHtmlText 'Este relatório é uma fotografia de leitura. Achados pedem revisão; ausência de alertas não certifica saúde, segurança, backup ou disponibilidade. Nenhuma correção foi aplicada.' 'This is a read-only snapshot. Findings require review; no alerts does not certify health, security, backup or availability. No remediation was applied.')+'</p></div><div class="cards">')
    $metrics=@(
        @($Report.Datasets.Hosts.Count,(Get-HvHtmlText 'Hosts com dados básicos' 'Hosts with basic data'),''),
        @($Report.Datasets.VMs.Count,(Get-HvHtmlText 'Registros de VMs coletados' 'Collected VM records'),''),
        @(@($Report.Datasets.VMs | Where-Object {$_.State -eq 'Running'}).Count,(Get-HvHtmlText 'Registros em execução' 'Running records'),''),
        @($critical,(Get-HvHtmlText 'Achados críticos' 'Critical findings'),'red'),
        @($warnings,(Get-HvHtmlText 'Avisos para revisar' 'Warnings to review'),'amber'),
        @($problems,(Get-HvHtmlText 'Sondagens incompletas' 'Incomplete probes'),'amber')
    )
    foreach($m in $metrics){[void]$html.Append('<div class="card '+$m[2]+'"><strong>'+[string]$m[0]+'</strong><span>'+(Convert-HvHtmlText $m[1])+'</span></div>')}
    [void]$html.Append('</div><p class="legend">'+(Get-HvHtmlText 'Contagens são registros observados, não totais garantidos do ambiente. — = desconhecido/não informado. Collected = consulta executada; não significa saudável. Consulte Coverage e Errors.' 'Counts are observed records, not guaranteed environment totals. — = unknown/not reported. Collected means the query ran; it does not mean healthy. Review Coverage and Errors.')+'</p>')
    [void]$html.Append('<div class="tools"><div><label for="global-search">'+(Get-HvHtmlText 'Buscar em todas as tabelas exibidas' 'Search all displayed tables')+'</label><input id="global-search" type="search" placeholder="'+(Get-HvHtmlText 'Host, VM, caminho, evento...' 'Host, VM, path, event...')+'"></div><div><label for="severity">'+(Get-HvHtmlText 'Severidade dos achados' 'Finding severity')+'</label><select id="severity"><option value="">'+(Get-HvHtmlText 'Todas' 'All')+'</option><option>Critical</option><option>Warning</option><option>Info</option></select></div><button id="expand" type="button">'+(Get-HvHtmlText 'Expandir tabelas' 'Expand tables')+'</button><button id="collapse" type="button">'+(Get-HvHtmlText 'Recolher tabelas' 'Collapse tables')+'</button><button id="print" type="button">'+(Get-HvHtmlText 'Imprimir / PDF' 'Print / PDF')+'</button><span id="search-status" class="counts" role="status" aria-live="polite"></span></div><noscript><p>'+(Get-HvHtmlText 'A busca requer JavaScript. Tabelas e links CSV continuam disponíveis.' 'Search requires JavaScript. Tables and CSV links remain available.')+'</p></noscript><nav aria-label="'+(Get-HvHtmlText 'Ir para seção' 'Jump to section')+'">')
    foreach($key in @('HostSummary','Findings','Coverage','Errors','VMs','Volumes','VHDChains','Checkpoints','Replication','Cluster','Events')){$label=($labels[$key] -split ' / ')[$([int]$en)];[void]$html.Append('<a href="#section-'+$key+'">'+(Convert-HvHtmlText $label)+'</a>')}
    [void]$html.Append('</nav>')
    $order=@('HostSummary','Findings','Coverage','Errors')+@($schemas.Keys | Where-Object {$_ -notin @('HostSummary','Findings','Coverage','Errors')})
    $columnLabels=@{Host=@('Host','Host');VMName=@('Máquina virtual','Virtual machine');Severity=@('Severidade','Severity');RuleId=@('Regra','Rule');Target=@('Alvo','Target');Evidence=@('Evidência','Evidence');Recommendation=@('Recomendação','Recommendation');Status=@('Situação','Status');State=@('Estado','State');Rows=@('Registros','Records');Dataset=@('Conjunto','Dataset');FreePercent=@('Livre (%)','Free (%)');MemoryFreePercent=@('Memória livre (%)','Memory free (%)');CollectedVMRows=@('VMs coletadas','VM records');RunningVMRows=@('VMs em execução','Running VM records');InventoryStatus=@('Cobertura das VMs','VM coverage');Observation=@('Como interpretar','Interpretation');CollectionProblems=@('Sondagens incompletas','Incomplete probes');WarningFindings=@('Avisos','Warnings');CriticalFindings=@('Críticos','Critical findings');DurationSeconds=@('Duração (s)','Duration (s)');Detail=@('Detalhes','Details');Message=@('Mensagem','Message');AgeDays=@('Idade (dias)','Age (days)');Path=@('Caminho','Path');Name=@('Nome','Name');ReadStatus=@('Leitura','Read status')}
    foreach($key in $order){
        $rows=$Report.Datasets[$key];$label=($labels[$key] -split ' / ')[$([int]$en)];$count=$rows.Count;$shown=[Math]::Min($count,$MaxHtmlRows);$open='';if($key -in @('HostSummary','Findings','Coverage','Errors')){$open=' open'}
        [void]$html.Append('<details id="section-'+$key+'"'+$open+'><summary>'+(Convert-HvHtmlText $label)+'<span class="num">'+$count+' '+(Get-HvHtmlText 'registros' 'records')+'</span></summary><div class="section-body"><p class="mini"><a download href="csv/'+$key+'.csv">'+(Get-HvHtmlText 'Baixar CSV completo deste conjunto' 'Download the full CSV for this dataset')+'</a> · '+$key+'.csv</p>')
        if($count -eq 0){[void]$html.Append('<p class="empty">'+(Get-HvHtmlText 'Nenhum registro exportado. Consulte a cobertura para distinguir ausência, inaplicabilidade e falha.' 'No exported records. Check coverage to distinguish absence, applicability and failure.')+'</p>')}
        else{
            [void]$html.Append('<label for="search-'+$key+'" class="sr-only">'+(Get-HvHtmlText 'Filtrar' 'Filter')+' '+(Convert-HvHtmlText $label)+'</label><input class="section-search" id="search-'+$key+'" type="search" data-table="'+$key+'" placeholder="'+(Get-HvHtmlText 'Buscar nesta tabela' 'Search this table')+'"><span class="counts table-count" data-for="'+$key+'">'+$shown+'/'+$count+'</span>')
            if($count -gt $shown){[void]$html.Append('<p class="notice">'+(Get-HvHtmlText "HTML limitado a $shown de $count registros. A busca alcança somente os registros exibidos; use o CSV para o conjunto exportado completo." "HTML is limited to $shown of $count records. Search covers displayed records only; use CSV for the full exported dataset.")+'</p>')}
            [void]$html.Append('<div class="table-wrap" tabindex="0" role="region" aria-label="'+(Convert-HvHtmlText $label)+'"><table id="table-'+$key+'"><thead><tr>')
            $columns=$schemas[$key] -split ','
            foreach($col in $columns){$head=$col;if($columnLabels.ContainsKey($col)){$head=$columnLabels[$col][[int]$en]};[void]$html.Append('<th scope="col" title="'+(Convert-HvHtmlText $col)+'">'+(Convert-HvHtmlText $head)+'</th>')}
            [void]$html.Append('</tr></thead><tbody>')
            foreach($row in @($rows | Select-Object -First $shown)){
                $severity=[string](Get-HvField $row Severity);[void]$html.Append('<tr data-severity="'+(Convert-HvHtmlText $severity)+'">')
                foreach($col in $columns){
                    $value=Get-HvField $row $col;$display=Convert-HvScalar $value
                    if($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$display)){$cell='<span class="unknown" title="'+(Get-HvHtmlText 'Desconhecido ou não informado' 'Unknown or not reported')+'">—</span>'}
                    elseif($value -is [bool]){$cell=Convert-HvHtmlText $(if($value){Get-HvHtmlText 'Sim' 'Yes'}else{Get-HvHtmlText 'Não' 'No'})}
                    elseif($col -in @('Severity','Status','State','ReadStatus','InventoryStatus','HealthStatus')){
                        $class='';if([string]$display -in @('Critical','Warning','Failed','TimedOut','Partial','Truncated','Unsupported','Collected')){$class=([string]$display).ToLowerInvariant()}
                        $cell='<span class="badge '+$class+'">'+(Convert-HvHtmlText $display)+'</span>'
                    }elseif($col -match 'Bytes$|^MemoryAssigned$|^MemoryDemand$|^MemoryStartup$|^Startup$|^Minimum$|^Maximum$' -and $value -is [ValueType] -and $col -notmatch 'Percent'){
                        $cell=(Convert-HvHtmlText ([Math]::Round([double]$value/1GB,2).ToString('0.##',[Globalization.CultureInfo]::InvariantCulture)))+' GiB<br><span class="mini">'+(Convert-HvHtmlText $value)+' B</span>'
                    }else{$cell=Convert-HvHtmlText $display}
                    [void]$html.Append('<td>'+$cell+'</td>')
                }
                [void]$html.Append('</tr>')
            }
            [void]$html.Append('</tbody></table></div>')
        }
        [void]$html.Append('</div></details>')
    }
    $script=@'
"use strict";
const globalInput=document.getElementById("global-search"),severity=document.getElementById("severity"),sections=[...document.querySelectorAll("details")];
const normalize=s=>s.normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase();
function filter(){let visible=0,total=0;const global=normalize(globalInput.value),sev=severity.value;
 sections.forEach(section=>{const table=section.querySelector("table");if(!table)return;const local=normalize(section.querySelector(".section-search").value);let count=0;
 table.querySelectorAll("tbody tr").forEach(row=>{const text=normalize(row.textContent),hit=(!global||text.includes(global))&&(!local||text.includes(local))&&(table.id!=="table-Findings"||!sev||row.dataset.severity===sev);row.hidden=!hit;if(hit){count++;visible++;}total++;});
 section.querySelector(".table-count").textContent=count+" / "+table.tBodies[0].rows.length;if((global||local||(sev&&table.id==="table-Findings"))&&count)section.open=true;
 });document.getElementById("search-status").textContent=visible+" / "+total;}
globalInput.addEventListener("input",filter);severity.addEventListener("change",filter);document.querySelectorAll(".section-search").forEach(input=>input.addEventListener("input",filter));
document.getElementById("expand").addEventListener("click",()=>sections.forEach(s=>s.open=true));document.getElementById("collapse").addEventListener("click",()=>sections.forEach(s=>s.open=false));document.getElementById("print").addEventListener("click",()=>{sections.forEach(s=>s.open=true);window.print();});
document.querySelectorAll('nav a').forEach(a=>a.addEventListener("click",()=>{const target=document.getElementById(a.hash.slice(1));if(target)target.open=true;}));filter();
'@
    [void]$html.Append('</main><footer><strong>FMODEL - SERVICOS E CONSULTORIA EM TECNOLOGIA DA INFORMAÇÃO</strong><br>F. Model · <a href="mailto:fmodel@fmodel.com.br">fmodel@fmodel.com.br</a><p>'+(Get-HvHtmlText 'Relatório local. Preserve a pasta csv ao compartilhar o HTML. JSON guarda os valores originais; CSV contém proteção contra fórmulas. O manifesto detecta alterações, mas não é assinatura digital.' 'Local report. Keep the csv folder when sharing HTML. JSON preserves original values; CSV includes formula protection. The manifest detects changes but is not a digital signature.')+'</p><span class="mini">RunId: '+(Convert-HvHtmlText $Report.RunId)+'</span></footer><script nonce="'+$nonce+'">'+$script+'</script></body></html>')
    Write-HvUtf8 $Path $html.ToString()
}

function Add-HvExampleData {
    param($Report)
    $Report.Synthetic=$true
    $first='HV-LAB01';$second='HV-LAB02';$id1='11111111-1111-4111-8111-111111111111';$id2='22222222-2222-4222-8222-222222222222'
    Add-HvRows $Report Hosts @(
        [pscustomobject]@{Host=$first;CollectedUtc=$Report.StartedUtc;Manufacturer='Fictional vendor';Model='Training server';Domain='lab.example';OSCaption='Microsoft Windows Server 2025 Datacenter';OSVersion='10.0';Build='26100';LastBootUtc='2026-11-10T08:00:00Z';UptimeHours=80;MemoryTotalBytes=128GB;MemoryFreeBytes=32GB;MemoryFreePercent=25;LogicalProcessors=32;PhysicalProcessors=2;HypervisorPresent=$true},
        [pscustomobject]@{Host=$second;CollectedUtc=$Report.StartedUtc;Manufacturer='Fictional vendor';Model='Training server';Domain='lab.example';OSCaption='Microsoft Windows Server 2022 Datacenter';OSVersion='10.0';Build='20348';LastBootUtc='2026-11-01T08:00:00Z';UptimeHours=300;MemoryTotalBytes=64GB;MemoryFreeBytes=4GB;MemoryFreePercent=6.25;LogicalProcessors=16;PhysicalProcessors=1;HypervisorPresent=$true})
    Add-HvRows $Report VMs @(
        [pscustomobject]@{Host=$first;VMId=$id1;VMName='APP-LAB01';Generation=2;Version='12.0';State='Running';Status='Operating normally';UptimeHours=48;CPUUsage=12;ProcessorCount=4;MemoryAssigned=8GB;MemoryDemand=6GB;MemoryStatus='OK';DynamicMemoryEnabled=$true;MemoryStartup=4GB;CheckpointType='Production';AutomaticCheckpointsEnabled=$false;ReplicationState='Replicating';ReplicationHealth='Normal';IntegrationServicesState='UpToDate';ResourceMeteringEnabled=$true;IsClustered=$true;ConfigurationLocation='C:\ClusterStorage\Volume1\VMs\APP-LAB01';Notes='Synthetic application VM'},
        [pscustomobject]@{Host=$second;VMId=$id2;VMName='DB-LAB01';Generation=2;Version='10.0';State='PausedCritical';Status='Synthetic storage issue; verify in lab';CPUUsage=0;ProcessorCount=8;MemoryAssigned=16GB;MemoryDemand=16GB;MemoryStatus='OK';DynamicMemoryEnabled=$false;MemoryStartup=16GB;CheckpointType='Standard';ReplicationState='Replicating';ReplicationHealth='Warning';ResourceMeteringEnabled=$false;IsClustered=$true;ConfigurationLocation='D:\VMs\DB-LAB01'})
    Add-HvRows $Report Volumes @(
        [pscustomobject]@{Host=$first;Path='\\?\Volume{aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa}\';UniqueId='LAB-VOL1';DriveLetter='C';FileSystemLabel='OS';FileSystemType='ReFS';HealthStatus='Healthy';OperationalStatus='OK';DriveType='Fixed';SizeBytes=1TB;FreeBytes=400GB;FreePercent=39.06},
        [pscustomobject]@{Host=$second;Path='\\?\Volume{bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb}\';UniqueId='LAB-VOL2';DriveLetter='D';FileSystemLabel='VM data';FileSystemType='ReFS';HealthStatus='Healthy';OperationalStatus='OK';DriveType='Fixed';SizeBytes=1TB;FreeBytes=40GB;FreePercent=3.91})
    Add-HvRows $Report VHDChains @(
        [pscustomobject]@{Host=$first;VMId=$id1;VMName='APP-LAB01';RootPath='C:\VMs\APP-LAB01\os.vhdx';Depth=0;Path='C:\VMs\APP-LAB01\os.vhdx';VhdFormat='VHDX';VhdType='Dynamic';FileSizeBytes=30GB;VirtualSizeBytes=120GB;FragmentationPercentage=2;ReadStatus='Read'},
        [pscustomobject]@{Host=$second;VMId=$id2;VMName='DB-LAB01';RootPath='D:\VMs\DB-LAB01\data.avhdx';Depth=0;Path='D:\VMs\DB-LAB01\data.avhdx';ParentPath='D:\VMs\DB-LAB01\data.vhdx';VhdFormat='VHDX';VhdType='Differencing';FileSizeBytes=40GB;VirtualSizeBytes=400GB;ReadStatus='Read'},
        [pscustomobject]@{Host=$second;VMId=$id2;VMName='DB-LAB01';RootPath='D:\VMs\DB-LAB01\data.avhdx';Depth=1;Path='D:\VMs\DB-LAB01\data.vhdx';VhdFormat='VHDX';VhdType='Dynamic';FileSizeBytes=250GB;VirtualSizeBytes=400GB;ReadStatus='Read'})
    Add-HvRows $Report Checkpoints @([pscustomobject]@{Host=$second;VMId=$id2;VMName='DB-LAB01';Name='Before lab update';Id='33333333-3333-4333-8333-333333333333';CreationTimeUtc='2026-10-20T12:00:00Z';AgeDays=24;SnapshotType='Standard'})
    Add-HvRows $Report VMNetworkAdapters @(
        [pscustomobject]@{Host=$first;VMId=$id1;VMName='APP-LAB01';Name='Network Adapter';SwitchName='Production SET';Status='Ok';MacAddress='00155D010001';DynamicMacAddressEnabled=$true;IPAddresses='192.0.2.11';DhcpGuard='Off';RouterGuard='Off'},
        [pscustomobject]@{Host=$second;VMId=$id2;VMName='DB-LAB01';Name='Network Adapter';SwitchName='Production SET';Status='Ok';MacAddress='00155D020001';DynamicMacAddressEnabled=$true;IPAddresses='192.0.2.12'})
    Add-HvRows $Report VMVlans @([pscustomobject]@{Host=$first;VMId=$id1;VMName='APP-LAB01';AdapterName='Network Adapter';OperationMode='Access';AccessVlanId=120})
    Add-HvRows $Report IntegrationServices @([pscustomobject]@{Host=$first;VMId=$id1;VMName='APP-LAB01';Name='Heartbeat';Id='84EAAE65-2F2E-45F5-9BB5-0E857DC8EB47';Enabled=$true;PrimaryStatusDescription='OK';PrimaryOperationalStatus='Ok'})
    Add-HvRows $Report Replication @([pscustomobject]@{Host=$second;VMId=$id2;VMName='DB-LAB01';State='Replicating';Health='Warning';Mode='Primary';PrimaryServer='HV-LAB02';ReplicaServer='HV-DR01';AuthenticationType='Kerberos';FrequencySec=300;LastReplicationTimeUtc='2026-11-13T17:50:00Z'})
    Add-HvRows $Report VMFirmware @([pscustomobject]@{Host=$first;VMId=$id1;VMName='APP-LAB01';SecureBoot='On';SecureBootTemplate='MicrosoftWindows'},[pscustomobject]@{Host=$second;VMId=$id2;VMName='DB-LAB01';SecureBoot='Off'})
    Add-HvRows $Report VMSecurity @([pscustomobject]@{Host=$first;VMId=$id1;VMName='APP-LAB01';TpmEnabled=$true;Shielded=$false;EncryptStateAndVmMigrationTraffic=$true})
    Add-HvRows $Report Services @([pscustomobject]@{Host=$first;Name='vmms';State='Running';StartMode='Auto';Status='OK'},[pscustomobject]@{Host=$second;Name='vmms';State='Running';StartMode='Auto';Status='OK'})
    Add-HvRows $Report Switches @([pscustomobject]@{Host=$first;Name='Production SET';SwitchType='External';AllowManagementOS=$true;EmbeddedTeamingEnabled=$true;IovEnabled=$false})
    Add-HvRows $Report RebootSignals @([pscustomobject]@{Host=$first;Signal='PendingFileRenameOperations';Present=$true;Detail='Example only: file-operation queue, not a confirmed reboot requirement.'})
    Add-HvRows $Report Cluster @([pscustomobject]@{Host=$first;Name='HV-LAB-CLUSTER';Domain='lab.example';ClusterFunctionalLevel=12;DynamicQuorum=1})
    Add-HvRows $Report ClusterNodes @([pscustomobject]@{Host=$first;Name=$first;State='Up';NodeWeight=1;DynamicWeight=1},[pscustomobject]@{Host=$first;Name=$second;State='Up';NodeWeight=1;DynamicWeight=1})
    Add-HvRows $Report ClusterVolumes @([pscustomobject]@{Host=$first;Name='Cluster Disk 1';OwnerNode=$first;State='Online';Path='C:\ClusterStorage\Volume1';PartitionName='\\?\Volume{cccccccc-cccc-cccc-cccc-cccccccccccc}\';FileSystem='ReFS';SizeBytes=2TB;FreeBytes=1TB;FreePercent=50;RedirectedAccess=$false;FaultState='NoFaults'})
    Add-HvRows $Report Events @([pscustomobject]@{Host=$second;LogName='Microsoft-Windows-Hyper-V-VMMS-Admin';TimeCreatedUtc='2026-11-13T18:00:00Z';EventId=16060;Level=2;Provider='Microsoft-Windows-Hyper-V-VMMS';RecordId=1;Message='Synthetic event for reading practice. Do not diagnose a real host from this example.'})
    Add-HvRows $Report EventCoverage @([pscustomobject]@{Host=$second;LogName='Microsoft-Windows-Hyper-V-VMMS-Admin';StartUtc='2026-11-06T18:00:00Z';EndUtc='2026-11-13T18:00:00Z';Status='Collected';Rows=1;Truncated=$false;Limit=200})
    foreach($key in (Get-HvSchemas).Keys){if($key -in @('Coverage','Findings','Errors','HostSummary','StorageCapacity')){continue};foreach($nodeName in @($first,$second)){
        $n=@($Report.Datasets[$key] | Where-Object {$_.Host -eq $nodeName}).Count;$state='NotRequested';if($n){$state='Collected'}
        Add-HvRows $Report Coverage @([pscustomobject]@{Host=$nodeName;Dataset=$key;Scope='Synthetic example';Status=$state;Rows=$n;StartedUtc=$Report.StartedUtc;EndedUtc=$Report.StartedUtc;DurationSeconds=0;Detail='Synthetic records, not a query result.'})
    }}
}

function Add-HvWorkerResult {
    param($Report,$Result,[string]$Target,[string]$Mode)
    foreach($packet in $Result.Packets){Add-HvPacket $Report $packet}
    if($Result.TimedOut -or $Result.Error -or $Result.Packets.Count -eq 0){
        $status='Failed';$message=[string]$Result.Error;if($Result.TimedOut){$status='TimedOut';$message='Host/cluster worker exceeded its time budget. Completed probe packets were preserved; remaining probes are unknown.'};if(-not $message){$message='No valid worker packets received.'}
        $dataset='VMs';if($Mode -eq 'Discover'){$dataset='ClusterNodes'}
        $node=$Target;if($Result.Packets.Count){$node=[string]$Result.Packets[0].Host}
        Add-HvPacket $Report ([pscustomobject]@{Dataset=$dataset;Host=$node;Scope='Worker completion';Status=$status;Rows=@();StartedUtc=$null;EndedUtc=[datetime]::UtcNow.ToString('o');DurationSeconds=$null;Detail=$message;Error=$message;ErrorType='WorkerFailure'})
    }
}
function Invoke-HvMain {
    param([hashtable]$Arguments,[string]$ParameterSet)
    $lang=$Arguments.Language
    if($ParameterSet -eq 'Offline'){
        $report=Read-HvOfflineReport $Arguments.InputJson $lang
        return Write-HvDeliverables $report $Arguments.OutputPath $Arguments.MaxHtmlRows -CreateZip:$Arguments.CreateZip
    }
    $report=New-HvReport $lang
    foreach($key in @('VolumeWarningPercent','VolumeCriticalPercent','MemoryWarningPercent','MemoryCriticalPercent','VcpuRatioWarning','CheckpointWarningDays','EventDays','MaxEventsPerLog','MaxVMsPerHost','MaxRowsPerProbe','MaxVhdDepth','HostTimeoutSeconds','MaxHosts','SkipEvents','IncludeBpaResults')){$report.Parameters[$key]=$Arguments[$key]}
    if($Arguments.VolumeCriticalPercent -ge $Arguments.VolumeWarningPercent -or $Arguments.MemoryCriticalPercent -ge $Arguments.MemoryWarningPercent){throw 'Critical free-space/memory thresholds must be lower than warning thresholds.'}
    if($ParameterSet -eq 'Example'){Add-HvExampleData $report}
    else{
        if([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or -not [Environment]::Is64BitProcess -or $PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'Live collection requires Windows PowerShell 5.1 x64 (powershell.exe). PowerShell 7 is supported for offline rendering/examples/tests.'}
        $options=@{MaxRowsPerProbe=$Arguments.MaxRowsPerProbe;MaxVMsPerHost=$Arguments.MaxVMsPerHost;MaxVhdDepth=$Arguments.MaxVhdDepth;SkipEvents=[bool]$Arguments.SkipEvents;EventDays=$Arguments.EventDays;MaxEventsPerLog=$Arguments.MaxEventsPerLog;IncludeBpa=[bool]$Arguments.IncludeBpaResults}
        $targets=@($Arguments.ComputerName)
        if($ParameterSet -eq 'Cluster'){
            Assert-HvTarget $Arguments.ClusterNode
            Write-Verbose ('Discovering cluster from member '+$Arguments.ClusterNode)
            $discovery=Invoke-HvBoundedWorker $Arguments.ClusterNode $options Discover $Arguments.HostTimeoutSeconds $Arguments.Credential
            Add-HvWorkerResult $report $discovery $Arguments.ClusterNode Discover
            $targets=@($report.Datasets.ClusterNodes | ForEach-Object {$_.Name} | Where-Object {$_} | Sort-Object -Unique)
            if($targets.Count -eq 0){Write-Warning 'No cluster nodes discovered. Review the generated coverage and errors.'}
        }else{
            foreach($key in @('Cluster','ClusterNodes','ClusterGroups','ClusterResources','ClusterVolumes','ClusterNetworks','ClusterQuorum')){Add-HvRows $report Coverage @([pscustomobject]@{Host='Collector';Dataset=$key;Scope='Cluster discovery';Status='NotRequested';Rows=0;Detail='Use -ClusterNode to discover and assess a cluster.'})}
        }
        if($targets.Count -gt $Arguments.MaxHosts){
            Add-HvPacket $report ([pscustomobject]@{Dataset='VMs';Host='Collector';Scope='Host selection';Status='Truncated';Rows=@();Detail="MaxHosts=$($Arguments.MaxHosts); additional hosts were not queried."})
            $targets=@($targets | Select-Object -First $Arguments.MaxHosts)
        }
        $targets=@($targets | Sort-Object -Unique)
        foreach($target in $targets){Assert-HvTarget $target}
        $report.Parameters['RequestedTargets']=$targets -join '; '
        $index=0
        foreach($target in $targets){
            $index++;Write-Progress -Activity 'Hyper-V Health Report' -Status "$index/$($targets.Count): $target" -PercentComplete (($index-1)*100.0/[Math]::Max(1,$targets.Count))
            $result=Invoke-HvBoundedWorker $target $options Collect $Arguments.HostTimeoutSeconds $Arguments.Credential
            Add-HvWorkerResult $report $result $target Collect
        }
        Write-Progress -Activity 'Hyper-V Health Report' -Completed
    }
    Invoke-HvAssessment $report
    Write-HvDeliverables $report $Arguments.OutputPath $Arguments.MaxHtmlRows -CreateZip:$Arguments.CreateZip
}
# Entrypoint: dot-sourcing loads functions for inspection/tests without collection.
if($MyInvocation.InvocationName -ne '.'){
    $arguments=@{}
    foreach($key in (Get-Command $PSCommandPath).Parameters.Keys){if(Get-Variable -Name $key -Scope Script -ErrorAction SilentlyContinue){$arguments[$key]=(Get-Variable -Name $key -Scope Script).Value}}
    $result=Invoke-HvMain $arguments $PSCmdlet.ParameterSetName
    $result
}
