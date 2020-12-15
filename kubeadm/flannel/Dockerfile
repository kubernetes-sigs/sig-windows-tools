ARG BASE="mcr.microsoft.com/powershell:nanoserver-1809"
ARG cniVersion="0.8.7"
ARG flannelVersion="0.13.0"

FROM --platform=linux/amd64 golang as setup
ENV GOOS=windows
ENV GOARCH=amd64
WORKDIR /build
ADD setup.go .
RUN go build -o setup.exe setup.go

FROM --platform=linux/amd64 curlimages/curl as bins
ARG cniVersion
ARG flannelVersion

WORKDIR /utils
RUN curl -Lo wins.exe https://github.com/rancher/wins/releases/download/v0.0.4/wins.exe
RUN curl -Lo yq.exe https://github.com/mikefarah/yq/releases/download/2.4.1/yq_windows_amd64.exe

WORKDIR /cni
RUN curl -Lo cni.tgz https://github.com/containernetworking/plugins/releases/download/v${cniVersion}/cni-plugins-windows-amd64-v${cniVersion}.tgz
RUN tar -xf cni.tgz
RUN rm cni.tgz

WORKDIR /flannel 
RUN curl -Lo flanneld.exe https://github.com/coreos/flannel/releases/download/v${flannelVersion}/flanneld.exe

FROM $BASE

ENV PATH="C:\Program Files\PowerShell;C:\utils;C:\Windows\system32;C:\Windows;"

# wins.exe doesn't work in nanoserver with default ContainerUser.
USER ContainerAdministrator

COPY --from=bins /utils /utils
COPY --from=bins /cni /cni
ADD https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1 /k/flannel/hns.psm1
COPY --from=setup /build/setup.exe /k/flannel/setup.exe
COPY --from=bins /flannel/flanneld.exe /k/flannel/flanneld.exe
