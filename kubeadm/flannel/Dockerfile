FROM mcr.microsoft.com/windows/servercore:ltsc2019
SHELL ["powershell", "-NoLogo", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN mkdir C:\flannel; \
  pushd C:\flannel; \
  curl.exe -LO https://github.com/benmoss/flannel/releases/download/v0.12.0-rc1/flanneld.exe

RUN mkdir C:\cni; \
  pushd C:\cni; \
  curl.exe -Lo cni.tgz https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-windows-amd64-v0.8.2.tgz; \
  tar -xf cni.tgz; \
  rm cni.tgz

RUN curl.exe -Lo C:\windows\wins.exe https://github.com/rancher/wins/releases/download/v0.0.4/wins.exe

RUN curl.exe -Lo C:\windows\yq.exe https://github.com/mikefarah/yq/releases/download/2.4.1/yq_windows_amd64.exe
