// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PermissionData, PolicyUpdateData, PolicyGrantData, PolicyRevokeData} from "src/lib/Structs.sol";

interface IVertexPolicyNFT {
  event PolicyAdded(PolicyGrantData grantData);
  event PermissionUpdated(PolicyUpdateData updateData);
  event PolicyRevoked(PolicyRevokeData revokeData);

  /// @notice updates the permissions for a policy token
  /// @param updateData array of PolicyUpdateData struct to update permissions
  function batchUpdatePermissions(PolicyUpdateData[] calldata updateData) external;

  /// @notice mints multiple policy token with the given permissions
  /// @param policyData array of PolicyGrantData struct to mint policy tokens
  function batchGrantPolicies(PolicyGrantData[] memory policyData) external;

  /// @notice revokes all permissions from multiple policy tokens
  /// @dev all permissions that the policy holds must be passed to the permissionsToRevoke array to avoid a permission
  /// not passed being available if a
  /// policy was ever reissued to the same address
  /// @param policyData array of PolicyRevokeData struct to revoke permissions
  function batchRevokePolicies(PolicyRevokeData[] calldata policyData) external;

  /// @notice Check if a holder has a permissionSignature at a specific timestamp
  /// @param policyholder the address of the policy holder
  /// @param permissionSignature the signature of the permission
  /// @param timestamp the block number to query
  function holderHasPermissionAt(address policyholder, bytes8 permissionSignature, uint256 timestamp)
    external
    view
    returns (bool);

  /// @notice Check if a holder has an expired permissionSignature and removes their permission if it is expired
  /// @dev should be called periodically to remove expired permissions
  /// @param policyId the address of the policy holder
  /// @param permissionSignature the signature of the permission
  function revokeExpiredPermission(uint256 policyId, bytes8 permissionSignature) external returns (bool expired);

  /// @notice sets the base URI for the contract
  /// @param _baseURI the base URI string to set
  function setBaseURI(string calldata _baseURI) external;

  /// @notice Total number of policy NFTs at that have at least 1 of these permissions at specific block number
  /// @param permissions the permissions we are querying for
  function getSupplyByPermissions(bytes8[] calldata permissions) external view returns (uint256);

  /// @dev returns the total token supply of the contract
  function totalSupply() external view returns (uint256);

  /// @dev checks if a token has a permission
  /// @param policyId the id of the token
  /// @param permissionSignature the signature of the permission
  function hasPermission(uint256 policyId, bytes8 permissionSignature) external view returns (bool);
}
