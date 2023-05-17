# Installing Calico

This should be followed after adding your [Windows node to the cluster with kubeadm](guide-for-adding-windows-node.md#adding-windows-nodes).

## Configuring Calico with HostProcess containers

>  **Note:** All code snippets in Linux sections are to be run in a Linux environment on the Linux worker node.

### Prepare Control Plane for Calico

1. Prepare Kubernetes control plane for Calico

Some minor preparation is recommended on the Kubernetes control plane in our cluster. It is recommended to enable bridged IPv4 traffic to iptables chains when using Calico. The following command must be run on all Linux nodes:

```bash
sudo sysctl net.bridge.bridge-nf-call-iptables=1
```

2. Download & configure Calico for Linux

The version of Calico will be set in the variable CALICO_VERSION (if another version is needed, modify this variable).

```bash
export CALICO_VERSION="v3.24.5"
```

Create the tigera-operator.yaml and the custom-resources.yaml for Calico: 
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources.yaml -O
# If IP CIDR differs from 192.168.0.0/16, make sure to modify it in custom-resources.yaml.
# After the file has the correct CIDR, run this command:
kubectl create -f custom-resources.yaml
```
>  **Note:** Before creating this manifest, read its contents and make sure its settings are correct for your environment. For example, you may need to change the default IP pool CIDR to match your pod network CIDR.

Remove the taints on the master so that you can schedule pods on it.

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

It should return the following.

```
node/<your-hostname> untainted
```

### Add Windows calico solution

1. Add calico and kube-proxy daemonsets from sig-windows-tools/hostprocess/calico

Now you can add Windows-compatible versions of calico and kube-proxy. In order to ensure that you get a compatible version of kube-proxy, you'll need to substitute the tag of the image. The following example shows usage for Kubernetes v1.25.3, but you should adjust the version for your own deployment.

```bash
curl -L https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/calico/kube-proxy/kube-proxy.yml | sed 's/KUBE_PROXY_VERSION/v1.25.3/g' | kubectl apply -f -
curl -L https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/calico/calico.yml | sed "s/CALICO_VERSION/$CALICO_VERSION/g" | kubectl apply -f -
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/calico/kube-calico-rbac.yml
```

>  **Note** To find your version of kubernetes run the following command:
> `kubeadm version`

The `$CALICO_VERSION` version in the above code section refers to the image of <a href="https://hub.docker.com/r/sigwindowstools/calico-node/tags" target="_blank">sigwindowstools/calico-node</a>, not the official version of Calico. Suggest modifying after querying rather than directly applying the `$CALICO_VERSION` value. `KUBE_PROXY_VERSION`-like modification method。

## Verifying your installation for Calico
>  **Note:** Remember to check if you have the calico cni installed on your Windows node ("C:\Program Files\containerd\cni\"). If you do not have it, follow this tutorial to install it: https://projectcalico.docs.tigera.io/getting-started/windows-calico/kubernetes/standard#install-calico-and-kubernetes-on-windows-nodes
If you have trouble with modifying config.ps1, use this https://github.com/kubernetes-sigs/sig-windows-dev-tools/blob/master/forked/config.ps1

You should now be able to view the Windows node in your cluster by running:

```bash
kubectl get nodes -o wide
```

If your new node is in the `NotReady` state it is likely because the calico image is still downloading. You can check the progress as before by checking on the calico pods in the `kube-system` namespace:

```shell
kubectl -n kube-system get pods -l app=calico
```

Once the calico Pods are running, your node should enter the `Ready` state and then be available to handle workloads.
