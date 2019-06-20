param(
    $tag="pause",
    $nanoserverTag="mcr.microsoft.com/windows/nanoserver:1809-amd64",
    $golangTag="1.12.6-windowsservercore-1809",
    $sigWindowsTag="master"
)

docker build `
             --build-arg nanoserverTag=$nanoserverTag `
             --build-arg golangTag=$golangTag `
             --build-arg sigWindowsTag=$sigWindowsTag `
             -t $tag `
             .