ARG BASE="mcr.microsoft.com/windows/nanoserver:1809"

FROM --platform=linux/amd64 curlimages/curl as bins
ARG k8sVersion="v1.22.4"

WORKDIR /kube-proxy
RUN curl -LO https://dl.k8s.io/v1.22.4/bin/windows/amd64/kube-proxy.exe

FROM $BASE

ENV PATH="C:\Windows\system32;C:\Windows;C:\WINDOWS\System32\WindowsPowerShell\v1.0\;"

ADD start.ps1 /kube-proxy/start.ps1
COPY --from=bins /kube-proxy/kube-proxy.exe /kube-proxy/kube-proxy.exe

ENTRYPOINT ["PowerShell"]
