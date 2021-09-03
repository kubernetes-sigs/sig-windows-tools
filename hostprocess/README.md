# HostProcess examples

This contains examples of services running as [HostProcess](https://kubernetes.io/docs/tasks/configure-pod-container/create-hostprocess-pod/) 
containers.  HostProcess is an alpha feature in Kubernetes 1.22. 

The eventual goal is to move many of these examples to the corresponding repositories.  

## Requirements

The CNI examples currently require the containerd change in https://github.com/containerd/containerd/pull/5131 and a nightly build of hcsschim

For convience there is a nightly job in the repository that builds the required components: https://github.com/kubernetes-sigs/sig-windows-tools/releases/tag/windows-containerd-nightly

> Docker does not support HostProcess containers. These images will not work with Docker.

## Future Improvements 

These scripts are based off the initial Docker implementation in https://github.com/kubernetes-sigs/sig-windows-tools/tree/master/kubeadm.  
Idealy these should use init containers (possible written in golang) to install and configure the binaries as is done with Linux.  Then the
main container can run the required components for a given CNI.

Kubeadm should create and configure kubeproxy for windows appropriately during node initialization.