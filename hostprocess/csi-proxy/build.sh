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

CSI_PROXY_VERSION=${CSI_PROXY_VERSION:-"v1.1.3"}
REPOSITORY=${REPOSITORY:-"ghcr.io/kubernetes-sigs/sig-windows"}
WINDOWS_BASE_IMAGE_REGISTRY=${WINDOWS_BASE_IMAGE_REGISTRY:-"mcr.microsoft.com/oss/kubernetes"}
WINDOWS_BASE_IMAGE=${WINDOWS_BASE_IMAGE:-"windows-host-process-containers-base-image"}
WINDOWS_BASE_IMAGE_VERSION=${WINDOWS_BASE_IMAGE_VERSION:-"v1.0.0"}
BUILDER_BASE_IMAGE=${BUILDER_BASE_IMAGE:-"golang"}

set -x

docker buildx create --name img-builder --use --platform windows/amd64
trap 'docker buildx rm img-builder' EXIT

docker buildx build --platform windows/amd64 --output=$output -f Dockerfile.windows \
    --build-arg REGISTRY=${WINDOWS_BASE_IMAGE_REGISTRY} \
    --build-arg WINDOWS_BASE_IMAGE=${WINDOWS_BASE_IMAGE} \
    --build-arg WINDOWS_BASE_IMAGE_VERSION=${WINDOWS_BASE_IMAGE_VERSION} \
    --build-arg BUILDER_BASE_IMAGE=${BUILDER_BASE_IMAGE} \
    --build-arg CSI_PROXY_VERSION=${CSI_PROXY_VERSION} \
    -t ${REPOSITORY}/csi-proxy:${version} .
