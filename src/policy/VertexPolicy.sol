// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@solmate/tokens/ERC721.sol";
import {Permission} from "src/utils/Structs.sol";

abstract contract VertexPolicy is ERC721 {
    event PermissionsAdded(uint256[] users, Permission[] permissions, bytes8[] permissionSignatures);
    event PermissionsDeleted(uint256[] users, bytes8[] permissionSignatures);

    error SoulboundToken();
    error InvalidInput();
    error OnlyVertex();

    ///@dev mints a new token
    ///@param to the address to mint the token to
    ///@param userPermissions the permissions to be granted to the token
    function mint(address to, bytes32[] calldata userPermissions) public virtual {}

    ///@dev burns a token
    ///@param tokenId the id of the token to burn
    function burn(uint256 tokenId) public virtual {}

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
}
