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
PS> .\PrepareNode.ps1 -KubernetesVersion v1.24.2 -ContainerRuntime containerD

#>

Param(
    [parameter(Mandatory = $true, HelpMessage="Kubernetes version to use")]
    [string] $KubernetesVersion,
    [parameter(HelpMessage="Container runtime that Kubernets will use")]
    [ValidateSet("containerD", "Docker")]
    [string] $ContainerRuntime = "Docker"
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

DownloadFile $kubeletBinPath https://dl.k8s.io/$KubernetesVersion/bin/windows/amd64/kubelet.exe
DownloadFile "$global:KubernetesPath\kubeadm.exe" https://dl.k8s.io/$KubernetesVersion/bin/windows/amd64/kubeadm.exe
DownloadFile "$global:KubernetesPath\wins.exe" https://github.com/rancher/wins/releases/download/v0.0.4/wins.exe

if ($ContainerRuntime -eq "Docker") {
    # Create host network to allow kubelet to schedule hostNetwork pods
    # NOTE: For containerd the 0-containerd-nat.json network config template added by
    # Install-containerd.ps1 joins pods to the host network.
    Write-Host "Creating Docker host network"
    docker network create -d nat host
} elseif ($ContainerRuntime -eq "containerD") {
    DownloadFile "c:\k\hns.psm1" https://github.com/Microsoft/SDN/raw/master/Kubernetes/windows/hns.psm1
    Import-Module "c:\k\hns.psm1"
    # TODO(marosset): check if network already exists before creatation
    New-HnsNetwork -Type NAT -Name nat
}

Write-Host "Registering wins service"
wins.exe srv app run --register
start-service rancher-wins

mkdir -force C:\var\log\kubelet
mkdir -force C:\var\lib\kubelet\etc\kubernetes
mkdir -force C:\etc\kubernetes\pki
New-Item -path C:\var\lib\kubelet\etc\kubernetes\pki -type SymbolicLink -value C:\etc\kubernetes\pki\

# dockershim related flags (--image-pull-progress-deadline=20m and --network-plugin=cni)  are removed in k8s v1.24
# Link to changelog: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.24.md

$cmd_commands=@("C:\k\kubelet.exe ", '$global:KubeletArgs ', '--cert-dir=$env:SYSTEMDRIVE\var\lib\kubelet\pki ', "--config=/var/lib/kubelet/config.yaml ", "--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf ", "--kubeconfig=/etc/kubernetes/kubelet.conf ", '--hostname-override=$(hostname) ', '--pod-infra-container-image=`"mcr.microsoft.com/oss/kubernetes/pause:3.6`" ', "--enable-debugging-handlers ", "--cgroups-per-qos=false ", '--enforce-node-allocatable=`"`" ', '--resolv-conf=`"`" ', "--log-dir=/var/log/kubelet ", "--logtostderr=false ")
[version]$CurrentVersion = $($KubernetesVersion.Split("v") | Select -Index 1)
[version]$V1_24_Version = '1.24'
if ($CurrentVersion -lt $V1_24_Version) {
    $cmd_commands = $cmd_commands + "--network-plugin=cni " + "--image-pull-progress-deadline=20m "
}
$StartKubeletFileContent = '$FileContent = Get-Content -Path "/var/lib/kubelet/kubeadm-flags.env"
$global:KubeletArgs = $FileContent.TrimStart(''KUBELET_KUBEADM_ARGS='').Trim(''"'')

$global:containerRuntime = {{CONTAINER_RUNTIME}}

if ($global:containerRuntime -eq "Docker") {
    $netId = docker network ls -f name=host --format "{{ .ID }}"

    if ($netId.Length -lt 1) {
    docker network create -d nat host
    }
}

$cmd = "' + $cmd_commands + '"
Invoke-Expression $cmd'
$StartKubeletFileContent = $StartKubeletFileContent -replace "{{CONTAINER_RUNTIME}}", "`"$ContainerRuntime`""
Set-Content -Path $global:StartKubeletScript -Value $StartKubeletFileContent

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

Write-Output "Please remember that after you have joined the node to the cluster, that you have to apply the cni daemonset/service and the kube-proxy"
Write-Output "Also remember that for kube-proxy you have to change the its version from the name of the image in the kube-proxy.yml to that of your kubernetes version `n"
# rancher commands
Write-Output "In case you use rancher, use the following commands:"
Write-Output "For Windows you can use the following command: "
Write-Output "(Get-Content `"$(git rev-parse --show-toplevel)/kubeadm/kube-proxy/kube-proxy.yml`") -Replace 'VERSION', '$KubernetesVersion' | Set-Content `"$(git rev-parse --show-toplevel)/kubeadm/kube-proxy/kube-proxy.yml`" `n"
Write-Output "For Linux, you can use the following command: "
Write-Output "sed -i 's/VERSION/$KubernetesVersion/g' `$(find `$(git rev-parse --show-toplevel) -iname 'kube-proxy.yml' | grep kubeadm)`n"
# flannel commands
Write-Output "In case you use flannel, use the following commands:"
Write-Output "For Windows you can use the following command: "
Write-Output "(Get-Content `"$(git rev-parse --show-toplevel)/hostprocess/flannel/kube-proxy/kube-proxy.yml`") -Replace 'image: (.*):(.*)-(.*)-(.*)$', 'image: `$1:$KubernetesVersion-`$3-`$4' | Set-Content `"$(git rev-parse --show-toplevel)/hostprocess/flannel/kube-proxy/kube-proxy.yml`" `n"
Write-Output "For Linux, you can use the following command: "
Write-Output "sed -i -E 's/image: (.*):(.*)-(.*)-(.*)$/image: \1:$KubernetesVersion-\3-\4/g' `$(find `$(git rev-parse --show-toplevel) -iname 'kube-proxy.yml' | grep flannel)`n"
# calico commands
Write-Output "In case you use calico, use the following commands:"
Write-Output "For Windows you can use the following command: "
Write-Output "(Get-Content `"$(git rev-parse --show-toplevel)/hostprocess/calico/kube-proxy/kube-proxy.yml`") -Replace 'image: (.*):(.*)-(.*)-(.*)$', 'image: `$1:$KubernetesVersion-`$3-`$4' | Set-Content `"$(git rev-parse --show-toplevel)/hostprocess/calico/kube-proxy/kube-proxy.yml`" `n"
Write-Output "For Linux, you can use the following command: "
# - image: sigwindowstools/kube-proxy:v1.24.2-flannel-hostprocess
Write-Output "sed -i -E 's/image: (.*):(.*)-(.*)-(.*)$/image: \1:$KubernetesVersion-\3-\4/g' `$(find `$(git rev-parse --show-toplevel) -iname 'kube-proxy.yml' | grep calico)`n"
