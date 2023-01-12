// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/access/Ownable.sol";
import "@forge-std/console.sol";
import "@forge-std/Test.sol";

///@dev Struct to define a permission
struct Permission {
    address target;
    bytes4 signature;
    address executor;
}

///@title PolicyERC721
///@dev PolicyERC721 is a (TODO: soulbound) ERC721 contract where each token has roles and permissions
///@dev The roles and permissions determine how the token can interact with the vertex administrator contract

/* one behavior with this contract is that if a role is deleted, it will still appear in the tokenToRoles mapping
 * to solve this, we could run a pre check on all role based access functions that checks if the role exists in the
 * @note roles array, and if not we delete that role from the tokenToRoles mapping, however, this adds gas to every call
 */

contract PolicyERC721 is ERC721, Ownable {
    mapping(uint256 => string[]) public tokenToRoles;
    mapping(string => uint256[]) public rolesToPermissionSignatures;
    string[] public roles;
    uint256 private _totalSupply;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        /* potential idea for deployment:
         * 1: mint initial NFTs with initial roles to users, contributors, etc
         * 2: deploy the administator contract
         * 2.5: (in the constructor of the administrator contract will deploy the initial executor contracts)
         * 3: set administrator contract as owner of PolicyERC721
         *
         * now the administrator contract can control the PolicyERC721 contract via governance
         */
    }

    event RoleAdded(string role, Permission[] permissions, uint256 permissionSignature);
    event RoleRevoked(uint256 tokenId, string role);
    event RoleDeleted(string role);
    event PermissionAdded(string role, Permission permission, uint256 permissionSignature);
    event PermissionDeleted(string role, Permission permission, uint256 permissionSignature);

    ///@dev returns the permission signatures of a token
    ///@param tokenId the id of the token
    function getPermissionSignatures(uint256 tokenId) public view returns (uint256[] memory) {
        string[] memory userRoles = tokenToRoles[tokenId];
        (uint256 userRolesLength, uint256 permissionSignaturesLength) = getTotalPermissions(userRoles);
        uint256[] memory permissionSignatures = new uint256[](permissionSignaturesLength);
        uint256 psIndex;
        for (uint256 i; i < userRolesLength; i++) {
            uint256[] memory rolePermissionSignatures = rolesToPermissionSignatures[userRoles[i]];
            for (uint256 j; j < rolePermissionSignatures.length; j++) {
                permissionSignatures[psIndex] = rolePermissionSignatures[j];
                psIndex++;
            }
        }
        return permissionSignatures;
    }

    ///@dev helper fn which returns the total number of roles and permissions of a token
    function getTotalPermissions(string[] memory userRoles) internal view returns (uint256, uint256) {
        uint256 userRolesLength;
        uint256 permissionSignaturesLength;
        for (uint256 i; i < userRoles.length; i++) {
            userRolesLength++;
            permissionSignaturesLength += rolesToPermissionSignatures[userRoles[i]].length;
        }
        return (userRolesLength, permissionSignaturesLength);
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

    ///@dev checks if a token has a role
    ///@param tokenId the id of the token
    ///@param role the role to check
    function hasRole(uint256 tokenId, string calldata role) public view returns (bool) {
        string[] memory userRoles = tokenToRoles[tokenId];
        for (uint256 i; i < userRoles.length; i++) {
            if (keccak256(abi.encodePacked(userRoles[i])) == keccak256(abi.encodePacked(role))) {
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
        _totalSupply++;
        tokenToRoles[tokenId] = userRoles;
        _mint(to, tokenId);
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
            rolesToPermissionSignatures[role].push(permissionSignature);
            emit RoleAdded(role, permissions, permissionSignature);
        }
    }

    ///@dev assigns a role to a token
    ///@param tokenId the id of the token
    function assignRole(uint256 tokenId, string calldata role) public onlyOwner {
        require(rolesToPermissionSignatures[role].length > 0, "PolicyERC721: role does not exist");
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
        emit RoleRevoked(tokenId, role);
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
        emit RoleDeleted(role);
    }

    ///@dev adds a permission to a role
    ///@param role the role to add the permission to
    ///@param permission the permission to add
    function addPermissionToRole(string calldata role, Permission calldata permission) public onlyOwner {
        uint256 permissionSignature = hashPermission(permission);
        rolesToPermissionSignatures[role][rolesToPermissionSignatures[role].length - 1] = permissionSignature;
        emit PermissionAdded(role, permission, permissionSignature);
    }

    ///@dev deletes a permission from a role
    ///@param role the role to delete the permission from
    ///@param permission the permission to delete
    function deletePermissionFromRole(string calldata role, Permission calldata permission) public onlyOwner {
        uint256 permissionSignature = hashPermission(permission);
        uint256[] storage rolePermissionSignatures = rolesToPermissionSignatures[role];
        for (uint256 i; i < rolePermissionSignatures.length; i++) {
            if (rolePermissionSignatures[i] == permissionSignature) {
                delete rolePermissionSignatures[i];
            }
        }
        emit PermissionDeleted(role, permission, permissionSignature);
    }
}
