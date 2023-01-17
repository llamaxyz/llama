// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

function getChainId() pure returns (uint256) {
    uint256 chainId;
    assembly {
        chainId := chainid()
    }
    return chainId;
}
