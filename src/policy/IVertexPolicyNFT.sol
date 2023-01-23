// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// TODO: @theo I'm just creating this interface so builds will pass.
// The strategy uses unimplemented view functions on builds will fail otherwise
// @theo this also where we can track the expected interface between strategy and policy

interface IVertexPolicyNFT {
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event PermissionAdded(string role, Permission permission, uint256 permissionSignature);
    event PermissionDeleted(string role, Permission permission, uint256 permissionSignature);
    event RoleAdded(string role, Permission[] permissions, uint256[] permissionSignatures);
    event RoleDeleted(string role);
    event RoleRevoked(uint256 tokenId, string role);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    struct Permission {
        address target;
        bytes4 selector;
        address executor;
    }

    // Check if a holder has a permissionSignature at a specific block number
    function holderHasPermissionAt(address policyholder, bytes32 permissionSignature, uint256 blockNumber) external view returns (bool);

    // Total number of policy NFTs
    function totalSupply() external view returns (uint256);

    // Total number of policy NFTs at that have at least 1 of these permissions
    function getSupplyByPermissions(bytes32[] memory permissions) external view returns (uint256);

    function addPermissionToRole(string memory role, Permission memory permission) external;

    function addRole(string memory role, Permission[] memory permissions) external;

    function approve(address to, uint256 tokenId) external;

    function assignRole(uint256 tokenId, string memory role) external;

    function balanceOf(address owner) external view returns (uint256);

    function burn(uint256 tokenId) external;

    function deletePermissionFromRole(string memory role, Permission memory permission) external;

    function deleteRole(string memory role) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function getPermissionSignatures(uint256 tokenId) external view returns (uint256[] memory);

    function hasPermission(uint256 tokenId, uint256 permissionSignature) external view returns (bool);

    function hasRole(uint256 tokenId, string memory role) external view returns (bool);

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function mint(address to, string[] memory userRoles) external;

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function ownerOf(uint256 tokenId) external view returns (address);

    function renounceOwnership() external;

    function revokeRole(uint256 tokenId, string memory role) external;

    function roles(uint256) external view returns (string memory);

    function rolesToPermissionSignatures(string memory, uint256) external view returns (uint256);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;

    function setApprovalForAll(address operator, bool approved) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function tokenToRoles(uint256, uint256) external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function transferOwnership(address newOwner) external;
}
