#!/usr/bin/env bash
# (c) Cartesi and individual authors (see AUTHORS)
# SPDX-License-Identifier: Apache-2.0 (see LICENSE)
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

DEVNET_ANVIL_STATE_INTERVAL=5
DEVNET_ANVIL_TIMEOUT=$(expr $DEVNET_ANVIL_STATE_INTERVAL + 10)
readonly DEVNET_ANVIL_STATE_INTERVAL DEVNET_ANVIL_TIMEOUT

anvil \
    --host "$ANVIL_IP_ADDR" \
    --dump-state "$ANVIL_STATE_FILE" \
    --state-interval "$DEVNET_ANVIL_STATE_INTERVAL" &
#    \
#    --silent &
#TODO export ANVIL_PID="$!"

#sleep "$DEVNET_ANVIL_TIMEOUT"
