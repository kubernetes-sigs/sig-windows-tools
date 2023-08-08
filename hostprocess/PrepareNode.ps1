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

.PARAMETER HostnameOverride
Overrides the hostname for kubeadm. Defaults to the value determined by the hostname command.

.EXAMPLE
PS> .\PrepareNode.ps1 -KubernetesVersion v1.25.3

#>

Param(
    [parameter(Mandatory = $true, HelpMessage="Kubernetes version to use")]
    [string] $KubernetesVersion,
    [parameter(HelpMessage="Hostname override for kubeadm")]
    [string] $HostnameOverride = "$(hostname)"
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

if (-not(Test-Path "//./pipe/containerd-containerd")) {
    Write-Error "ContainerD service was not detected - please install and start containerD before calling PrepareNode.ps1 with -ContainerRuntime containerD"
    exit 1
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

$kubeletLogPath = "C:\var\log\kubelet"
mkdir -force $kubeletLogPath
mkdir -force C:\var\lib\kubelet\etc\kubernetes
mkdir -force C:\etc\kubernetes\pki
mkdir -Force c:\etc\kubernetes\manifests
New-Item -path C:\var\lib\kubelet\etc\kubernetes\pki -type SymbolicLink -value C:\etc\kubernetes\pki\

# dockershim related flags (--image-pull-progress-deadline=20m and --network-plugin=cni)  are removed in k8s v1.24
# Link to changelog: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.24.md

$cmd_commands=@("C:\k\kubelet.exe ", '$global:KubeletArgs ', '--cert-dir=$env:SYSTEMDRIVE\var\lib\kubelet\pki ', "--config=/var/lib/kubelet/config.yaml ", "--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf ", "--kubeconfig=/etc/kubernetes/kubelet.conf ", "--hostname-override=$HostnameOverride ", '--pod-infra-container-image=`"mcr.microsoft.com/oss/kubernetes/pause:3.6`" ', "--enable-debugging-handlers ", "--cgroups-per-qos=false ", '--enforce-node-allocatable=`"`" ', '--resolv-conf=`"`" ')
[version]$CurrentVersion = $($KubernetesVersion.Split("v") | Select -Index 1)
[version]$V1_24_Version = '1.24'
if ($CurrentVersion -lt $V1_24_Version) {
    $cmd_commands = $cmd_commands + "--network-plugin=cni " + "--image-pull-progress-deadline=20m "
}
[version]$V1_26_Version = '1.26'
if ($CurrentVersion -lt $V1_26_Version) {
    $cmd_commands += ("--log-dir=/var/log/kubelet ", "--logtostderr=false ")
}

$StartKubeletFileContent = '$FileContent = Get-Content -Path "/var/lib/kubelet/kubeadm-flags.env"
$global:KubeletArgs = $FileContent.TrimStart(''KUBELET_KUBEADM_ARGS='').Trim(''"'')

$cmd = "' + $cmd_commands + '"
Invoke-Expression $cmd'
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
nssm set kubelet AppStdout $kubeletLogPath\kubelet.out.log
nssm set kubelet AppStderr $kubeletLogPath\kubelet.err.log

# Configure online file rotation.
nssm set kubelet AppRotateFiles 1
nssm set kubelet AppRotateOnline 1
# Rotate once per day.
nssm set kubelet AppRotateSeconds 86400
# Rotate after 10MB.
nssm set kubelet AppRotateBytes 10485760

nssm set kubelet DependOnService containerd

New-NetFirewallRule -Name kubelet -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250

$repoUrl='https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master'

Write-Output "Please remember that after you have joined the node to the cluster, that you have to apply the cni daemonset/service and the kube-proxy"
Write-Output "Also remember that for kube-proxy you have to change the its version from the name of the image in the kube-proxy.yml to that of your kubernetes version `n"
# rancher commands
Write-Output "In case you use rancher, use the following commands:"
Write-Output "For Windows you can use the following command: "
Write-Output "curl.exe -LO $repoUrl/kubeadm/kube-proxy/kube-proxy.yml"
Write-Output "(Get-Content `"kube-proxy.yml`") -Replace 'VERSION', '$KubernetesVersion' | Set-Content `"kube-proxy.yml`" `n"
Write-Output "For Linux, you can use the following command: "
Write-Output "curl -LO $repoUrl/kubeadm/kube-proxy/kube-proxy.yml"
Write-Output "sed -i 's/VERSION/$KubernetesVersion/g' `kube-proxy.yml`n"
# flannel commands
Write-Output "In case you use flannel, use the following commands:"
Write-Output "For Windows you can use the following command: "
Write-Output "curl.exe -LO $repoUrl/hostprocess/flannel/kube-proxy/kube-proxy.yml"
Write-Output "(Get-Content `"kube-proxy.yml`") -Replace 'image: (.*):(.*)-(.*)-(.*)$', 'image: `$1:$KubernetesVersion-`$3-`$4' | Set-Content `"kube-proxy.yml`" `n"
Write-Output "For Linux, you can use the following command: "
Write-Output "curl -LO $repoUrl/hostprocess/flannel/kube-proxy/kube-proxy.yml"
Write-Output "sed -i -E 's/image: (.*):(.*)-(.*)-(.*)$/image: \1:$KubernetesVersion-\3-\4/g' `kube-proxy.yml`n"
# calico commands
Write-Output "In case you use calico, use the following commands:"
Write-Output "For Windows you can use the following command: "
Write-Output "curl.exe -LO $repoUrl/hostprocess/calico/kube-proxy/kube-proxy.yml"
Write-Output "(Get-Content `"kube-proxy.yml`") -Replace 'image: (.*):(.*)-(.*)-(.*)$', 'image: `$1:$KubernetesVersion-`$3-`$4' | Set-Content `"kube-proxy.yml`" `n"
Write-Output "For Linux, you can use the following command: "
# - image: sigwindowstools/kube-proxy:v1.24.2-flannel-hostprocess
Write-Output "curl -LO $repoUrl/hostprocess/calico/kube-proxy/kube-proxy.yml"
Write-Output "sed -i -E 's/image: (.*):(.*)-(.*)-(.*)$/image: \1:$KubernetesVersion-\3-\4/g' `kube-proxy.yml`n"
