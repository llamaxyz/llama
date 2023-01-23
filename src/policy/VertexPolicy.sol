// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@solmate/tokens/ERC721.sol";

struct Permission {
    address strategy;
    address target;
    bytes4 signature;
}

abstract contract VertexPolicy is ERC721 {
    event RolesAdded(bytes32[] roles, string[] roleStrings, Permission[][] permissions, bytes8[][] permissionSignatures);
    event RolesAssigned(uint256 tokenId, bytes32[] roles);
    event RolesRevoked(uint256 tokenId, bytes32[] roles);
    event RolesDeleted(bytes32[] role);
    event PermissionsAdded(bytes32 role, Permission[] permissions, bytes8[] permissionSignatures);
    event PermissionsDeleted(bytes32 role, bytes8[] permissionSignatures);

    error RoleNonExistant(bytes32 role);
    error SoulboundToken();
    error InvalidInput();
    error OnlyVertex();

    ///@dev checks if a token has a role
    ///@param tokenId the id of the token
    ///@param role the role to check
    function hasRole(uint256 tokenId, bytes32 role) public view virtual returns (bool) {}

    ///@dev mints a new token
    ///@param to the address to mint the token to
    ///@param userRoles the roles of the token
    function mint(address to, bytes32[] calldata userRoles) public virtual {}

    ///@dev burns a token
    ///@param tokenId the id of the token to burn
    function burn(uint256 tokenId) public virtual {}

    ///@dev allows admin to add a roles to the contract
    ///@dev indexes in rolesArray and permissionsArray must match
    ///@param rolesArray the roles to add
    ///@param permissionsArray and array of permissions arrays for each role
    function addRoles(string[] calldata rolesArray, Permission[][] calldata permissionsArray) public virtual {}

    ///@dev assigns a role to a token
    ///@param tokenId the id of the token
    function assignRoles(uint256 tokenId, bytes32[] calldata rolesArray) public virtual {}

    ///@dev revokes a role from a token
    ///@param tokenId the id of the token
    ///@param revokeRolesArray the array of roles to revoke
    function revokeRoles(uint256 tokenId, bytes32[] calldata revokeRolesArray) public virtual {}

    ///@dev deletes multiple roles from the contract
    ///@param deleteRolesArray the role to delete
    function deleteRoles(bytes32[] calldata deleteRolesArray) public virtual {}

    // Check if a holder has a permissionSignature at a specific block number
    function holderHasPermissionAt(address policyHolder, bytes32 permissionSignature, uint256 blockNumber) external view virtual returns (bool) {}

    function setBaseURI(string memory _baseURI) public virtual {}

    // Total number of policy NFTs at specific block number
    function totalSupplyAt(uint256 blockNumber) external view virtual returns (uint256) {}

    // Total number of policy NFTs at that have at least 1 of these permissions at specific block number
    function getSupplyByPermissions(bytes32[] memory permissions) external view virtual returns (uint256) {}

    ///@dev returns the total token supply of the contract
    function totalSupply() public view virtual returns (uint256) {}

    ///@dev returns the permission signatures of a token
    ///@param tokenId the id of the token
    function getPermissionSignatures(uint256 tokenId) public view virtual returns (bytes8[] memory) {}

    ///@dev checks if a token has a permission
    ///@param tokenId the id of the token
    ///@param permissionSignature the signature of the permission
    function hasPermission(uint256 tokenId, bytes8 permissionSignature) public view virtual returns (bool) {}

    function getRoles() public view virtual returns (bytes32[] memory) {}
}
