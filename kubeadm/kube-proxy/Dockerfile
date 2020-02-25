ARG k8sVersion="1.17.3"
ARG servercoreTag="ltsc2019"

FROM mcr.microsoft.com/windows/servercore:${servercoreTag}
SHELL ["powershell", "-NoLogo", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG k8sVersion

RUN mkdir C:\kube-proxy; \
  pushd C:\kube-proxy; \
  curl.exe -LO https://dl.k8s.io/v${env:k8sVersion}/bin/windows/amd64/kube-proxy.exe

RUN mkdir C:\utils; \
  curl.exe -Lo C:\utils\wins.exe https://github.com/rancher/wins/releases/download/v0.0.4/wins.exe; \
  curl.exe -Lo C:\utils\yq.exe https://github.com/mikefarah/yq/releases/download/2.4.1/yq_windows_amd64.exe; \
  "[Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';C:\utils', [EnvironmentVariableTarget]::Machine)"
