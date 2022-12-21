<#
.SYNOPSIS
Installs ContainerD on a Windows machines in preperation for joining the node to a Kubernetes cluster.

.DESCRIPTION
This script
- Verifies that Windows Features requried for running contianers are enabled (and enables then if they are not)
- Downloads ContainerD binaries from from at the version specified.
- Downloads Windows SND CNI plugins.
- Registers ContainerD as a windows service.

.PARAMETER ContainerDVersion
ContainerD version to download and use.

.PARAMETER netAdapterName
Name of network adapter to use when configuring basic nat network.

.PARAMETER UseHostProcess
Declares that HostProcess model is in use. Some code should be omitted.

.EXAMPLE
PS> .\Install-Conatinerd.ps1

#>

[CmdletBinding(
    DefaultParameterSetName="kubeadm"
)]
Param(
    [parameter(HelpMessage = "ContainerD version to use")]
    [string] $ContainerDVersion = "1.6.8",
    [parameter(
        HelpMessage = "Name of network adapter to use when configuring basic nat network",
        ParameterSetName = "kubeadm"
    )]
    [string] $netAdapterName = "Ethernet",
    [parameter(
        HelpMessage = "Declares that HostProcess model is in use",
        ParameterSetName = "hostprocess"
    )]
    [switch] $UseHostProcess
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

$requiredWindowsFeatures = @(
    "Containers",
    "Hyper-V",
    "Hyper-V-PowerShell")

function ValidateWindowsFeatures {
    $allFeaturesInstalled = $true
    foreach ($feature in $requiredWindowsFeatures) {
        $f = Get-WindowsFeature -Name $feature
        if (-not $f.Installed) {
            Write-Warning "Windows feature: '$feature' is not installed."
            $allFeaturesInstalled = $false
        }
    }
    return $allFeaturesInstalled
}

if (-not (ValidateWindowsFeatures)) {
    Write-Output "Installing required windows features..."

    foreach ($feature in $requiredWindowsFeatures) {
        Install-WindowsFeature -Name $feature
    }

    Write-Output "Please reboot and re-run this script."
    exit 0
}

Write-Output "Getting ContainerD binaries"
$global:ConainterDPath = "$env:ProgramFiles\containerd"
mkdir -Force $global:ConainterDPath | Out-Null
DownloadFile "$global:ConainterDPath\containerd.tar.gz" https://github.com/containerd/containerd/releases/download/v${ContainerDVersion}/containerd-${ContainerDVersion}-windows-amd64.tar.gz
tar.exe -xvf "$global:ConainterDPath\containerd.tar.gz" --strip=1 -C $global:ConainterDPath
$env:Path += ";$global:ConainterDPath"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
containerd.exe config default | Out-File "$global:ConainterDPath\config.toml" -Encoding ascii
#config file fixups
$config = Get-Content "$global:ConainterDPath\config.toml"
$config = $config -replace "bin_dir = (.)*$", "bin_dir = `"c:/opt/cni/bin`""
$config = $config -replace "conf_dir = (.)*$", "conf_dir = `"c:/etc/cni/net.d`""
$config | Set-Content "$global:ConainterDPath\config.toml" -Force 

mkdir -Force c:\opt\cni\bin | Out-Null
mkdir -Force c:\etc\cni\net.d | Out-Null

Write-Output "Getting SDN CNI binaries"
DownloadFile "c:\opt\cni\cni-plugins.zip" https://github.com/microsoft/windows-container-networking/releases/download/v0.2.0/windows-container-networking-cni-amd64-v0.2.0.zip
Expand-Archive -Path "c:\opt\cni\cni-plugins.zip" -DestinationPath "c:\opt\cni\bin" -Force

Write-Output "Registering ContainerD as a service"
containerd.exe --register-service

Write-Output "Starting ContainerD service"
Start-Service containerd

Write-Output "Done - please remember to add '--cri-socket `"npipe:////./pipe/containerd-containerd`"' to your kubeadm join command"