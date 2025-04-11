# Adding Windows nodes

You can use Kubernetes to run a mixture of Linux and Windows nodes, so you can mix Pods that run on Linux on with Pods that run on Windows. This is a guide on how to register Windows nodes to your cluster.

## Before you begin

Your Kubernetes server must be at or later than version 1.23. To check the version, enter `kubectl version`.

- Obtain a [Windows Server 2019 license](https://www.microsoft.com/en-us/cloud-platform/windows-server-pricing) (or higher) in order to configure the Windows node that hosts Windows containers. If you are using VXLAN/Overlay networking you must have also have [KB4489899](https://support.microsoft.com/help/4489899) installed.

- A Linux-based Kubernetes kubeadm cluster in which you have access to the control plane (see [Creating a single control-plane cluster with kubeadm](https://kubernetes-docsy-staging.netlify.app/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)).

## Objectives

- Register a Windows node to the cluster
- Configure networking so Pods and Services on Linux and Windows can communicate with each other

## Getting Started: Adding a Windows Node to Your Cluster

### Joining a Windows worker node

> **Note** All code snippets in Windows sections are to be run in a PowerShell environment with elevated permissions (Administrator) on the Windows worker node.

1. Install ContainerD.

```PowerShell
# Install ContainerD
curl.exe -LO https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/Install-Containerd.ps1
.\Install-Containerd.ps1 -ContainerDVersion 1.7.1
```

> **Note** Adjust the parameters for `Install-Containerd.ps1` as you need them.

> **Note** Set `skipHypervisorSupportCheck` if your machine does not support Hyper-V. You way wont be able to host Hyper-V isolated containers.
> Example: `.\Install-Containerd.ps1 -ContainerDVersion 1.7.1 -netAdapterName Ethernet -skipHypervisorSupportCheck`

> **Note** If you change the `Install-Containerd.ps1` optional parameters `$CNIBinPath` and/or `$CNIConfigPath`, you will need to change the calico
> or flannel configuration accordingly. See the specific guides for more details.

2. Install kubelet and kubeadm.

```PowerShell
# Install kubelet and kubeadm
curl.exe -LO https://raw.githubusercontent.com/kubernetes-sigs/sig-windows-tools/master/hostprocess/PrepareNode.ps1
.\PrepareNode.ps1 -KubernetesVersion v1.29.6
```

> **Note** If you want to install another version of kubernetes, modify v1.25.3 with the version you want to install

3. Run `kubeadm` to join the node

Use the command that was given to you when you ran `kubeadm init` on a control plane host. If you no longer have this command, or the token has expired, you can run `kubeadm token create --print-join-command` (on a control plane host) to generate a new token and join command.

> **Note** Do not forget to add `--cri-socket "npipe:////./pipe/containerd-containerd" --v=5` at the end of the join command, if you use ContainerD with Kubernetes version below 1.25.

4. Install kubectl for windows (optional)

For more information about it : https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/

### Networking Configuration

Once you have a Linux-based Kubernetes control-plane node and a Windows node you are ready to choose a networking solution.

This guide offers three choices:

- [Calico](calico.md)
- [Calico-Operator](calico_operator.md)
