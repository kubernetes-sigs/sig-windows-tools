#!/usr/bin/env bash

set -e

INITIAL_MAJOR=1
INITIAL_MINOR=17
INITIAL_PATCH=0

dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)

# https://github.com/google/go-containerregistry/tree/master/cmd/crane
versions=$(crane ls k8s.gcr.io/kube-proxy 2>/dev/null)
for version in $versions; do
  if [[ $version =~ alpha|beta|rc ]]; then
    continue
  fi
  major=`echo $version | cut -d. -f1 | tr -d v`
  minor=`echo $version | cut -d. -f2`
  patch=`echo $version | cut -d. -f3`
  if [ $major -lt $INITIAL_MAJOR ]; then
    continue
  fi
  if [ $minor -lt $INITIAL_MINOR ]; then
    continue
  fi

  echo "building $major.$minor.$patch"

  docker build --pull --build-arg k8sVersion="$version" --tag sigwindowstools/kube-proxy:$version $dir
done

docker push sigwindowstools/kube-proxy
