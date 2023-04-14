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

Describe "Kubernetes processes are running" {
    It "There is 1 running kubelet.exe process" {
        (Get-Process "kubelet").Count | Should BeExactly 1
    }
    It "There is 1 running kube-proxy.exe process" {
        (Get-Process "*kube-proxy*").Count | Should BeExactly 1
    }
}
