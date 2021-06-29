<#
Copyright 2021 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>

<#
.SYNOPSIS
Assists with preparing a Windows VM prior to calling kubeadm join

.DESCRIPTION
This script assists with joining a Windows node to a cluster.
- Downloads Kubernetes binaries (kubelet, kubeadm) at the version specified
- Registers wins as a service in order to run kube-proxy and cni as DaemonSets.
- Registers kubelet as an nssm service. More info on nssm: https://nssm.cc/

.PARAMETER KubernetesVersion
Kubernetes version to download and use

.PARAMETER ContainerRuntime
Container that Kubernetes will use. (Docker or containerD)

.EXAMPLE
PS> .\PrepareNode.ps1 -KubernetesVersion v1.19.3 -ContainerRuntime containerD

#>

Param(
    [parameter(HelpMessage="Kubernetes version to use", Mandatory = $false)]
    [string] $KubernetesVersion = "1.21.0",

    [parameter(HelpMessage="Container runtime that Kubernets will use")]
    [ValidateSet("containerD", "Docker")]
    [string] $ContainerRuntime = "Docker",

    # This is a modifcation for the windows-dev-tools where we
    # OVERWRITE the WINDOWS kubelet AND kubeadm BINARY.
    [parameter(HelpMessage="Allows to overwrite bins with self-built ones")]
    [switch] $OverwriteBins
)
$ErrorActionPreference = 'Stop'
Write-Output "Overwriting bins is set to '$OverwriteBins'"

function DownloadFile($destination, $source) {
    if (Test-Path -Path $destination) {
        Write-Host("Skipping download to avoid overwriting, already found on disk...")
        return
    }
    else {
        Write-Host("Downloading $source to $destination")
        curl.exe --silent --fail -Lo $destination $source

        if (!$?) {
            Write-Error "Download $source failed"
            exit 1
        }
    }
}

if ($ContainerRuntime -eq "Docker") {
    if (-not(Test-Path "//./pipe/docker_engine")) {
        Write-Error "Docker service was not detected - please install start Docker before calling PrepareNode.ps1 with -ContainerRuntime Docker"
        exit 1
    }
} elseif ($ContainerRuntime -eq "containerD") {
    if (-not(Test-Path "//./pipe/containerd-containerd")) {
        Write-Error "ContainerD service was not detected - please install and start containerD before calling PrepareNode.ps1 with -ContainerRuntime containerD"
        exit 1
    }
}

if (!$KubernetesVersion.StartsWith("v")) {
    $KubernetesVersion = "v" + $KubernetesVersion
}
Write-Host "Using Kubernetes version: $KubernetesVersion"
$global:Powershell = (Get-Command powershell).Source
$global:PowershellArgs = "-ExecutionPolicy Bypass -NoProfile"
$global:KubernetesPath = "$env:SystemDrive\k"
$global:StartKubeletScript = "$global:KubernetesPath\StartKubelet.ps1"
$global:NssmInstallDirectory = "$env:ProgramFiles\nssm"
$kubeletBinPath = "$global:KubernetesPath\kubelet.exe"

mkdir -force "$global:KubernetesPath"
$env:Path += ";$global:KubernetesPath"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)

# DownloadFile $kubeletBinPath https://dl.k8s.io/$KubernetesVersion/bin/windows/amd64/kubelet.exe
# We replaced this ↑ with ↓
Write-Output "Deciding source to use for Kubelet.exe ..."
$SelfBuiltKubeletSource = "C:\sync\windows\bin\kubelet.exe"
if ((Test-Path -Path $SelfBuiltKubeletSource -PathType Leaf) -and ($OverwriteBins)) {
    New-Item -ItemType File -Path $kubeletBinPath -Force
    Write-Output "Found $SelfBuiltKubeletSource, copyin ..."
    Copy-Item  $SelfBuiltKubeletSource -Destination $kubeletBinPath -Force
} else {
    Write-Output "Didn't find $SelfBuiltKubeletSource, downloading ..."
    DownloadFile $kubeletBinPath https://dl.k8s.io/$KubernetesVersion/bin/windows/amd64/kubelet.exe
}

# Copying the self-built bins to windows
# TODO does this even overwrite the kube-proxy.exe? where does kube-proxy.exe come from if we dont copy it here?
$SelfBuiltKubeProxySource = "C:\sync\windows\bin\kube-proxy.exe"
$KubeProxyPath = "C:\k\bin\kube-proxy.exe"
if ($OverwriteBins) {
    New-Item -ItemType File -Path $KubeProxyPath -Force
    Write-Output "Copying $SelfBuiltKubeletPath"
    Copy-Item  $SelfBuiltKubeProxySource  -Destination $KubeProxyPath -Force
}

DownloadFile "$global:KubernetesPath\kubeadm.exe" https://dl.k8s.io/$KubernetesVersion/bin/windows/amd64/kubeadm.exe

if ($ContainerRuntime -eq "Docker") {
    # Create host network to allow kubelet to schedule hostNetwork pods
    # NOTE: For containerd the 0-containerd-nat.json network config template added by
    # Install-containerd.ps1 joins pods to the host network.
    Write-Host "Creating Docker host network"
    docker network create -d nat host
} elseif ($ContainerRuntime -eq "containerD") {
    DownloadFile "C:\k\hns.psm1" https://github.com/Microsoft/SDN/raw/master/Kubernetes/windows/hns.psm1
    Import-Module "C:\k\hns.psm1"
    # TODO(marosset): check if network already exists before creatation
    New-HnsNetwork -Type NAT -Name nat
}

# Who needs wins were on the cusp of priveliged containers
# Write-Host "Registering wins service"
# wins.exe srv app run --register
# start-service rancher-wins

mkdir -force C:\var\log\kubelet
mkdir -force C:\var\lib\kubelet\etc\kubernetes
mkdir -force C:\etc\kubernetes\pki
New-Item -force -path C:\var\lib\kubelet\etc\kubernetes\pki -type SymbolicLink -value C:\etc\kubernetes\pki\

$StartKubeletFileContent = '$FileContent = Get-Content -Path "/var/lib/kubelet/kubeadm-flags.env"
$global:KubeletArgs = $FileContent.TrimStart(''KUBELET_KUBEADM_ARGS='').Trim(''"'')

$global:containerRuntime = {{CONTAINER_RUNTIME}}

# TODO: This is useless because we only support containerd in this repo.
# Lets delete at some point upstream and delete this also
if ($global:containerRuntime -eq "Docker") {
    $netId = docker network ls -f name=host --format "{{ .ID }}"

    if ($netId.Length -lt 1) {
    docker network create -d nat host
    }
}

$cmd = "C:\k\kubelet.exe $global:KubeletArgs --cert-dir=$env:SYSTEMDRIVE\var\lib\kubelet\pki --config=/var/lib/kubelet/config.yaml --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --hostname-override=$(hostname) --pod-infra-container-image=`"mcr.microsoft.com/oss/kubernetes/pause:1.4.1`" --enable-debugging-handlers --cgroups-per-qos=false --enforce-node-allocatable=`"`" --network-plugin=cni --resolv-conf=`"`" --log-dir=/var/log/kubelet --logtostderr=false --image-pull-progress-deadline=20m"

Invoke-Expression $cmd'
$StartKubeletFileContent = $StartKubeletFileContent -replace "{{CONTAINER_RUNTIME}}", "`"$ContainerRuntime`""
Set-Content -Path $global:StartKubeletScript -Value $StartKubeletFileContent
Write-Host "KUBEADM INITIAL FILE CONTENTS............"
Write-Host $StartKubeletFileContent


Write-Host "Installing nssm"
$arch = "win32"
if ([Environment]::Is64BitOperatingSystem) {
    $arch = "win64"
}

mkdir -Force $global:NssmInstallDirectory
DownloadFile nssm.zip https://k8stestinfrabinaries.blob.core.windows.net/nssm-mirror/nssm-2.24.zip
tar C $global:NssmInstallDirectory -xvf .\nssm.zip --strip-components 2 */$arch/*.exe
Remove-Item -Force .\nssm.zip

$env:path += ";$global:NssmInstallDirectory"
$newPath = "$global:NssmInstallDirectory;" +
[Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)

[Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::Machine)

Write-Host "Registering kubelet service"
nssm install kubelet $global:Powershell $global:PowershellArgs $global:StartKubeletScript

if ($ContainerRuntime -eq "Docker") {
    nssm set kubelet DependOnService docker
} elseif ($ContainerRuntime -eq "containerD") {
    nssm set kubelet DependOnService containerd
}

New-NetFirewallRule -Name kubelet -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250
