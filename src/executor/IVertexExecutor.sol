// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVertexExecutor {
    function execute(address target, uint256 value, string memory signature, bytes memory data) external returns (bytes memory);
}
