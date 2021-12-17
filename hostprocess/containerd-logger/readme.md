# Containerd logger

This is a small applicaiton that you can run inside a hostproces container (or directly on the host) that will log ETW events to stdout.

This makes use of the [EventFlow library](https://github.com/Azure/diagnostics-eventflow).  The [inputs](https://github.com/Azure/diagnostics-eventflow#inputs) and [outputs](https://github.com/Azure/diagnostics-eventflow#outputs) can be adjust according to the documentation. There are also [filters](https://github.com/Azure/diagnostics-eventflow#filters) that can be applied to events.

## Hostpocess container

Build the contianer:

```
docker build -t jsturtevant/containerd-logger .
```

Deploy:

```
kubectl apply -f containerd-logger.yaml
```

## Running locally

```
dotnet run -- eventFlowConfig.json
```

## Publishing as single file
Configured to produce a [single binary(https://docs.microsoft.com/en-us/dotnet/core/deploying/single-file#publish-a-single-file-app---cli)].  To build run:

```
dotnet publish -r win-x64
```
