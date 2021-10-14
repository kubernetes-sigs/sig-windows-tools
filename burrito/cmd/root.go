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
	"burrito/utils"
	"log"

	homedir "github.com/mitchellh/go-homedir"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile string
	verFile string
	mc      utils.BurritoConfig
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "burrito",
	Short: "A useful bundler to host files for kubernetes-sigs/image-builder",
	Long: `
	Downloads and hosts files relating to image-builder, it can also provide the variables
	file that can be passed to image-builder as arguments`,
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	cobra.CheckErr(rootCmd.Execute())
}

func init() {
	cobra.OnInitialize(initConfig)
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.burrito.yaml)")
	rootCmd.PersistentFlags().StringVar(&verFile, "versions", "", "versions file (default is $HOME/.versions)")
}

// initConfig reads in config file and ENV variables if set.
func initConfig() {
	if cfgFile != "" {
		// Use config file from the flag.
		viper.SetConfigFile(cfgFile)
	} else {
		// Find home directory.
		home, err := homedir.Dir()
		cobra.CheckErr(err)

		// Search config in home directory with name ".burrito" (without extension).
		viper.AddConfigPath(home)
		viper.SetConfigName(".burrito")
	}

	viper.AutomaticEnv() // read in environment variables that match

	// If a config file is found, read it in.
	if err := viper.ReadInConfig(); err != nil {
		log.Fatalf("Error reading config %s: %s", viper.ConfigFileUsed(), err)
	}

	log.Printf("Using config file: %s", viper.ConfigFileUsed())

	if err := viper.Unmarshal(&mc); err != nil {
		log.Fatalf("Using config file: %s", err)
	}
}
