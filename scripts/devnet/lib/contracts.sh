#!/usr/bin/env bash
# (c) Cartesi and individual authors (see AUTHORS)
# SPDX-License-Identifier: Apache-2.0 (see LICENSE)

################################################################################
# Deploy rollups-contracts
deploy_rollups() {
    local tmp_dir=$1
    shift
    local contracts_version=$1

    cd "$tmp_dir"

    local download_dir="$tmp_dir/downloads"
    local artifact_name="rollups-contracts"
    local tgz_file="v$contracts_version.tar.gz"
    local url="https://github.com/cartesi/$artifact_name/archive/refs/tags/$tgz_file"

    mkdir -p "$download_dir"
    wget \
        --quiet \
        $url \
        --directory-prefix $download_dir
    check_error $? "failed to download $url"

    tar zxf \
        $download_dir/$tgz_file \
        --directory $download_dir \
        > /dev/null
    check_error $? "failed to extract $download_dir/$tgz_file"

    local tar_dir="$download_dir/$artifact_name-$contracts_version"
    log "downloaded rollups-contracts to $tar_dir"

    cd "$tar_dir/onchain/rollups"
    yarn install
    RPC_URL="$DEVNET_RPC_URL" yarn deploy:development
    cd -
    #rm -rf "$tar_dir" "$download_dir"
}

################################################################################
# Call arbitrary code on a contract
# Splits returned values into an array
contract_create() {
    local -n addrs="$1"
    shift
    local -n block="$1"
    shift

    # Generate values without issuing a transaction
    local values=$(
        cast call \
            --rpc-url $DEVNET_RPC_URL \
            $@
    )
    check_error $? "failed to retrieve returned values"
    # Split returned values
    IFS=$'\n' addrs=($values)

    # Send tansaction
    block=$(cast send \
        --json \
        --rpc-url $DEVNET_RPC_URL \
        --private-key $DEVNET_FOUNDRY_ACCOUNT_0_PRIVATE_KEY \
        $@ \
        | jq -r '.blockNumber'
    )
    check_error $? "failed to send transaction"
}
