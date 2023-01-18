// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

function getChainId() view returns (uint256 chainId) {
    assembly {
        chainId := chainid()
    }
}
