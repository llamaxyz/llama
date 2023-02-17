// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@solmate/tokens/ERC721.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {VertexPolicy} from "src/policy/VertexPolicy.sol";
import {PermissionData, Checkpoint} from "src/utils/Structs.sol";

/// @title VertexPolicyNFT
/// @author Llama (vertex@llama.xyz)
/// @dev VertexPolicyNFT is a (TODO: pick a soulbound standard) ERC721 contract where each token has permissions
/// @notice The permissions determine how the token can interact with the vertex administrator contract
contract VertexPolicyNFT is VertexPolicy {
    mapping(uint256 => bytes8[]) public tokenToPermissionSignatures;
    mapping(uint256 => mapping(bytes8 => uint256)) public tokenToPermissionExpirationTimestamp;
    mapping(uint256 => Checkpoint[]) private checkpoints;
    uint256[] public policyIds;
    string public baseURI;
    uint256 private _totalSupply;
    address public vertex;

    modifier onlyVertex() {
        if (msg.sender != vertex) revert OnlyVertex();
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address[] memory initialPolicyholders,
        bytes8[][] memory initialPermissions,
        uint256[][] memory initialExpirationTimestamps
    ) ERC721(_name, _symbol) {
        if (initialPolicyholders.length > 0 && initialPermissions.length > 0) {
            uint256 policyholderLength = initialPolicyholders.length;
            uint256 permissionsLength = initialPermissions.length;
            uint256 expirationsLength = initialExpirationTimestamps.length;
            if (policyholderLength != permissionsLength && (expirationsLength == 0 || expirationsLength != policyholderLength)) revert InvalidInput();
            for (uint256 i = 0; i < policyholderLength; ++i) {
                uint256[] memory expiration;
                if (expirationsLength > 0) expiration = initialExpirationTimestamps[i];
                grantPermissions(initialPolicyholders[i], initialPermissions[i], expiration);
            }
        }
    }

    function setVertex(address _vertex) external {
        if (vertex != address(0)) revert AlreadyInitialized();
        vertex = _vertex;
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
    function getSupplyByPermissions(bytes8[] calldata _permissions) external view override returns (uint256) {
        uint256 policyLength = policyIds.length;
        uint256 permissionLength = _permissions.length;
        uint256 supply;
        unchecked {
            for (uint256 i; i < policyLength; ++i) {
                for (uint256 j; j < permissionLength; ++j) {
                    if (hasPermission(policyIds[i], _permissions[j])) {
                        ++supply;
                        break;
                    }
                }
            }
        }
        return supply;
    }

    /// @inheritdoc VertexPolicy
    function batchGrantPermissions(address[] calldata to, bytes8[][] memory userPermissions, uint256[][] memory expirationTimestamps)
        public
        override
        onlyVertex
    {
        uint256 length = userPermissions.length;
        uint256 expirationTimeStampLength = expirationTimestamps.length;
        if (length == 0 || length != to.length && (expirationTimeStampLength == 0 || expirationTimeStampLength == length)) {
            revert InvalidInput();
        }
        for (uint256 i = 0; i < length; ++i) {
            uint256[] memory expiration;
            if (expirationTimeStampLength > 0) {
                expiration = expirationTimestamps[i];
            }
            grantPermissions(to[i], userPermissions[i], expiration);
        }
    }

    /// @inheritdoc VertexPolicy
    function batchUpdatePermissions(uint256[] calldata _policyIds, bytes8[][] calldata permissions, uint256[][] calldata expirationTimestamps)
        public
        override
        onlyVertex
    {
        uint256 length = _policyIds.length;
        if (length != permissions.length && (expirationTimestamps.length == 0 || expirationTimestamps.length == length)) revert InvalidInput();
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                uint256[] memory expiration;
                if (expirationTimestamps.length > 0) {
                    expiration = expirationTimestamps[i];
                }
                updatePermissions(_policyIds[i], permissions[i], expiration);
            }
        }
    }

    /// @inheritdoc VertexPolicy
    function batchRevokePermissions(uint256[] calldata _policyIds) public override onlyVertex {
        uint256 length = _policyIds.length;
        if (length == 0) revert InvalidInput();
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                revokePermissions(_policyIds[i]);
            }
        }
    }

    /// @dev hashes a permission
    /// @param _permission the permission to hash
    function hashPermission(PermissionData calldata _permission) public pure returns (bytes8) {
        return bytes8(keccak256(abi.encodePacked(_permission.target, _permission.selector, _permission.strategy)));
    }

    /// @dev hashes an array of permissions
    /// @param _permissions the permissions array to hash
    function hashPermissions(PermissionData[] calldata _permissions) public pure returns (bytes8[] memory) {
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
        bytes8[] storage permissionSignatures = tokenToPermissionSignatures[policyId];
        uint256 length = permissionSignatures.length;
        if (length == 0) return false;
        uint256 min;
        uint256 max = length - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (permissionSignatures[mid] <= permissionSignature) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        bool expired = _checkExpiration(policyId, permissionSignatures[min]);
        return permissionSignatures[min] == permissionSignature && !expired;
    }

    /// @notice updates a policyID with a new set of permissions
    /// @notice will delete and add permissions as needed
    /// @param policyId the policy token id being updated
    /// @param newPermissionSignatures the new permissions array to be set
    function updatePermissions(uint256 policyId, bytes8[] calldata newPermissionSignatures, uint256[] memory expirationTimestamps) private onlyVertex {
        if (ownerOf(policyId) == address(0)) revert InvalidInput();
        bytes8[] storage permissionSignatures = tokenToPermissionSignatures[policyId];
        uint256 permissionSignaturesLength = permissionSignatures.length;
        uint256 newPermissionSignaturesLength = newPermissionSignatures.length;
        uint256 expirationTimestampsLength = expirationTimestamps.length;
        if (expirationTimestampsLength != 0 && newPermissionSignaturesLength != expirationTimestampsLength) revert InvalidInput();
        bytes8[] memory permissionsToRemove = new bytes8[](permissionSignaturesLength);
        uint256 permissionsToRemoveIndex;
        unchecked {
            for (uint256 i; i < permissionSignaturesLength; ++i) {
                if (!permissionIsInPermissionsArrayCalldata(newPermissionSignatures, permissionSignatures[i])) {
                    permissionsToRemove[permissionsToRemoveIndex] = permissionSignatures[i];
                    ++permissionsToRemoveIndex;
                }
            }
            for (uint256 j; j < permissionsToRemoveIndex; ++j) {
                sortedPermissionRemove(permissionSignatures, permissionsToRemove[j]);
            }
            for (uint256 k; k < newPermissionSignaturesLength; ++k) {
                bool permissionIsInArray = permissionIsInPermissionsArray(permissionSignatures, newPermissionSignatures[k]);
                uint256 expiration = expirationTimestamps.length > 0 ? expirationTimestamps[k] : 0;
                if (!permissionIsInArray) {
                    sortedPermissionInsert(permissionSignatures, newPermissionSignatures[k]);
                }
                if (expiration > 0 && expiration != tokenToPermissionExpirationTimestamp[policyId][permissionSignatures[k]]) {
                    if (expiration < block.timestamp) revert Expired();
                    tokenToPermissionExpirationTimestamp[policyId][permissionSignatures[k]] = expiration;
                }
            }
        }
        checkpoints[policyId].push(Checkpoint({blockNumber: block.number, permissionSignatures: permissionSignatures}));
    }

    /// @notice mints a new policy token with the given permissions
    /// @param to the address to mint the policy token to
    /// @param permissionSignatures the permission signature's to be granted to the policyholder
    /// @param expirationTimestamp the expiration timestamp for each permission signature in the permissionSignatures array
    function grantPermissions(address to, bytes8[] memory permissionSignatures, uint256[] memory expirationTimestamp) private {
        if (balanceOf(to) != 0) revert OnlyOnePolicyPerHolder();
        uint256 length = permissionSignatures.length;
        if (length == 0 || (expirationTimestamp.length != 0 && expirationTimestamp.length != length)) revert InvalidInput();
        uint256 policyId = uint256(uint160(to));
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                checkExpiration(policyId, permissionSignatures[i]);
                if (!hasPermission(policyId, permissionSignatures[i])) {
                    uint256 expiration = expirationTimestamp.length > 0 ? expirationTimestamp[i] : 0;
                    if (expiration > 0) {
                        if (expiration < block.timestamp) revert Expired();
                        tokenToPermissionExpirationTimestamp[policyId][permissionSignatures[i]] = expiration;
                    }
                    sortedPermissionInsert(tokenToPermissionSignatures[policyId], permissionSignatures[i]);
                }
            }
            ++_totalSupply;
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
                sortedPermissionRemove(userPermissions, userPermissions[i]);
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
        checkpoints[policyId].push(Checkpoint({blockNumber: block.number, permissionSignatures: new bytes8[](0)}));
        _burn(policyId);
    }

    function sortedPermissionInsert(bytes8[] storage signatures, bytes8 value) internal {
        uint256 length = signatures.length;
        if (length == 0 || value > signatures[length - 1]) {
            signatures.push(value);
            return;
        }
        uint256 i;
        unchecked {
            while (i < length && signatures[i] < value) {
                ++i;
            }
            if (i == length) {
                signatures.push(value);
            } else {
                signatures.push(signatures[length - 1]);
                for (uint256 j = length - 1; j > i; --j) {
                    signatures[j] = signatures[j - 1];
                }
                signatures[i] = value;
            }
        }
    }

    function sortedPermissionRemove(bytes8[] storage signatures, bytes8 value) internal {
        uint256 length = signatures.length;
        if (length == 0) return;
        uint256 i;
        unchecked {
            while (i < length && signatures[i] < value) {
                ++i;
            }
            if (i == length) return;
            for (uint256 j = i; j < length - 1; ++j) {
                signatures[j] = signatures[j + 1];
            }
            signatures.pop();
        }
    }

    function permissionIsInPermissionsArray(bytes8[] storage policyPermissionSignatures, bytes8 permissionSignature) internal view returns (bool) {
        uint256 length = policyPermissionSignatures.length;
        if (length == 0) return false;
        uint256 min;
        uint256 max = length - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (policyPermissionSignatures[mid] <= permissionSignature) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return policyPermissionSignatures[min] == permissionSignature;
    }

    function permissionIsInPermissionsArrayCalldata(bytes8[] calldata policyPermissionSignatures, bytes8 permissionSignature) internal pure returns (bool) {
        uint256 length = policyPermissionSignatures.length;
        if (length == 0) return false;
        uint256 min;
        uint256 max = length - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (policyPermissionSignatures[mid] <= permissionSignature) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return policyPermissionSignatures[min] == permissionSignature;
    }

    /// @inheritdoc VertexPolicy
    function checkExpiration(uint256 policyId, bytes8 permissionSignature) public override returns (bool expired) {
        expired = _checkExpiration(policyId, permissionSignature);
        if (expired) {
            sortedPermissionRemove(tokenToPermissionSignatures[policyId], permissionSignature);
        }
        return expired;
    }

    ///@notice checks if a permission has expired
    ///@param policyId the id of the policy token to check
    ///@param permissionSignature the signature of the permission to check
    function _checkExpiration(uint256 policyId, bytes8 permissionSignature) internal view returns (bool expired) {
        uint256 expiration = tokenToPermissionExpirationTimestamp[policyId][permissionSignature];
        if (expiration == 0 || expiration > block.timestamp) return false;
        if (block.timestamp > expiration) {
            return true;
        }
    }

    /// @notice sets the base URI for the contract
    /// @param _baseURI the base URI string to set
    function setBaseURI(string calldata _baseURI) public override onlyVertex {
        baseURI = _baseURI;
    }

    /// @dev overriding transferFrom to disable transfers for SBTs
    /// @dev this is a temporary solution, we will need to conform to a Souldbound standard
    function transferFrom(address, /* from */ address, /* to */ uint256 /* policyId */ ) public override {
        revert SoulboundToken();
    }

    /// @inheritdoc VertexPolicy
    function getPermissionSignatures(uint256 userId) public view override returns (bytes8[] memory) {
        return tokenToPermissionSignatures[userId];
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
