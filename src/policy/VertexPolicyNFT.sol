// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

///@dev Struct to define a permission
struct Permission {
    address target;
    bytes4 signature;
    address executor;
}

///@title VertexPolicyNFT
///@dev VertexPolicyNFT is a (TODO: soulbound) ERC721 contract where each token has roles and permissions
///@dev The roles and permissions determine how the token can interact with the vertex administrator contract

/* one behavior with this contract is that if a role is deleted, it will still appear in the tokenToRoles mapping.
 * to solve this, we could run a pre check on all role based access functions that checks if the role exists in the...
 * roles array, and if not we delete that role from the tokenToRoles mapping, however, this adds extra gas to every call.
 */

contract VertexPolicyNFT is ERC721, Ownable {
    mapping(uint256 => bytes32[]) public tokenToRoles;
    mapping(bytes32 => bytes8[]) public rolesToPermissionSignatures;
    bytes32[] public roles;
    uint256 private _totalSupply;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    event RoleAdded(bytes32 role, string roleString, Permission[] permissions, bytes8[] permissionSignatures);
    event RoleRevoked(uint256 tokenId, bytes32 role);
    event RoleDeleted(bytes32 role);
    event PermissionAdded(bytes32 role, Permission permission, bytes8 permissionSignature);
    event PermissionDeleted(bytes32 role, Permission permission, bytes8 permissionSignature);

    error RoleNonExistant(bytes32 role);

    ///@dev checks if a token has a role
    ///@param tokenId the id of the token
    ///@param role the role to check
    function hasRole(uint256 tokenId, bytes32 role) public view returns (bool) {
        bytes32[] memory userRoles = tokenToRoles[tokenId];
        uint256 userRolesLength = userRoles.length;
        unchecked {
            for (uint256 i; i < userRolesLength; ++i) {
                if (userRoles[i] == role) {
                    return true;
                }
            }
        }
        return false;
    }

    ///@dev mints a new token
    ///@param to the address to mint the token to
    ///@param userRoles the roles of the token
    function mint(address to, bytes32[] calldata userRoles) public onlyOwner {
        uint256 tokenId = totalSupply();
        unchecked {
            _totalSupply++;
        }
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
        bytes32 roleHash = hashRole(role);
        roles.push(roleHash);
        uint256 permissionsLength = permissions.length;
        bytes8[] memory permissionSignatures = new bytes8[](permissionsLength);
        unchecked {
            for (uint256 i; i < permissionsLength; ++i) {
                bytes8 permissionSignature = hashPermission(permissions[i]);
                rolesToPermissionSignatures[roleHash].push(permissionSignature);
                permissionSignatures[i] = permissionSignature;
            }
        }
        emit RoleAdded(roleHash, role, permissions, permissionSignatures);
    }

    ///@dev assigns a role to a token
    ///@param tokenId the id of the token
    function assignRole(uint256 tokenId, bytes32 role) public onlyOwner {
        if (rolesToPermissionSignatures[role].length == 0) {
            revert RoleNonExistant(role);
        }
        tokenToRoles[tokenId].push(role);
    }

    ///@dev revokes a role from a token
    ///@param tokenId the id of the token
    ///@param role the role to revoke
    function revokeRole(uint256 tokenId, bytes32 role) public onlyOwner {
        bytes32[] storage userRoles = tokenToRoles[tokenId];
        uint256 userRolesLength = userRoles.length;
        unchecked {
            for (uint256 i; i < userRolesLength; ++i) {
                if (roles[i] == role) {
                    delete userRoles[i];
                }
            }
        }
        emit RoleRevoked(tokenId, role);
    }

    ///@dev deletes a role from the contract
    ///@param role the role to delete
    function deleteRole(bytes32 role) public onlyOwner {
        delete rolesToPermissionSignatures[role];
        uint256 rolesLength = roles.length;
        unchecked {
            for (uint256 i; i < rolesLength; ++i) {
                if (roles[i] == role) {
                    delete roles[i];
                }
            }
        }
        emit RoleDeleted(role);
    }

    ///@dev adds a permission to a role
    ///@param role the role to add the permission to
    ///@param permission the permission to add
    function addPermissionToRole(bytes32 role, Permission calldata permission) public onlyOwner {
        bytes8 permissionSignature = hashPermission(permission);
        rolesToPermissionSignatures[role][rolesToPermissionSignatures[role].length - 1] = permissionSignature;
        emit PermissionAdded(role, permission, permissionSignature);
    }

    ///@dev deletes a permission from a role
    ///@param role the role to delete the permission from
    ///@param permission the permission to delete
    function deletePermissionFromRole(bytes32 role, Permission calldata permission) public onlyOwner {
        bytes8 permissionSignature = hashPermission(permission);
        bytes8[] storage rolePermissionSignatures = rolesToPermissionSignatures[role];
        uint256 rolePermissionSignaturesLength = rolePermissionSignatures.length;
        for (uint256 i; i < rolePermissionSignaturesLength; ++i) {
            if (rolePermissionSignatures[i] == permissionSignature) {
                delete rolePermissionSignatures[i];
            }
        }
        emit PermissionDeleted(role, permission, permissionSignature);
    }

    ///@dev overriding transferFrom to disable transfers for SBTs
    ///@dev this is a temporary solution, we will need to conform to a Souldbound standard
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        revert("VertexPolicyNFT: transferFrom is disabled");
    }

    ///@dev hashes a permission
    ///@param permission the permission to hash
    function hashPermission(Permission calldata permission) internal pure returns (bytes8) {
        return bytes8(keccak256(abi.encodePacked(permission.target, permission.signature, permission.executor)));
    }

    ///@dev hashes a role
    ///@param role the role to hash
    function hashRole(string calldata role) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(role));
    }

    ///@dev hashes multiple roles
    ///@param rolesArray the roles to hash
    function hashRoles(string[] calldata rolesArray) internal pure returns (bytes32[] memory) {
        bytes32[] memory output = new bytes32[](rolesArray.length);
        unchecked {
            for (uint256 i; i < rolesArray.length; ++i) {
                output[i] = hashRole(rolesArray[i]);
            }
        }
        return output;
    }

    ///@dev returns the total token supply of the contract
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    ///@dev returns the permission signatures of a token
    ///@param tokenId the id of the token
    function getPermissionSignatures(uint256 tokenId) public view returns (bytes8[] memory) {
        bytes32[] memory userRoles = tokenToRoles[tokenId];
        (uint256 userRolesLength, uint256 permissionSignaturesLength) = getTotalPermissions(userRoles);
        bytes8[] memory permissionSignatures = new bytes8[](permissionSignaturesLength);
        uint256 psIndex;
        unchecked {
            for (uint256 i; i < userRolesLength; ++i) {
                bytes8[] memory rolePermissionSignatures = rolesToPermissionSignatures[userRoles[i]];
                uint256 rolePermissionSignaturesLength = rolePermissionSignatures.length;
                for (uint256 j; j < rolePermissionSignaturesLength; j++) {
                    permissionSignatures[psIndex] = rolePermissionSignatures[j];
                    psIndex++;
                }
            }
        }
        return permissionSignatures;
    }

    ///@dev helper fn which returns the total number of roles and permissions of a token
    function getTotalPermissions(bytes32[] memory userRoles) internal view returns (uint256, uint256) {
        uint256 permissionSignaturesLength;
        uint256 userRolesLength = userRoles.length;
        for (uint256 i; i < userRolesLength; ++i) {
            permissionSignaturesLength += rolesToPermissionSignatures[userRoles[i]].length;
        }
        return (userRolesLength, permissionSignaturesLength);
    }

    ///@dev checks if a token has a permission
    ///@param tokenId the id of the token
    ///@param permissionSignature the signature of the permission
    function hasPermission(uint256 tokenId, bytes8 permissionSignature) public view returns (bool) {
        bytes8[] memory permissionSignatures = getPermissionSignatures(tokenId);
        unchecked {
            uint256 permissionSignatureLength = permissionSignatures.length;
            for (uint256 i; i < permissionSignatureLength; ++i) {
                if (permissionSignatures[i] == permissionSignature) {
                    return true;
                }
            }
            return false;
        }
    }

    function getRoles() public view returns (bytes32[] memory) {
        return roles;
    }
}
