# Windows updates cause the node to reboot at arbitrary times.
& sc.exe config wuauserv start=disabled
& sc.exe stop wuauserv

curl.exe -sLO https://github.com/kubernetes-sigs/sig-windows-tools/releases/latest/download/PrepareNode.ps1
.\PrepareNode.ps1 -KubernetesVersion VERSION

$kubeadmJoinCommand=$(curl.exe -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/join_cmd -H "Metadata-Flavor: Google")

Invoke-Expression $kubeadmJoinCommand

