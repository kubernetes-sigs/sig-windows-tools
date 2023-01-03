# Installing Flannel

This should be followed after adding your [Windows node to the cluster with kubeadm](guide-for-adding-windows-node.md#adding-windows-nodes).

## Configuring Flannel with Host Process containers

### Prepare Control Plane for Flannel

1. Prepare Kubernetes control plane for Flannel

Some minor preparation is recommended on the Kubernetes control plane in our cluster. It is recommended to enable bridged IPv4 traffic to iptables chains when using Flannel. The following command must be run on all Linux nodes:

```bash
sudo sysctl net.bridge.bridge-nf-call-iptables=1
```

2. Download & configure Flannel for Linux

Download the most recent Flannel manifest:

```bash
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

Modify the `net-conf.json` section of the flannel manifest in order to set the VNI to 4096 and the Port to 4789. It should look as follows:

```json
net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan",
        "VNI" : 4096,
        "Port": 4789
      }
    }
```

> **Note:** The VNI must be set to 4096 and port 4789 for Flannel on Linux to interoperate with Flannel on Windows. See the [VXLAN documentation](https://github.com/coreos/flannel/blob/master/Documentation/backends.md#vxlan). for an explanation of these fields.

> **Note:** To use L2Bridge/Host-gateway mode instead change the value of `Type` to `"host-gw"` and omit `VNI` and `Port`.

3. Apply the Flannel manifest and validate

Let's apply the Flannel configuration:

```bash
kubectl apply -f kube-flannel.yml
```

After a few minutes, you should see all the pods as running if the Flannel pod network was deployed.

```bash
kubectl get pods -n kube-flannel
```

The output should include the Linux flannel DaemonSet as running:

```
NAMESPACE NAME READY STATUS RESTARTS AGE
...
kube-system kube-flannel-ds-54954 1/1 Running 0 1m
```

### Add Windows flannel solution

1. Add Windows Flannel and kube-proxy DaemonSets

Now you can add Windows-compatible versions of Flannel and kube-proxy. In order to ensure that you get a compatible version of kube-proxy, you'll need to substitute the tag of the image. The following example shows usage for Kubernetes v1.24.3, but you should adjust the version for your own deployment.

```bash
curl -L https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/flannel/kube-proxy/kube-proxy.yml | sed 's/KUBE_PROXY_VERSION/v1.25.3/g' | kubectl apply -f -
curl -L https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/flannel/flanneld/flannel-overlay.yml | sed 's/FLANNEL_VERSION/v0.17.0/g' | kubectl apply -f -
```

>  **Note** If you are using another version of kubernetes on your Windows node, change v1.25.3 with your own version .
> To find your version of kubernetes run the following command:
> `kubeadm version`

2. Apply kube-flannel-rbac.yml from sig-windows-tools/kubeadm/flannel
Next you will need to apply the configuration that allows flannel to spawn pods and keep them running:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/flannel/flanneld/kube-flannel-rbac.yml
```

## Verifying your installation for Flannel

You should now be able to view the Windows node in your cluster by running:

```bash
kubectl get nodes -o wide
```

If your new node is in the `NotReady` state it is likely because the flannel image is still downloading. You can check the progress as before by checking on the flannel pods in the `kube-system` namespace:

```shell
kubectl -n kube-system get pods -l app=flannel
```

Once the flannel Pod is running, your node should enter the `Ready` state and then be available to handle workloads.
