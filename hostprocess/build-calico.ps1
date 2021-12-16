param(
    [string]$repository = "sigwindowstools",
    [version]$minCalicoVersion = "3.19.0",
    [version]$minK8sVersion = "1.22.0"
)

pushd calico
write-host "build calico"
$calicoVersions = (curl -L https://api.github.com/repos/projectcalico/calico/releases | ConvertFrom-Json) | % tag_name
foreach($calicoVersion in $calicoVersions)
{
    if ($calicoVersion -match "^v(\d+\.\d+\.\d+)$")
    {
        $testVersion = [version]$Matches[1]
        if ($testVersion -ge $minCalicoVersion)
        {
            Write-Host "Build images for calico $calicoVersion"
            pushd install
            docker buildx build --platform windows/amd64 --output=type=registry --pull --build-arg=CALICO_VERSION=$calicoVersion -f Dockerfile.install -t $repository/calico-install:$calicoVersion-hostprocess .
            popd
            pushd node
            docker buildx build --platform windows/amd64 --output=type=registry --pull --build-arg=CALICO_VERSION=$calicoVersion -f Dockerfile.node -t $repository/calico-node:$calicoVersion-hostprocess .
            popd
        }
    }
}


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
            docker buildx build --platform windows/amd64 --output=type=registry --pull --build-arg=k8sVersion=$version -f Dockerfile -t $repository/kube-proxy:$version-calico-hostprocess .
        }
    }
}
popd

popd
