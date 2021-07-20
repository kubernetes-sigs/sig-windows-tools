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
	"path"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// buildCmd represents the build command
var buildCmd = &cobra.Command{
	Use:   "build",
	Short: "Download the resources specified in your config file ready to be served by the burrito",
	Long: `
	Read the specified config file and download the resources into the files 
	sub directory.`,
	Run: func(cmd *cobra.Command, args []string) {
		var mc utils.BurritoConfig
		if err := viper.Unmarshal(&mc); err != nil {
			fmt.Println(err)
		}

		for _, c := range mc.Components {
			path, err := os.Getwd()
			if err != nil {
				log.Println(err)
			}
			location := filepath.Join(path, mc.FsDir, c.Name)
			os.MkdirAll(location, os.ModePerm)
			fmt.Printf("Fetching: %s from %s\n", c.Name, c.Source)
			DownloadFile(location, c.Source, c.Sha256)

		}
	},
}

// DownloadFile will download a url to a local file. It's efficient because it will
// write as it downloads and not load the whole file into memory.
func DownloadFile(folder, url, checksum string) error {

	// Get the data
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Create the file
	r, _ := http.NewRequest("GET", url, nil)
	filename := fmt.Sprintf(path.Base(r.URL.Path))
	downloadlocation := fmt.Sprintf("%s/%s", folder, filename)
	out, err := os.Create(downloadlocation)
	if err != nil {
		return err
	}
	defer out.Close()

	// Write the body to file
	_, err = io.Copy(out, resp.Body)
	if checksum == "" {
		fmt.Println("No checksum specified to validate download: Skipping")

	} else {
		hash := GetFileHash(downloadlocation)
		if checksum != hash {
			fmt.Printf("Expected: %s got %s", checksum, hash)
			os.Remove(downloadlocation)
		}
	}
	return err
}

func GetFileHash(file string) string {
	f, err := os.Open(file)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		log.Fatal(err)
	}
	hash := fmt.Sprintf("%x", h.Sum(nil))
	return hash
}

func init() {
	rootCmd.AddCommand(buildCmd)
}
