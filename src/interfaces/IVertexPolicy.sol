// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {PermissionData, PolicyUpdateData, PolicyGrantData, PolicyRevokeData} from "src/lib/Structs.sol";

interface IVertexPolicy {
  event PolicyAdded(PolicyGrantData grantData);
  event PermissionUpdated(PolicyUpdateData updateData);
  event PolicyRevoked(PolicyRevokeData revokeData);

  /// @notice initializes the contract
  /// @param _name the name of the contract
  /// @param initialPolicies the initial policies to mint
  function initialize(string memory _name, PolicyGrantData[] memory initialPolicies) external;

  /// @notice sets the vertexCore address
  /// @param _vertex the address of the vertexCore
  function setVertex(address _vertex) external;

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

  /// @notice Check if a holder has a permissionId at a specific timestamp
  /// @param policyholder the address of the policy holder
  /// @param role the signature of the permission
  /// @param timestamp the block number to query
  function holderWeightAt(address policyholder, bytes32 role, uint256 timestamp) external view returns (uint256);

  /// @notice sets the base URI for the contract
  /// @param _baseURI the base URI string to set
  function setBaseURI(string calldata _baseURI) external;

  /// @dev returns the total token supply of the contract
  function totalSupply() external view returns (uint256);

  /// @dev checks if a token has a permission
  /// @param policyId the id of the token
  /// @param permissionId the signature of the permission
  function hasPermission(uint256 policyId, bytes32 permissionId) external view returns (bool);
}
