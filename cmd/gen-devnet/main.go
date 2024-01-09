// (c) Cartesi and individual authors (see AUTHORS)
// SPDX-License-Identifier: Apache-2.0 (see LICENSE)

package main

import (
	"encoding/json"
	"os"

	"github.com/spf13/cobra"
)

var Cmd = &cobra.Command{
	Use:   "gen-devnet",
	Short: "Generates a devnet for testing",
	Long: `Generates a devnet to be used for testing.
It uses a previously generated Cartesi Machine snapshot
and deploys an Application based upon it's hash file.`,
	Run: run,
}

var (
	hashFile    string
	rpcEndpoint string
)

func init() {
	Cmd.Flags().StringVarP(&hashFile, "template-hash-file", "t", "",
		"path for a Cartesi Machine template hash file")
	Cmd.MarkFlagRequired("template-hash-file")
	Cmd.Flags().StringVarP(&rpcEndpoint, "rpc-endpoint", "r", "http://0.0.0.0:8545",
		"URL to be used to deploy anvil")
}

func run(cmd *cobra.Command, args []string) {
	depInfo, err := generate(rpcEndpoint, hashFile)

	jsonInfo, err := json.MarshalIndent(depInfo, "", "\t")
	if err != nil {
		panic(err)
	}
	os.Stdout.Write(jsonInfo)
}

func main() {
	err := Cmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}
