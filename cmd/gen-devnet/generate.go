package main

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"log"
	"os"
	"os/exec"
	"strings"
)

// Self-contained procedure for generating a devnet image inside
// a Docker container
// It MUST not depend on any other facilities

// XXX Same as internal/services/service.go
/*type Service interface {
	fmt.Stringer

	// Starts a service and sends a message to the channel when ready
	Start(ctx context.Context, ready chan<- struct{}) error
}

type AnvilService struct {
	IpAddr string
}

func (s AnvilService) String() string {
	return fmt.Sprintf("Anvil running on %v", s.IpAddr)
}

func (s AnvilService) Start(ctx context.Context) error {
	cmd := exec.CommandContext(ctx, "anvil")

	var out strings.Builder
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return err
	}
	fmt.Printf("in all caps: %q\n", out.String())

	return nil
}

func newAnvilService(ipAddr string) AnvilService {
	return AnvilService{
		IpAddr: ipAddr,
	}
}
*/

// TODO Think about using pkg/addresses/addresses.go (aka copying it to the build container)
var config = DeploymentConfig{
	authorityHistoryFactoryAddress: "0x3890A047Cf9Af60731E80B2105362BbDCD70142D",
	applicationFactoryAddress:      "0x7122cd1221C20892234186facfE8615e6743Ab02",
	signerAddress:                  "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
	signerPrivateKey:               "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
	salt:                           "0x0000000000000000000000000000000000000000000000000000000000000000",
}

// Generate the actual Application by reading the template machine hash and
// calling the Rollups contracts
func generate(rpcUrl string, hashPath string) (DeploymentInfo, error) {
	ctx := context.Background()
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	config.hash = readMachineHash(hashPath)

	// TODO Start anvil
	/*
		anvil := newAnvilService(rpcUrl)
			if err := anvil.Start(ctx); err != nil {
				log.Fatalf("Failed to start anvil: %v", err)
			}
	*/
	// TODO Deploy rollups contracts

	// Deploy Application. Assumes Rollups contracts are deployed
	config.rpcUrl = rpcUrl
	depInfo, err := createApplication(config)
	if err != nil {
		log.Fatalf("could not create Application: %v", err)
	}

	return depInfo, nil
}

// Read template machine hash from file
func readMachineHash(hashPath string) string {
	data, err := os.ReadFile(hashPath)
	if err != nil {
		log.Fatalf("Error reading %v (%v)", hashPath, err)
	}

	return hex.EncodeToString(data)
}

// Create a Rollups Application by calling the necessary factories
func createApplication(config DeploymentConfig) (DeploymentInfo, error) {
	depInfo := DeploymentInfo{"", "", "", ""}

	// Create the Authority/History pair
	addresses, blockNumber, err := execContract(
		config,
		config.authorityHistoryFactoryAddress,
		"newAuthorityHistoryPair(address,bytes32)(address,address)",
		config.signerAddress,
		config.signerPrivateKey,
		config.salt)
	if err != nil {
		log.Fatalf("could not create application: %v", err)
	}

	depInfo.AuthorityAddress = addresses[0]
	depInfo.HistoryAddress = addresses[1]

	// Create the Application, passing the address of the newly created Authority
	addresses, blockNumber, err = execContract(
		config,
		config.applicationFactoryAddress,
		"newApplication(address,address,bytes32,bytes32)(address)",
		depInfo.AuthorityAddress,
		config.signerAddress,
		config.hash,
		config.salt)
	if err != nil {
		log.Fatalf("could not create application: %v", err)
	}

	depInfo.ApplicationAddress = addresses[0]
	depInfo.BlockNumber = blockNumber

	return depInfo, nil
}

// Call a contract factory, passing a factory function to be executed.
// Returns the resulting contract address(es) and the corresponding
// block number.
//
// Warning: a second call to a contract with the same arguments will fail.
func execContract(config DeploymentConfig, args ...string) ([]string, string, error) {
	commonArgs := []string{"--rpc-url", config.rpcUrl}
	commonArgs = append(commonArgs, args...)

	// Calculate the resulting deterministc address(es)
	castCall := exec.Command(
		"cast",
		"call")
	castCall.Args = append(castCall.Args, commonArgs...)
	var outStrBuilder strings.Builder
	castCall.Stdout = &outStrBuilder
	err := castCall.Run()
	if err != nil {
		log.Fatalf("command failed %v: %v", castCall.Args, err)
	}
	addresses := strings.Fields(outStrBuilder.String())

	// Perform actual transaction on the contract
	castSend := exec.Command(
		"cast",
		"send",
		"--json",
		"--private-key",
		config.signerPrivateKey)
	castSend.Args = append(castSend.Args, commonArgs...)
	outStrBuilder.Reset()
	castSend.Stdout = &outStrBuilder
	err = castSend.Run()
	if err != nil {
		log.Fatalf("command failed %v: %v", castSend.Args, err)
	}

	// Extract blockNumber from JSON output
	jsonMap := make(map[string](any))
	err = json.Unmarshal([]byte([]byte(outStrBuilder.String())), &jsonMap)
	if err != nil {
		log.Fatalf("failed to unmarshal json, %s", err.Error())
	}
	blockNumber := jsonMap["blockNumber"].(string)

	return addresses, blockNumber, nil
}
