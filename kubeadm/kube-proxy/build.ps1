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

function Build-KubeProxy([string]$version) 
{
    $config = Get-Content ".\buildconfig.json" | ConvertFrom-Json

    [string[]]$items = @()
    [string[]]$bases = @()
    foreach($tag in $config.tagsMap) 
    {
        $base = "$($config.baseimage):$($tag.source)"
        $current = "$($image):$($version)-$($tag.target)"
        $bases += $base
        $items += $current
        New-Build -name $current -output $output -args @("BASE=$base", "k8sVersion=$version")
    }

    if ($push.IsPresent)
    {
        Push-Manifest -name "$($image):$version" -items $items -bases $bases
    }
}

$versions = (curl -L k8s.gcr.io/v2/kube-proxy/tags/list | ConvertFrom-Json).tags
foreach($version in $versions)
{
    if ($version -match "^v(\d+)\.(\d+)\.(\d+)$")
    {
        [int]$major = $Matches[1]
        [int]$minor = $Matches[2]
        [int]$build = $Matches[3]

        if (($major -gt $minMajor) -or ($major -eq $minMajor -and $minor -gt $minMinor) -or ($major -eq $minMajor -and $minor -eq $minMinor -and $build -ge $minBuild))
        {
            Build-KubeProxy -version $version
        }
    }
}
