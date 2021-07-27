$Global:BaseDir = "$env:ALLUSERSPROFILE\Kubernetes"
$Global:GithubSDNRepository = 'Microsoft/SDN'
$Global:GithubSDNBranch = 'master'
$Global:NetworkName = "cbr0"
$Global:NetworkMode = "l2bridge"
$Global:DockerImageTag = "1809"
$Global:Configuration = @{}
$Global:MasterUsername = "localadmin"
$Global:PauseImage = "mcr.microsoft.com/k8s/core/pause:1.2.0"
$Global:NanoserverImage = "mcr.microsoft.com/windows/nanoserver:1809"
$Global:ServercoreImage = "mcr.microsoft.com/windows/servercore:ltsc2019"
$Global:Cri = "dockerd"

function GetKubeConfig()
{
    return [io.Path]::Combine($Global:BaseDir, "config");
}

function KubeConfigExists()
{
    return Test-Path $(GetKubeConfig)
}

function DownloadKubeConfig($Master, $User=$Global:MasterUsername)
{
    $kc = GetKubeConfig
    Write-Host "Downloading Kubeconfig from ${Master}:~/.kube/config to $kc"
    scp ${User}@${Master}:~/.kube/config $kc
}

function GetLogDir()
{
    return [io.Path]::Combine($Global:BaseDir, "logs");
}

function GetUserDir()
{
    if ($env:HOMEDRIVE -and $env:HOMEPATH)
    {
        Join-Path $env:HOMEDRIVE $env:HOMEPATH
    }
    else
    {
        (Resolve-Path ~).Path
    }
}

function GetCniPath()
{
    return [io.Path]::Combine($Global:BaseDir, "cni");
}

function GetCniConfigPath()
{
    return [io.Path]::Combine($(GetCniPath), "config");
}

function GetKubeClusterConfig()
{
    return [io.Path]::Combine($Global:BaseDir, ".kubeclusterconfig")
}

function GetFlannelNetConf()
{
    return [io.Path]::Combine($Global:BaseDir, "net-conf.json")
}

function HasKubeClusterConfig()
{
    $kc = $(GetKubeClusterConfig)
    return (Test-Path $kc)
}

function WriteKubeClusterConfig()
{
    $Global:ClusterConfiguration | ConvertTo-Json -Depth 10 | Out-File -FilePath $(GetKubeClusterConfig) 
}

#  
# Reads Kube
#
#
function ReadKubeClusterConfig()
{
    if (HasKubeClusterConfig)
    {
        $Global:ClusterConfiguration = ConvertFrom-Json ((Get-Content $(GetKubeClusterConfig)) | out-string)
        LoadGlobals
    }
}

function InitHelper()
{
    LoadGlobals
    ValidateConfig
    CreateDirectory $(GetLogDir)
}

function LoadGlobals()
{
    $Global:BaseDir = $Global:ClusterConfiguration.Install.Destination
    $Global:MasterUsername = $Global:ClusterConfiguration.Kubernetes.ControlPlane.Username
    $Global:MasterIp = $Global:ClusterConfiguration.Kubernetes.ControlPlane.IpAddress
    $Global:Token = $Global:ClusterConfiguration.Kubernetes.ControlPlane.KubeadmToken
    $Global:CAHash = $Global:ClusterConfiguration.Kubernetes.ControlPlane.KubeadmCAHash
    $Global:PauseImage = $Global:ClusterConfiguration.Cri.Images.Pause
    $Global:NanoserverImage = $Global:ClusterConfiguration.Cri.Images.Nanoserver
    $Global:ServercoreImage = $Global:ClusterConfiguration.Cri.Images.ServerCore
    $Global:Cni = $Global:ClusterConfiguration.Cni.Name
    $Global:Release = $Global:ClusterConfiguration.Kubernetes.Source.Release
    $Global:InterfaceName = $Global:ClusterConfiguration.Cni.InterfaceName
    $Global:NetworkPlugin =$Global:ClusterConfiguration.Cni.Plugin.Name
    $Global:Cri = $Global:ClusterConfiguration.Cri.Name
    $Global:ClusterCIDR = $Global:ClusterConfiguration.Kubernetes.Network.ClusterCidr
    $Global:ServiceCIDR = $Global:ClusterConfiguration.Kubernetes.Network.ServiceCidr

    $Global:KubeproxyGates = $Global:ClusterConfiguration.Kubernetes.KubeProxy.Gates
    $Global:DsrEnabled = $false;
    if ($Global:ClusterConfiguration.Kubernetes.KubeProxy -and $Global:ClusterConfiguration.Kubernetes.KubeProxy.Gates -contains "WinDSR=true")
    {
        $Global:DsrEnabled = $true;
    }

    if ((Get-NetAdapter -InterfaceAlias "vEthernet ($Global:InterfaceName)" -ErrorAction SilentlyContinue))   
    {
        $Global:ManagementIp = Get-InterfaceIpAddress -InterfaceName "vEthernet ($Global:InterfaceName)"
        $Global:ManagementSubnet = Get-MgmtSubnet -InterfaceName "vEthernet ($Global:InterfaceName)"
    }
    elseif ((Get-NetAdapter -InterfaceAlias "$Global:InterfaceName" -ErrorAction SilentlyContinue))        
    {
        $Global:ManagementIp = Get-InterfaceIpAddress -InterfaceName "$Global:InterfaceName"
        $Global:ManagementSubnet = Get-MgmtSubnet -InterfaceName "$Global:InterfaceName"
    }
    else {
        throw "$Global:InterfaceName doesn't exist"
    }
}

function ValidateConfig()
{
    if ($Global:Cni -ne "flannel")
    {
        throw "$Global:Cni not yet supported"
    }
    
    if ($Global:NetworkPlugin -ne "vxlan" -and $Global:NetworkPlugin -ne "bridge")
    {
        throw "$Global:NetworkPlugin is not yet supported"
    }

    if ($Global:Cri -ne "dockerd")
    {
        throw "$Global:Cri is not yet supported"
    }
}

function PrintConfig()
{
    ######################################################################################################################

    Write-Host "############################################"
    Write-Host "User Input "
    Write-Host "Destination       : $Global:BaseDir"
    Write-Host "Master            : $Global:MasterIp"
    Write-Host "InterfaceName     : $Global:InterfaceName"
    Write-Host "Cri               : $Global:Cri"
    Write-Host "Cni               : $Global:Cni"
    Write-Host "NetworkPlugin     : $Global:NetworkPlugin" 
    Write-Host "Release           : $Global:Release"
    Write-Host "MasterIp          : $Global:MasterIp"
    Write-Host "ManagementIp      : $Global:ManagementIp"
    Write-Host "ManagementSubnet  : $Global:ManagementSubnet"
    Write-Host "############################################"

    ######################################################################################################################
}

###################################################################################################

function DownloadFile()
{
    param(
    [parameter(Mandatory = $true)] $Url,
    [parameter(Mandatory = $true)] $Destination,
    [switch] $Force
    )

    if (!$Force.IsPresent -and (Test-Path $Destination))
    {
        Write-Host "[DownloadFile] File $Destination already exists."
        return
    }

    $secureProtocols = @() 
    $insecureProtocols = @([System.Net.SecurityProtocolType]::SystemDefault, [System.Net.SecurityProtocolType]::Ssl3) 
    foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType])) 
    { 
        if ($insecureProtocols -notcontains $protocol) 
        { 
            $secureProtocols += $protocol 
        } 
    } 
    [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols
    
    try {
        (New-Object System.Net.WebClient).DownloadFile($Url,$Destination)
        Write-Host "Downloaded [$Url] => [$Destination]"
    } catch {
        Write-Error "Failed to download $Url"
        throw
    }
}

function CleanupOldNetwork($NetworkName, $ClearDocker = $true)
{
    $hnsNetwork = Get-HnsNetwork | ? Name -EQ $NetworkName.ToLower()

    if ($hnsNetwork)
    {
        if($ClearDocker) {
            # Cleanup all containers
            CleanupContainers
        }

        Write-Host "Cleaning up old HNS network found"
        Write-Host ($hnsNetwork | ConvertTo-Json -Depth 10) 
        Remove-HnsNetwork $hnsNetwork
    }
}

function CleanupPolicyList()
{
    $policyLists = Get-HnsPolicyList 
    if ($policyList)
    {
        $policyList | Remove-HnsPolicyList
    }
}

function WaitForNetwork($NetworkName, $waitTimeSeconds = 60)
{
    $startTime = Get-Date

    # Wait till the network is available
    while ($true)
    {
        $timeElapsed = $(Get-Date) - $startTime
        if ($($timeElapsed).TotalSeconds -ge $waitTimeSeconds)
        {
            throw "Fail to create the network[($NetworkName)] in $waitTimeSeconds seconds"
        }
        if ((Get-HnsNetwork | ? Name -EQ $NetworkName.ToLower()))
        {
            break;
        }
        Write-Host "Waiting for the Network ($NetworkName) to be created by flanneld"
        Start-Sleep 5
    }
}

function IsNodeRegistered()
{
    kubectl.exe get nodes/$($(hostname).ToLower())
    return (!$LASTEXITCODE)
}

function WaitForServiceRunningState($ServiceName, $TimeoutSeconds)
{
    $startTime = Get-Date
    while ($true)
    {
        Write-Host "Waiting for service [$ServiceName] to be running"
        $timeElapsed = $(Get-Date) - $startTime
        if ($($timeElapsed).TotalSeconds -ge $TimeoutSeconds)
        {
            throw "Service [$ServiceName] failed to stay in Running state in $TimeoutSeconds seconds"
        }
        if ((Get-Service $ServiceName).Status -eq "Running")
        {
            break;
        }
        Start-Service -Name $ServiceName -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep 1
    }
}


function DownloadCniBinaries($NetworkMode, $CniPath)
{
    Write-Host "Downloading CNI binaries for $NetworkMode to $CniPath"
    
    CreateDirectory $CniPath
    CreateDirectory $CniPath\config
    DownloadFlannelBinaries -Destination $Global:BaseDir
    DownloadFile -Url https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-windows-amd64-v0.8.2.tgz -Destination $Global:BaseDir/cni-plugins-windows-amd64-v0.8.2.tgz
    & cmd /c tar -zxvf $Global:BaseDir/cni-plugins-windows-amd64-v0.8.2.tgz -C $CniPath '2>&1'
    if (!$?) { Write-Warning "Error decompressing file, exiting."; exit; }
}

function DownloadFlannelBinaries()
{
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $Release = "0.11.0",
        [string] $Destination = "c:\flannel"
    )

    Write-Host "Downloading Flannel binaries"
    DownloadFile -Url  "https://github.com/coreos/flannel/releases/download/v${Release}/flanneld.exe" -Destination $Destination\flanneld.exe 
}

function GetKubeFlannelPath()
{
    return "c:\etc\kube-flannel"
}

function InstallFlannelD()
{
    param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string] $Destination = "c:\flannel",
    [Parameter(Mandatory = $true)][string] $InterfaceIpAddress
    )
    
    Write-Host "Installing FlannelD Service"
    $logDir = [io.Path]::Combine($(GetLogDir), "flanneld");
    CreateDirectory $logDir
    $log = [io.Path]::Combine($logDir, "flanneldsvc.log");

    DownloadFile -Url  "https://github.com/$Global:GithubSDNRepository/raw/$Global:GithubSDNBranch/Kubernetes/flannel/$Global:NetworkMode/net-conf.json" -Destination $(GetFlannelNetConf)
    CreateDirectory $(GetKubeFlannelPath)
    copy $Global:BaseDir\net-conf.json $(GetKubeFlannelPath)

    $flanneldArgs = @(
        "$Destination\flanneld.exe",
        "--kubeconfig-file=$(GetKubeConfig)",
        "--iface=$InterfaceIpAddress",
        "--ip-masq=1",
        "--kube-subnet-mgr=1"
    )

    $service = Get-Service FlannelD -ErrorAction SilentlyContinue
    if (!$service)
    {
        $nodeName = (hostname).ToLower()
        CreateService -ServiceName FlannelD -CommandLine $flanneldArgs `
            -DependsOn "kubelet" `
            -LogFile "$log" -EnvVaribles @{NODE_NAME = "$nodeName";}    
    }
}

function UnInstallFlannelD()
{
    RemoveService -ServiceName FlannelD
    Remove-Item $(GetKubeFlannelPath) -Force -Recurse -ErrorAction SilentlyContinue
}

function StartFlanneld()
{
    $service = Get-Service -Name FlannelD -ErrorAction SilentlyContinue
    if (!$service)
    {
        throw "FlannelD service not installed"
    }
    Start-Service FlannelD -ErrorAction Stop
    WaitForServiceRunningState -ServiceName FlannelD  -TimeoutSeconds 30
}

function GetSourceVip($NetworkName)
{
    $sourceVipJson = [io.Path]::Combine($Global:BaseDir,  "sourceVip.json")
    $sourceVipRequest = [io.Path]::Combine($Global:BaseDir,  "sourceVipRequest.json")

    $hnsNetwork = Get-HnsNetwork | ? Name -EQ $NetworkName.ToLower()
    $subnet = $hnsNetwork.Subnets[0].AddressPrefix

    $ipamConfig = @"
        {"cniVersion": "0.2.0", "name": "vxlan0", "ipam":{"type":"host-local","ranges":[[{"subnet":"$subnet"}]],"dataDir":"/var/lib/cni/networks"}}
"@

    $ipamConfig | Out-File $sourceVipRequest

    pushd  
    $env:CNI_COMMAND="ADD"
    $env:CNI_CONTAINERID="dummy"
    $env:CNI_NETNS="dummy"
    $env:CNI_IFNAME="dummy"
    $env:CNI_PATH=$(GetCniPath) #path to host-local.exe

    cd $env:CNI_PATH
    Get-Content $sourceVipRequest | .\host-local.exe | Out-File $sourceVipJson
    $sourceVipJSONData = Get-Content $sourceVipJson | ConvertFrom-Json 

    Remove-Item env:CNI_COMMAND
    Remove-Item env:CNI_CONTAINERID
    Remove-Item env:CNI_NETNS
    Remove-Item env:CNI_IFNAME
    Remove-Item env:CNI_PATH
    popd

    return $sourceVipJSONData.ip4.ip.Split("/")[0]
}

function Get-InterfaceIpAddress()
{
    Param (
        [Parameter(Mandatory=$false)] [String] $InterfaceName = "Ethernet"
    )
    return (Get-NetIPAddress -InterfaceAlias "$InterfaceName" -AddressFamily IPv4).IPAddress
}

function ConvertTo-DecimalIP
{
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [Net.IPAddress] $IPAddress
  )
  $i = 3; $DecimalIP = 0;
  $IPAddress.GetAddressBytes() | % {
    $DecimalIP += $_ * [Math]::Pow(256, $i); $i--
  }

  return [UInt32]$DecimalIP
}

function ConvertTo-DottedDecimalIP
{
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [Uint32] $IPAddress
  )

    $DottedIP = $(for ($i = 3; $i -gt -1; $i--)
    {
      $Remainder = $IPAddress % [Math]::Pow(256, $i)
      ($IPAddress - $Remainder) / [Math]::Pow(256, $i)
      $IPAddress = $Remainder
    })

    return [String]::Join(".", $DottedIP)
}

function ConvertTo-MaskLength
{
  param(
    [Parameter(Mandatory = $True, Position = 0)]
    [Net.IPAddress] $SubnetMask
  )
    $Bits = "$($SubnetMask.GetAddressBytes() | % {
      [Convert]::ToString($_, 2)
    } )" -replace "[\s0]"
    return $Bits.Length
}


function Get-MgmtSubnet
{
    Param (
        [Parameter(Mandatory=$false)] [String] $InterfaceName = "Ethernet"
    )
    $na = Get-NetAdapter -InterfaceAlias "$InterfaceName"  -ErrorAction Stop
    $addr = (Get-NetIPAddress -InterfaceAlias "$InterfaceName" -AddressFamily IPv4).IPAddress
    $naReg = Get-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($na.InterfaceGuid)"
    $mask = $naReg.GetValueNames() -like "*SubnetMask" | % { $naReg.GetValue($_) }
    $mgmtSubnet = (ConvertTo-DecimalIP $addr) -band (ConvertTo-DecimalIP $mask)
    $mgmtSubnet = ConvertTo-DottedDecimalIP $mgmtSubnet
    return "$mgmtSubnet/$(ConvertTo-MaskLength $mask)"
}

function CreateDirectory($Path)
{
    if (!(Test-Path $Path))
    {
        md $Path
    }
}

function Update-NetConfig
{
    Param(
        $NetConfig,
        $clusterCIDR,
        $NetworkName,
        [ValidateSet("l2bridge", "overlay",IgnoreCase = $true)] 
        [parameter(Mandatory = $true)] $NetworkMode
    )
    $jsonSampleConfig = '{
        "Network": "10.244.0.0/16",
        "Backend": {
          "name": "cbr0",
          "type": "host-gw"
        }
      }
    '
    $configJson =  ConvertFrom-Json $jsonSampleConfig
    $configJson.Network = $clusterCIDR
    $configJson.Backend.name = $NetworkName
    $configJson.Backend.type = "host-gw"

    if ($NetworkMode -eq "overlay")
    {
        $configJson.Backend.type = "vxlan"
    }
    if (Test-Path $NetConfig) {
        Clear-Content -Path $NetConfig
    }
    $outJson = (ConvertTo-Json $configJson -Depth 20)
    Add-Content -Path $NetConfig -Value $outJson
    Write-Host "Generated net-conf Config [$outJson]"
}
function
Update-CNIConfig
{
    Param(
        $clusterCIDR,
        $KubeDnsServiceIP,
        $serviceCIDR,
        $InterfaceName,
        $NetworkName,
        [ValidateSet("l2bridge", "overlay",IgnoreCase = $true)] [parameter(Mandatory = $true)] $NetworkMode
    )
    if ($NetworkMode -eq "l2bridge")
    {
        $jsonSampleConfig = '{
            "cniVersion": "0.2.0",
            "name": "<NetworkMode>",
            "type": "flannel",
            "capabilities": {
                "dns" : true
            },
            "delegate": {
               "type": "win-bridge",
                "policies" : [
                   {
                      "Name" : "EndpointPolicy", "Value" : { "Type" : "OutBoundNAT", "ExceptionList": [ "<ClusterCIDR>", "<ServerCIDR>", "<MgmtSubnet>" ] }
                   },
                   {
                      "Name" : "EndpointPolicy", "Value" : { "Type" : "ROUTE", "DestinationPrefix": "<ServerCIDR>", "NeedEncap" : true }
                   },
                   {
                      "Name" : "EndpointPolicy", "Value" : { "Type" : "ROUTE", "DestinationPrefix": "<MgmtIP>/32", "NeedEncap" : true }
                   }
                ]
            }
        }'

        $configJson =  ConvertFrom-Json $jsonSampleConfig
        $configJson.name = $NetworkName
        $configJson.delegate.type = "win-bridge"
          
        $configJson.delegate.policies[0].Value.ExceptionList[0] = $clusterCIDR
        $configJson.delegate.policies[0].Value.ExceptionList[1] = $serviceCIDR
        $configJson.delegate.policies[0].Value.ExceptionList[2] = $Global:ManagementSubnet
          
        $configJson.delegate.policies[1].Value.DestinationPrefix  = $serviceCIDR
        $configJson.delegate.policies[2].Value.DestinationPrefix  = ($Global:ManagementIp + "/32")
    }
    elseif ($NetworkMode -eq "overlay")
    {
        $jsonSampleConfig = '{
            "cniVersion": "0.2.0",
            "name": "<NetworkMode>",
            "type": "flannel",
            "capabilities": {
                "dns" : true
            },
            "delegate": {
                "type": "win-overlay",
                "Policies" : [
                   {
                       "Name" : "EndpointPolicy", "Value" : { "Type" : "OutBoundNAT", "ExceptionList": [ "<ClusterCIDR>", "<ServerCIDR>" ] }
                   },
                   {
                       "Name" : "EndpointPolicy", "Value" : { "Type" : "ROUTE", "DestinationPrefix": "<ServerCIDR>", "NeedEncap" : true }
                   }
                ]
            }
        }'
          
        $configJson =  ConvertFrom-Json $jsonSampleConfig
        $configJson.name = $NetworkName
        $configJson.type = "flannel"
        $configJson.delegate.type = "win-overlay"
          
        $configJson.delegate.Policies[0].Value.ExceptionList[0] = $clusterCIDR
        $configJson.delegate.Policies[0].Value.ExceptionList[1] = $serviceCIDR
          
        $configJson.delegate.Policies[1].Value.DestinationPrefix  = $serviceCIDR
    }
    
    $CNIConfig = [io.Path]::Combine($(GetCniConfigPath), "cni.conf");
    if (Test-Path $CNIConfig) {
        Clear-Content -Path $CNIConfig
    }

    $outJson = (ConvertTo-Json $configJson -Depth 20)
    Write-Host "Generated CNI Config [$outJson]"

    Add-Content -Path $CNIConfig -Value $outJson
}

function CleanupContainers()
{
    docker ps -aq | foreach {docker rm $_ -f} 
}

function CreateExternalNetwork
{
    Param([ValidateSet("l2bridge", "overlay",IgnoreCase = $true)] 
    [parameter(Mandatory = $true)] $NetworkMode,
    [parameter(Mandatory = $true)] $InterfaceName)

    if ($NetworkMode -eq "l2bridge")
    {
        if(!(Get-HnsNetwork | ? Name -EQ "External"))
        {
            # Create a L2Bridge network to trigger a vSwitch creation. Do this only once as it causes network blip
            New-HNSNetwork -Type $NetworkMode -AddressPrefix "192.168.255.0/30" -Gateway "192.168.255.1" -Name "External" -AdapterName "$InterfaceName"
        }
    }
    elseif ($NetworkMode -eq "overlay")
    {
        # Open firewall for Overlay traffic
        New-NetFirewallRule -Name OverlayTraffic4789UDP -Description "Overlay network traffic UDP" -Action Allow -LocalPort 4789 -Enabled True -DisplayName "Overlay Traffic 4789 UDP" -Protocol UDP -ErrorAction SilentlyContinue
        # Create a Overlay network to trigger a vSwitch creation. Do this only once
        if(!(Get-HnsNetwork | ? Name -EQ "External"))
        {
            New-HNSNetwork -Type $NetworkMode -AddressPrefix "192.168.255.0/30" -Gateway "192.168.255.1" -Name "External" -AdapterName "$InterfaceName" -SubnetPolicies @(@{Type = "VSID"; VSID = 9999; }) 
        }
    }
}

function RemoveExternalNetwork
{
    $network = (Get-HnsNetwork | ? Name -EQ "External")
    if ($network)
    {
        $network | remove-hnsnetwork
    }

}

function GetKubeletArguments()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $LogDir,
        [parameter(Mandatory=$true)] [string] $CniDir,
        [parameter(Mandatory=$true)] [string] $CniConf,
        [parameter(Mandatory=$true)] [string] $KubeDnsServiceIp,
        [parameter(Mandatory=$true)] [string] $NodeIp,
        [parameter(Mandatory = $false)] $KubeletFeatureGates = ""
    )
    $kubeletArgs = @(
        (get-command kubelet.exe -ErrorAction Stop).Source,
        "--windows-service"
        "--hostname-override=$(hostname)"
        '--v=6'
        "--pod-infra-container-image=$Global:PauseImage"
        #'--resolv-conf=\"\"',
        #'--allow-privileged=true',
        #'--enable-debugging-handlers', # Comment for Config
        "--cluster-dns=`"$KubeDnsServiceIp`"",
        '--cluster-domain=cluster.local', 
        #'--hairpin-mode=promiscuous-bridge', # Comment for Config
        '--image-pull-progress-deadline=20m'
        '--cgroups-per-qos=false'
        "--log-dir=$LogDir"
        '--logtostderr=false'
        "--enforce-node-allocatable=`"`""
        '--network-plugin=cni'
        "--cni-bin-dir=$CniDir"
        "--cni-conf-dir=$CniConf"
        "--node-ip=$NodeIp"
        "--cert-dir=$env:SYSTEMDRIVE\var\lib\kubelet\pki"
        "--config=$env:SYSTEMDRIVE\var\lib\kubelet\config.yaml"
        "--kubeconfig=$env:SYSTEMDRIVE\etc\kubernetes\kubelet.conf"
        "--bootstrap-kubeconfig=$env:SYSTEMDRIVE\etc\kubernetes\bootstrap-kubelet.conf"
    )

    if ($KubeletFeatureGates -ne "")
    {
        $kubeletArgs += "--feature-gates=$KubeletFeatureGates"
    }

    return $kubeletArgs
}

function GetProxyArguments()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $KubeConfig,
        [parameter(Mandatory=$true)] [string] $KubeProxyConfig,
        [parameter(Mandatory=$true)] [string] $LogDir,
        [parameter(Mandatory=$false)] [switch] $IsDsr,
        [parameter(Mandatory=$true)] [string] $NetworkName,
        [parameter(Mandatory=$false)] [string] $SourceVip,
        [parameter(Mandatory=$true)] [string] $ClusterCIDR,
        [parameter(Mandatory = $false)] $ProxyFeatureGates = ""
    )

    $proxyArgs = @(
        (get-command kube-proxy.exe -ErrorAction Stop).Source,
        "--hostname-override=$(hostname)" # Comment for config
        '--v=6'
        '--proxy-mode=kernelspace'
        "--kubeconfig=$KubeConfig" # Comment for config
        "--network-name=$NetworkName" # Comment for config
        "--cluster-cidr=$ClusterCIDR" # Comment for config
        "--log-dir=$LogDir"
        '--logtostderr=false'
        "--windows-service"
    )

    if ($ProxyFeatureGates -ne "")
    {
        $proxyArgs += "--feature-gates=$ProxyFeatureGates"
    }

    $KubeproxyConfiguration = @{
        Kind = "KubeProxyConfiguration";
        apiVersion = "kubeproxy.config.k8s.io/v1alpha1";
        hostnameOverride = $(hostname);
        clusterCIDR = $ClusterCIDR;
        clientConnection = @{
            kubeconfig = $KubeConfig
        };
        winkernel = @{
            enableDSR = ($ProxyFeatureGates -match "WinDSR=true");
            networkName = $NetworkName;
        };
    }

    if ($ProxyFeatureGates -match "WinDSR=true")
    {
        $proxyArgs +=  "--enable-dsr=true" # Comment for config
    }

    if ($SourceVip)
    {
        $proxyArgs +=  "--source-vip=$SourceVip" # Comment out for config

        $KubeproxyConfiguration.winkernel += @{
            sourceVip = $SourceVip;
        }
    }
    ConvertTo-Json -Depth 10 $KubeproxyConfiguration | Out-File -FilePath $KubeProxyConfig
    #$proxyArgs += "--config=$KubeProxyConfig" # UnComment for Config
    
    return $proxyArgs
}

function InstallKubelet()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $CniDir,
        [parameter(Mandatory=$true)] [string] $CniConf,
        [parameter(Mandatory=$true)] [string] $KubeDnsServiceIp,
        [parameter(Mandatory=$true)] [string] $NodeIp,
        [parameter(Mandatory = $false)] $KubeletFeatureGates = ""
    )

    Write-Host "Installing Kubelet Service"
    $logDir = [io.Path]::Combine($(GetLogDir), "kubelet")
    CreateDirectory $logDir 

    $kubeletArgs = GetKubeletArguments -CniDir $CniDir `
                    -CniConf $CniConf   `
                    -KubeDnsServiceIp $KubeDnsServiceIp `
                    -NodeIp $NodeIp -KubeletFeatureGates $KubeletFeatureGates `
                    -LogDir $logDir

    $kubeletBinPath = $((get-command kubelet.exe -ErrorAction Stop).Source)

    New-Service -Name "kubelet" -StartupType Automatic `
        -DependsOn "docker" `
        -BinaryPathName "$kubeletBinPath --windows-service --v=6 --log-dir=$logDir --cert-dir=$env:SYSTEMDRIVE\var\lib\kubelet\pki --cni-bin-dir=$CniDir --cni-conf-dir=$CniConf --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --hostname-override=$(hostname) --pod-infra-container-image=$Global:PauseImage --enable-debugging-handlers  --cgroups-per-qos=false --enforce-node-allocatable=`"`" --logtostderr=false --network-plugin=cni --resolv-conf=`"`" --cluster-dns=`"$KubeDnsServiceIp`" --cluster-domain=cluster.local --feature-gates=$KubeletFeatureGates"

    # Investigate why the below doesn't work, probably a syntax error with the args
    #New-Service -Name "kubelet" -StartupType Automatic -BinaryPathName "$kubeletArgs"
    & cmd /c kubeadm join "$(GetAPIServerEndpoint)" --token "$Global:Token" --discovery-token-ca-cert-hash "$Global:CAHash" '2>&1'
    if (!$?) { Write-Warning "Error joining cluster, exiting."; exit; }

    # Open firewall for 10250. Required for kubectl exec pod <>
    if (!(Get-NetFirewallRule -Name KubeletAllow10250 -ErrorAction SilentlyContinue ))
    {
        New-NetFirewallRule -Name KubeletAllow10250 -Description "Kubelet Allow 10250" -Action Allow -LocalPort 10250 -Enabled True -DisplayName "KubeletAllow10250" -Protocol TCP -ErrorAction Stop
    }
    if (!(IsNodeRegistered)) {
        throw "Kubelet failed to bootstrap"
    }
}

function UninstallKubelet()
{
    Write-Host "Uninstalling Kubelet Service"
    # close firewall for 10250
    $out = (Get-NetFirewallRule -Name KubeletAllow10250 -ErrorAction SilentlyContinue )
    if ($out)
    {
        Remove-NetFirewallRule $out
    }

    RemoveService -ServiceName Kubelet
    & cmd /c kubeadm reset -f '2>&1'
}



function InstallKubeProxy()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $KubeConfig,
        [parameter(Mandatory=$false)] [switch] $IsDsr,
        [parameter(Mandatory=$true)] [string] $NetworkName,
        [parameter(Mandatory=$false)] [string] $SourceVip,
        [parameter(Mandatory=$true)] [string] $ClusterCIDR,
        [parameter(Mandatory = $false)] $ProxyFeatureGates = ""
    )

    $kubeproxyConfig = [io.Path]::Combine($Global:BaseDir, "kubeproxy.conf")
    $logDir = [io.Path]::Combine($(GetLogDir), "kube-proxy")
    CreateDirectory $logDir
    $log = [io.Path]::Combine($logDir, "kubproxysvc.log");

    Write-Host "Installing Kubeproxy Service"
    $proxyArgs = GetProxyArguments -KubeConfig $KubeConfig `
        -KubeProxyConfig $kubeproxyConfig `
        -IsDsr:$IsDsr.IsPresent -NetworkName $NetworkName `
        -SourceVip $SourceVip `
        -ClusterCIDR $ClusterCIDR `
        -ProxyFeatureGates $ProxyFeatureGates `
        -LogDir $logDir
    
    New-Service -Name "kubeproxy" -StartupType Automatic -BinaryPathName "$proxyArgs"
}

function UninstallKubeProxy()
{
    Write-Host "Uninstalling Kubeproxy Service"
    RemoveService -ServiceName Kubeproxy
}
function StartKubeProxy()
{
    $service = Get-Service Kubeproxy -ErrorAction SilentlyContinue
    if (!$service)
    {
        throw "Kubeproxy service not installed"
    }
    if ($srv.Status -ne "Running")
    {
        Start-Service Kubeproxy -ErrorAction Stop
        WaitForServiceRunningState -ServiceName Kubeproxy  -TimeoutSeconds 5
    }
}

function CreateService()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $ServiceName,
        [parameter(Mandatory=$true)] [string[]] $CommandLine,
        [parameter(Mandatory=$true)] [string] $LogFile,
        [parameter(Mandatory=$false)] [string[]] $DependsOn = @(),
        [parameter(Mandatory=$false)] [Hashtable] $EnvVaribles = $null
    )
    $binary = CreateSCMService -ServiceName $ServiceName -CommandLine $CommandLine -LogFile $LogFile -EnvVaribles $EnvVaribles

    New-Service -name $ServiceName -binaryPathName $binary `
        -DependsOn $DependsOn `
        -displayName $ServiceName -startupType Automatic    `
        -Description "$ServiceName Kubernetes Service" 

    Write-Host @" 
    ++++++++++++++++++++++++++++++++
    Successfully created the service
    ++++++++++++++++++++++++++++++++
    Service   [$ServiceName]
    Cmdline   [$binary]
    Env       [$($EnvVaribles | ConvertTo-Json -Depth 10)]
    Log       [$LogFile]
    DependsOn [$($DependsOn -join ", ")]
    ++++++++++++++++++++++++++++++++
"@
}

function CreateSCMService()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $ServiceName,
        [parameter(Mandatory=$true)] [string[]] $CommandLine,
        [parameter(Mandatory=$true)] [string] $LogFile,
        [parameter(Mandatory=$false)] [Hashtable] $EnvVaribles = $null
    )
    $Binary = $CommandLine[0].Replace("\", "\\");
    $Arguments = ($CommandLine | Select -Skip 1).Replace("\", "\\").Replace('"', '\"')
    $SvcBinary = "$Global:BaseDir\${ServiceName}Svc.exe"
    $LogFile = $LogFile.Replace("\", "\\")

    $envSrc = "";
    if ($EnvVaribles)
    {
        foreach ($key in $EnvVaribles.Keys)
        {
            $value = $EnvVaribles[$key];
            $envSrc += @"
            m_process.StartInfo.EnvironmentVariables["$key"] = "$value";
"@
        }
    }

    Write-Host "Create a SCMService Binary for [$ServiceName] [$CommandLine] => [$SvcBinary]"
    # reference: https://msdn.microsoft.com/en-us/magazine/mt703436.aspx
    $svcSource = @"
        using System;
        using System.IO;
        using System.ServiceProcess;
        using System.Diagnostics;
        using System.Runtime.InteropServices;
        using System.ComponentModel;

        public enum ServiceType : int {                                       
            SERVICE_WIN32_OWN_PROCESS = 0x00000010,
            SERVICE_WIN32_SHARE_PROCESS = 0x00000020,
        };                                                                    
        
        public enum ServiceState : int {                                      
            SERVICE_STOPPED = 0x00000001,
            SERVICE_START_PENDING = 0x00000002,
            SERVICE_STOP_PENDING = 0x00000003,
            SERVICE_RUNNING = 0x00000004,
            SERVICE_CONTINUE_PENDING = 0x00000005,
            SERVICE_PAUSE_PENDING = 0x00000006,
            SERVICE_PAUSED = 0x00000007,
        };                                                                    
          
        [StructLayout(LayoutKind.Sequential)]
        public struct ServiceStatus {
            public ServiceType dwServiceType;
            public ServiceState dwCurrentState;
            public int dwControlsAccepted;
            public int dwWin32ExitCode;
            public int dwServiceSpecificExitCode;
            public int dwCheckPoint;
            public int dwWaitHint;
        };     

        public class ScmService_$ServiceName : ServiceBase {
            private ServiceStatus m_serviceStatus;
            private Process m_process;
            private StreamWriter m_writer = null;
            public ScmService_$ServiceName() {
                ServiceName = "$ServiceName";
                CanStop = true;
                CanPauseAndContinue = false;
                
                m_writer = new StreamWriter("$LogFile");
                Console.SetOut(m_writer);
                Console.WriteLine("$Binary $ServiceName()");
            }

            ~ScmService_$ServiceName() {
                if (m_writer != null) m_writer.Dispose();
            }

            [DllImport("advapi32.dll", SetLastError=true)]
            private static extern bool SetServiceStatus(IntPtr handle, ref ServiceStatus serviceStatus);

            protected override void OnStart(string [] args) {
                EventLog.WriteEntry(ServiceName, "OnStart $ServiceName - $Binary $Arguments");
                m_serviceStatus.dwServiceType = ServiceType.SERVICE_WIN32_OWN_PROCESS; // Own Process
                m_serviceStatus.dwCurrentState = ServiceState.SERVICE_START_PENDING;
                m_serviceStatus.dwWin32ExitCode = 0;
                m_serviceStatus.dwWaitHint = 2000;
                SetServiceStatus(ServiceHandle, ref m_serviceStatus);

                try
                {
                    m_process = new Process();
                    m_process.StartInfo.UseShellExecute = false;
                    m_process.StartInfo.RedirectStandardOutput = true;
                    m_process.StartInfo.RedirectStandardError = true;
                    m_process.StartInfo.FileName = "$Binary";
                    m_process.StartInfo.Arguments = "$Arguments";
                    m_process.EnableRaisingEvents = true;
                    m_process.OutputDataReceived  += new DataReceivedEventHandler((s, e) => { Console.WriteLine(e.Data); });
                    m_process.ErrorDataReceived += new DataReceivedEventHandler((s, e) => { Console.WriteLine(e.Data); });

                    m_process.Exited += new EventHandler((s, e) => { 
                        Console.WriteLine("$Binary exited unexpectedly " + m_process.ExitCode);
                        if (m_writer != null) m_writer.Flush();
                        m_serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
                        SetServiceStatus(ServiceHandle, ref m_serviceStatus);
                    });

                    $envSrc;
                    m_process.Start();
                    m_process.BeginOutputReadLine();
                    m_process.BeginErrorReadLine();
                    m_serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
                    Console.WriteLine("OnStart - Successfully started the service ");
                } 
                catch (Exception e)
                {
                    Console.WriteLine("OnStart - Failed to start the service : " + e.Message);
                    m_serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
                }
                finally
                {
                    SetServiceStatus(ServiceHandle, ref m_serviceStatus);
                    if (m_writer != null) m_writer.Flush();
                }
            }

            protected override void OnStop() {
                Console.WriteLine("OnStop $ServiceName");
                try 
                {
                    m_serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
                    if (m_process != null)
                    {
                        m_process.Kill();
                        m_process.WaitForExit();
                        m_process.Close();
                        m_process.Dispose();
                        m_process = null;
                    }
                    Console.WriteLine("OnStop - Successfully stopped the service ");
                } 
                catch (Exception e)
                {
                    Console.WriteLine("OnStop - Failed to stop the service : " + e.Message);
                    m_serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
                }
                finally
                {
                    SetServiceStatus(ServiceHandle, ref m_serviceStatus);
                    if (m_writer != null) m_writer.Flush();
                }
            }

            public static void Main() {
                System.ServiceProcess.ServiceBase.Run(new ScmService_$ServiceName());
            }
        }
"@

    Add-Type -TypeDefinition $svcSource -Language CSharp `
        -OutputAssembly $SvcBinary -OutputType ConsoleApplication   `
        -ReferencedAssemblies "System.ServiceProcess" -Debug:$false

    return $SvcBinary
}

function RemoveService()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $ServiceName
    )
    $src = Get-Service -Name $ServiceName  -ErrorAction SilentlyContinue
    if ($src) {
        Stop-Service $src
        sc.exe delete $src;
    }
}

function InstallDockerD()
{
    Param(
    [ValidateSet("docker")] [parameter(Mandatory = $false)] $Version = "docker",
    $DestinationPath
    ) 
    # Add path to this PowerShell session immediately
    $env:path += ";$env:ProgramFiles\Docker"
    # For persistent use after a reboot
    $existingMachinePath = [Environment]::GetEnvironmentVariable("Path",[System.EnvironmentVariableTarget]::Machine)
    [Environment]::SetEnvironmentVariable("Path", $existingMachinePath + ";$env:ProgramFiles\Docker", [EnvironmentVariableTarget]::Machine)

    $cmd = get-command docker.exe -ErrorAction SilentlyContinue
    if (!$cmd)
    {
        Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
        Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
        Install-Package -Name docker -ProviderName DockerMsftProvider -Force -RequiredVersion 18.09
        Start-Service Docker -ErrorAction Stop
        $Global:Configuration += @{
            InstallDocker = $true;
        }
        WriteKubeClusterConfig
    }
}

function InstallDockerImages()
{
    if (!(docker images $Global:NanoserverImage -q))
    {
        docker pull $Global:NanoserverImage
        if (!(docker images $Global:NanoserverImage -q)) {
            throw "Failed to pull $Global:NanoserverImage"
        }
    }
    docker tag $Global:NanoserverImage mcr.microsoft.com/windows/nanoserver:latest
    if (!(docker images $Global:ServercoreImage -q))
    {
        docker pull $Global:ServercoreImage
        if (!(docker images $Global:ServercoreImage -q)) {
            throw "Failed to pull $Global:ServercoreImage"
        }
    }
    docker tag $Global:ServercoreImage mcr.microsoft.com/windows/servercore:latest
}

function InstallPauseImage()
{
    # Prepare POD infra Images
    $infraPodImage=docker images $Global:PauseImage -q
    if (!$infraPodImage)
    {
        Write-Host "No infrastructure container image found. Pulling $Global:PauseImage"
        docker pull $Global:PauseImage
        if ($LastExitCode) {
            throw "Failed to pull $Global:PauseImage"
        }
    }
}

function InstallKubernetesBinaries()
{
    Param(
        [parameter(Mandatory = $true)] $Source,
        $DestinationPath
    ) 

    $existingPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

    # Update path for current process, user, and machine
    [System.EnvironmentVariableTarget].GetEnumNames() | % { 
        $existingPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::$_)
        $existingPath = $existingPath.Replace($DestinationPath+'\bin;', "")
        [Environment]::SetEnvironmentVariable("Path", $existingPath + ";$DestinationPath\kubernetes\node\bin", [EnvironmentVariableTarget]::$_)
        [Environment]::SetEnvironmentVariable("KUBECONFIG", $(GetKubeConfig), [EnvironmentVariableTarget]::$_)
    }
    
    $env:KUBECONFIG = $(GetKubeConfig)

    $Release = "1.15"
    if ($Source.Release)
    {
        $Release = $Source.Release
    }
    $Url = "https://dl.k8s.io/v${Release}/kubernetes-node-windows-amd64.tar.gz"
    if ($Source.Url)
    {
        $Url = $Source.Url
    }
    DownloadFile -Url  $Url -Destination $Global:BaseDir/kubernetes-node-windows-amd64.tar.gz
    & cmd /c tar -zxvf $Global:BaseDir/kubernetes-node-windows-amd64.tar.gz -C $DestinationPath '2>&1'
    if (!$?) { Write-Warning "Error decompressing file, exiting."; exit; }
}

function UninstallKubernetesBinaries()
{
    Param(
        $DestinationPath
    ) 
    Remove-Item Env:\KUBECONFIG -ErrorAction SilentlyContinue

    # Update path for current process, user, and machine
    [System.EnvironmentVariableTarget].GetEnumNames() | % { 
        $existingPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::$_)
        $existingPath = $existingPath.Replace($DestinationPath+'\bin;', "")
        [Environment]::SetEnvironmentVariable("Path", $existingPath, [EnvironmentVariableTarget]::$_)
    }
    
    Remove-Item $DestinationPath -Force -Recurse -ErrorAction SilentlyContinue
}

function InstallContainersRole()
{
    $feature = Get-WindowsFeature -Name Containers
    if (!$feature.Installed)
    {
        Install-WindowsFeature -Name Containers -IncludeAllSubFeature
        return $true
    }

    return $false
}

function ReadKubeClusterInfo()
{
    $KubeConfiguration = @{
        ClusterCIDR = GetClusterCidr;
        ServiceCIDR = GetServiceCidr;
        KubeDnsIp = GetKubeDnsServiceIp;
        NetworkName = $Global:NetworkName;
        NetworkMode = $Global:NetworkMode;
    }

    $Global:Configuration += @{
        Kube = $KubeConfiguration;
    }
    WriteKubeClusterConfig
}

function GetKubeDnsServiceIp()
{
    $svc = ConvertFrom-Json $(kubectl.exe get services -n kube-system -o json | Out-String)
    $svc.Items | foreach { $i = $_; if ($i.Metadata.Name -match "kube-dns") { return $i.spec.ClusterIP } }
}

function GetAPIServerEndpoint() {
    $endpoints = ConvertFrom-Json $(kubectl.exe get endpoints --all-namespaces -o json | Out-String)
    $endpoints.Items | Where-Object { $_.Metadata.Name -eq "kubernetes" } | ForEach-Object { "$($_.subsets[0].addresses[0].ip):$($_.subsets[0].ports[0].port)" }
}

function GetKubeNodes()
{
    kubectl.exe get nodes
}

function RemoveKubeNode()
{
    kubectl.exe delete node (hostname).ToLower()
}

function GetClusterCidr()
{
    return $Global:ClusterConfiguration.Kubernetes.Network.ClusterCidr
}

function GetServiceCidr()
{
    return $Global:ClusterConfiguration.Kubernetes.Network.ServiceCidr
}


function InstallCRI($cri)
{
    # Install CRI
    switch ($cri)
    {
        "dockerd" {
            # Setup Docker
            InstallDockerD
            InstallDockerImages
            InstallPauseImage
            break
        }

        "containerd" {
            # Setup ContainerD
            throw "Not Implemented"
            # InstallContainerD
            break
        }
    }
}

function InstallCNI($cni, $NetworkMode, $ManagementIp, $CniPath, $InterfaceName)
{
   
    switch ($Cni)
    {
        "kubenet" {
            break
        }
    
        "flannel" {
            InstallFlannelD -Destination $Global:BaseDir -InterfaceIpAddress $ManagementIp
            Update-CNIConfig  `
                -ClusterCIDR (GetClusterCidr) -KubeDnsServiceIP (GetKubeDnsServiceIp) `
                -ServiceCidr (GetServiceCidr) -InterfaceName $InterfaceName `
                -NetworkName $Global:NetworkName -NetworkMode $Global:NetworkMode

            Update-NetConfig -NetConfig (GetFlannelNetConf) `
                -ClusterCIDR (GetClusterCidr) `
                -NetworkName $Global:NetworkName -NetworkMode $Global:NetworkMode

            Copy-Item $(GetFlannelNetConf) $(GetKubeFlannelPath)

            break
        }
    } 
}

function UninstallCNI($cni)
{
    switch ($Cni)
    {
        "kubenet" {
            break
        }
        "flannel" {
            UnInstallFlannelD
            break
        }
    } 
}

function GetFileContent($Path)
{
    if ((Test-Path $Path))
    {
        return Get-Content $Path
    }
    if ($Path.StartsWith("http"))
    {
        return (iwr $Path -ErrorAction Stop).Content
    }
}

# List of all exports from this module
Export-ModuleMember DownloadFile
Export-ModuleMember CleanupOldNetwork
Export-ModuleMember IsNodeRegistered
Export-ModuleMember WaitForNetwork
Export-ModuleMember GetSourceVip
Export-ModuleMember GetUserDir
Export-ModuleMember Get-PodCIDR
Export-ModuleMember Get-PodCIDRs
Export-ModuleMember Get-PodEndpointGateway
Export-ModuleMember Get-PodGateway
Export-ModuleMember CreateDirectory
Export-ModuleMember Update-CNIConfig
Export-ModuleMember Update-NetConfig
Export-ModuleMember CleanupContainers
Export-ModuleMember DownloadAndExtractTarGz
Export-ModuleMember Assert-FileExists
Export-ModuleMember StartKubelet
Export-ModuleMember StartFlanneld
Export-ModuleMember StartKubeproxy
Export-ModuleMember CreateService
Export-ModuleMember RemoveService
Export-ModuleMember InstallKubernetesBinaries
Export-ModuleMember UninstallKubernetesBinaries
Export-ModuleMember InstallDockerD
Export-ModuleMember InstallDockerImages
Export-ModuleMember InstallPauseImage
Export-ModuleMember InstallContainersRole
Export-ModuleMember ReadKubeClusterInfo
Export-ModuleMember GetKubeDnsServiceIp
Export-ModuleMember GetClusterCidr
Export-ModuleMember GetServiceCidr
Export-ModuleMember KubeConfigExists
Export-ModuleMember InstallKubeProxy
Export-ModuleMember UninstallKubeProxy
Export-ModuleMember InstallKubelet
Export-ModuleMember UninstallKubelet
Export-ModuleMember InstallCNI
Export-ModuleMember InstallCRI
Export-ModuleMember UninstallCNI
Export-ModuleMember InitHelper
Export-ModuleMember GetKubeConfig
Export-ModuleMember DownloadKubeConfig
Export-ModuleMember GetCniPath
Export-ModuleMember GetCniConfigPath
Export-ModuleMember Get-InterfaceIpAddress
Export-ModuleMember GetLogDir
Export-ModuleMember HasKubeClusterConfig
Export-ModuleMember WriteKubeClusterConfig
Export-ModuleMember ReadKubeClusterConfig
Export-ModuleMember GetKubeNodes
Export-ModuleMember RemoveKubeNode
Export-ModuleMember GetFileContent
Export-ModuleMember PrintConfig
Export-ModuleMember CleanupPolicyList
Export-ModuleMember CreateExternalNetwork
Export-ModuleMember RemoveExternalNetwork
Export-ModuleMember DownloadCniBinaries
