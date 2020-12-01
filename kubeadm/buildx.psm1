function Set-Builder()
{
    $env:DOCKER_CLI_EXPERIMENTAL = "enabled"
    & docker buildx create --name img-builder --use
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

function Push-Manifest([string]$name, [string[]]$items, [string[]]$bases)
{
    $command = "docker manifest create $name";
    foreach($item in $items)
    {
        $command = "$command --amend $item"
    }
    Write-Host $command
    Invoke-Expression $command

    for ($i = 0; $i -lt $items.Length; $i++) {
        $base = $bases[$i]
        $item = $items[$i]

        $manifest = $(docker manifest inspect $base -v) | ConvertFrom-Json
        $platform = $manifest.Descriptor.platform

        $folder = ("docker.io/$name" -replace "/", "_") -replace ":", "-"
        $img = ("docker.io/$item" -replace "/", "_") -replace ":", "-"
    
        $manifest = Get-Content "~/.docker/manifests/$folder/$img" | ConvertFrom-Json
        $manifest.Descriptor.platform = $platform
        $manifest | ConvertTo-Json -Depth 10 -Compress | Set-Content "~/.docker/manifests/$folder/$img"
    }

    & docker manifest push $name
}

Export-ModuleMember Set-Builder
Export-ModuleMember New-Build
Export-ModuleMember Push-Manifest
