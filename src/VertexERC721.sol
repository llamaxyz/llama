// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/access/Ownable.sol";

struct Permission {
    address target;
    bytes4 signature;
    address executor;
}

contract VertexERC721 is ERC721, Ownable {
    mapping(uint256 => string[]) public tokenToRoles;
    mapping(string => uint256[]) public rolesToPermissionSignatures;
    string[] public roles;
    uint256 private _totalSupply;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function getPermissionSignatures(uint256 tokenId) public view returns (uint256[] memory) {
        string[] memory userRoles = tokenToRoles[tokenId];
        uint256[] memory permissionSignatures;
        for (uint256 i; i < userRoles.length; i++) {
            uint256[] memory rolePermissionSignatures = rolesToPermissionSignatures[userRoles[i]];
            for (uint256 j; j < rolePermissionSignatures.length; j++) {
                permissionSignatures[permissionSignatures.length - 1] = rolePermissionSignatures[j];
            }
        }
        return permissionSignatures;
    }

    function hasPermission(uint256 tokenId, uint256 permissionSignature) public view returns (bool) {
        uint256[] memory permissionSignatures = getPermissionSignatures(tokenId);
        for (uint256 i; i < permissionSignatures.length; i++) {
            if (permissionSignatures[i] == permissionSignature) {
                return true;
            }
        }
        return false;
    }

    function hashPermission(Permission calldata permission) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(permission.target, permission.signature, permission.executor)));
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function mint(address to, string[] memory userRoles) public onlyOwner {
        uint256 tokenId = totalSupply() + 1;
        _mint(to, tokenId);
        tokenToRoles[tokenId] = userRoles;
    }

    function addRole(string calldata role, Permission[] calldata permissions) public onlyOwner {
        roles.push(role);
        for (uint256 i; i < permissions.length; i++) {
            uint256 permissionSignature = hashPermission(permissions[i]);
            rolesToPermissionSignatures[role][rolesToPermissionSignatures[role].length - 1] = permissionSignature;
        }
    }

    function assignRole(uint256 tokenId, string calldata role) public onlyOwner {
        tokenToRoles[tokenId].push(role);
    }

    function revokeRole(uint256 tokenId, string calldata role) public onlyOwner {
        string[] storage userRoles = tokenToRoles[tokenId];
        for (uint256 i; i < userRoles.length; i++) {
            if (keccak256(abi.encodePacked(roles[i])) == keccak256(abi.encodePacked(role))) {
                delete roles[i];
            }
        }
    }

    function deleteRole(string calldata role) public onlyOwner {
        delete rolesToPermissionSignatures[role];
        for (uint256 i; i < roles.length; i++) {
            if (keccak256(abi.encodePacked(roles[i])) == keccak256(abi.encodePacked(role))) {
                delete roles[i];
            }
        }
    }
}
