#!/bin/bash
<<'DESCRIPTION'
  Script to build flannel and callico versions as well as their kube-proxy versions
  There is also the posibility to build only a specific kube-proxy image or change the repository
  and flannel/calico versions via the environment variables in the script,
  in order to build it for other versions of them
  
  .EXAMPLE
  ./build.sh --kubeProxyVersion v1.24.3
  ./build.sh --kubeProxyVersion v1.24.3 -r sigwindowstools --flannelVersion v0.14.0
  ./build.sh --kubeProxyVersion v1.24.3 -r sigwindowstools --calicoVersion v3.23.0

DESCRIPTION

repository=${repository:-"sigwindowstools"}
flannelVersion=${flannelVersion:-"v0.14.0"}
calicoVersion=${calicoVersion:-"v3.23.0"}
kubeProxyVersion=${kubeProxyVersion:-""}
minVersion=${minVersion:-"v1.23.0"}

SCRIPTROOT=$(dirname "${BASH_SOURCE[0]}")
pushd $SCRIPTROOT/flannel
./build.sh -r $repository --flannelVersion $flannelVersion
popd
pushd $SCRIPTROOT/calico
./build.sh -r $repository --calicoVersion $calicoVersion
popd

declare -a proxyVersions=($(curl -L registry.k8s.io/v2/kube-proxy/tags/list | jq .tags | tr "\n" " " | tr -d '"' | tr -d ','))

if [ -n "$kubeProxyVersion" ]
then
  proxyVersions=("$kubeProxyVersion")
fi

# Read the array values with space
for proxyVersion in "${proxyVersions[@]}"; do
  if [[ "$proxyVersion" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ && $minVersion == `echo -e "$minVersion\n$proxyVersion" | sort -V | head -n1` ]]
  then
    echo "Building flannel proxy version $proxyVersion"
    pushd $SCRIPTROOT/flannel
    ./build.sh -r $repository --proxyVersion $proxyVersion
    popd
    echo "Building calico proxy version $proxyVersion"
    pushd $SCRIPTROOT/calico
    ./build.sh -r $repository --proxyVersion $proxyVersion
    popd
  fi
done
