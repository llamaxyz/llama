// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@solmate/tokens/ERC721.sol";
import {PermissionData} from "src/utils/Structs.sol";

abstract contract VertexPolicy is ERC721 {
    event PermissionsAdded(uint256[] users, PermissionData[] permissions, bytes8[] permissionSignatures);
    event PermissionsDeleted(uint256[] users, bytes8[] permissionSignatures);

    error SoulboundToken();
    error InvalidInput();
    error OnlyVertex();
    error OnlyOnePolicyPerHolder();
    error OnlyVertexFactory();
    error AlreadyInitialized();

    /// @notice updates the permissions for a policy token
    /// @param _policyIds the policy token id being altered
    /// @param permissions the new permissions array to be set
    /// @param expirationTimestamps the new expiration timestamps array to be set
    function batchUpdatePermissions(uint256[] calldata _policyIds, bytes8[][] calldata permissions, uint256[][] calldata expirationTimestamps) public virtual;

    /// @notice mints multiple policy token with the given permissions
    /// @param to the addresses to mint the policy token to
    /// @param userPermissions the permissions to be granted to the policy token
    /// @param expirationTimestamps the expiration timestamps to be set for the policy token
    function batchGrantPermissions(address[] calldata to, bytes8[][] memory userPermissions, uint256[][] memory expirationTimestamps) public virtual;

    /// @notice revokes all permissions from multiple policy tokens
    /// @param policyIds the ids of the policy tokens to revoke permissions from
    function batchRevokePermissions(uint256[] calldata policyIds) public virtual;

    /// @notice Check if a holder has a permissionSignature at a specific block number
    /// @param policyholder the address of the policy holder
    /// @param permissionSignature the signature of the permission
    /// @param blockNumber the block number to query
    function holderHasPermissionAt(address policyholder, bytes8 permissionSignature, uint256 blockNumber) external view virtual returns (bool);

    /// @notice Check if a holder has an expired permissionSignature and removes their permission if it is expired
    /// @param policyId the address of the policy holder
    /// @param permissionSignature the signature of the permission
    function checkExpiration(uint256 policyId, bytes8 permissionSignature) public virtual returns (bool expired);

    /// @notice sets the base URI for the contract
    /// @param _baseURI the base URI string to set
    function setBaseURI(string calldata _baseURI) public virtual;

    /// @notice Total number of policy NFTs at that have at least 1 of these permissions at specific block number
    /// @param permissions the permissions we are querying for
    function getSupplyByPermissions(bytes8[] calldata permissions) external view virtual returns (uint256);

    /// @dev returns the total token supply of the contract
    function totalSupply() public view virtual returns (uint256);

    /// @dev returns the permission signatures of a token
    /// @param policyId the id of the token
    function getPermissionSignatures(uint256 policyId) public view virtual returns (bytes8[] memory);

    /// @dev checks if a token has a permission
    /// @param policyId the id of the token
    /// @param permissionSignature the signature of the permission
    function hasPermission(uint256 policyId, bytes8 permissionSignature) public view virtual returns (bool);
}
