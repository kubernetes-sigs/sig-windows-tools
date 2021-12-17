#!/bin/bash

repository=${repository:-"sigwindowstools"}
flannelVersion=${flannelVersion:-"v0.14.0"}
proxyVersion=${proxyVersion:-"v1.22.4"}
calicoVersion=${calicoVersion:-"v3.20.0"}

SCRIPTROOT=$(dirname "${BASH_SOURCE[0]}")
pushd $SCRIPTROOT/flannel
./build.sh -r $repository --flannelVersion $flannelVersion
popd
pushd $SCRIPTROOT/calico
./build.sh -r $repository --calicoVersion $calicoVersion
popd

declare -a proxyVersions=("v1.22.5" "v1.23.1")

# Read the array values with space
for proxyVersion in "${proxyVersions[@]}"; do
  pushd $SCRIPTROOT/flannel
  ./build.sh -r $repository --proxyVersion $proxyVersion
  popd
  pushd $SCRIPTROOT/calico
  ./build.sh -r $repository --proxyVersion $proxyVersion
  popd
done
