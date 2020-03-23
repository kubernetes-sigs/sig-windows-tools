# Windows updates cause the node to reboot at arbitrary times.
& sc.exe config wuauserv start=disabled
& sc.exe stop wuauserv

# tell windows defender to allow netcat, which is needed by the e2e tests
# https://www.microsoft.com/en-us/wdsi/threats/malware-encyclopedia-description?Name=HackTool:Win32/NetCat&ThreatID=2147593673
while($true) {
    if ((Get-Service -Name WinDefend).Status -Eq "Running") {
        Add-MpPreference -ThreatIDDefaultAction_Ids 2147593673 -ThreatIDDefaultAction_Actions 6
        break
    }
}

curl.exe -sLO https://github.com/kubernetes-sigs/sig-windows-tools/releases/latest/download/PrepareNode.ps1
.\PrepareNode.ps1 -KubernetesVersion VERSION

$kubeadmJoinCommand=$(curl.exe -s http://metadata.google.internal/computeMetadata/v1/instance/attributes/join_cmd -H "Metadata-Flavor: Google")

Invoke-Expression $kubeadmJoinCommand

