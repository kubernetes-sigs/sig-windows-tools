#!/bin/bash

repository=${repository:-"sigwindowstools"}
calicoVersion=${calicoVersion:-"v3.25.0"}

SCRIPTROOT=$(dirname "${BASH_SOURCE[0]}")
pushd $SCRIPTROOT/calico
./build.sh -r $repository --calicoVersion $calicoVersion
popd

declare -a proxyVersions=("v1.24.13" "v1.25.9" "v1.26.4" "v1.27.0")

# Read the array values with space
for proxyVersion in "${proxyVersions[@]}"; do
  pushd $SCRIPTROOT/calico
  ./build.sh -r $repository --proxyVersion $proxyVersion
  popd
done
