<#
.SYNOPSIS
Installs ContainerD on a Windows machine in preparation for joining the node to a Kubernetes cluster.

.DESCRIPTION
This script
- Verifies that Windows Features requried for running containers are enabled (and enables them if they are not)
- Downloads ContainerD binaries for the version specified.
- Downloads Windows SND CNI plugins.
- Registers ContainerD as a windows service.

.PARAMETER ContainerDVersion
ContainerD version to download and use.

.PARAMETER skipHypervisorSupportCheck
Skip the CPU check for Hypervisor support. You wont be able to host Hyper-V isolated containers.
Check https://github.com/kubernetes-sigs/sig-windows-tools/issues/296#issuecomment-1511695392 for more information.

.PARAMETER CNIBinPath
Path to configure ContainerD to look for CNI binaries. Optional, defaults to "c:/opt/cni/bin".

.PARAMETER CNIConfigPath
Path to configure ContainerD to look for CNI config files. Optional, defaults to "c:/etc/cni/net.d".

.EXAMPLE
PS> .\Install-Containerd.ps1 -ContainerDVersion 1.7.1 -skipHypervisorSupportCheck -CNIBinPath "c:/opt/cni/bin" -CNIConfigPath "c:/etc/cni/net.d"

#>

Param(
    [parameter(HelpMessage = "ContainerD version to use")]
    [string] $ContainerDVersion = "1.7.1",
    [parameter(HelpMessage = "crictl version to use")]
    [string] $crictlVersion = "1.27.0",
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

function Find-TomlSectionFromRegex {
    <#
    .SYNOPSIS
        Finds the exact TOML section header string that matches a given Regular Expression.
    .OUTPUTS
        System.String containing the exact trimmed section header, or $null if not found.
    #>
    param (
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$Regex
    )

    foreach ($line in (Get-Content -Path $FilePath)) {
        if ($line -match $Regex) {
            return $line.Trim()
        }
    }

    return $null
}

function Find-TomlKeyInSection {
    <#
    .SYNOPSIS
        Checks if a specific key exists within a specific TOML section.
    #>
    param (
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$TargetSection,
        [Parameter(Mandatory=$true)][string]$Key
    )

    $lines = Get-Content -Path $FilePath
    $inTargetSection = $false
    $sectionWasFound = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # Track if we are inside the target section
        if ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]")) {
            $inTargetSection = ($trimmed -eq $TargetSection)
            if ($inTargetSection) {
                $sectionWasFound = $true
            }
        }
        # If inside the section, check if the key matches
        if ($inTargetSection -and $trimmed -match "^\s*$Key\s*=") {
                return $true
        }
    }

    if (!$sectionWasFound) {
        Write-Error "Section $TargetSection not found in $FilePath"
    }

    return $false
}

function Update-TomlKeyInSection {
    <#
    .SYNOPSIS
        Updates a specific key's value only within a specific TOML section.
    #>
    param (
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$TargetSection,
        [Parameter(Mandatory=$true)][string]$Key,
        [Parameter(Mandatory=$true)][string]$Value
    )

    $lines = Get-Content -Path $FilePath
    $inTargetSection = $false
    $newContent = @()
    $sectionWasFound = $false
    $keyWasUpdated = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]")) {
            $inTargetSection = ($trimmed -eq $TargetSection)
            if ($inTargetSection) {
                $sectionWasFound = $true
            }
            $newContent += $line
            continue
        }

        if ($inTargetSection -and $trimmed -match "^\s*$Key\s*=") {
            # Capture original indentation
            $indent = ""
            if ($line -match "^(\s+)") { $indent = $matches[1] }

            # Replace the line (Note: $Value is inserted exactly as provided)
            $newContent += "${indent}$Key = $Value"
            $keyWasUpdated = $true
        }
        else {
            $newContent += $line
        }
    }

    $newContent | Set-Content -Path $FilePath -Force

    if (!$sectionWasFound) {
        Write-Error "Section $TargetSection not found in $FilePath"
    }

    if (!$keyWasUpdated) {
        Write-Error "Failed to update $Key with value '$Value' in section $TargetSection of $FilePath"
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
$configFile = "$global:ContainerDPath\config.toml"

# Regex for either v1.x or v2.x CNI section (accommodates single or double quotes)
$CNISectionRegex = '^\s*\[plugins\.[''"]io\.containerd\.(grpc\.v1\.cri|cri\.v1\.runtime)[''"]\.cni\]\s*$'
$CNISection = Find-TomlSectionFromRegex -FilePath $configFile -Regex $CNISectionRegex
if ($null -eq $CNISection) {
    Write-Error "Could not find a recognized CNI section in $configFile"
    exit 1
}
Write-Output "Configuring ContainerD CNI section: $CNISection"

# Check for bin_dirs key and update it if present, otherwise update bin_dir key
$hasBinDirs = Find-TomlKeyInSection -FilePath $configFile -TargetSection $CNISection -Key "bin_dirs"
if ($hasBinDirs) {
    # bin_dirs is a list, format the value as a TOML array
    Update-TomlKeyInSection -FilePath $configFile `
                   -TargetSection $CNISection `
                   -Key "bin_dirs" `
                   -Value "['$CNIBinPath']"
} else {
    # bin_dir is a string, format it as a literal TOML string
    Update-TomlKeyInSection -FilePath $configFile `
                   -TargetSection $CNISection `
                   -Key "bin_dir" `
                   -Value "'$CNIBinPath'"
}

# Always update conf_dir key (using single quotes as it is a literal TOML string)
Update-TomlKeyInSection -FilePath $configFile `
               -TargetSection $CNISection `
               -Key "conf_dir" `
               -Value "'$CNIConfigPath'"

mkdir -Force $CNIBinPath | Out-Null
mkdir -Force $CNIConfigPath | Out-Null

Write-Output "Registering ContainerD as a service"
containerd.exe --register-service

Write-Output "Starting ContainerD service"
Start-Service containerd

# Install crictl from the cri-tools project which is required so that kubeadm can talk to the CRI endpoint.
DownloadFile "$global:ContainerDPath\crictl.tar.gz" https://github.com/kubernetes-sigs/cri-tools/releases/download/v$crictlVersion/crictl-v$crictlVersion-windows-amd64.tar.gz
tar.exe -xvf "$global:ContainerDPath\crictl.tar.gz" -C $global:ContainerDPath

# Configure crictl
mkdir -Force "$home\.crictl"
@"
runtime-endpoint: npipe://./pipe/containerd-containerd
image-endpoint: npipe://./pipe/containerd-containerd
"@ | Set-Content "$home\.crictl\crictl.yaml" -Force

Write-Output "Done - please remember to add '--cri-socket `"npipe:////./pipe/containerd-containerd`"' to your kubeadm join command if your kubernetes version is below 1.25!"
