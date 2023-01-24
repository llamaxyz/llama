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

    ///@notice mints a new policy token with the given permissions
    ///@param to the address to mint the policy token to
    ///@param userPermissions the permissions to be granted to the policy token
    function grantPermissions(address to, bytes8[] calldata userPermissions) public override onlyVertex {
        if (balanceOf(to) != 0) revert SoulboundToken();
        uint256 length = userPermissions.length;
        if (length == 0) revert InvalidInput();
        uint256 userId = uint256(to);
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
    function revokePermissions(uint256 tokenId) public override onlyVertex {
        if (ownerOf(tokenId) == address(0)) revert InvalidInput();
        bytes8[] storage userPermissions = tokenToPermissionSignatures[tokenId];
        uint256 userPermissionslength = userPermissions.length;
        delete tokenToPermissionSignatures[tokenId];
        unchecked {
            _totalSupply--;
            for (uint256 i; i < userPermissionslength; ++i) {
                permissionSupply[userPermissions[i]]--;
                tokenToHasPermissionSignature[tokenId][userPermissions[i]] = false;
            }
        }
        _burn(tokenId);
    }

    ///@dev overriding transferFrom to disable transfers for SBTs
    ///@dev this is a temporary solution, we will need to conform to a Souldbound standard
    function transferFrom(address from, address to, uint256 tokenId) public override {
        revert SoulboundToken();
    }

    // BEGIN TODO

    // Check if a holder has a permissionSignature at a specific block number
    function holderHasPermissionAt(address policyHolder, bytes8 permissionSignature, uint256 blockNumber) external view override returns (bool) {
        // TODO
        return true;
    }

    function setBaseURI(string memory _baseURI) public override onlyVertex {
        baseURI = _baseURI;
    }

    // Total number of policy NFTs at specific block number
    // TODO: This should queried at action creation time and stored on the Action object
    function totalSupplyAt(uint256 blockNumber) external view override returns (uint256) {
        // TODO
        return totalSupply();
    }

    // Total number of policy NFTs at that have at least 1 of these permissions at specific block number
    // TODO: This should queried at action creation time and stored on the Action object
    function getSupplyByPermissions(bytes8[] memory permissions) external view override returns (uint256) {
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
    ///@param permissions the permissions array to hash
    function hashPermissions(Permission[] calldata permissions) internal pure returns (bytes8[] memory) {
        bytes8[] memory output = new bytes8[](permissions.length);
        unchecked {
            for (uint256 i; i < permissions.length; ++i) {
                output[i] = hashPermission(permissions[i]);
            }
        }
        return output;
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

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(id)));
    }
}
