// Copyright (C) 2020 Cartesi Pte. Ltd.

// SPDX-License-Identifier: GPL-3.0-only
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.

// This program is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
// PARTICULAR PURPOSE. See the GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Note: This component currently has dependencies that are licensed under the GNU
// GPL, version 3, and so you should treat this component as a whole as being under
// the GPL version 3. But all Cartesi-written code in this component is licensed
// under the Apache License, version 2, or a compatible permissive license, and can
// be used independently under the Apache v2 license. After this component is
// rewritten, the entire component will be released under the Apache v2 license.

/// @title Output Implementation
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract OutputImpl is Output {
    use BitMask for uint256[];

    address immutable descartesV2; // descartes 2 contract using this validator

    bytes32[] epochHashes;
    uint256[] outputBitmask;

    // @notice functions modified by onlyDescartesV2 will only be executed if
    // they're called by DescartesV2 contract, otherwise it will throw an exception
    modifier onlyDescartesV2 {
        require(
            msg.sender == descartesV2,
            "Only descartesV2 can call this functions"
        );
        _;
    }

    /// @notice executes output
    /// @param _epochIndex which epoch the output belongs to
    /// @param _inputIndex which input, inside the epoch, the output belongs to
    /// @param _outputIndex index of output inside the input
    /// @param _output bytes that describe the ouput, can encode different things
    /// @param _proof siblings of output, to prove it is contained on epoch hash
    /// @return true if output was executed successfully
    /// @dev  outputs can only be executed once
    function executeOutput(
        uint256 _epochIndex,
        uint256 _inputIndex,
        uint256 _outputIndex,
        bytes calldata _output,
        bytes32[] calldata _proof
    ) public override returns (bool) {
        uint256 position = getBitMaskPosition(_outputIndex, _inputIndex, _epochIndex);

        require(
            outputBitmask.getBit(position) == 0,
            "output has already been executed"
        );

        bytes32 outputHash = keccak256(_output);

        // TODO: Merkle getRoot has some hardcoded values that we need to fix
        require(
            Merkle.getRoot(
                _outputIndex,
                outputHash,
                _proof
            ) == outputHashOfEpoch[_epochIndex],
            "merkle proofs do not match"
        );

        (address target, bytes data) = decodeOutput(_output);

        // TODO: add reentrancy guard
        // do we need return data? emit event?
        (bool succ, bytes32 memory returnData) = address(target).call(data);

        if (succ) outputBitmask.setBit(position, 1);

        return succ;
    }

    /// @notice called by descartesv2 when an epoch is finalized
    /// @param _epochHash hash of finalized epoch 
    /// @dev an epoch being finalized means that its outputs can be called
    function onNewEpoch(bytes32 _epochHash) onlyDescartesV2 public override {
        epochHashes.push(_epochHash);
    }

    /// @notice translate output into coherent information
    /// @param _output output bytes
    /// @return target address contained on _output
    /// @return data contained on _output
    function decodeOutput(bytes calldata _output) returns (address, bytes) {
        // TODO: we have to decide how the output is going to be encoded
        // where do we store this information?

    }

    /// @notice get output position on bitmask
    /// @param _output of output inside the input
    /// @param _input which input, inside the epoch, the output belongs to
    /// @param _epoch which epoch the output belongs to
    /// @return position of that output on bitmask 
    function getBitMaskPosition(
        uint256 _output,
        uint256 _input,
        uint256 _epoch
    )
    private
    returns (uint256)
    {
        // output * 2 ** 128 + input * 2 ** 64 + epoch
        // this can't overflow because its impossible to have > 2**128 outputs
        return (_output << 128) + (_input << 64) + _epoch;
    }
}