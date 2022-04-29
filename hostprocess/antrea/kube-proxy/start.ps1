if (test-path env:KUBEPROXY_PATH){ 
        $KubeProxy = $env:KUBEPROXY_PATH
}else {
        $KubeProxy = "$env:CONTAINER_SANDBOX_MOUNT_POINT/kube-proxy/kube-proxy.exe"
        # TODO check if we can use Antrea kube-proxy binary here
}

Write-Host "Write files so the kubeconfig points to correct locations"
mkdir -force /var/lib/kube-proxy/

cp $env:CONTAINER_SANDBOX_MOUNT_POINT/k/antrea/etc/kube-proxy.conf /var/lib/kube-proxy/kubeconfig.conf

$arguements = "--proxy-mode=userspace",
        "--kubeconfig=/var/lib/kube-proxy/kubeconfig.conf",
        "--log-dir=C:\var\log\kube-proxy", 
        "--logtostderr=false", 
        "--alsologtostderr"

$exe = "$KubeProxy " + ($arguements -join " ")

Write-Host "Starting $exe"
Invoke-Expression $exe
