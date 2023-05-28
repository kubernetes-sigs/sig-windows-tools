# Installing Flannel

This should be followed after adding your [Windows node to the cluster with kubeadm](guide-for-adding-windows-node.md#adding-windows-nodes).

## Configuring Flannel with HostProcess containers

### Prepare Control Plane for Flannel

1. Prepare Kubernetes control plane for Flannel

Some minor preparation is recommended on the Kubernetes control plane in our cluster. It is recommended to enable bridged IPv4 traffic to iptables chains when using Flannel. The following command must be run on all Linux nodes:

```bash
sudo sysctl net.bridge.bridge-nf-call-iptables=1
```

2. Download & configure Flannel for Linux

Download the most recent Flannel manifest:

```bash
wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
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

> **Note** The VNI must be set to 4096 and port 4789 for Flannel on Linux to interoperate with Flannel on Windows. See the [VXLAN documentation](https://github.com/flannel-io/flannel/blob/master/Documentation/backends.md#vxlan). for an explanation of these fields.

> **Note** To use L2Bridge/Host-gateway mode instead change the value of `Type` to `"host-gw"` and omit `VNI` and `Port`.

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
kube-flannel kube-flannel-ds-sfqkv 1/1 Running 0 1m
```

### Add Windows flannel solution

Now you can add a Windows-compatible version of Flannel.

```bash
controlPlaneEndpoint=$(kubectl get configmap -n kube-system kube-proxy -o jsonpath="{.data['kubeconfig\.conf']}" | grep server: | sed 's/.*\:\/\///g')
kubernetesServiceHost=$(echo $controlPlaneEndpoint | cut -d ":" -f 1)
kubernetesServicePort=$(echo $controlPlaneEndpoint | cut -d ":" -f 2)
curl -L https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/flannel/flanneld/flannel-overlay.yml | sed 's/FLANNEL_VERSION/v0.21.5/g' | sed "s/KUBERNETES_SERVICE_HOST_VALUE/$kubernetesServiceHost/g" | sed "s/KUBERNETES_SERVICE_PORT_VALUE/$kubernetesServicePort/g" | kubectl apply -f -
```

>  **Note** If your cluster uses a different service subnet than `10.96.0.0/12` then you need to adjust the environment variable `SERVICE_SUBNET` before applying it.
> To find your service subnet run the following command:  
> `kubectl get configmap -n kube-system kubeadm-config -o yaml | grep serviceSubnet`

>  **Note** If you changed the`$CNIBinPath` or `$CNIConfigPath` optional parameters when running `Install-Containerd.ps1`,
>  you will need to use those paths. Pipe it through
>  `| sed 's/C:\\\\opt\\\\cni\\\\bin/<your cni bin path>/g' | sed 's/C:\\\\etc\\\\cni\\\\net.d/<your cni config path>/g'`
>  before feeding it to `kubectl apply -f -`.

Next add a Windows-compatible version of kube-proxy. In order to ensure that you get a compatible version of kube-proxy, you'll need to substitute the tag of the image. The following example shows usage for Kubernetes v1.27.1, but you should adjust the version for your own deployment.

```bash
curl -L https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/flannel/kube-proxy/kube-proxy.yml | sed 's/KUBE_PROXY_VERSION/v1.27.1/g' | kubectl apply -f -
```

>  **Note** If you are using another version of kubernetes on your Windows node, change v1.27.1 with your own version .
> To find your version of kubernetes run the following command:
> `kubeadm version`

>  **Note** If you changed the`$CNIBinPath` optional parameter when running `Install-Containerd.ps1`, you will need to
>  use that path. Pipe it through `| sed 's/C:\\\\opt\\\\cni\\\\bin/<your cni bin path>/g'` before
>  feeding it to `kubectl apply -f -`.

## Verifying your installation for Flannel

You should now be able to view the Windows node in your cluster by running:

```bash
kubectl get nodes -o wide
```

If your new node is in the `NotReady` state it is likely because the flannel image is still downloading. You can check the progress as before by checking on the flannel pods in the `kube-flannel` namespace:

```shell
kubectl -n kube-flannel get pods -l app=flannel
```

Once the flannel Pod is running, your node should enter the `Ready` state and then be available to handle workloads.
