// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/token/ERC721/ERC721.sol";

struct Permission {
    address target;
    bytes4 signature;
    address executor;
}

contract SentryERC721 is ERC721 {
    mapping(uint256 => string[]) public tokenToRoles;
    mapping(string => uint256[]) public rolesToPermissionSignatures;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function getPermissionSignatures(uint256 tokenId) public view returns (uint256[] memory) {
        string[] storage roles = tokenToRoles[tokenId];
        uint256[] memory permissionSignatures;
        for (uint256 i; i < roles.length; i++) {
            uint256[] memory rolePermissionSignatures = rolesToPermissionSignatures[roles[i]];
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

    function hashPermission(Permission memory permission) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(permission.target, permission.signature, permission.executor)));
    }
}
