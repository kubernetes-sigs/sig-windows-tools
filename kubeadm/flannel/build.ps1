param(
    [switch] $push, 
    [string] $image = "sigwindowstools/flannel"
)

$output="docker"
if ($push.IsPresent) {
    $output="registry"
}

Import-Module "../buildx.psm1"
Set-Builder

$config = Get-Content .\buildconfig.json | ConvertFrom-Json
$base = $config.baseimage # should be `mcr.microsoft.com/powershell`
foreach ($flannel in $config.flannel)
{
    Write-Host "Build images for flannel version: $flannel"

    [string[]]$items = @()
    [string[]]$bases = @()
    foreach($map in $config.tagsMap) 
    {
        $bases += "$($base):$($map.source)"
        $current = "$($image):$flannel-$($map.target)"
        $items += $current
        New-Build -name $current -output $output -args @("BASE=$($base):$($map.source)", "flannelVersion=$flannel")
    }

    if ($push.IsPresent)
    {
        Push-Manifest -name "$($image):$flannel" -items $items -bases $bases
    }

    Write-Host
}
