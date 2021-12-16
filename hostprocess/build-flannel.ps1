param(
    [string]$repository = "sigwindowstools",
    [version]$minFlannelVersion = "0.12.0",
    [version]$minK8sVersion = "1.22.0"
)

pushd flannel
write-host "build flannel"
pushd flanneld
$flannelVersions = (curl -L https://api.github.com/repos/flannel-io/flannel/releases | ConvertFrom-Json) | % tag_name
foreach($flannelVersion in $flannelVersions)
{
    if ($flannelVersion -match "^v(\d+\.\d+\.\d+)$")
    {
        $testVersion = [version]$Matches[1]
        if ($testVersion -ge $minFlannelVersion)
        {
            Write-Host "Build images for flannel $flannelVersion"
            docker buildx build --platform windows/amd64 --output=type=registry --pull --build-arg=flannelVersion=$flannelVersion -f Dockerfile -t $repository/flannel:$flannelVersion-hostprocess .
        }
    }
}
popd

write-host "build kube-proxy"
pushd kube-proxy
$versions = (curl -L k8s.gcr.io/v2/kube-proxy/tags/list | ConvertFrom-Json).tags
foreach($version in $versions)
{
    if ($version -match "^v(\d+\.\d+\.\d+)$")
    {
        $testVersion = [version]$Matches[1]
        if ($testVersion -ge $minK8sVersion)
        {
            Write-Host "Build image for kube-proxy $version"
            docker buildx build --platform windows/amd64 --output=type=registry --pull --build-arg=k8sVersion=$version -f Dockerfile -t $repository/kube-proxy:$version-flannel-hostprocess .
        }
    }
}
popd

popd
