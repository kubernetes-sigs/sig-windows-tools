# Note this image doesn't really mater for hostprocess
# the files in the image are copied to $env:CONTAINER_SANDBOX_MOUNT_POINT on the host
# but the file system is the Host NOT the container
ARG BASE="mcr.microsoft.com/windows/nanoserver:1809"

FROM --platform=linux/amd64 curlimages/curl as bins
ARG containernetworkingCniVersion="0.8.7"
ARG cniVersion="0.2.0"
ARG flannelVersion="v0.13.0"

# Todo simplify this
# We need both sets of binaries 
# sdnoverlay from windows-container-networking is requred for containerd
# flannel.exe and hostlocal.exe from containernetworking 
# flannel.exe recently moved to https://github.com/flannel-io/cni-plugin but has no releases
WORKDIR /cni
RUN curl -Lo cni.tgz https://github.com/containernetworking/plugins/releases/download/v${containernetworkingCniVersion}/cni-plugins-windows-amd64-v${containernetworkingCniVersion}.tgz
RUN tar -xf cni.tgz
RUN rm cni.tgz

RUN curl -Lo cni.zip https://github.com/microsoft/windows-container-networking/releases/download/v${cniVersion}/windows-container-networking-cni-amd64-v${cniVersion}.zip
RUN unzip /cni/cni.zip

WORKDIR /flannel 
RUN curl -Lo flanneld.exe https://github.com/coreos/flannel/releases/download/${flannelVersion}/flanneld.exe

FROM $BASE

ENV PATH="C:\Program Files\PowerShell;C:\utils;C:\Windows\system32;C:\Windows;"

ADD https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1 /flannel/hns.psm1
COPY start.ps1 /flannel/start.ps1
COPY --from=bins /cni /cni
COPY --from=bins /flannel/flanneld.exe /flannel/flanneld.exe

ENTRYPOINT ["PowerShell", "/c", "$env:CONTAINER_SANDBOX_MOUNT_POINT/flannel/start.ps1"]
