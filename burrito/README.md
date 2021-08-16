# Burrito

The burrito is meant as a companion to image-builder to allow you to run a pod containing all of the components needed to build a windows image either offline or as an air-gapped image.

Usage

Config File
``` yaml
path: burrito
components:
  - name: kubernetes
    src: <Source URL>
    sha256: <SHA Hash of package>
  - name: containerd
    src: <Source URL>
    sha256: <SHA Hash of package>
```