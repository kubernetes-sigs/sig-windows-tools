# HostProcess examples

This contains examples of services running as [HostProcess](https://kubernetes.io/docs/tasks/configure-pod-container/create-hostprocess-pod/) 
containers.  HostProcess went beta in Kubernetes v1.23 and stable in Kubernetes v1.26.

The eventual goal is to move many of these examples to the corresponding repositories.

## Requirements

HostProcess containers require containerd v1.6 or later.

For convenience there is a nightly job in the repository that builds the required components: https://github.com/kubernetes-sigs/sig-windows-tools/releases/tag/windows-containerd-nightly.

> Docker does not support HostProcess containers. These images will not work with Docker.

## Future Improvements

kube-proxy has slightly different configurations (sourcevip as example) across cni's so they are split into separate folder for each. Kubeadm should create and configure kube-proxy for windows appropriately during node initialization.

## Building images

To build all the images update version and images references in `build.sh` then run it.
