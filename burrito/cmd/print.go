/*
Copyright © 2021 NAME HERE <EMAIL ADDRESS>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
package cmd

import (
	"burrito/utils"
	"encoding/json"
	"fmt"
	"net/http"
	"path"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// printCmd represents the print command
var printCmd = &cobra.Command{
	Use:   "print",
	Short: "Print the image-builder configuration variables",
	Long: `
	Read the configuration file and print the image-builder 
	variables that will be used by image builder. For example:

	Using config file: examples/burrito.yaml
	{
	   "cloudbase_init_url": "http://localhost:3000/files/cloudbase_init_v2/CloudbaseInitSetup_1_1_2_x64.msi",
	   "containerd_sha256_windows": "5e27d311e1aaab3fc26c3be0277485591e5e097085d3adf90d55dceb623ed5c0",
	   "containerd_url": "http://localhost:3000/files/containerd/containerd-1.5.2-windows-amd64.tar.gz",
	   "kubernetes_base_url": "http://localhost:3000/files/kubernetes/containerd-1.5.2-windows-amd64.tar.gz",
	   "nssm_url": "http://localhost:3000/files/nssm/nssm.exe",
	   "wins_url": "http://localhost:3000/files/wins/wins.exe"
	}`,
	Run: func(cmd *cobra.Command, args []string) {
		var mc utils.BurritoConfig
		if err := viper.Unmarshal(&mc); err != nil {
			fmt.Println(err)
		}
		d := make(map[string]string)
		for _, c := range mc.Components {
			if c.Variable_Src != "" {
				r, _ := http.NewRequest("GET", c.Source, nil)
				httpRoot := mc.HttpRoot
				if mc.Port != "80" && mc.Port != "" {
					httpRoot = fmt.Sprintf("%s:%s", mc.HttpRoot, mc.Port)
				}
				val := fmt.Sprintf("http://%s/%s/%s/%s", httpRoot, mc.FsDir, c.Name, path.Base(r.URL.Path))
				d[c.Variable_Src] = val
			}
			if c.Variable_Checksum != "" {
				d[c.Variable_Checksum] = c.Sha256
			}

		}
		json, err := json.MarshalIndent(d, "\r", "   ")
		if err != nil {
			fmt.Printf("Unable to Marshall to json: %e", err)
		}
		fmt.Println(string(json))
	},
}

func init() {
	rootCmd.AddCommand(printCmd)
}
