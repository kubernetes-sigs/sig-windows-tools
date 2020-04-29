ARG k8sVersion="v1.18.1"
ARG servercoreTag="1909"
ARG golangTag=1.14.2-windowsservercore-1909

FROM golang:${golangTag} as builder
ADD setup.go build/
RUN go build -o build/setup.exe build/setup.go

FROM mcr.microsoft.com/windows/servercore:${servercoreTag}
SHELL ["powershell", "-NoLogo", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG k8sVersion

RUN mkdir -force C:\k\kube-proxy; \
  pushd C:\k\kube-proxy; \
  curl.exe -sLO https://dl.k8s.io/${env:k8sVersion}/bin/windows/amd64/kube-proxy.exe

ADD hns.psm1 /k/kube-proxy
COPY --from=builder /gopath/build/setup.exe /k/kube-proxy/setup.exe

RUN mkdir C:\utils; \
  curl.exe -sLo C:\utils\wins.exe https://github.com/rancher/wins/releases/download/v0.0.4/wins.exe; \
  curl.exe -sLo C:\utils\yq.exe https://github.com/mikefarah/yq/releases/download/2.4.1/yq_windows_amd64.exe; \
  "[Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';C:\utils', [EnvironmentVariableTarget]::Machine)"

