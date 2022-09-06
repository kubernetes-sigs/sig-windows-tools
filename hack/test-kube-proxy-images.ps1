param (
    [string]$minK8sVersion = "v1.22"
)

# Get kube-proxy images
$content = curl.exe -L registry.k8s.io/v2/kube-proxy/tags/list
$json = ConvertFrom-Json $content

$missingKubeProxyImages = @()

foreach ($tag in $json.tags) {
    if (-not($tag.StartsWith("v"))) {
        continue
    }
    if ($tag.Contains("-")) {
        continue
    }
    if ([Version]($tag.TrimStart('v')) -lt [Version]($minK8sVersion.TrimStart('v'))) {
        continue
    }

    foreach ($flavor in @("-calico-hostprocess", "-flannel-hostprocess")) {
        $image = "sigwindowstools/kube-proxy:$tag$flavor"
        Write-Output "Checking for image $image"
        docker manifest inspect $image | Out-Null
        if ($LastExitCode -ne 0) {
            $missingKubeProxyimages += $image
            Write-Output "  Image $image is missing!"
        }
    }
}

if ($missingKubeProxyImages.Length -gt 0) {
    Write-Output "Found ${$missingKubeProxyImages.Length} missing images!"
    exit 1
}