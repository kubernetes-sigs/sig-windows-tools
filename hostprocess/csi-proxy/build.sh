#!/bin/bash
set -x

if [[ -z "${version}" ]]; then
    echo "Required env var 'version' is not set"
    exit 1
fi
echo "Using version ${version}"

repository=${repository:-"ghcr.io/kubernetes-sigs/sig-windows"}

docker buildx create --name img-builder --use --platform windows/amd64
trap 'docker buildx rm img-builder' EXIT

docker buildx build --platform windows/amd64 --output=type=registry -f Dockerfile.windows --build-arg=WINDOWS_VERSION=1809 -t ${repository}/csi-proxy:${version}-1809 .
docker buildx build --platform windows/amd64 --output=type=registry -f Dockerfile.windows --build-arg=WINDOWS_VERSION=ltsc2022 -t ${repository}/csi-proxy:${version}-ltsc2022 .

docker manifest create ${repository}/csi-proxy:${version} ${repository}/csi-proxy:${version}-1809 ${repository}/csi-proxy:${version}-ltsc2022

os_version_1809=$(docker manifest inspect mcr.microsoft.com/windows/nanoserver:1809 | grep "os.version" | head -n 1 | awk -F\" '{print $4}')
docker manifest annotate --os windows --arch amd64 --os-version $os_version_1809 $repository/csi-proxy:$version $repository/csi-proxy:$version-1809

os_version_ltsc2022=$(docker manifest inspect mcr.microsoft.com/windows/nanoserver:ltsc2022 | grep "os.version" | head -n 1 | awk -F\" '{print $4}')
docker manifest annotate --os windows --arch amd64 --os-version $os_version_ltsc2022 $repository/csi-proxy:$version $repository/csi-proxy:$version-ltsc2022

docker manifest inspect $repository/csi-proxy:$version
docker manifest push ${repository}/csi-proxy:${version}
