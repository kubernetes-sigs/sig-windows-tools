ARG OS=1809
FROM mcr.microsoft.com/windows/nanoserver:${OS} as runtime
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build-env
WORKDIR /app

# Copy csproj and restore as distinct layers
COPY *.csproj ./
RUN dotnet restore

# Copy everything else and build
COPY Program.cs ./
COPY eventFlowConfig.json ./
RUN dotnet publish -c Release -r win-x64 -o out

# Build runtime image
FROM runtime
WORKDIR /
COPY --from=build-env /app/out/eventflow-logger.exe .
ENTRYPOINT ["eventflow-logger.exe"]
