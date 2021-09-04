#!/bin/bash

# https://devhints.io/bash
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -f | --flannel )
    shift; flannel="1"
    ;;
  -p | --proxy )
    shift; proxy="1"
    ;;
  -a | --all )
    shift; all="1"
    ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

docker buildx create --name img-builder --use --platform windows/amd64
trap 'docker buildx rm img-builder' EXIT

if [[ "$flannel" == "1" || "$all" == "1" ]] ; then
    pushd flanneld
    docker buildx build --platform windows/amd64 --output=type=registry --pull -f Dockerfile -t jsturtevant/flannel:hostprocess .
    popd
fi

if [[ "$proxy" == "1" || "$all" == "1" ]] ; then
    pushd kube-proxy
    docker buildx build --platform windows/amd64 --output=type=registry --pull -f Dockerfile -t jsturtevant/flannel:hostprocess .
    popd
fi
