# Installing Calico using the Operator

This should be followed after adding your [Windows node to the cluster with kubeadm](guide-for-adding-windows-node.md#adding-windows-nodes).

>  **Note** This guide is available ONLY for Calico version greater or equal to **v3.27.0** and for Kubernetes versions that support **HostProcess containers (HPC)**.

## Configuring Calico with HostProcess containers using the Operator

>  **Note** All code snippets in Linux sections are to be run in a Linux environment on the Linux worker node.

### Prepare Control Plane for Calico

1. Prepare Kubernetes control plane for Calico

Some minor preparation is recommended on the Kubernetes control plane in our cluster. It is recommended to enable bridged IPv4 traffic to iptables chains when using Calico. The following command must be run on all Linux nodes:

```bash
sudo sysctl net.bridge.bridge-nf-call-iptables=1
```

2. Download & configure Calico for Linux

The version of Calico will be set in the variable CALICO_VERSION (if another version is needed, modify this variable).

```bash
export CALICO_VERSION="v3.28.0"
```

Create the tigera-operator.yaml and the custom-resources.yaml for Calico:
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml -O
# If IP CIDR differs from 192.168.0.0/16, make sure to modify it in custom-resources.yaml.
# After the file has the correct CIDR, run this command:
kubectl create -f custom-resources.yaml
```
>  **Note** Before creating this manifest, read its contents and make sure its settings are correct for your environment. For example, you may need to change the default IP pool CIDR to match your pod network CIDR.

### Add Windows Calico Solution with the Operator

For Linux control nodes using Calico networking, strict affinity must be set to true. This is required to prevent Linux nodes from borrowing IP addresses from Windows nodes:

```bash
kubectl patch ipamconfigurations default --type merge --patch='{"spec": {"strictAffinity": true}}'
```

>  **NOTE** If the above command failed to find `ipamconfigurations` resource, you need to install the Calico API server. Please refer to [installing the Calico API server](https://docs.tigera.io/calico/latest/operations/install-apiserver).

Now, you can follow the operator installation steps from the tigera/docs regarding [Operator Installation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/windows-calico/operator#operator-installation)

>  **NOTE** Regarding the Kubernetes VXLAN installation, until the [issue regarding the Operator docs](https://github.com/tigera/docs/issues/1547) is still open, you must follow these [steps](https://docs.tigera.io/calico/latest/getting-started/kubernetes/windows-calico/manual-install/standard#install-calico-on-linux-control-and-worker-nodes):

- Modify the IPPool to have `vxlanMode: Always`

```bash
kubectl patch ippool default-ipv4-ippool --type='json' -p='[{"op": "replace", "path": "/spec/vxlanMode", "value": "Always"}]'
```

- Modify VXLAN for `installation` default's resource from `VXLANCrossSubnet` to `VXLAN`

```bash
kubectl patch installation default --type='json' -p='[{"op": "replace", "path": "/spec/calicoNetwork/ipPools/0/encapsulation", "value": "VXLAN"}]'
```

>  **NOTE** Windows supports only VXLAN on port 4789 and VSID ≥ 4096. Calico's default (on Linux and Windows) is to use port 4789 and VSID 4096.
>  **NOTE** Windows can support only a single type of IP pool so it is important that you use only a single VXLAN IP pool in this mode.