# HostProcess examples

This contains examples of services running as [HostProcess](https://kubernetes.io/docs/tasks/configure-pod-container/create-hostprocess-pod/) 
containers.  HostProcess is an alpha feature in Kubernetes 1.22. 

The eventual goal is to move many of these examples to the corresponding repositories.  

## Requirements

The CNI examples currently require the containerd 1.6+: https://github.com/containerd/containerd/releases/tag/v1.6.0-beta.1

For convenience there is a nightly job in the repository that builds the required components: https://github.com/kubernetes-sigs/sig-windows-tools/releases/tag/windows-containerd-nightly

> Docker does not support HostProcess containers. These images will not work with Docker.

## Future Improvements 

These scripts are based off the initial Docker implementation in https://github.com/kubernetes-sigs/sig-windows-tools/tree/master/kubeadm.  
Ideally these should use init containers (possible written in golang) to install and configure the binaries as is done with Linux.  Then the
main container can run the required components for a given CNI.

kube-proxy has slightly different configurations (sourcevip as example) across cni's so they are split into separate folder for each. Kubeadm should create and configure kube-proxy for windows appropriately during node initialization.

## Building images

To build all the images update version and images references in `build.sh` then run it.
