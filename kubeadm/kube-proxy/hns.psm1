# get surce vip
function Get-SourceVip()
{
    param(
        [parameter(Mandatory = $false)] [string] $NetworkName
    )
    
    $hnsNetwork = Get-HnsNetwork | ? Name -EQ $NetworkName.ToLower()
    $subnet = $hnsNetwork.Subnets[0].AddressPrefix

    $ipamConfig = @"
{"cniVersion": "0.2.0", "name": "$NetworkName", "ipam":{"type":"host-local","ranges":[[{"subnet":"$subnet"}]],"dataDir":"/var/lib/cni/networks"}}
"@

    $ipamConfig | Out-File "c:\k\sourceVipRequest.json"

    $env:CNI_COMMAND="ADD"
    $env:CNI_CONTAINERID="dummy"
    $env:CNI_NETNS="dummy"
    $env:CNI_IFNAME="dummy"
    $env:CNI_PATH="c:\opt\cni\bin" #path to host-local.exe

    cd $env:CNI_PATH
    If(!(Test-Path c:\k\sourceVip.json)){
        Get-Content c:\k\sourceVipRequest.json | .\host-local.exe | Out-File "c:\k\sourceVip.json"
    }

    Remove-Item env:CNI_COMMAND
    Remove-Item env:CNI_CONTAINERID
    Remove-Item env:CNI_NETNS
    Remove-Item env:CNI_IFNAME
    Remove-Item env:CNI_PATH

}

Export-ModuleMember -Function Get-SourceVip
