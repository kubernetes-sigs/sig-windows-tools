# Calico example

This contains a HostProcess container for kube-proxy that works with Calico.  It uses the release files from Calico. The felix and node services scripts are modified slightly until we can get the support in upstream which has other dependencies.

See https://docs.tigera.io/calico/latest/getting-started/kubernetes/windows-calico/operator for details on installing Calico