// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IVertexPolicyNFT, Permission} from "src/policy/IVertexPolicyNFT.sol";

///@title VertexPolicyNFT
///@dev VertexPolicyNFT is a (TODO: soulbound) ERC721 contract where each token has roles and permissions
///@dev The roles and permissions determine how the token can interact with the vertex administrator contract

/* one behavior with this contract is that if a role is deleted, it will still appear in the tokenToRoles & the tokenToHasRole mapping.
 * to solve this, we could run a pre check on all role based access functions that checks if the role exists in the...
 * roles array, and if not we delete that role from the tokenToRoles mapping, however, this adds extra gas to every call.
 */

contract VertexPolicyNFT is ERC721 {
    mapping(uint256 => bytes32[]) public tokenToRoles;
    mapping(bytes32 => bytes8[]) public roleToPermissionSignatures;
    mapping(bytes32 => mapping(bytes8 => bool)) public roleToHasPermissionSignature;
    mapping(uint256 => mapping(bytes32 => bool)) public tokenToHasRole;
    bytes32[] public roles;
    uint256 private _totalSupply;
    address public immutable vertexCore;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        vertexCore = msg.sender;
    }

    event RolesAdded(bytes32[] roles, string[] roleStrings, Permission[][] permissions, bytes8[][] permissionSignatures);
    event RolesAssigned(uint256 tokenId, bytes32[] roles);
    event RolesRevoked(uint256 tokenId, bytes32[] roles);
    event RolesDeleted(bytes32[] role);
    event PermissionsAdded(bytes32 role, Permission[] permissions, bytes8[] permissionSignatures);
    event PermissionsDeleted(bytes32 role, bytes8[] permissionSignatures);

    error RoleNonExistant(bytes32 role);
    error SoulboundToken();
    error InvalidInput();
    error OnlyVertex();

    modifier onlyVertex() {
        if (msg.sender != address(vertexCore)) revert OnlyVertex();
        _;
    }

    ///@dev checks if a token has a role
    ///@param tokenId the id of the token
    ///@param role the role to check
    function hasRole(uint256 tokenId, bytes32 role) public view returns (bool) {
        return tokenToHasRole[tokenId][role];
    }

    ///@dev mints a new token
    ///@param to the address to mint the token to
    ///@param userRoles the roles of the token
    function mint(address to, bytes32[] calldata userRoles) public onlyVertex {
        if (balanceOf(to) != 0) {
            revert SoulboundToken();
        }
        uint256 tokenId = totalSupply();
        unchecked {
            _totalSupply++;
        }
        tokenToRoles[tokenId] = userRoles;
        uint256 length = userRoles.length;
        for (uint256 i = 0; i < length; i++) {
            tokenToHasRole[tokenId][userRoles[i]] = true;
        }
        _mint(to, tokenId);
    }

    ///@dev burns a token
    ///@param tokenId the id of the token to burn
    function burn(uint256 tokenId) public onlyVertex {
        bytes32[] storage userRoles = tokenToRoles[tokenId];
        uint256 length = userRoles.length;
        for (uint256 i = 0; i < length; i++) {
            delete tokenToHasRole[tokenId][userRoles[i]];
        }
        delete tokenToRoles[tokenId];
        _burn(tokenId);
    }

    ///@dev private function which adds a role to the contract
    ///@param role the role to add
    ///@param permissions the permissions of the role
    function addRole(bytes32 role, Permission[] calldata permissions) private returns (bytes8[] memory) {
        roles.push(role);
        uint256 permissionsLength = permissions.length;
        bytes8[] memory permissionSignatures = new bytes8[](permissionsLength);
        unchecked {
            for (uint256 i; i < permissionsLength; ++i) {
                bytes8 permissionSignature = hashPermission(permissions[i]);
                roleToHasPermissionSignature[role][permissionSignature] = true;
                roleToPermissionSignatures[role].push(permissionSignature);
                permissionSignatures[i] = permissionSignature;
            }
        }
        return permissionSignatures;
    }

    ///@dev allows admin to add a roles to the contract
    ///@dev indexes in rolesArray and permissionsArray must match
    ///@param rolesArray the roles to add
    ///@param permissionsArray and array of permissions arrays for each role
    function addRoles(string[] calldata rolesArray, Permission[][] calldata permissionsArray) public onlyVertex {
        uint256 rolesArrayLength = rolesArray.length;
        uint256 permissionsArrayLength = permissionsArray.length;
        if (rolesArrayLength != permissionsArrayLength || rolesArrayLength == 0) {
            revert InvalidInput();
        }
        bytes32[] memory roleHashes = hashRoles(rolesArray);
        bytes8[][] memory permissionsHashes = new bytes8[][](permissionsArrayLength);
        for (uint256 i; i < rolesArrayLength; ++i) {
            if (permissionsArray[i].length == 0) {
                revert InvalidInput();
            }
            bytes8[] memory permissionsHash = addRole(roleHashes[i], permissionsArray[i]);
            permissionsHashes[i] = permissionsHash;
        }
        emit RolesAdded(roleHashes, rolesArray, permissionsArray, permissionsHashes);
    }

    ///@dev assigns a role to a token
    ///@param tokenId the id of the token
    function assignRoles(uint256 tokenId, bytes32[] calldata rolesArray) public onlyVertex {
        if (rolesArray.length == 0) {
            revert InvalidInput();
        }
        uint256 rolesArrayLength = rolesArray.length;
        unchecked {
            for (uint256 i; i < rolesArrayLength; ++i) {
                bytes32 role = rolesArray[i];
                if (roleToPermissionSignatures[role].length == 0) {
                    revert RoleNonExistant(role);
                }
                if (!tokenToHasRole[tokenId][role]) {
                    tokenToHasRole[tokenId][role] = true;
                    tokenToRoles[tokenId].push(role);
                }
            }
        }
        emit RolesAssigned(tokenId, rolesArray);
    }

    ///@dev revokes a role from a token
    ///@param tokenId the id of the token
    ///@param revokeRolesArray the array of roles to revoke
    function revokeRoles(uint256 tokenId, bytes32[] calldata revokeRolesArray) public onlyVertex {
        if (revokeRolesArray.length == 0) {
            revert InvalidInput();
        }
        bytes32[] storage userRoles = tokenToRoles[tokenId];
        uint256 userRolesLength = userRoles.length;
        uint256 revokeRolesLength = revokeRolesArray.length;
        unchecked {
            for (uint256 i; i < userRolesLength; ++i) {
                for (uint256 j; j < revokeRolesLength; ++j) {
                    if (tokenToHasRole[tokenId][revokeRolesArray[j]]) {
                        delete userRoles[i];
                        delete tokenToHasRole[tokenId][revokeRolesArray[j]];
                    }
                }
            }
        }
        emit RolesRevoked(tokenId, revokeRolesArray);
    }

    ///@dev deletes multiple roles from the contract
    ///@param deleteRolesArray the role to delete
    function deleteRoles(bytes32[] calldata deleteRolesArray) public onlyVertex {
        if (deleteRolesArray.length == 0) {
            revert InvalidInput();
        }
        unchecked {
            uint256 deleteRolesLength = deleteRolesArray.length;
            for (uint256 i; i < deleteRolesLength; ++i) {
                bytes32 role = deleteRolesArray[i];
                bytes8[] storage rolePermissionSignatures = roleToPermissionSignatures[role];
                uint256 roleToPermissionSignaturesLength = rolePermissionSignatures.length;
                for (uint256 j; j < roleToPermissionSignaturesLength; ++j) {
                    delete roleToHasPermissionSignature[role][rolePermissionSignatures[j]];
                }
                delete roleToPermissionSignatures[role];
                uint256 rolesLength = roles.length;
                for (uint256 k; k < rolesLength; ++k) {
                    if (roles[k] == role) {
                        delete roles[k];
                    }
                }
            }
        }
        emit RolesDeleted(deleteRolesArray);
    }

    ///@dev overriding transferFrom to disable transfers for SBTs
    ///@dev this is a temporary solution, we will need to conform to a Souldbound standard
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        revert SoulboundToken();
    }

    // BEGIN TODO

    // Check if a holder has a permissionSignature at a specific block number
    function holderHasPermissionAt(
        address policyHolder,
        bytes32 permissionSignature,
        uint256 blockNumber
    ) external view returns (bool) {
        // TODO
        return true;
    }

    // Total number of policy NFTs at specific block number
    // TODO: This should queried at action creation time and stored on the Action object
    function totalSupplyAt(uint256 blockNumber) external view returns (uint256) {
        // TODO
        return totalSupply();
    }

    // Total number of policy NFTs at that have at least 1 of these permissions at specific block number
    // TODO: This should queried at action creation time and stored on the Action object
    function getSupplyByPermissionsAt(bytes32[] memory permissions, uint256 blockNumber) external view returns (uint256) {
        // TODO
        return totalSupply();
    }

    ///@dev hashes a permission
    ///@param permission the permission to hash
    function hashPermission(Permission calldata permission) internal pure returns (bytes8) {
        return bytes8(keccak256(abi.encodePacked(permission.target, permission.signature, permission.strategy)));
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

    ///@dev hashes multiple roles
    ///@param rolesArray the roles to hash
    function hashRoles(string[] calldata rolesArray) internal pure returns (bytes32[] memory) {
        bytes32[] memory output = new bytes32[](rolesArray.length);
        unchecked {
            for (uint256 i; i < rolesArray.length; ++i) {
                output[i] = keccak256(abi.encodePacked(rolesArray[i]));
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
                bytes8[] memory rolePermissionSignatures = roleToPermissionSignatures[userRoles[i]];
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
            permissionSignaturesLength += roleToPermissionSignatures[userRoles[i]].length;
        }
        return (userRolesLength, permissionSignaturesLength);
    }

    ///@dev checks if a token has a permission
    ///@param tokenId the id of the token
    ///@param permissionSignature the signature of the permission
    function hasPermission(uint256 tokenId, bytes8 permissionSignature) public view returns (bool) {
        bytes32[] storage tokenRoles = tokenToRoles[tokenId];
        unchecked {
            uint256 tokenRolesLength = tokenRoles.length;
            for (uint256 i; i < tokenRolesLength; ++i) {
                if (roleToHasPermissionSignature[tokenRoles[i]][permissionSignature]) {
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
