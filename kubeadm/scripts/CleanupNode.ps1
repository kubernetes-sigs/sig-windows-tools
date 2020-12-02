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
Stop-Process -Name rancher-wins* -Force
Get-HnsNetwork | ?{ $_.type -eq "L2Bridge" } | Remove-HnsNetwork
Get-HnsNetwork | ?{ $_.type -eq "Overlay" } | Remove-HnsNetwork

del /etc -Recurse -Force | out-null
del /opt -Recurse -Force | out-null
del /run -Recurse -Force | out-null
cmd /c rmdir c:\var /S /Q | out-null
del /k/flannel -Recurse -Force | out-null
del /k/kube-proxy -Recurse -Force | out-null
del /k/*.exe | out-null
del /k/StartKubelet.ps1 | out-null

Write-Host "Please restart computer to complete node cleanup."