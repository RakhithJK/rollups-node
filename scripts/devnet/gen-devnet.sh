#!/usr/bin/env bash
# (c) Cartesi and individual authors (see AUTHORS)
# SPDX-License-Identifier: Apache-2.0 (see LICENSE)
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

script_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir

. "$script_dir/lib/util.sh"
. "$script_dir/lib/anvil.sh"
. "$script_dir/lib/contracts.sh"

################################################################################
# Configuration
DEVNET_RPC_URL="http://localhost:8545"
DEVNET_AUTHORITY_HISTORY_FACTORY_ADDRESS="0x3890A047Cf9Af60731E80B2105362BbDCD70142D"
DEVNET_DAPP_FACTORY_ADDRESS="0x7122cd1221C20892234186facfE8615e6743Ab02"
DEVNET_FOUNDRY_ACCOUNT_0_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
DEVNET_FOUNDRY_ACCOUNT_0_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
# Salt is the same as hardhat's create2Salt
# See https://github.com/wighawag/hardhat-deploy/blob/a611466906282969cee601e4f6cd53438fefa2b3/src/helpers.ts#L559
DEVNET_DEFAULT_SALT="0x0000000000000000000000000000000000000000000000000000000000000000"
readonly ROLLUPS_CONTRACTS_VERSION \
    DEVNET_RPC_URL \
    DEVNET_AUTHORITY_HISTORY_FACTORY_ADDRESS \
    DEVNET_DAPP_FACTORY_ADDRESS \
    DEVNET_FOUNDRY_ACCOUNT_0_ADDRESS \
    DEVNET_FOUNDRY_ACCOUNT_0_PRIVATE_KEY \
    DEVNET_DEFAULT_SALT

# Defaults
rollups_contracts_version="${ROLLUPS_CONTRACTS_VERSION}"
devnet_anvil_state_file=$(realpath "./anvil_state.json")
devnet_deployment_file=$(realpath "./deployment.json")
template_hash_file=""
VERBOSE=""

# Deployment info, which will be gathered during processing
declare -A deployment_info

################################################################################
# Utility functions
################################################################################
usage()
{
   echo
   echo "Generate devnet for testing the Cartesi Rollups Node"
   echo
   echo "Usage: ROLLUPS_CONTRACTS_VERSION="VERSION_NUMBER" $0 [options]"
   echo
   echo "OPTIONS:"
   echo
   echo "    -t template-hash-file"
   echo "        Mandatory Cartesi Machine template hash file"
   echo "    -a"
   echo "        Path for output anvil state file"
   echo "    -d"
   echo "        Path for deployment information file"
   echo "    -v"
   echo "        Verbose mode"
   echo "    -h"
   echo "        Show this message"
   echo

   exit 0
}

################################################################################
# Finish processing and clean up environment
finish() {
    verbose "finishing up"

    if [ -n "$work_dir" ]; then
        rm -rf "$work_dir"
        check_error $? "failed to remove workdir $work_dir"
    fi

    if [[ -n "$anvil_pid" ]]; then
        anvil_down "$anvil_pid"
    fi
}

################################################################################
# Print deployment report
print_report() {
    log "Deployment report:"
    log "rollups-contracts version: $ROLLUPS_CONTRACTS_VERSION"
    log "anvil state file location: $devnet_anvil_state_file"
    log "deployment file location : $devnet_deployment_file"
}

################################################################################
# Generate deployment file
generate_deployment_file() {
    local deployment_file="$1"

    echo "{" > "$deployment_file"
    for key in "${!deployment_info[@]}"; do
        echo "    \"${key}\": \"${deployment_info[${key}]}\"," >> "$deployment_file"
    done
    echo "}" >> "$deployment_file"
    verbose "Deployment information saved to $deployment_file"
}

################################################################################
# create DApp contracts
create_dapp() {
    local -n ret="$1"
    local addresses

    contract_create \
        addresses \
        block_number \
        "$DEVNET_AUTHORITY_HISTORY_FACTORY_ADDRESS" \
        "newAuthorityHistoryPair(address,bytes32)(address,address)" \
            "$DEVNET_FOUNDRY_ACCOUNT_0_ADDRESS" \
            "$DEVNET_DEFAULT_SALT"
    authority_address="${addresses[0]}"
    history_address="${addresses[1]}"
    deployment_info["CARTESI_CONTRACTS_AUTHORITY_ADDRESS"]="$authority_address"
    deployment_info["CARTESI_CONTRACTS_HISTORY_ADDRESS"]="$history_address"
    verbose "deployed authority_address=$authority_address"
    verbose "deployed history_address=$history_address"

    contract_create \
        addresses \
        block_number \
        "$DEVNET_DAPP_FACTORY_ADDRESS" \
        "newApplication(address,address,bytes32,bytes32)(address)" \
            "$authority_address" \
            "$DEVNET_FOUNDRY_ACCOUNT_0_ADDRESS" \
            "$template_hash" \
            "$DEVNET_DEFAULT_SALT"
    ret="${addresses[0]}"
    deployment_info["CARTESI_CONTRACTS_DAPP_ADDRESS"]="$ret"
    deployment_info["CARTESI_CONTRACTS_DAPP_DEPLOYMENT_BLOCK_NUMBER"]="$block_number"
    verbose "deployed dapp_address=$ret"
}

################################################################################
# Main workflow
################################################################################

# Process script options
while getopts ":a:d:t:hv" option; do
    case $option in
        a)
            devnet_anvil_state_file=$(realpath "$OPTARG")
            ;;
        d)
            devnet_deployment_file=$(realpath "$OPTARG")
            ;;
        t)
            template_hash_file="$OPTARG"
            ;;
        h)
            usage
            ;;
        v)
            VERBOSE=1
            ;;
        \?)
            err "$OPTARG is not a valid option"
            usage
            ;;
    esac
done

if [[ -z "$rollups_contracts_version" ]]; then
    err "missing ROLLUPS_CONTRACTS_VERSION definition"
    usage
fi

if [[ -z "$template_hash_file" ]]; then
    err "missing template-hash-file"
    usage
fi

template_hash=$(xxd -p "$template_hash_file")
check_error $? "failed to read template hash"
template_hash=$(echo "$template_hash" | tr -d "\n")
readonly devnet_anvil_state_file devnet_deployment_file template_hash

# From here on, any exit deserves a clean up
trap finish EXIT ERR

log "starting devnet creation"
work_dir=$(mktemp -d)
readonly work_dir
check_error $? "failed to create temp dir"
verbose "created work dir at $work_dir"

anvil_pid=""
anvil_up \
    anvil_pid \
    "$devnet_anvil_state_file"
check_error $? "failed to start anvil"
log "started anvil (pid=$anvil_pid)"

deploy_rollups \
    "$work_dir" \
    "$rollups_contracts_version"
check_error $? "failed to deploy rollups-contracts"
log "rollups-contracts successfully deployed"

create_dapp \
    dapp_address
log "created CartesiDApp"

generate_deployment_file \
    "$devnet_deployment_file"

print_report
log "done creating devnet"
