package main

import (
	"flag"
	"log"
	"os"
	"os/exec"
	"strings"
)

func run(file string, params []string) {
	shell := "pwsh"
	if _, err := exec.LookPath(shell); err != nil {
		shell = "powershell"
	}
	args := []string{"-NoLogo", "-File", file}
	if len(args) > 0 {
		args = append(args, params...)
	}
	cmd := exec.Command(shell, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		log.Fatalf("Error running PowerShell script %s with args %s: %v", file, params, err)
		panic(err)
	}
}

func main() {
	ps_script_file := flag.String("file", "", "PowerShell script path to execute")
	ps_params := flag.String("params", "", "PowerShell script parameters (comma-seperated list)")
	flag.Parse()

	run(*ps_script_file, strings.Split(*ps_params, ","))
}
