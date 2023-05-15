ARG BASE="mcr.microsoft.com/oss/kubernetes/windows-host-process-containers-base-image:v0.1.0"

FROM --platform=linux/amd64 curlimages/curl as bins
ARG containernetworkingCniVersion="1.3.0"
ARG cniVersion="0.3.0"
ARG flannelCniVersion="1.1.2"
ARG flannelVersion="v0.21.5"

# Todo simplify this
# We need multiple sets of binaries 
# sdnoverlay from windows-container-networking is requred for containerd
# hostlocal.exe from containernetworking 
# flannel.exe from https://github.com/flannel-io/cni-plugin
WORKDIR /cni
RUN curl -Lo cni.tgz https://github.com/containernetworking/plugins/releases/download/v${containernetworkingCniVersion}/cni-plugins-windows-amd64-v${containernetworkingCniVersion}.tgz
RUN tar -xf cni.tgz
RUN rm cni.tgz

RUN curl -Lo cni.zip https://github.com/microsoft/windows-container-networking/releases/download/v${cniVersion}/windows-container-networking-cni-amd64-v${cniVersion}.zip
RUN unzip /cni/cni.zip

RUN curl -Lo flannel.exe https://github.com/flannel-io/cni-plugin/releases/download/v${flannelCniVersion}/flannel-amd64.exe

WORKDIR /flannel 
RUN curl -Lo flanneld.exe https://github.com/flannel-io/flannel/releases/download/${flannelVersion}/flanneld.exe

FROM $BASE

ENV PATH="C:\Windows\system32;C:\Windows;C:\WINDOWS\System32\WindowsPowerShell\v1.0\;"

ADD https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1 /flannel/hns.psm1
COPY start.ps1 /flannel/start.ps1
COPY --from=bins /cni /cni
COPY --from=bins /flannel/flanneld.exe /flannel/flanneld.exe

ENTRYPOINT ["PowerShell", "/c", "$env:CONTAINER_SANDBOX_MOUNT_POINT/flannel/start.ps1"]
