ARG BASE="mcr.microsoft.com/powershell:nanoserver-1809"
ARG k8sVersion="v1.19.3"

FROM --platform=linux/amd64 golang as gobuilder
ENV GOOS=windows
ENV GOARCH=amd64
WORKDIR /build
ADD exec_ps.go .
RUN go build -o exec_ps.exe exec_ps.go

FROM --platform=linux/amd64 curlimages/curl as bins
ARG k8sVersion

WORKDIR /utils
RUN curl -Lo wins.exe https://github.com/rancher/wins/releases/download/v0.0.4/wins.exe
RUN curl -Lo yq.exe https://github.com/mikefarah/yq/releases/download/2.4.1/yq_windows_amd64.exe

WORKDIR /kube-proxy
RUN curl -sLO https://dl.k8s.io/${k8sVersion}/bin/windows/amd64/kube-proxy.exe

FROM $BASE

ENV PATH="C:\Program Files\PowerShell;C:\utils;C:\Windows\system32;C:\Windows;"

# wins.exe doesn't work in nanoserver with default ContainerUser.
USER ContainerAdministrator

COPY --from=bins /utils /utils
COPY --from=gobuilder /build/exec_ps.exe /utils/exec_ps.exe
COPY --from=bins /kube-proxy /k/kube-proxy
