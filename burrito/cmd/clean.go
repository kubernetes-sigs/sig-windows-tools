/*
Copyright © 2021 The Kubernetes Authors
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
	"bufio"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(cleanCmd)
}

// cleanCmd represents the clean command
var cleanCmd = &cobra.Command{
	Use:   "clean",
	Short: "Remove downloaded files",
	Long: `
	Cleans any downloaded files created by build`,
	Run: func(cmd *cobra.Command, args []string) {
		if !confirm(cmd, "Are you sure you want to clean up?", 3) {
			return
		}
		path, err := os.Getwd()
		if err != nil {
			log.Printf("unable to get curring working dir: %s\n", err)
		}

		location := filepath.Join(path, mc.FsDir)
		log.Printf("removing all files from %s", location)
		if _, err := os.Stat(location); !os.IsNotExist(err) {
			if err := os.RemoveAll(location); err != nil {
				log.Fatalf("unable to delete file %s:", err)
			}
		}
		log.Printf("cleanup complete")
	},
}

// confirm displays a prompt `s` to the user and returns a bool indicating yes / no
// If the lowercase, trimmed input begins with anything other than 'y', it returns false
// It accepts an int `tries` representing the number of attempts before returning false
func confirm(cmd *cobra.Command, s string, tries int) bool {
	r := bufio.NewReader(os.Stdin)
	for ; tries > 0; tries-- {
		cmd.Printf("%s [y/n]: ", s)

		res, err := r.ReadString('\n')
		if err != nil {
			log.Fatal(err)
		}

		// Empty input (i.e. "\n")
		if len(res) < 2 {
			continue
		}

		ok := strings.ToLower(strings.TrimSpace(res))[0]
		if ok == 'y' {
			return true
		}
		if ok == 'n' {
			return false
		}
	}
	return false
}
