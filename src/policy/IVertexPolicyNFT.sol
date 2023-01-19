// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// TODO: I'm just creating this interface so builds will pass.
// The strategy uses unimplemented view functions on builds will fail otherwise
// @theo this also where we can track the expected interface between strategy and policy

interface IVertexPolicyNFT {
    // Check if a holder has a permissionSignature at a specific block number
    function holderHasPermissionAt(address policyHolder, bytes32 permissionSignature, uint256 blockNumber) external view returns (bool);

    // Total number of policy NFTs at specific block number
    function totalSupplyAt(uint256 blockNumber) external view returns (uint256);

    // Total number of policy NFTs at that have at least 1 of these permissions at specific block number
    function getSupplyByPermissionsAt(bytes32[] memory permissions, uint256 blockNumber) external view returns (uint256);
}
