$global:Powershell = (Get-Command powershell).Source
$global:PowershellArgs = "-ExecutionPolicy Bypass -NoProfile"
$global:KubernetesPath = "$env:SystemDrive\k"
$global:StartKubeletScript = "$global:KubernetesPath\StartKubelet.ps1"
$kubeletBinPath = "$global:KubernetesPath\kubelet.exe"

mkdir -force "$global:KubernetesPath"
$env:Path += ";$global:KubernetesPath"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)

curl.exe -Lo $kubeletBinPath https://dl.k8s.io/v1.17.0/bin/windows/amd64/kubelet.exe
curl.exe -Lo "$global:KubernetesPath\kubeadm.exe" https://dl.k8s.io/v1.17.0/bin/windows/amd64/kubeadm.exe
curl.exe -Lo "$global:KubernetesPath\wins.exe" https://github.com/rancher/wins/releases/download/v0.0.4/wins.exe

#Create host network to allow kubelet to schedule hostNetwork pods
docker network create -d nat host

wins.exe srv app run --register
start-service rancher-wins

mkdir -force C:\var\log\kubelet
mkdir -force C:\var\lib\kubelet\etc\kubernetes
mkdir -force C:\etc\kubernetes\pki
New-Item -path C:\var\lib\kubelet\etc\kubernetes\pki -type SymbolicLink -value C:\etc\kubernetes\pki\

cp $PSScriptRoot/StartKubelet.ps1 $global:StartKubeletScript
nssm install kubelet $global:Powershell $global:PowershellArgs $global:StartKubeletScript
nssm set kubelet DependOnService docker

New-NetFirewallRule -Name kubelet -DisplayName 'kubelet' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 10250
