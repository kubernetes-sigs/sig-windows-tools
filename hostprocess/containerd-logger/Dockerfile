# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build-env
WORKDIR /app

# Copy csproj and restore as distinct layers
COPY *.csproj ./
RUN dotnet restore

# Copy everything else and build
COPY program.cs ./
COPY eventFlowConfig.json ./
RUN dotnet publish -c Release -r win-x64 -o out

# Build runtime image
FROM mcr.microsoft.com/windows/nanoserver:1809
WORKDIR /
COPY --from=build-env /app/out/containerd-logger.exe .
ENTRYPOINT ["containerd-logger.exe"]
