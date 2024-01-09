package main

import (
	"encoding/hex"
	"log"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestHashMatches(t *testing.T) {
	const HASH = "427a8eeaa6a990b7b1e4e1a4d34b4d21a536e05c6d52aa4b40a58efcee609ab0"

	hashFile, err := os.CreateTemp("", "hash_file")
	if err != nil {
		log.Fatal(err)
	}
	defer os.Remove(hashFile.Name())

	bytes, err := hex.DecodeString(HASH)
	if err != nil {
		log.Fatal(err)
	}

	if _, err := hashFile.Write(bytes); err != nil {
		log.Fatal(err)
	}

	hash := readMachineHash(hashFile.Name())
	assert.Equal(t, HASH, hash, "hash from file does not match expected value")
}
