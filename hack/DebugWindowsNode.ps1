Write-Output "Checking for common problems with Windows Kubernetes nodes"

$global:DockerVersion = $null

$currentVersion = Get-Item 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$OSProductName = $currentVersion.GetValue('ProductName')
$OSBuildLabel = $currentVersion.GetValue('BuildLabEx')
Write-Output "Container Host OS Product Name: $OSProductName"
Write-Output "Container Host OS Build Label: $OSBuildLabel"

Describe "Windows Version and Prerequisites" {
    $buildNumber = (Get-CimInstance -Namespace root\cimv2 Win32_OperatingSystem).BuildNumber
    It "Is Windows Server 2019 (or higher)" {
        $buildNumber -ge 17763 | Should Be $true
    }

    It "Has 'Containers' feature installed" {
        if (((Get-ComputerInfo).WindowsInstallationType) -eq "Client") {
            (Get-WindowsOptionalFeature -Online -FeatureName Containers).State | Should Be "Enabled"
        }
        else {
            (Get-WindowsFeature -Name Containers).InstallState | Should Be "Installed"
        }
    }

    It "Has HNS running" {
        (Get-Service "hns").Status | Should BeExactly "Running"
    }
}

Describe "Docker is installed" {
    $services = Get-Service | Where-Object {($_.Name -eq "Docker") -or ($_.Name -eq "com.Docker.Service")}

    It "A Docker service is installed - 'Docker' or 'com.Docker.Service' " {
        $services| Should Not BeNullOrEmpty
    }

    It "Service is running" {
        $AtLeastOneRunning = $false;
        foreach ($service in $services)
        {
           #if there is more than 1 only one can be running
           if ($service.Status -eq "Running")
           {
                $AtLeastOneRunning = $true
           }
        }
        $AtLeastOneRunning | Should Be $true
    }

    It "Docker.exe is in path" {
        # This also captures 'docker info' and 'docker version' output to be shown later
        {
            $versionText = & docker.exe version --format '{{ json . }}'
            $global:DockerVersion = $versionText | ConvertFrom-Json
        } | Should Not Throw
    }

    It "Should be a supported version" {
        $supported = $false
        if ($global:DockerVersion.Server.Version -match "\d+\.\d+\.\d+") {
             $dockerVersion = [version]$Matches[0]
             $supported = $dockerVersion -ge [version]"19.3.0"
        }
        $supported | Should Be $true
    }
}

Write-Output "Docker version: $($global:DockerVersion.Server.Version)"

Describe "Kubernetes processes are running" {
    It "There is 1 running kubelet.exe process" {
        (Get-Process "kubelet").Count | Should BeExactly 1
    }
    It "There is 1 running kube-proxy.exe process" {
        (Get-Process "*kube-proxy*").Count | Should BeExactly 1
    }
}
