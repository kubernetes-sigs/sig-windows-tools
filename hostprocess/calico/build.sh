#!/bin/bash

# https://devhints.io/bash
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -i | --installer )
    shift; installer="1"
    ;;
  -n | --node )
    shift; node="1"
    ;;
  -a | --all )
    shift; all="1"
    ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

docker buildx create --name img-builder --use --platform windows/amd64
if [[ "$installer" == "1" || "$all" == "1" ]] ; then
    trap 'docker buildx rm img-builder' EXIT
    pushd install
    docker buildx build --platform windows/amd64 --output=type=registry --pull -f Dockerfile.install -t jsturtevant/calico-install:hostprocess .
    popd
fi

if [[ "$node" == "1" || "$all" == "1" ]] ; then
    pushd node
    docker buildx build --platform windows/amd64 --output=type=registry --pull -f Dockerfile.node -t jsturtevant/calico-node:hostprocess .
    popd
fi

docker buildx rm img-builder || true