ARG BASE="mcr.microsoft.com/oss/kubernetes/windows-host-process-containers-base-image:v0.1.0"

FROM --platform=linux/amd64 curlimages/curl as bins
ARG k8sVersion="v1.22.4"

WORKDIR /kube-proxy
RUN curl -LO https://dl.k8s.io/$k8sVersion/bin/windows/amd64/kube-proxy.exe
RUN curl -LO https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/windows/hns.psm1

FROM $BASE

ENV PATH="C:\Windows\system32;C:\Windows;C:\WINDOWS\System32\WindowsPowerShell\v1.0\;"

ADD start.ps1 /kube-proxy/start.ps1
COPY --from=bins /kube-proxy/kube-proxy.exe /kube-proxy/kube-proxy.exe
COPY --from=bins /kube-proxy/hns.psm1 /kube-proxy/hns.psm1

ENTRYPOINT ["PowerShell"]
