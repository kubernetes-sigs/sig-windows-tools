<#
.SYNOPSIS
Installs ContainerD on a Windows machines in preparation for joining the node to a Kubernetes cluster.

.DESCRIPTION
This script
- Verifies that Windows Features requried for running containers are enabled (and enables them if they are not)
- Downloads ContainerD binaries for the version specified.
- Downloads Windows SND CNI plugins.
- Registers ContainerD as a windows service.

.PARAMETER ContainerDVersion
ContainerD version to download and use.

.PARAMETER netAdapterName
Name of network adapter to use when configuring basic nat network.

.PARAMETER skipHypervisorSupportCheck
Skip the CPU check for Hypervisor support. You way wont be able to host Hyper-V isolated containers.
Check https://github.com/kubernetes-sigs/sig-windows-tools/issues/296#issuecomment-1511695392 for more information.

.PARAMETER CNIBinPath
Path to configure ContainerD to look for CNI binaries. Optional, defaults to "c:/opt/cni/bin".

.PARAMETER CNIConfigPath
Path to configure ContainerD to look for CNI config files. Optional, defaults to "c:/etc/cni/net.d".

.EXAMPLE
PS> .\Install-Containerd.ps1 -ContainerDVersion 1.7.1 -netAdapterName Ethernet -skipHypervisorSupportCheck -CNIBinPath "c:/opt/cni/bin" -CNIConfigPath "c:/etc/cni/net.d"

#>

Param(
    [parameter(HelpMessage = "ContainerD version to use")]
    [string] $ContainerDVersion = "1.7.1",
    [parameter(HelpMessage = "Name of network adapter to use when configuring basic nat network")]
    [string] $netAdapterName = "Ethernet",
    [parameter(HelpMessage = "Skip the CPU check for Hypervisor support. Note that you will not be able to host Hyper-V isolated containers")]
    [switch] $skipHypervisorSupportCheck,
    [parameter(HelpMessage = "Path to configure ContainerD to look for CNI binaries")]
    [string] $CNIBinPath = "c:/opt/cni/bin",
    [parameter(HelpMessage = "Path to configure ContainerD to look for CNI config files")]
    [string] $CNIConfigPath = "c:/etc/cni/net.d"
)

$ErrorActionPreference = 'Stop'

function DownloadFile($destination, $source) {
    Write-Host("Downloading $source to $destination")
    curl.exe --silent --fail -Lo $destination $source

    if (!$?) {
        Write-Error "Download $source failed"
        exit 1
    }
}

$rebootNeeded = $false

$windowsFeatures = @("Containers")

if (!$skipHypervisorSupportCheck) {
    $windowsFeatures += @("Hyper-V", "Hyper-V-PowerShell")
}

foreach ($feature in $windowsFeatures) {
    $featureInstalled = (Get-WindowsFeature -Name $feature).Installed

    if ($featureInstalled) {
        Write-Output "Windows feature '$feature' is already installed."
    }
    else {
        Write-Warning "Windows feature '$feature' is not installed. Installing it now..."
        Install-WindowsFeature -Name $feature
        $rebootNeeded = $true
    }
}

if ($skipHypervisorSupportCheck) {
    $hyperVFeatureName = "Microsoft-Hyper-V"
    $hyperVState = (Get-WindowsOptionalFeature -FeatureName $hyperVFeatureName -Online).State

    if ($hyperVState -eq "Enabled") {
        Write-Output "Windows optional feature '$hyperVFeatureName' is already enabled."
    }
    else {
        Write-Warning "Windows optional feature '$hyperVFeatureName' is not enabled. Enabling it now..."
        DISM /Online /Enable-Feature /FeatureName:$hyperVFeatureName /All /NoRestart
        $rebootNeeded = $true
    }

    $hyperVOnlineFeatureName = "Microsoft-Hyper-V-Online"
    $hyperVOnlineState = (Get-WindowsOptionalFeature -FeatureName $hyperVOnlineFeatureName -Online).State

    if ($hyperVOnlineState -eq "Disabled") {
        Write-Output "Windows optional feature '$hyperVOnlineFeatureName' is already disabled."
    }
    else {
        Write-Warning "Windows optional feature '$hyperVOnlineFeatureName' is not disabled. Disabling it now..."
        DISM /Online /Disable-Feature /FeatureName:$hyperVOnlineFeatureName /NoRestart
        $rebootNeeded = $true
    }

    Write-Warning "The Hyper-V features was installed without checking the CPU for Hypervisor support. You may not be able to host Hyper-V isolated containers if CPU doesn't support hypervisors."
}

if ($rebootNeeded) {
    Write-Output "Please reboot and re-run this script."
    exit 0
}

Write-Output "Getting ContainerD binaries"
$global:ContainerDPath = "$env:ProgramFiles\containerd"
mkdir -Force $global:ContainerDPath | Out-Null
DownloadFile "$global:ContainerDPath\containerd.tar.gz" https://github.com/containerd/containerd/releases/download/v${ContainerDVersion}/containerd-${ContainerDVersion}-windows-amd64.tar.gz
tar.exe -xvf "$global:ContainerDPath\containerd.tar.gz" --strip=1 -C $global:ContainerDPath
$env:Path += ";$global:ContainerDPath"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
containerd.exe config default | Out-File "$global:ContainerDPath\config.toml" -Encoding ascii
#config file fixups
$config = Get-Content "$global:ContainerDPath\config.toml"
$config = $config -replace "bin_dir = (.)*$", "bin_dir = `"$CNIBinPath`""
$config = $config -replace "conf_dir = (.)*$", "conf_dir = `"$CNIConfigPath`""
$config | Set-Content "$global:ContainerDPath\config.toml" -Force

mkdir -Force $CNIBinPath | Out-Null
mkdir -Force $CNIConfigPath | Out-Null

Write-Output "Registering ContainerD as a service"
containerd.exe --register-service

Write-Output "Starting ContainerD service"
Start-Service containerd

Write-Output "Done - please remember to add '--cri-socket `"npipe:////./pipe/containerd-containerd`"' to your kubeadm join command if your kubernetes version is below 1.25!"
