#!/bin/bash

# https://devhints.io/bash
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -n | --calicoVersion )
    shift; calicoVersion="$1"
    ;;
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
calicoVersion=${calicoVersion:-"v3.20.0"}

docker buildx create --name img-builder --use --platform windows/amd64
trap 'docker buildx rm img-builder' EXIT

if [[ -n "$calicoVersion" || "$all" == "1" ]] ; then
    trap 'docker buildx rm img-builder' EXIT
    pushd install
    docker buildx build --platform windows/amd64 --output=type=registry --pull --build-arg=CALICO_VERSION=$calicoVersion -f Dockerfile.install -t $repository/calico-install:$calicoVersion-hostprocess .
    popd
fi

if [[ -n "$calicoVersion" || "$all" == "1" ]] ; then
    pushd node
    docker buildx build --platform windows/amd64 --output=type=registry --pull --build-arg=CALICO_VERSION=$calicoVersion -f Dockerfile.node -t $repository/calico-node:$calicoVersion-hostprocess .
    popd
fi

if [[ -n "$proxyVersion" || "$all" == "1" ]] ; then
    proxyVersion=${proxyVersion:-"v1.22.2"}
    pushd kube-proxy
    docker buildx build --platform windows/amd64 --output=type=registry --pull --build-arg=k8sVersion=$proxyVersion -f Dockerfile -t $repository/kube-proxy:$proxyVersion-calico-hostprocess .
    popd
fi
