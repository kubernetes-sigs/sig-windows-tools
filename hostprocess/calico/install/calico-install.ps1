# The CNI_BIN_DIR and CNI_CONF_DIR environment variables must be defined in the install-cni initContainer of the
# calico-node-windows daemonset. Otherwise, these values are not configurable.

Write-Host "Starting install. Cleaning up any previous files"
Remove-Item -Path $env:CNI_BIN_DIR/* -Recurse
Remove-Item -Path $env:CNI_CONF_DIR/* -Recurse

Write-Host "Writing calico kubeconfig to $env:CNI_CONF_DIR"
$token = Get-Content -Path "$env:CONTAINER_SANDBOX_MOUNT_POINT/var/run/secrets/kubernetes.io/serviceaccount/token"
$ca = Get-Content -Raw -Path "$env:CONTAINER_SANDBOX_MOUNT_POINT/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
$caBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($ca))

# TODO figure out how the kubernetes service endpoint works in Linux.
# For windows since kubeproxy hasn't started the endpoints are not configured on the SVC
# look it up via kubeadm configuration
$cpEndpoint = get-content $env:CONTAINER_SANDBOX_MOUNT_POINT/etc/kubeadm-config/ClusterConfiguration | ForEach-Object -Process {if($_.Contains("controlPlaneEndpoint:")) {$_.Trim().Split()[1]}}
$server = "server: https://$cpEndpoint"

(Get-Content $env:CONTAINER_SANDBOX_MOUNT_POINT\calico\calico-kube-config.template).
    replace('<ca>', $caBase64).
    replace('<server>', $server.Trim()).
    replace('<token>', $token) | Set-Content ${env:CNI_CONF_DIR}/calico-kubeconfig -Force

Write-Host "Copying CNI binaries to $env:CNI_BIN_DIR"
Copy-Item -Path "$env:CONTAINER_SANDBOX_MOUNT_POINT\calico\cni\calico.exe" -Destination "$env:CNI_BIN_DIR\calico.exe" -Force
Copy-Item -Path "$env:CONTAINER_SANDBOX_MOUNT_POINT\calico\cni\calico-ipam.exe" -Destination "$env:CNI_BIN_DIR\calico-ipam.exe" -Force

Write-Host "Writing CNI configuration to $env:CNI_CONF_DIR."
(echo "$env:CNI_NETWORK_CONFIG").
    replace('__KUBECONFIG_FILEPATH__', "$env:CNI_CONF_DIR/calico-kubeconfig").
    replace('__K8S_SERVICE_CIDR__', $env:K8S_SERVICE_CIDR).
    replace('__KUBERNETES_NODE_NAME__', $env:KUBERNETES_NODE_NAME).
    replace('__CNI_MTU__', $env:CNI_MTU) | Set-Content "${env:CNI_CONF_DIR}/10-calico.conflist" -Force

Write-Host "CNI configured"
