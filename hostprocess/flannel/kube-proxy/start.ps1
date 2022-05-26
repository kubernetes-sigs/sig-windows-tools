$ErrorActionPreference = "Stop";

# GetSourceVip is a work around for flannel becuase kubeproxy doesn't setup ipam properly
# https://github.com/kubernetes/kubernetes/issues/96996
# https://github.com/kubernetes/kubernetes/issues/100962#issuecomment-825044781
function GetSourceVip($NetworkName)
{
        mkdir -force c:/sourcevip | Out-Null
        $sourceVipJson = [io.Path]::Combine("c:/", "sourcevip",  "sourceVip.json")
        $sourceVipRequest = [io.Path]::Combine("c:/", "sourcevip", "sourceVipRequest.json")

        if (Test-Path $sourceVipJson) {
                $sourceVipJSONData = Get-Content $sourceVipJson | ConvertFrom-Json
                $vip = $sourceVipJSONData.ip4.ip.Split("/")[0]
                return $vip
        }

        $hnsNetwork = Get-HnsNetwork | ? Name -EQ $NetworkName.ToLower()
        $subnet = $hnsNetwork.Subnets[0].AddressPrefix

        $ipamConfig = @"
        {"cniVersion": "0.2.0", "name": "$NetworkName", "ipam":{"type":"host-local","ranges":[[{"subnet":"$subnet"}]],"dataDir":"/var/lib/cni/networks"}}
"@

        Write-Host "ipam sourcevip request: $ipamConfig"
        $ipamConfig | Out-File $sourceVipRequest

        $env:CNI_COMMAND="ADD"
        $env:CNI_CONTAINERID="dummy"
        $env:CNI_NETNS="dummy"
        $env:CNI_IFNAME="dummy"
        $env:CNI_PATH="c:\opt\cni\bin" #path to host-local.exe

        # reserve an ip address for source VIP, a requirement for kubeproxy in overlay mode
        Get-Content $sourceVipRequest | c:/opt/cni/bin/host-local.exe | Out-File $sourceVipJson

        Remove-Item env:CNI_COMMAND
        Remove-Item env:CNI_CONTAINERID
        Remove-Item env:CNI_NETNS
        Remove-Item env:CNI_IFNAME
        Remove-Item env:CNI_PATH

        $sourceVipJSONData = Get-Content $sourceVipJson | ConvertFrom-Json
        $vip = $sourceVipJSONData.ip4.ip.Split("/")[0]
        return $vip
}

# This is a workaround since the go-client doesn't know about the path $env:CONTAINER_SANDBOX_MOUNT_POINT
# go-client is going to be address in a future release:
#   https://github.com/kubernetes/kubernetes/pull/104490
# We could address this in kubeamd as well: 
#   https://github.com/kubernetes/kubernetes/blob/9f0f14952c51e7a5622eac05c541ba20b5821627/cmd/kubeadm/app/phases/addons/proxy/manifests.go
Write-Host "Write files so the kubeconfig points to correct locations"
mkdir -force /var/lib/kube-proxy/
((Get-Content -path $env:CONTAINER_SANDBOX_MOUNT_POINT/var/lib/kube-proxy/kubeconfig.conf -Raw) -replace '/var',"$($env:CONTAINER_SANDBOX_MOUNT_POINT)/var") | Set-Content -Path $env:CONTAINER_SANDBOX_MOUNT_POINT/var/lib/kube-proxy/kubeconfig.conf
cp $env:CONTAINER_SANDBOX_MOUNT_POINT/var/lib/kube-proxy/kubeconfig.conf /var/lib/kube-proxy/kubeconfig.conf

Write-Host "Finding sourcevip"
$vip = GetSourceVip -NetworkName $env:KUBE_NETWORK 
Write-Host "sourceip: $vip"

$arguements = "--v=6",
        "--hostname-override=$env:NODE_NAME",
        "--proxy-mode=kernelspace",
        "--source-vip=$vip",  
        "--kubeconfig=$env:CONTAINER_SANDBOX_MOUNT_POINT/var/lib/kube-proxy/kubeconfig.conf"

$exe = "$env:CONTAINER_SANDBOX_MOUNT_POINT/kube-proxy/kube-proxy.exe " + ($arguements -join " ")

Write-Host "Starting $exe"
Invoke-Expression $exe


