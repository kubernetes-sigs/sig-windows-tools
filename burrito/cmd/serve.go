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
	"crypto/sha256"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// serveCmd represents the serve command
var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Serve a URL Endpoint hosting the downloaded executables",
	Long: `
	Read the configuration file and serve the files, the files will be served. 
	under {fsDir}/{componentName}/{resource} For example:
	"containerd_url": "http://localhost:3000/files/containerd/containerd-1.5.2-windows-amd64.tar.gz"
	
	Defaults: 
	- port: 80`,
	Run: func(cmd *cobra.Command, args []string) {
		var mc utils.BurritoConfig
		if err := viper.Unmarshal(&mc); err != nil {
			fmt.Println(err)
		}
		httpRoot := mc.HttpRoot
		port := mc.Port
		if mc.Port != "80" && mc.Port != "" {
			httpRoot = fmt.Sprintf("%s:%s", mc.HttpRoot, mc.Port)
			port = mc.Port
		} else {
			port = "80"
		}
		if !preflightCheck(mc) {
			log.Fatal("One or more errors occurred when checking files, have you run build?")
		}
		print_contents(mc.FsDir, httpRoot)
		root := fmt.Sprintf("/%s/", mc.FsDir)
		http.Handle(root, http.StripPrefix(strings.TrimRight(root, "/"), http.FileServer(http.Dir(mc.FsDir))))
		log.Printf("Listening on :%s...\n", port)
		port = fmt.Sprintf(":%s", port)
		err := http.ListenAndServe(port, nil)
		if err != nil {
			log.Fatal(err)
		}
	},
}

func print_contents(root, url string) {
	var files []string

	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if !info.IsDir() {
			files = append(files, path)
		}
		return nil
	})
	if err != nil {
		panic(err)
	}
	for _, file := range files {
		fmt.Printf("http://%s/%s\n", url, file)
	}
}

func preflightCheck(mc utils.BurritoConfig) bool {
	ok := true
	for _, c := range mc.Components {
		path, err := os.Getwd()
		if err != nil {
			log.Println(err)
		}
		s := strings.Split(c.Source, "/")
		location := filepath.Join(path, mc.FsDir, c.Name, s[len(s)-1])
		if _, err := os.Stat(location); os.IsNotExist(err) {
			log.Printf("%s is unavailable", location)
			ok = false
		} else {
			if c.Sha256 != "" {
				shaCheck, actualSha := checkSha(location, c.Sha256)
				if !shaCheck {
					log.Printf("%s has an invalid checksum: expected %s, got %s", location, c.Sha256, actualSha)
					ok = false
				}
			}
		}
	}
	return ok
}

func checkSha(location, sha string) (bool, string) {
	f, err := os.Open(location)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		log.Fatal(err)
	}
	return fmt.Sprintf("%x", h.Sum(nil)) == sha, fmt.Sprintf("%x", h.Sum(nil))
}

func init() {
	rootCmd.AddCommand(serveCmd)
}
