param(
    [string]$image = "sigwindowstools/kube-proxy",
    [switch]$push,
    [version]$minVersion = "1.17.0"
)

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
        Push-Manifest -name "$($image):$version-nanoserver" -items $items -bases $bases
    }
}

$versions = (curl -L k8s.gcr.io/v2/kube-proxy/tags/list | ConvertFrom-Json).tags
foreach($version in $versions)
{
    if ($version -match "^v(\d+\.\d+\.\d+)$")
    {
        $testVersion = [version]$Matches[1]
        if ($testVersion -ge $minVersion)
        {
            Write-Host "Build $($image):$($version)"
            Build-KubeProxy -version $version
        }
        else
        {
            Write-Host "Skip $version because it less than $minVersion."
        }
    }
    else
    {
        Write-Host "Skip $version because it isn't release version."
    }
}
