/*
Copyright © 2021 The Kubnernetes Authoers

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
	"crypto/sha256"
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path"
	"path/filepath"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(buildCmd)
}

// buildCmd represents the build command
var buildCmd = &cobra.Command{
	Use:   "build",
	Short: "Download the resources specified in your config file ready to be served by the burrito",
	Long: `
	Read the specified config file and download the resources into the files 
	sub directory.`,
	Run: func(cmd *cobra.Command, args []string) {
		http.DefaultTransport.(*http.Transport).TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
		for _, c := range mc.Components {
			path, err := os.Getwd()
			if err != nil {
				cmd.Println(err)
			}
			location := filepath.Join(path, mc.FsDir, c.Name)
			if err := os.MkdirAll(location, os.ModePerm); err != nil {
				panic(err)
			}

			log.Printf("validating file for %s\n", c.Name)
			if err := DownloadFile(location, c.Source, c.Sha256); err != nil {
				cobra.CheckErr(err)
			}
		}
	},
}

// DownloadFile will download a url to a local file. It's efficient because it will
// write as it downloads and not load the whole file into memory.
func DownloadFile(folder, url, checksum string) error {
	// Create the file
	r, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}
	downloadlocation := filepath.Join(folder, path.Base(r.URL.Path))

	if _, err := os.Stat(downloadlocation); err == nil {
		log.Printf("file already exists: %s\n", downloadlocation)
		return nil
	}

	log.Printf("fetching file %s\n", url)

	// local file doesn't exist, download it
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	out, err := os.Create(downloadlocation)
	if err != nil {
		return err
	}
	defer out.Close()

	log.Printf("downloading file to %s\n", downloadlocation)
	_, err = io.Copy(out, resp.Body)
	if err != nil {
		return err
	}

	if checksum == "" {
		log.Printf("No checksum specified, skipping download validation: %s\n", downloadlocation)
		return nil
	}

	hash, err := GetFileHash(downloadlocation)
	if err != nil {
		return err
	}

	if checksum != hash {
		log.Printf("Expected: %s got %s\n", checksum, hash)
		if err := os.Remove(downloadlocation); err != nil {
			return err
		}
	}

	return nil
}

func GetFileHash(file string) (string, error) {
	f, err := os.Open(file)
	if err != nil {
		return "", nil
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	hash := fmt.Sprintf("%x", h.Sum(nil))
	return hash, nil
}
