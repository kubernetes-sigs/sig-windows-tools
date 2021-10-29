# Note this image doesn't really mater for hostprocess
# the files in the image are copied to $env:CONTAINER_SANDBOX_MOUNT_POINT on the host
# but the file system is the Host NOT the container
ARG BASE="mcr.microsoft.com/windows/nanoserver:1809"

FROM --platform=linux/amd64 curlimages/curl as bins
ARG k8sVersion="v1.22.3"

WORKDIR /kube-proxy
RUN curl -LO https://dl.k8s.io/$k8sVersion/bin/windows/amd64/kube-proxy.exe
RUN curl -LO https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1

FROM $BASE

ENV PATH="C:\Program Files\PowerShell;C:\utils;C:\Windows\system32;C:\Windows;"

Add start.ps1 /kube-proxy/start.ps1
COPY --from=bins /kube-proxy/kube-proxy.exe /kube-proxy/kube-proxy.exe
COPY --from=bins /kube-proxy/hns.psm1 /kube-proxy/hns.psm1

ENTRYPOINT ["PowerShell"]
