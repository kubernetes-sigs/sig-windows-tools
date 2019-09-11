FROM microsoft/windowsservercore:1809

ADD lcow-injector-webhook.exe /lcow-injector-webhook.exe
ENTRYPOINT ["/lcow-injector-webhook.exe"]