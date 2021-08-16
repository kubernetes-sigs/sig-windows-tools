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

package utils

type BurritoConfig struct {
	HttpRoot   string      `mapstructure:"httpRoot"`
	FsDir      string      `mapstructure:"fsDir"`
	Port       string      `mapstructure:"port"`
	Components []Component `mapstructure:"components"`
}

type Component struct {
	Name             string `mapstructure:"name"`
	Source           string `mapstructure:"src"`
	Sha256           string `mapstructure:"Sha256"`
	VariableSrc      string `mapstructure:"variable_src"`
	VariableChecksum string `mapstructure:"variable_checksum"`
}
