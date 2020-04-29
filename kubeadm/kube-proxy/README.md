
# Build your own image
```
build-arg:
    <servercoreTag>: default ltsc2019
    <k8sVersion>:    default v1.17.3
    <golangTag>:     default windowsservercore-1809
```

## Example
### windows server 1809
```bash
docker build --build-arg servercoreTag=ltsc2019 --build-arg k8sVersion=v1.18.1 --build-arg golangTag=windowsservercore-1809 -t flannel:0.12.0-windowsservercore-1809 .
```

### windows server core 1909
```bash
docker build --build-arg servercoreTag=1909 --build-arg k8sVersion=v1.18.1 --build-arg golangTag=windowsservercore-1909 -t flannel:0.12.0-windowsservercore-1909 .
```