# Calico example

This contains a HostProcess container for kube-proxy that works with Calico.  It uses the release files from Calico. The felix and node services scripts are modified slightly until we can get the support in upstream which has other dependencies.

DSR and overlay networking are configured through the `--enable-dsr` and `--source-vip` kube-proxy options, respectively. For kube-proxy versions before v1.38, the startup script also passes the corresponding `WinDSR` and `WinOverlay` feature gates. Starting with v1.38, these gates have been removed, so the script omits them.

See [guides/guide-for-adding-windows-node.md](../../guides/guide-for-adding-windows-node.md) for details on installing Calico