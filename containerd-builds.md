# Overview

This project uses GitHub actions to build nightly packages of [contianerd](https://github.com/containerd/containerd) and other required binaries from source for testing containerd on Windows.

## windows-containerd nightly builds

![windows-containerd-nightly](https://github.com/kubernetes-sigs/sig-windows-tools/workflows/windows-containerd-nightly/badge.svg?branch=master)

Package includes:

- https://github.com/Microsoft/hcsshim/tree/master
  - containerd-shim-runhcs-v1.exe
- https://github.com/containerd/containerd/tree/master
  - containerd.exe
  - ctr.exe

## Windows-container nightly builds with hostprocess support

![windows-containerd-hostprocess](https://github.com/kubernetes-sigs/sig-windows-tools/workflows/windows-containerd-hostprocess/badge.svg?branch=master)

Package includes:

- https://github.com/Microsoft/hcsshim/tree/master
  - containerd-shim-runhcs-v1.exe
- https://github.com/perithompson/containerd/tree/windows-hostnetwork
  - containerd.exe
  - ctr.exe
