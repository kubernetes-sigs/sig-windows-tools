param(
    [string]$image = "sigwindowstools/kube-proxy",
    [switch]$push
)

[int]$minMajor = 1
[int]$minMinor = 17
[int]$minBuild = 0

$output="docker"
if ($push.IsPresent) {
    $output="registry"
}

Import-Module "../buildx.psm1"
Set-Builder

function Build-KubeProxy([string]$tag) 
{
    $config = Get-Content ".\buildconfig.json" | ConvertFrom-Json
    $base = $config.baseimage

    [string[]]$items = @()
    [string[]]$bases = @()
    foreach($map in $config.tagsMap) 
    {
        $bases += "$($base):$($map.source)"
        $current = "$($image):$tag-$($map.target)"
        $items += $current
        New-Build -name $current -output $output -args @("BASE=$($base):$($map.source)", "k8sVersion=$tag")
    }

    if ($push.IsPresent)
    {
        Push-Manifest -name "$($image):$tag" -items $items -bases $bases
    }

    Write-Host
}

$tags = (curl -L k8s.gcr.io/v2/kube-proxy/tags/list | ConvertFrom-Json).tags
foreach($tag in $tags)
{
    if ($tag -match "^v(\d+)\.(\d+)\.(\d+)$")
    {
        [int]$major = $Matches[1]
        [int]$minor = $Matches[2]
        [int]$build = $Matches[3]

        if (($major -gt $minMajor) -or ($major -eq $minMajor -and $minor -gt $minMinor) -or ($major -eq $minMajor -and $minor -eq $minMinor -and $build -ge $minBuild))
        {
            Build-KubeProxy -tag $tag
        }
    }
}
