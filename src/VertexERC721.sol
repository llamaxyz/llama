// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/access/Ownable.sol";

///@dev Struct to define a permission
struct Permission {
    address target;
    bytes4 signature;
    address executor;
}

///@title VertexERC721
///@dev VertexERC721 is a (TODO: soulbound) ERC721 contract where each token has roles and permissions
///@dev The roles and permissions determine how the token can interact with the vertex administrator contract

contract VertexERC721 is ERC721, Ownable {
    mapping(uint256 => string[]) public tokenToRoles;
    mapping(string => uint256[]) public rolesToPermissionSignatures;
    string[] public roles;
    uint256 private _totalSupply;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        /* potential idea for deployment:
         * 1: mint initial NFTs with initial roles to users, contributors, etc
         * 2: deploy the administator contract
         * 2.5: (in the constructor of the administrator contract will deploy the initial executor contracts)
         * 3: set administrator contract as owner of VertexERC721
         *
         * now the administrator contract can control the VertexERC721 contract via governance
         */
    }

    ///@dev returns the permission signatures of a token
    ///@param tokenId the id of the token
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

    ///@dev checks if a token has a permission
    ///@param tokenId the id of the token
    ///@param permissionSignature the signature of the permission
    function hasPermission(uint256 tokenId, uint256 permissionSignature) public view returns (bool) {
        uint256[] memory permissionSignatures = getPermissionSignatures(tokenId);
        for (uint256 i; i < permissionSignatures.length; i++) {
            if (permissionSignatures[i] == permissionSignature) {
                return true;
            }
        }
        return false;
    }

    ///@dev hashes a permission
    ///@param permission the permission to hash
    function hashPermission(Permission calldata permission) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(permission.target, permission.signature, permission.executor)));
    }

    ///@dev returns the total token supply of the contract
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    ///@dev mints a new token
    ///@param to the address to mint the token to
    ///@param userRoles the roles of the token
    function mint(address to, string[] memory userRoles) public onlyOwner {
        uint256 tokenId = totalSupply() + 1;
        _mint(to, tokenId);
        tokenToRoles[tokenId] = userRoles;
    }

    ///@dev burns a token
    ///@param tokenId the id of the token to burn
    function burn(uint256 tokenId) public onlyOwner {
        delete tokenToRoles[tokenId];
        _burn(tokenId);
    }

    ///@dev adds a role to the contract
    ///@param role the role to add
    ///@param permissions the permissions of the role
    function addRole(string calldata role, Permission[] calldata permissions) public onlyOwner {
        roles.push(role);
        for (uint256 i; i < permissions.length; i++) {
            uint256 permissionSignature = hashPermission(permissions[i]);
            rolesToPermissionSignatures[role][rolesToPermissionSignatures[role].length - 1] = permissionSignature;
        }
    }

    ///@dev assigns a role to a token
    ///@param tokenId the id of the token
    function assignRole(uint256 tokenId, string calldata role) public onlyOwner {
        tokenToRoles[tokenId].push(role);
    }

    ///@dev revokes a role from a token
    ///@param tokenId the id of the token
    ///@param role the role to revoke
    function revokeRole(uint256 tokenId, string calldata role) public onlyOwner {
        string[] storage userRoles = tokenToRoles[tokenId];
        for (uint256 i; i < userRoles.length; i++) {
            if (keccak256(abi.encodePacked(roles[i])) == keccak256(abi.encodePacked(role))) {
                delete roles[i];
            }
        }
    }

    ///@dev deletes a role from the contract
    ///@param role the role to delete
    function deleteRole(string calldata role) public onlyOwner {
        delete rolesToPermissionSignatures[role];
        for (uint256 i; i < roles.length; i++) {
            if (keccak256(abi.encodePacked(roles[i])) == keccak256(abi.encodePacked(role))) {
                delete roles[i];
            }
        }
    }

    function addPermissionToRole(string calldata role, Permission calldata permission) public onlyOwner {
        uint256 permissionSignature = hashPermission(permission);
        rolesToPermissionSignatures[role][rolesToPermissionSignatures[role].length - 1] = permissionSignature;
    }

    function deletePermissionFromRole(string calldata role, Permission calldata permission) public onlyOwner {
        uint256 permissionSignature = hashPermission(permission);
        uint256[] storage rolePermissionSignatures = rolesToPermissionSignatures[role];
        for (uint256 i; i < rolePermissionSignatures.length; i++) {
            if (rolePermissionSignatures[i] == permissionSignature) {
                delete rolePermissionSignatures[i];
            }
        }
    }
}
