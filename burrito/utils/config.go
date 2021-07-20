package utils

type BurritoConfig struct {
	HttpRoot   string      `mapstructure:"httpRoot"`
	FsDir      string      `mapstructure:"fsDir"`
	Port       string      `mapstructure:"port"`
	Components []Component `mapstructure:"components"`
}

type Component struct {
	Name              string `mapstructure:"name"`
	Source            string `mapstructure:"src"`
	Sha256            string `mapstructure:"Sha256"`
	Variable_Src      string `mapstructure:"variable_src"`
	Variable_Checksum string `mapstructure:"variable_checksum"`
}
