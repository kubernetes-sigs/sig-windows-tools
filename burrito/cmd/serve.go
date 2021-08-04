/*
Copyright © 2021 Peri Thompson

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
)

var build bool

func init() {
	serveCmd.Flags().BoolVarP(&build, "build", "b", false, "Perform a build when starting up the server")
	rootCmd.AddCommand(serveCmd)
}

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Serve a URL Endpoint hosting the downloadable files",
	Long: `
	Read the configuration file and serve the files, the files will be served. 
	under {fsDir}/{componentName}/{resource} For example:
	"containerd_url": "http://localhost:3000/files/containerd/containerd-1.5.2-windows-amd64.tar.gz"
	
	Flags:
	--build, -b	Build the file directory at runtime, like calling build before serve

	Defaults:
	- port: 80`,
	Run: func(cmd *cobra.Command, args []string) {
		if build {
			buildCmd.Run(cmd, []string{})
		}

		if !preflightCheck(mc) {
			log.Fatal("One or more errors occurred when checking files, have you run build?")
		}

		if mc.Port == "" {
			mc.Port = "80"
		}

		if mc.HttpRoot == "" {
			mc.HttpRoot = "localhost"
		}

		s := fmt.Sprintf("%s:%s", mc.HttpRoot, mc.Port)

		printContents(mc.FsDir, s)
		root := fmt.Sprintf("/%s/", mc.FsDir)
		http.Handle(root, http.StripPrefix(strings.TrimRight(root, "/"), http.FileServer(http.Dir(mc.FsDir))))

		log.Printf("Listening on :%s...\n", s)
		if err := http.ListenAndServe(s, nil); err != nil {
			log.Fatal(err)
		}
	},
}

func printContents(root, url string) {
	var files []string
	if err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if !info.IsDir() {
			files = append(files, filepath.ToSlash(path))
		}
		return nil
	}); err != nil {
		panic(err)
	}
	for _, file := range files {
		log.Printf("http://%s/%s\n", url, file)
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
			log.Printf("file to serve does not exist: %s", location)
			ok = false
			continue
		}

		if c.Sha256 == "" {
			continue
		}

		if shaCheck, actualSha := checkSha(location, c.Sha256); !shaCheck {
			log.Printf("%s has an invalid checksum: expected %s, got %s", location, c.Sha256, actualSha)
			ok = false
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
