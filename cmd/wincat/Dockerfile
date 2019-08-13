ARG golangTag=1.12.6-windowsservercore-1809
# TODO: need a -1903 tag but none published yet
ARG nanoserverTag="mcr.microsoft.com/windows/nanoserver:1809-amd64"
# Other common ones: 1803-amd64, 1903-amd64
# full list: curl -L https://mcr.microsoft.com/v2/windows/nanoserver/tags/list
ARG sigWindowsTag=master
ARG windowsTestingTag=master

FROM golang:${golangTag} as builder
ENV pausesrcdir="src\\github.com\\kubernetes-sigs\\windows-testing"
ENV wincatsrcdir="src\\github.com\\kubernetes-sigs\\sig-windows-tools"
RUN mkdir $ENV:pausesrcdir ; cd $ENV:pausesrcdir ; git clone https://github.com/kubernetes-sigs/windows-testing.git .
RUN mkdir $ENV:wincatsrcdir ; cd $ENV:wincatsrcdir ; git clone https://github.com/kubernetes-sigs/sig-windows-tools.git .
RUN cd $ENV:pausesrcdir ; cd images\pause ; git fetch --all ; git checkout ${windowsTestingTag} ; git status ; go build -o pauseloop.exe .
RUN cd $ENV:wincatsrcdir ; cd cmd\wincat ; git fetch --all ; git checkout ${sigWindowsTag} ; git status ; go build -o wincat.exe .

FROM ${nanoserverTag}
COPY --from=builder "c:\\gopath\\src\\github.com\\kubernetes-sigs\\sig-windows-tools\\cmd\\wincat\\wincat.exe" "c:\\windows\\system32\\wincat.exe"
COPY --from=builder "c:\\gopath\\src\\github.com\\kubernetes-sigs\\windows-testing\\images\\pause\\pauseloop.exe" "c:\\windows\\system32\\pauseloop.exe"
CMD pauseloop.exe