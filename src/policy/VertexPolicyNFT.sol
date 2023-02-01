// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@solmate/tokens/ERC721.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {VertexPolicy} from "src/policy/VertexPolicy.sol";
import {Permission, Checkpoint} from "src/utils/Structs.sol";

/// @title VertexPolicyNFT
/// @author Llama (vertex@llama.xyz)
/// @dev VertexPolicyNFT is a (TODO: pick a soulbound standard) ERC721 contract where each token has permissions
/// @notice The permissions determine how the token can interact with the vertex administrator contract
contract VertexPolicyNFT is VertexPolicy {
    mapping(uint256 => bytes8[]) public tokenToPermissionSignatures;
    mapping(uint256 => mapping(bytes8 => bool)) public tokenToHasPermissionSignature;
    mapping(uint256 => Checkpoint[]) private checkpoints;
    uint256[] public policyIds;
    string public baseURI;
    uint256 private _totalSupply;
    address public immutable vertex;

    modifier onlyVertex() {
        if (msg.sender != vertex) revert OnlyVertex();
        _;
    }

    constructor(string memory name, string memory symbol, address _vertex, address[] memory initialPolicyholders, bytes8[][] memory initialPermissions)
        ERC721(name, symbol)
    {
        vertex = _vertex;
        if (initialPolicyholders.length > 0 && initialPermissions.length > 0) {
            uint256 policyholderLength = initialPolicyholders.length;
            uint256 permissionsLength = initialPermissions.length;
            if (policyholderLength != permissionsLength) revert InvalidInput();
            for (uint256 i = 0; i < policyholderLength; ++i) {
                grantPermissions(initialPolicyholders[i], initialPermissions[i]);
            }
        }
    }

    /// @inheritdoc VertexPolicy
    function holderHasPermissionAt(address policyholder, bytes8 permissionSignature, uint256 blockNumber) external view override returns (bool) {
        uint256 policyId = uint256(uint160(policyholder));
        Checkpoint[] storage _checkpoints = checkpoints[policyId];
        uint256 length = _checkpoints.length;
        if (length == 0) return false;
        if (blockNumber >= _checkpoints[length - 1].blockNumber) {
            return permissionIsInPermissionsArray(_checkpoints[length - 1].permissionSignatures, permissionSignature);
        }
        if (blockNumber < _checkpoints[0].blockNumber) return false;
        uint256 min = 0;
        uint256 max = length - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (_checkpoints[mid].blockNumber <= blockNumber) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return permissionIsInPermissionsArray(_checkpoints[min].permissionSignatures, permissionSignature);
    }

    /// @inheritdoc VertexPolicy
    function getSupplyByPermissions(bytes8[] memory _permissions) external view override returns (uint256) {
        uint256 policyLength = policyIds.length;
        uint256 permissionLength = _permissions.length;
        uint256 supply;
        unchecked {
            for (uint256 i; i < policyLength; ++i) {
                for (uint256 j; j < permissionLength; ++j) {
                    if (tokenToHasPermissionSignature[policyIds[i]][_permissions[j]]) {
                        ++supply;
                        break;
                    }
                }
            }
        }
        return supply;
    }

    /// @inheritdoc VertexPolicy
    function batchGrantPermissions(address[] memory to, bytes8[][] memory userPermissions) public override onlyVertex {
        uint256 length = userPermissions.length;
        if (length == 0 || length != to.length) revert InvalidInput();
        for (uint256 i = 0; i < length; ++i) {
            grantPermissions(to[i], userPermissions[i]);
        }
    }

    /// @inheritdoc VertexPolicy
    function batchUpdatePermissions(uint256[] memory _policyIds, bytes8[][] memory permissions) public override onlyVertex {
        uint256 length = _policyIds.length;
        if (length != permissions.length) revert InvalidInput();
        for (uint256 i = 0; i < length; ++i) {
            updatePermissions(_policyIds[i], permissions[i]);
        }
    }

    /// @inheritdoc VertexPolicy
    function batchRevokePermissions(uint256[] calldata _policyIds) public override onlyVertex {
        uint256 length = _policyIds.length;
        if (length == 0) revert InvalidInput();
        for (uint256 i = 0; i < length; ++i) {
            revokePermissions(_policyIds[i]);
        }
    }

    /// @dev hashes a permission
    /// @param permission the permission to hash
    function hashPermission(Permission memory permission) public pure returns (bytes8) {
        return bytes8(keccak256(abi.encodePacked(permission.target, permission.selector, permission.strategy)));
    }

    /// @dev hashes an array of permissions
    /// @param _permissions the permissions array to hash
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

    /// @inheritdoc VertexPolicy
    function hasPermission(uint256 policyId, bytes8 permissionSignature) public view override returns (bool) {
        return tokenToHasPermissionSignature[policyId][permissionSignature];
    }

    /// @notice mints a new policy token with the given permissions
    /// @param to the address to mint the policy token to
    /// @param permissionSignatures the permission signature's to be granted to the policyholder
    function grantPermissions(address to, bytes8[] memory permissionSignatures) private {
        if (balanceOf(to) != 0) revert OnlyOnePolicyPerHolder();
        uint256 length = permissionSignatures.length;
        if (length == 0) revert InvalidInput();
        uint256 policyId = uint256(uint160(to));

        unchecked {
            ++_totalSupply;
            tokenToPermissionSignatures[policyId] = permissionSignatures;
            for (uint256 i = 0; i < length; ++i) {
                if (!tokenToHasPermissionSignature[policyId][permissionSignatures[i]]) {
                    tokenToHasPermissionSignature[policyId][permissionSignatures[i]] = true;
                }
            }
            policyIds.push(policyId);
            checkpoints[policyId].push(Checkpoint(block.number, permissionSignatures));
            _mint(to, policyId);
        }
    }

    /// @notice revokes all permissions from a policy token
    /// @param policyId the id of the policy token to revoke permissions from
    function revokePermissions(uint256 policyId) private {
        if (ownerOf(policyId) == address(0)) revert InvalidInput();
        bytes8[] storage userPermissions = tokenToPermissionSignatures[policyId];
        uint256 userPermissionslength = userPermissions.length;
        unchecked {
            _totalSupply--;
            for (uint256 i; i < userPermissionslength; ++i) {
                tokenToHasPermissionSignature[policyId][userPermissions[i]] = false;
            }
            uint256 policyIdsLength = policyIds.length;
            for (uint256 j = 0; j < policyIdsLength; ++j) {
                if (policyIds[j] == policyId) {
                    policyIds[j] = policyIds[policyIdsLength - 1];
                    policyIds.pop();
                    break;
                }
            }
        }
        delete tokenToPermissionSignatures[policyId];
        checkpoints[policyId].push(Checkpoint({blockNumber: block.number, permissionSignatures: new bytes8[](0)}));
        _burn(policyId);
    }

    /// @notice burns and then mints a token with the same policy ID to the same address with a new set of permissions
    /// @param policyId the policy token id being updated
    /// @param permissions the new permissions array to be set
    function updatePermissions(uint256 policyId, bytes8[] memory permissions) private onlyVertex {
        revokePermissions(policyId);
        grantPermissions(address(uint160(policyId)), permissions);
    }

    /// @notice sets the base URI for the contract
    /// @param _baseURI the base URI string to set
    function setBaseURI(string memory _baseURI) public override onlyVertex {
        baseURI = _baseURI;
    }

    /// @dev overriding transferFrom to disable transfers for SBTs
    /// @dev this is a temporary solution, we will need to conform to a Souldbound standard
    function transferFrom(address from, address to, uint256 policyId) public override {
        revert SoulboundToken();
    }

    /// @inheritdoc VertexPolicy
    function getPermissionSignatures(uint256 userId) public view override returns (bytes8[] memory) {
        return tokenToPermissionSignatures[userId];
    }

    function permissionIsInPermissionsArray(bytes8[] storage policyPermissionSignatures, bytes8 permissionSignature) internal view returns (bool) {
        uint256 length = policyPermissionSignatures.length;
        unchecked {
            for (uint256 i; i < length; ++i) {
                if (policyPermissionSignatures[i] == permissionSignature) return true;
            }
        }
        return false;
    }

    /// @inheritdoc VertexPolicy
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /// @notice returns the location of the policy metadata
    /// @param id the id of the policy token
    function tokenURI(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(baseURI, Strings.toString(id)));
    }
}
