// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct Permission {
    address strategy;
    address target;
    bytes4 signature;
}

interface IVertexPolicyNFT {
    event PermissionAdded(string role, Permission permission, uint256 permissionSignature);
    event PermissionDeleted(string role, Permission permission, uint256 permissionSignature);
    event RoleAdded(string role, Permission[] permissions, uint256[] permissionSignatures);
    event RoleDeleted(string role);
    event RoleRevoked(uint256 tokenId, string role);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // Check if a holder has a permissionSignature at a specific block number
    function holderHasPermissionAt(
        address policyHolder,
        bytes32 permissionSignature,
        uint256 blockNumber
    ) external view returns (bool);

    // Total number of policy NFTs at specific block number
    // TODO: This should queried at action creation time and stored on the Action object
    function totalSupplyAt(uint256 blockNumber) external view returns (uint256);

    // Total number of policy NFTs at that have at least 1 of these permissions at specific block number
    // TODO: This should queried at action creation time and stored on the Action object
    function getSupplyByPermissionsAt(bytes32[] memory permissions, uint256 blockNumber) external view returns (uint256);

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

    function ownerOf(uint256 tokenId) external view returns (address);

    function revokeRole(uint256 tokenId, string memory role) external;

    function roles(uint256) external view returns (string memory);

    function roleToPermissionSignatures(string memory, uint256) external view returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) external;

    function setApprovalForAll(address operator, bool approved) external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function tokenToRoles(uint256, uint256) external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferOwnership(address newOwner) external;
}
