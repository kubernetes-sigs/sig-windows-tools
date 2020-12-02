if (Get-Service kubelet -ErrorAction Ignore) {
    Stop-Service kubelet
    sc.exe delete kubelet
}
if (Get-Service rancher-wins -ErrorAction Ignore) {
    Stop-Service rancher-wins
    sc.exe delete rancher-wins
}
if (Get-Service docker -ErrorAction Ignore) {
    Restart-Service docker
}
if (Get-Service containerd -ErrorAction Ignore) {
    Restart-Service containerd
}
del /etc -Recurse -Force
del /opt -Recurse -Force
del /run -Recurse -Force
del /var -Recurse -Force
del /k/flannel -Recurse -Force
del /k/kube-proxy -Recurse -Force
del /k/*.exe
del /k/StartKubelet.ps1
Get-HnsNetwork | ?{ $_.type -eq "L2Bridge" } | Remove-HnsNetwork
Get-HnsNetwork | ?{ $_.type -eq "Overlay" } | Remove-HnsNetwork
