<#
.SYNOPSIS
Utility script to assist in management of Kubernetes Windows worker nodes

.DESCRIPTION
Assists in installing required pre-requisites, and can join and unjoin this Windows worker node from an existing Kubernetes cluster.

.PARAMETER help
Print the help

.PARAMETER install
Install pre-requisites

.PARAMETER join
Join the windows node to the cluster

.PARAMETER reset
Reset and clean up this Windows worker node

.PARAMETER force
Skip user prompts and auto-accept (i.e. deletion, installing dependencies, etc)

.PARAMETER ConfigFile
Path to input configuration JSON

.EXAMPLE
PS> .\KubeCluster.ps1 -help
Prints this help
.EXAMPLE
PS> .\KubeCluster.ps1 -install -ConfigFile kubecluster.json 
Sets up this Windows worker node to run containers
.EXAMPLE
PS> .\KubeCluster.ps1 -join -ConfigFile kubecluster.json
Joins this Windows worker node to an existing cluster
.EXAMPLE
PS> .\KubeCluster.ps1 -reset -ConfigFile kubecluster.json
Resets and cleans up this Windows worker node

.LINK

https://github.com/kubernetes-sigs/sig-windows-tools/tree/master/kubeadm

#>
Param(
    [parameter(Mandatory = $false,HelpMessage="Print the help")]
    [switch] $help,
    [parameter(Mandatory = $false,HelpMessage="Install pre-requisites")]
    [switch] $install,
    [parameter(Mandatory = $false,HelpMessage="Join the windows node to the cluster")]
    [switch] $join,
    [parameter(Mandatory = $false,HelpMessage="Reset and clean up this Windows worker node")]
    [switch] $reset,
    [parameter(Mandatory = $false,HelpMessage="Skip user prompts and auto-accept (i.e. deletion, installing dependencies, etc)")]
    [switch] $force,
    [parameter(Mandatory = $false,HelpMessage="Path to input configuration JSON")] 
    $ConfigFile
)

function Usage()
{
    $bin = $PSCommandPath 
    Get-Help $bin -Detailed
}

# Handle --help
if ($help.IsPresent)
{
    Usage
    exit
}

function ReadKubeclusterConfig($ConfigFile)
{
    # Read the configuration and initialize default values if not found
    $Global:ClusterConfiguration = ConvertFrom-Json ((GetFileContent $ConfigFile -ErrorAction Stop) | out-string)
    if (!$Global:ClusterConfiguration.Install)
    {
        $Global:ClusterConfiguration | Add-Member -MemberType NoteProperty -Name Install -Value @{ 
            Destination = "$env:ALLUSERSPROFILE\Kubernetes";
        }
    }

    if (!$Global:ClusterConfiguration.Kubernetes)
    {
        throw "Kubernetes information missing in the configuration file"
    }
    if (!$Global:ClusterConfiguration.Kubernetes.Source)
    {
        $Global:ClusterConfiguration.Kubernetes | Add-Member -MemberType NoteProperty -Name Source -Value @{
            Release = "1.16.2";
        }
    }
    if (!$Global:ClusterConfiguration.Kubernetes.ControlPlane)
    {
        throw "Control-plane node information missing in the configuration file"
    }

    if (!$Global:ClusterConfiguration.Kubernetes.Network)
    {
        $Global:ClusterConfiguration.Kubernetes | Add-Member -MemberType NoteProperty -Name Network -Value @{
            ServiceCidr = "10.96.0.0/12";
            ClusterCidr = "10.244.0.0/16";
        }
    }

    if (!$Global:ClusterConfiguration.Cni)
    {
        $Global:ClusterConfiguration | Add-Member -MemberType NoteProperty -Name Cni -Value @{
            Name = "flannel";
            Plugin = @{
                Name = "vxlan";
            };
            InterfaceName = "Ethernet";
        }
    }

    if ($Global:ClusterConfiguration.Cni.Plugin.Name -eq "vxlan")
    {
        if (!$Global:ClusterConfiguration.Kubernetes.KubeProxy)
        {
            $Global:ClusterConfiguration.Kubernetes | Add-Member -MemberType NoteProperty -Name KubeProxy -Value @{
                    Gates = "WinOverlay=true";
            }
        }
    }

    if (!$Global:ClusterConfiguration.Cri)
    {
        $Global:ClusterConfiguration | Add-Member -MemberType NoteProperty -Name Cri -Value @{
            Name = "dockerd";
            Images = @{
                Pause = "mcr.microsoft.com/k8s/core/pause:1.2.0";
                Nanoserver = "mcr.microsoft.com/windows/nanoserver:1809";
                ServerCore = "mcr.microsoft.com/windows/servercore:ltsc2019";
            }
        }
    }
}

###############################################################################################
# Download pre-req scripts
$helperPath = "$PSScriptRoot\KubeClusterHelper.psm1"
Import-Module $helperPath
$hnsPath = "https://raw.githubusercontent.com/Microsoft/SDN/master/Kubernetes/windows/hns.psm1"
$hnsDestination = "$PSScriptRoot\hns.psm1" 
DownloadFile -Url $hnsPath -Destination $hnsDestination
Import-Module $hnsDestination

ReadKubeclusterConfig -ConfigFile $ConfigFile
InitHelper
PrintConfig
WriteKubeClusterConfig


# Initialize internal network modes of windows corresponding to 
# the plugin used in the cluster
$Global:NetworkName = "cbr0"
$Global:NetworkMode = "l2bridge"
if ($Global:NetworkPlugin -eq "vxlan")
{
    $Global:NetworkMode = "overlay"
    $Global:NetworkName = "vxlan0"
}
######################################################################################################################

# Handle --install
function
Restart-And-Run()
{
    Write-Output "Restart is required; restarting now..."

    $argList = $script:MyInvocation.Line.replace($script:MyInvocation.InvocationName, "")

    #
    # Update .\ to the invocation directory for the bootstrap
    #
    $scriptPath = $script:MyInvocation.MyCommand.Path

    $argList = $argList -replace "\.\\", "$pwd\"

    if ((Split-Path -Parent -Path $scriptPath) -ne $pwd)
    {
        $sourceScriptPath = $scriptPath
        $scriptPath = "$pwd\$($script:MyInvocation.MyCommand.Name)"

        Copy-Item $sourceScriptPath $pwd -Force
        Copy-Item $helperPath $pwd -Force
    }

    Write-Output "Creating scheduled task action ($scriptPath $argList)..."
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass $scriptPath $argList" -WorkingDirectory $pwd 

    try
    {
        if ($force.IsPresent)
        {
            Write-Output "Creating scheduled task trigger..."
            $trigger = New-ScheduledTaskTrigger -AtLogOn

            Write-Output "Registering script to re-run at next user logon..."
            Register-ScheduledTask -TaskName "ContainerBootstrap" -Action $action -Trigger $trigger -RunLevel Highest | Out-Null
            Restart-Computer -Force
        }
        else
        {
            Write-Output "Creating scheduled task trigger..."
            $trigger = New-ScheduledTaskTrigger -AtLogOn

            Write-Output "Registering script to re-run at next user logon..."
            Register-ScheduledTask -TaskName "ContainerBootstrap" -Action $action -Trigger $trigger -RunLevel Highest | Out-Null

            Restart-Computer
        }
    }
    catch
    {
        Write-Error $_

        Write-Output "Please restart your computer manually to continue script execution."
    }

    exit
}

if ($install.IsPresent)
{
    if (InstallContainersRole)
    {
        $res = 'Y'
        if (!$force.IsPresent)
        {
            $res = Read-Host "Continue to Reboot the host [Y/n] - Default [Y]"
        }

        if ($res -eq '' -or $res -eq 'Y'  -or $res -eq 'y')
        {
            Restart-And-Run
        }
    }

    InstallCRI $Global:Cri
    InstallKubernetesBinaries -Destination  $Global:BaseDir -Source $Global:ClusterConfiguration.Kubernetes.Source
    DownloadCniBinaries -NetworkMode $Global:NetworkMode -CniPath $(GetCniPath)

    if (!(Test-Path "$(GetUserDir)/.ssh/id_rsa.pub"))
    {
        if (!$force.IsPresent)
        {
            $res = Read-Host "Do you wish to generate a SSH Key & Add it to the Linux control-plane node [Y/n] - Default [Y]"
            if ($res -eq '' -or $res -eq 'Y'  -or $res -eq 'y')
            {
                ssh-keygen.exe
            }
        }
        else
        {
            Write-Host "Generating SSH key"
            if (!(Test-Path "$env:USERPROFILE/.ssh")) { New-Item -Path "$env:USERPROFILE/.ssh" -ItemType "Directory" -Force }
            cmd /c "ssh-keygen.exe -t rsa -N """" -f ""$env:USERPROFILE\.ssh\id_rsa"""
            cmd /c "ssh-keyscan.exe $($Global:MasterIp) 2>NUL" | Out-File -Encoding utf8 $env:USERPROFILE\.ssh\known_hosts
        }
    }
    else
    {
        "$(GetUserDir)/.ssh/id_rsa.pub"
        Write-Host "Execute the below commands on the Linux control-plane node ($Global:MasterIp) to add this Windows node's public key to its authorized keys"
    
        Write-Host "touch ~/.ssh/authorized_keys"
        Write-Host "echo $pubKey >> ~/.ssh/authorized_keys"
    }

    Write-Host "Please close this shell and open a new one to join this node to the cluster."

    # Check for ContainerBootstrap task that needs to get removed
    $task = Get-ScheduledTask -TaskName "ContainerBootstrap" -ErrorAction "SilentlyContinue"
    if ($task -ne $null)
    {
        $task | Unregister-ScheduledTask -Confirm:$false
        Write-Host "Unregistered ContainerBootstrap scheduled task, as InstallPrerequisites has completed."
        
        if (!($force.IsPresent))
        {
            Read-Host "Press enter to close this window"
        }
    }

    exit
}


# Handle -Join
if ($Join.IsPresent)
{
    $kubeConfig = GetKubeConfig
    if (!(KubeConfigExists))
    {
        # Fetch KubeConfig from the master
        DownloadKubeConfig -Master $Global:MasterIp -User $Global:MasterUsername
        if (!(KubeConfigExists))
        {
            throw $kubeConfig + " does not exist. Cannot connect to the control-plane node"
        }
    }

    # Validate connectivity with the API Server

    Write-Host "Trying to connect to the Kubernetes control-plane node"
    try {
        ReadKubeClusterInfo 
    } catch {
        throw "Unable to connect to the control-plane node. Reason [$_]"
    }

    $KubeDnsServiceIP = GetKubeDnsServiceIp
    $ClusterCIDR = GetClusterCidr
    $ServiceCIDR = GetServiceCidr
    
    Write-Host "############################################"
    Write-Host "Able to connect to the control-plane node"
    Write-Host "Discovered the following"
    Write-Host "Cluster CIDR    : $ClusterCIDR"
    Write-Host "Service CIDR    : $ServiceCIDR"
    Write-Host "DNS ServiceIp   : $KubeDnsServiceIP"
    Write-Host "############################################"

    #
    # Install Services & Start in the below order
    # 1. Install & Start Kubelet
    InstallKubelet  -CniDir $(GetCniPath) `
        -CniConf $(GetCniConfigPath) -KubeDnsServiceIp $KubeDnsServiceIp `
        -NodeIp $Global:ManagementIp -KubeletFeatureGates $KubeletFeatureGates
    #StartKubelet

    #WaitForNodeRegistration -TimeoutSeconds 10

    # 2. Install CNI & Start services
    InstallCNI -Cni $Global:Cni -NetworkMode $Global:NetworkMode `
        -ManagementIP $Global:ManagementIp `
        -InterfaceName $Global:InterfaceName `
        -CniPath $(GetCniPath)

    if ($Global:Cni -eq "flannel")
    {
        CreateExternalNetwork -NetworkMode $Global:NetworkMode -InterfaceName $Global:InterfaceName
        StartFlanneld 
        WaitForNetwork $Global:NetworkName
    }

    # 3. Install & Start Kubeproxy
    if ($Global:NetworkMode -eq "overlay")
    {
        $sourceVip = GetSourceVip -NetworkName $Global:NetworkName
        InstallKubeProxy -KubeConfig $(GetKubeConfig) `
            -NetworkName $Global:NetworkName -ClusterCIDR  $ClusterCIDR `
            -SourceVip $sourceVip `
            -IsDsr:$Global:DsrEnabled `
            -ProxyFeatureGates $Global:KubeproxyGates
    }
    else 
    {
        $env:KUBE_NETWORK=$Global:NetworkName
        InstallKubeProxy -KubeConfig $(GetKubeConfig) `
            -IsDsr:$Global:DsrEnabled `
            -NetworkName $Global:NetworkName -ClusterCIDR  $ClusterCIDR
    }
    
    StartKubeproxy

    GetKubeNodes
    Write-Host "Node $(hostname) successfully joined the cluster"
}
# Handle -Reset
elseif ($Reset.IsPresent)
{
    ReadKubeClusterConfig -ConfigFile $ConfigFile
    RemoveKubeNode
    # Initiate cleanup
    CleanupContainers
    CleanupOldNetwork $Global:NetworkName
    CleanupPolicyList
    UninstallCNI $Global:Cni
    UninstallKubeProxy
    UninstallKubelet
    UninstallKubernetesBinaries -Destination  $Global:BaseDir

    if ($force.IsPresent)
    {
        Remove-Item $Global:BaseDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$(GetUserDir)\.kube" -Recurse -Force -ErrorAction SilentlyContinue    
    }
    else
    {
        Remove-Item $Global:BaseDir -ErrorAction SilentlyContinue
        Remove-Item "$(GetUserDir)\.kube" -ErrorAction SilentlyContinue    
    }

    RemoveExternalNetwork
}
