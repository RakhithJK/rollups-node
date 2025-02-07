// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

package main

import (
	"fmt"
	"go/format"
	"os"
	"sort"
	"strings"

	"github.com/BurntSushi/toml"
)

func readTOML(name string) string {
	bytes, err := os.ReadFile(name)
	if err != nil {
		panic(err)
	}
	return string(bytes)
}

type configTOML = map[string](map[string]*Env)

func decodeTOML(data string) configTOML {
	var config configTOML
	_, err := toml.Decode(data, &config)
	if err != nil {
		panic(err)
	}
	return config
}

// Creates sorted lists of environment variables from the config
// to make the generated files deterministic.
func sortConfig(config configTOML) []Env {
	var topics []string
	mapping := make(map[string]([]string)) // topic names to env names

	for name, topic := range config {
		var envs []string
		for name, env := range topic {
			env.Name = name // initializes the environment variable's name
			envs = append(envs, name)
		}
		sort.Strings(envs)

		topics = append(topics, name)
		mapping[name] = envs
	}
	sort.Strings(topics)

	var envs []Env
	for _, topic := range topics {
		for _, name := range mapping[topic] {
			envs = append(envs, *config[topic][name])
		}
	}

	return envs
}

func addLine(builder *strings.Builder, s string, a ...any) {
	builder.WriteString(fmt.Sprintf(s, a...))
	builder.WriteString("\n")
}

func addCodeHeader(builder *strings.Builder) {
	addLine(builder, `// Code generated by internal/config/generate.`)
	addLine(builder, `// DO NOT EDIT.`)
	addLine(builder, "")

	addLine(builder, `// (c) Cartesi and individual authors (see AUTHORS)`)
	addLine(builder, `// SPDX-License-Identifier: Apache-2.0 (see LICENSE)`)
	addLine(builder, "")

	addLine(builder, `package config`)
	addLine(builder, `import (`)
	addLine(builder, `"time"`)
	addLine(builder, `)`)
	addLine(builder, "")

	// adding aliases for the <to> functions
	addLine(builder, `type (`)
	addLine(builder, `Duration = time.Duration`)
	addLine(builder, `)`)
	addLine(builder, "")
}

func addDocHeader(builder *strings.Builder) {
	addLine(builder, "<!--")
	addLine(builder, "File generated by internal/config/generate.")
	addLine(builder, "DO NOT EDIT.")
	addLine(builder, "-->")
	addLine(builder, "")
	addLine(builder, "<!-- markdownlint-disable line_length -->")

	addLine(builder, "# Node Configuration")
	addLine(builder, "")

	addLine(builder, "The node is configurable through environment variables.")
	addLine(builder, "(There is no other way to configure it.)")
	addLine(builder, "")

	addLine(builder, "This file documents the configuration options.")
	addLine(builder, "")
}

func formatCode(s string) []byte {
	bytes, err := format.Source([]byte(s))
	if err != nil {
		panic(err)
	}
	return bytes
}

func writeToFile(name string, bytes []byte) {
	// creating the file
	codeFile, err := os.Create(name)
	if err != nil {
		panic(err)
	}
	defer codeFile.Close()

	// writing to the file
	_, err = codeFile.Write(bytes)
	if err != nil {
		panic(err)
	}
}
