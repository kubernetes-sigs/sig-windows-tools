package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
)

func setupOverlay(interfaceName string) {
	run(fmt.Sprintf(`ipmo C:\k\flannel\hns.psm1; New-HNSNetwork -Type Overlay -AddressPrefix "192.168.255.0/30"`+
		`-Gateway "192.168.255.1" -Name "External" -AdapterName "%s" -SubnetPolicies @(@{Type = "VSID"; VSID = 9999; })`,
		interfaceName),
	)
}

func setupL2bridge(interfaceName string) {
	run(fmt.Sprintf(`ipmo C:\k\flannel\hns.psm1; New-HNSNetwork -Type Overlay -AddressPrefix "192.168.255.0/30"`+
		`-Gateway "192.168.255.1" -Name "External" -AdapterName "%s"`,
		interfaceName),
	)
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
	interfaceName := flag.String("interface", "", "Name of the network interface to use for Kubernetes networking")
	flag.Parse()

	switch *mode {
	case "overlay":
		setupOverlay(*interfaceName)
	case "l2bridge":
		setupL2bridge(*interfaceName)
	default:
		log.Fatalf("invalid mode %q. Options are 'overlay' and 'l2bridge'", *mode)
	}
}
