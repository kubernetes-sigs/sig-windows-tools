param(
    [switch] $push, 
    [string] $image = "sigwindowstools/flannel",
    [string] $tagSuffix = ""
)

$output="docker"
if ($push.IsPresent) {
    $output="registry"
}

Import-Module "../buildx.psm1"
Set-Builder

$config = Get-Content .\buildconfig.json | ConvertFrom-Json
foreach ($flannel in $config.flannel)
{
    Write-Host "Build images for flannel version: $flannel"

    [string[]]$items = @()
    [string[]]$bases = @()
    foreach($tag in $config.tagsMap) 
    {
        $base = "$($config.baseimage):$($tag.source)"
        $current = "$($image):v$($flannel)-$($tag.target)$($tagSuffix)"
        $bases += $base
        $items += $current
        New-Build -name $current -output $output -args @("BASE=$base", "flannelVersion=$flannel")
    }

    if ($push.IsPresent)
    {
        Push-Manifest -name "$($image):v$flannel" -items $items -bases $bases
    }
}
