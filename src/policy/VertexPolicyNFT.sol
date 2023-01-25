// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@solmate/tokens/ERC721.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {VertexPolicy} from "src/policy/VertexPolicy.sol";
import {Permission} from "src/utils/Structs.sol";

///@title VertexPolicyNFT
///@dev VertexPolicyNFT is a (TODO: pick a soulbound standard) ERC721 contract where each token has permissions
///@notice The permissions determine how the token can interact with the vertex administrator contract

contract VertexPolicyNFT is VertexPolicy {
    mapping(uint256 => bytes8[]) public tokenToPermissionSignatures;
    mapping(uint256 => mapping(bytes8 => bool)) public tokenToHasPermissionSignature;
    mapping(bytes8 => uint256) public permissionSupply;
    bytes8[] public permissions;
    uint256 private _totalSupply;
    address public immutable vertex;
    string public baseURI;

    modifier onlyVertex() {
        if (msg.sender != vertex) revert OnlyVertex();
        _;
    }

    constructor(string memory name, string memory symbol, address _vertex) ERC721(name, symbol) {
        vertex = _vertex;
    }

    ///@notice mints multiple policy token with the given permissions
    ///@param to the addresses to mint the policy token to
    ///@param userPermissions the permissions to be granted to the policy token
    function batchGrantPermissions(address[] calldata to, bytes8[][] calldata userPermissions) public override onlyVertex {
        uint256 length = userPermissions.length;
        if (length == 0 || length != to.length) revert InvalidInput();
        for (uint256 i = 0; i < length; i++) {
            grantPermissions(to[i], userPermissions[i]);
        }
    }

    ///@notice revokes all permissions from multiple policy tokens
    ///@param tokenIds the ids of the policy tokens to revoke permissions from
    function batchRevokePermissions(uint256[] calldata tokenIds) public override onlyVertex {
        uint256 length = tokenIds.length;
        if (length == 0) revert InvalidInput();
        for (uint256 i = 0; i < length; i++) {
            revokePermissions(tokenIds[i]);
        }
    }

    ///@dev overriding transferFrom to disable transfers for SBTs
    ///@dev this is a temporary solution, we will need to conform to a Souldbound standard
    function transferFrom(address from, address to, uint256 tokenId) public override {
        revert SoulboundToken();
    }

    // BEGIN TODO

    ///@notice Check if a holder has a permissionSignature at a specific block number
    ///@param policyHolder the address of the policy holder
    ///@param permissionSignature the signature of the permission
    ///@param blockNumber the block number to query
    function holderHasPermissionAt(address policyHolder, bytes8 permissionSignature, uint256 blockNumber) external view override returns (bool) {
        // TODO
        return true;
    }

    ///@notice sets the base URI for the contract
    ///@param _baseURI the base URI string to set
    function setBaseURI(string memory _baseURI) public override onlyVertex {
        baseURI = _baseURI;
    }

    ///@notice Total number of policy NFTs at specific block number
    ///@param blockNumber the block number to query
    // TODO: This should queried at action creation time and stored on the Action object
    function totalSupplyAt(uint256 blockNumber) external view override returns (uint256) {
        // TODO
        return totalSupply();
    }

    ///@notice Total number of policy NFTs at that have at least 1 of these permissions at specific block number
    ///@param _permissions the permissions we are querying for
    // TODO: This should queried at action creation time and stored on the Action object
    function getSupplyByPermissions(bytes8[] memory _permissions) external view override returns (uint256) {
        // TODO
        return totalSupply();
    }

    ///@dev hashes a permission
    ///@param permission the permission to hash
    function hashPermission(Permission memory permission) public pure returns (bytes8) {
        return bytes8(keccak256(abi.encodePacked(permission.target, permission.selector, permission.strategy)));
    }

    // END TODO

    ///@dev hashes an array of permissions
    ///@param _permissions the permissions array to hash
    function hashPermissions(Permission[] calldata _permissions) public pure returns (bytes8[] memory) {
        uint256 length = _permissions.length;
        bytes8[] memory output = new bytes8[](length);
        unchecked {
            for (uint256 i; i < length; ++i) {
                output[i] = hashPermission(_permissions[i]);
            }
        }
        return output;
    }

    ///@notice mints a new policy token with the given permissions
    ///@param to the address to mint the policy token to
    ///@param userPermissions the permissions to be granted to the policy token
    function grantPermissions(address to, bytes8[] calldata userPermissions) private {
        if (balanceOf(to) != 0) revert SoulboundToken();
        uint256 length = userPermissions.length;
        if (length == 0) revert InvalidInput();
        uint256 userId = uint256(uint160(to));
        unchecked {
            _totalSupply++;
            tokenToPermissionSignatures[userId] = userPermissions;
            for (uint256 i = 0; i < length; i++) {
                if (permissionSupply[userPermissions[i]] == 0) {
                    permissions.push(userPermissions[i]);
                    ++permissionSupply[userPermissions[i]];
                }
                if (!tokenToHasPermissionSignature[userId][userPermissions[i]]) {
                    tokenToHasPermissionSignature[userId][userPermissions[i]] = true;
                }
            }
            _mint(to, userId);
        }
    }

    ///@notice revokes all permissions from a policy token
    ///@param tokenId the id of the policy token to revoke permissions from
    function revokePermissions(uint256 tokenId) private {
        if (ownerOf(tokenId) == address(0)) revert InvalidInput();
        bytes8[] storage userPermissions = tokenToPermissionSignatures[tokenId];
        uint256 userPermissionslength = userPermissions.length;
        unchecked {
            _totalSupply--;
            for (uint256 i; i < userPermissionslength; ++i) {
                permissionSupply[userPermissions[i]]--;
                tokenToHasPermissionSignature[tokenId][userPermissions[i]] = false;
            }
        }
        delete tokenToPermissionSignatures[tokenId];
        _burn(tokenId);
    }

    ///@dev returns the total token supply of the contract
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    ///@notice returns the permission signatures of a token
    ///@param userId the id of the policy token
    function getPermissionSignatures(uint256 userId) public view override returns (bytes8[] memory) {
        return tokenToPermissionSignatures[userId];
    }

    ///@dev checks if a token has a permission
    ///@param tokenId the id of the token
    ///@param permissionSignature the signature of the permission
    function hasPermission(uint256 tokenId, bytes8 permissionSignature) public view override returns (bool) {
        return tokenToHasPermissionSignature[tokenId][permissionSignature];
    }

    ///@notice returns the location of the policy metadata
    ///@param id the id of the policy token
    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(id)));
    }
}
