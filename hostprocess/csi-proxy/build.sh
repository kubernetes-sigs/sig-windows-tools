#!/bin/bash
set -e

args=$(getopt -o v:p -l version:,push -- "$@")
eval set -- "$args"

while [ $# -ge 1 ]; do
  case "$1" in
    --)
      shift
      break
      ;;
    -v|--version)
      version="$2"
      shift 
      ;;
    -p|--push)
      push="1"
      shift
      ;;
  esac
  shift
done

if [[ -z "$version" ]]; then
  echo "--version is required"
  exit 1
fi
echo "Using version ${version}"

output="type=docker,dest=./export.tar"

if [[ "$push" == "1" ]]; then
  output="type=registry"
fi

repository=${repository:-"ghcr.io/kubernetes-sigs/sig-windows"}

set -x

docker buildx create --name img-builder --use --platform windows/amd64
trap 'docker buildx rm img-builder' EXIT


declare -a win_vers=("1809" "ltsc2022")

manifest_entries=""

# Build container images with buildx
for win_ver in "${win_vers[@]}"; do
  docker buildx build --platform windows/amd64 --output=$output -f Dockerfile.windows --build-arg=WINDOWS_VERSION=$win_ver -t ${repository}/csi-proxy:${version}-$win_ver .

  manifest_entries="$manifest_entries ${repository}/csi-proxy:${version}-$win_ver"
done

if [[ $push != "1" ]]; then
  exit
fi

# Create manifest
docker manifest create ${repository}/csi-proxy:${version} $manifest_entries

# Annotate manifests
for win_ver in "${win_vers[@]}"; do
  os_ver=$(docker manifest inspect mcr.microsoft.com/windows/nanoserver:${win_ver} | grep "os.version" | head -n 1 | awk -F\" '{print $4}')
  docker manifest annotate --os windows --arch amd64 --os-version $os_ver $repository/csi-proxy:$version $repository/csi-proxy:$version-$win_ver
done

docker manifest inspect $repository/csi-proxy:$version

docker manifest push ${repository}/csi-proxy:${version}
