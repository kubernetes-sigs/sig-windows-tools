#!/bin/bash
# https://devhints.io/bash
repository=${repository:-"projects-stg.registry.vmware.com/tkgdev/yzac"}

docker buildx create --name img-builder --use --platform windows/amd64
trap 'docker buildx rm img-builder' EXIT

proxyVersion=${proxyVersion:-"v1.22.4"}
pushd kube-proxy
docker buildx build --platform windows/amd64 --output=type=registry --pull --build-arg=k8sVersion=$proxyVersion -f Dockerfile -t $repository/kube-proxy:$proxyVersion-antrea-hostprocess .
popd

