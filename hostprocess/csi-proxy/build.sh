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


docker buildx build --platform windows/amd64 --output=$output -f Dockerfile.windows -t ${repository}/csi-proxy:${version} .

