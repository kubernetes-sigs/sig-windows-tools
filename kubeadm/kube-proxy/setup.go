package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
)

func getSourceVip(networkName string) {
    run(fmt.Sprintf(`ipmo c:\k\kube-proxy\hns.psm1; Get-SourceVip -NetworkName "%s"`, networkName))
}


func run(command string) {
	cmd := exec.Command("powershell", "-Command", command)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatalf("Error running command: %v", err)
	}
}

func main() {
    mode := flag.String("mode", "", "Network mode: overlay or l2bridge")
    networkName := flag.String("networkName", "", "Name of the network name to use for flanneld")
    flag.Parse()
    
    switch *mode {
    case "overlay":
        getSourceVip(*networkName)
    case "l2bridge":
		log.Printf("Network mode: %s, networkName: %s, No operation required\n", *mode, *networkName)
    default:
		log.Fatalf("invalid networkName %q. Options are 'vxlan0' and 'flannel.4096'", *networkName)
	}
}