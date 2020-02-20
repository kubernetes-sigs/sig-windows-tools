FROM mcr.microsoft.com/windows/servercore:ltsc2019
SHELL ["powershell", "-NoLogo", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN mkdir C:\kube-proxy; \
  pushd C:\kube-proxy; \
  curl.exe -LO https://dl.k8s.io/v1.16.2/bin/windows/amd64/kube-proxy.exe

RUN curl.exe -Lo C:\windows\wins.exe https://github.com/rancher/wins/releases/download/v0.0.4/wins.exe

RUN curl.exe -Lo C:\windows\yq.exe https://github.com/mikefarah/yq/releases/download/2.4.1/yq_windows_amd64.exe
