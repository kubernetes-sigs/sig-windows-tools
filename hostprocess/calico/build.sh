#!/bin/bash

# https://devhints.io/bash
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -p | --proxyVersion )
    shift; proxyVersion="$1"
    ;;
  -r | --repository )
    shift; repository="$1"
    ;;
  -a | --all )
    shift; all="1"
    ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

repository=${repository:-"sigwindowstools"}

docker buildx create --name img-builder --use --platform windows/amd64
trap 'docker buildx rm img-builder' EXIT

if [[ -n "$proxyVersion" || "$all" == "1" ]] ; then
    proxyVersion=${proxyVersion:-"v1.32.3"}
    pushd kube-proxy
    docker buildx build --provenance=false --sbom=false --platform windows/amd64 --output=type=registry --pull --build-arg=k8sVersion=$proxyVersion -f Dockerfile -t $repository/kube-proxy:$proxyVersion-calico-hostprocess .
    popd
fi
