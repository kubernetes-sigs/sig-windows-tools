# Overview

This project uses GitHub actions to build nightly packages of [contianerd](https://github.com/containerd/containerd) and other required binaries from source for testing containerd on Windows.

## windows-containerd nightly builds

![Nightly](https://github.com/kubernetes-sigs/sig-windows-tools/workflows/Nightly/badge.svg?branch=master)

Package includes:

- https://github.com/Microsoft/hcsshim/tree/master
  - containerd-shim-runhcs-v1.exe
- https://github.com/containerd/containerd/tree/master
  - containerd.exe
  - ctr.exe

## Windows-container with hostprocess support

![hostprocess](https://github.com/kubernetes-sigs/sig-windows-tools/workflows/hostprocess/badge.svg?branch=master)

Package includes:

- https://github.com/dcantah/hcsshim/tree/master
  - containerd-shim-runhcs-v1.exe
- https://github.com/perithompson/containerd/tree/windows-hostnetwork
  - containerd.exe
  - ctr.exe
