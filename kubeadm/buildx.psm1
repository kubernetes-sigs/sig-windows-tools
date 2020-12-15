function Set-Builder()
{
    $env:DOCKER_CLI_EXPERIMENTAL = "enabled"
    & docker buildx create --name img-builder --use --driver docker-container --driver-opt image=moby/buildkit:v0.7.2
}

function New-Build()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$name,
        [Parameter(Mandatory = $true)]
        [ValidateSet("docker", "registry")]
        [string]$output,
        [Parameter(Mandatory = $true)]
        [string[]]$args
    )

    $command = "docker buildx build --platform windows/amd64 --output=type=$output -f Dockerfile -t $name"
    foreach($arg in $args)
    {
        $command = "$command --build-arg=$arg"
    }
    $command = "$command ."
    Write-Host $command
    Invoke-Expression $command
}

function Get-ManifestName([string]$name)
{
    if (($name -split "/").Length -eq 1) {
        $name = "library/$name"
    }
    if (($name -split "/").Length -eq 2) {
        $name = "docker.io/$name"
    }
    return ($name -replace "/", "_") -replace ":", "-"
}

function Push-Manifest([string]$name, [string[]]$items, [string[]]$bases)
{
    $folder = Get-ManifestName -name $name
    if (Test-Path "~/.docker/manifests/$folder")
    {
        Write-Warning "Manifest $name already exists and will be overridden."
        & docker manifest rm $name | out-null
    }

    $command = "docker manifest create $name";
    foreach($item in $items)
    {
        $command = "$command --amend $item"
    }
    Write-Host $command
    Invoke-Expression $command

    # Use `docker manifest annotate` instead of this when docker cli 20.* is ready.
    # See details: https://github.com/docker/cli/pull/2578
    for ($i = 0; $i -lt $items.Length; $i++) {
        $base = $bases[$i]
        $item = $items[$i]

        $manifest = $(docker manifest inspect $base -v) | ConvertFrom-Json
        $platform = $manifest.Descriptor.platform

        $img = Get-ManifestName -name $item
    
        $manifest = Get-Content "~/.docker/manifests/$folder/$img" | ConvertFrom-Json
        $manifest.Descriptor.platform = $platform
        $manifest | ConvertTo-Json -Depth 10 -Compress | Set-Content "~/.docker/manifests/$folder/$img"
    }

    & docker manifest push $name
}

Export-ModuleMember Set-Builder
Export-ModuleMember New-Build
Export-ModuleMember Push-Manifest
