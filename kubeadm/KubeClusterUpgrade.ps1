<#
.SYNOPSIS
Utility script to assist in upgrading of Kubernetes Windows worker Nodes

.PARAMETER KubeVersion
Kubernetes version to upgrade to. For example, 'v1.17.0'

.EXAMPLE
PS> .\KubeClusterUpgrade.ps1 -help
Prints this help

.EXAMPLE
PS> .\KubeClusterUpgrade.ps1 -KubeVersion v1.17.0
Upgrade this Windows worker Node to v1.17.0

.LINK
https://github.com/kubernetes-sigs/sig-windows-tools/tree/master/kubeadm
#>

Param(
    [parameter(Mandatory = $false,HelpMessage="Print the help")]
    [switch] $help,
    [parameter(Mandatory = $false,HelpMessage="Kubernetes version to upgrade to. For example, 'v1.17.0'")]
    $KubeVersion
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


$helperPath = "$PSScriptRoot\KubeClusterHelper.psm1"
Import-Module $helperPath

if (($KubeVersion -eq "") -or ($KubeVersion -eq $null))
{
    Write-Host "the parameter '-KubeVersion' is mandatory. See '-help'"
    exit
}

function DownloadKubeBinary()
{
    param(
    [parameter(Mandatory = $true)] $Name,
    [parameter(Mandatory = $true)] $DestinationPath
    )
    Write-Host "# Downloading $Name binary..."
    DownloadFile -Url https://dl.k8s.io/$KubeVersion/bin/windows/amd64/$Name.exe -Destination $DestinationPath/$Name.exe
}

function UpgradeKubeBinary()
{
    param(
    [parameter(Mandatory = $true)] $Name,
    [parameter(Mandatory = $true)] $SourcePath
    )
    $DestinationPath = (get-command "$Name.Exe" -ErrorAction Stop).Source
    Write-Host "# Upgrading $Name binary..."
    Move-Item -Path $SourcePath/$Name.exe -Destination $DestinationPath -Force
}

Write-Host "# Will now upgrade this Kubernetes Node to version '$KubeVersion'"

$tmpPath = [System.IO.Path]::GetTempPath()

# Upgrade kubeadm

DownloadKubeBinary -Name "kubeadm" -DestinationPath $tmpPath
UpgradeKubeBinary -Name "kubeadm" -SourcePath $tmpPath
Write-Host "# Executing 'kubeadm upgrade node'"
cmd /c kubeadm upgrade node

# Upgrade kube-proxy

DownloadKubeBinary -Name "kube-proxy" -DestinationPath $tmpPath
Stop-Service kubeproxy
UpgradeKubeBinary -Name "kube-proxy" -SourcePath $tmpPath
Start-Service kubeproxy -ErrorAction Stop

# Upgrade kubelet

DownloadKubeBinary -Name "kubelet" -DestinationPath $tmpPath
Stop-Service kubelet
UpgradeKubeBinary -Name "kubelet" -SourcePath $tmpPath
Start-Service kubelet -ErrorAction Stop

Write-Host "Done!"
