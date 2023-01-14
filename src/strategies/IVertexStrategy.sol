// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVertexStrategy {
    function initiateAction(address target, uint256 value, string calldata signature, bytes calldata callData) external;
}
