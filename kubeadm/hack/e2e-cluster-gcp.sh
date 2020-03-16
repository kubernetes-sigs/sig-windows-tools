#!/usr/bin/env bash

# Copyright 2020 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

if [[ -n "${VERBOSE}" ]]; then
	set -o xtrace
fi

NODE_COUNT=${NODE_COUNT:-2}
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
CLUSTER_NAME=${CLUSTER_NAME:-"test-$(date +%s)"}
ARTIFACTS="${ARTIFACTS:-${PWD}/_artifacts}"
scratchDir=$(mktemp -d)
export KUBECONFIG="$scratchDir/kubeconfig.yml"

export ARTIFACTS
mkdir -p "${ARTIFACTS}/logs"

# disable gcloud prompts
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# print the gcloud version
echo "Using gcloud version:"
gcloud -v

cleanup() {
	gcloud compute firewall-rules list --filter network="$CLUSTER_NAME" --format "value(selfLink.basename())" | \
		xargs gcloud compute firewall-rules delete
	gcloud compute instances list --filter labels.cluster="$CLUSTER_NAME" --format "value(selfLink.basename())" | \
		xargs gcloud compute instances delete
	gcloud compute networks delete "$CLUSTER_NAME"
	rm -rf $scratchDir
}
SKIP_CLEANUP=${SKIP_CLEANUP:-""}
if [[ -z "${SKIP_CLEANUP}" ]]; then
	trap cleanup EXIT
fi

gcloud compute networks create "$CLUSTER_NAME"
gcloud compute firewall-rules create "$CLUSTER_NAME-default-internal" --network "$CLUSTER_NAME" --allow tcp,udp,icmp --source-ranges "10.0.0.0/8"
gcloud compute firewall-rules create "$CLUSTER_NAME-default-external" --network "$CLUSTER_NAME" --allow "tcp:22,tcp:3389,tcp:6443" --source-ranges "0.0.0.0/0"

ctrlPlaneNodeName="$CLUSTER_NAME-control-plane"
controlPlane=$(gcloud compute instances create "$ctrlPlaneNodeName" \
	--metadata-from-file startup-script="$REPO_ROOT/kubeadm/hack/startup/controlplane.sh" \
	--image-family ubuntu-1804-lts \
	--image-project ubuntu-os-cloud \
	--machine-type n1-standard-2 \
	--network "$CLUSTER_NAME" \
	--tags kube-control-plane \
	--labels=cluster="$CLUSTER_NAME" \
	--format "json(networkInterfaces[0].networkIP, networkInterfaces[0].accessConfigs[0].natIP)")

# wait for kubeadm init
SECONDS=0
while true; do
	set +o errexit
	timeout 30 gcloud compute ssh "root@${ctrlPlaneNodeName}" --command "KUBECONFIG=/etc/kubernetes/admin.conf kubectl version"
	if [ $? -eq 0 ]; then
		gcloud compute scp "root@${ctrlPlaneNodeName}:/etc/kubernetes/admin.conf" "$KUBECONFIG"
		break
	else
		if [ $SECONDS -ge 600 ]; then
			echo "Failed waiting for control plane to become ready"
			exit 1
		fi
		sleep 10
	fi
done
set -o errexit

privateIP=$(echo $controlPlane | jq -r '.[] | .networkInterfaces[0].networkIP')
externalIP=$(echo $controlPlane | jq -r '.[] | .networkInterfaces[0].accessConfigs[0].natIP')
sed -i "s/${privateIP}/${externalIP}/g" $KUBECONFIG

k8sVersion=$(kubectl version -ojson | jq -r .serverVersion.gitVersion)
sed "s/VERSION/${k8sVersion}/" "$REPO_ROOT/kubeadm/hack/startup/windows.ps1" > $scratchDir/windows.ps1

set +o xtrace
joinCmd="$(gcloud compute ssh root@${ctrlPlaneNodeName} --command "kubeadm token create --print-join-command") --ignore-preflight-errors=IsPrivilegedUser"

for i in $(seq 1 $NODE_COUNT); do
	gcloud compute instances create "$CLUSTER_NAME-windows-node-$i" \
		--metadata-from-file windows-startup-script-ps1="$scratchDir/windows.ps1" \
		--metadata join_cmd="$joinCmd" \
		--image-project windows-cloud \
		--network "$CLUSTER_NAME" \
		--image-family windows-2019-core-for-containers \
		--labels=cluster="$CLUSTER_NAME" \
		--machine-type n1-standard-4
done
if [[ -n "${VERBOSE}" ]]; then
	set -o xtrace
fi

# build kubectl and e2e.test
pushd $(go env GOPATH)/src/k8s.io/kubernetes
git checkout "$k8sVersion"
make all WHAT="test/e2e/e2e.test cmd/kubectl vendor/github.com/onsi/ginkgo/ginkgo"
export PATH="$PWD/_output/bin:$PATH"

# install flannel overlay & kube-proxy
curl -sL https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml | \
	sed 's/"Type": "vxlan"/"Type": "vxlan", "VNI": 4096, "Port": 4789/' | kubectl apply -f-

curl -sL https://github.com/kubernetes-sigs/sig-windows-tools/releases/latest/download/kube-proxy.yml | \
	sed "s/VERSION/${k8sVersion}/g" | kubectl apply -f -

kubectl apply -f https://github.com/kubernetes-sigs/sig-windows-tools/releases/latest/download/flannel-overlay.yml

# wait for all the nodes to appear
SECONDS=0
while true; do
	nodeCount=$(kubectl get nodes -l kubernetes.io/os=windows --no-headers | wc -l)
	if [ $nodeCount -eq $NODE_COUNT ]; then
		break
	else
		if [ $SECONDS -ge 600 ]; then
			echo "Failed waiting for Windows nodes to join the cluster"
			exit 1
		fi
		sleep 10
	fi
done

# wait for all kube-system pods to become ready
kubectl -n kube-system wait --for=condition=Ready pods --all --timeout=15m

# setting this env prevents ginkgo e2e from trying to run provider setup
export KUBERNETES_CONFORMANCE_TEST="y"

SKIP="${SKIP:-\\[LinuxOnly\\]|\\[Slow\\]}"
FOCUS="${FOCUS:-"\\[Conformance\\]|\\[NodeConformance\\]|\\[sig-windows\\]"}"
# if we set PARALLEL=true, skip serial tests set --ginkgo-parallel
if [ "${PARALLEL:-false}" = "true" ]; then
	export GINKGO_PARALLEL=y
	SKIP="\\[Serial\\]|${SKIP}"
fi
$(go env GOPATH)/src/sigs.k8s.io/windows-testing/gce/run-e2e.sh \
	--provider=skeleton --num-nodes="$NODE_COUNT" \
	--ginkgo.focus="$FOCUS" --ginkgo.skip="$SKIP" \
	--node-os-distro=windows --report-dir="$ARTIFACTS" \
	--disable-log-dump=true
