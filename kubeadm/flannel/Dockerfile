ARG servercoreTag="ltsc2019"
ARG cniVersion="0.8.5"

FROM mcr.microsoft.com/windows/servercore:${servercoreTag}
SHELL ["powershell", "-NoLogo", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG cniVersion

# Stuck on a prerelease flannel until https://github.com/coreos/flannel/issues/1231 is resolved
RUN mkdir -force C:\k\flannel; \
  pushd C:\k\flannel; \
  curl.exe -LO https://github.com/benmoss/flannel/releases/download/v0.12.0-rc1/flanneld.exe

RUN mkdir C:\cni; \
  pushd C:\cni; \
  curl.exe -Lo cni.tgz https://github.com/containernetworking/plugins/releases/download/v${env:cniVersion}/cni-plugins-windows-amd64-v${env:cniVersion}.tgz; \
  tar -xf cni.tgz; \
  rm cni.tgz

RUN mkdir C:\utils; \
  curl.exe -Lo C:\utils\wins.exe https://github.com/rancher/wins/releases/download/v0.0.4/wins.exe; \
  curl.exe -Lo C:\utils\yq.exe https://github.com/mikefarah/yq/releases/download/2.4.1/yq_windows_amd64.exe; \
  "[Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';C:\utils', [EnvironmentVariableTarget]::Machine)"
