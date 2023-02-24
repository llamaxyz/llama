// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "@solmate/tokens/ERC721.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {VertexPolicy} from "src/policy/VertexPolicy.sol";
import {PermissionData, PermissionIdCheckpoint, PermissionChangeData, BatchUpdateData} from "src/utils/Structs.sol";

/// @title VertexPolicyNFT
/// @author Llama (vertex@llama.xyz)
/// @dev VertexPolicyNFT is a (TODO: pick a soulbound standard) ERC721 contract where each token has permissions
/// @notice The permissions determine how the token can interact with the vertex administrator contract
contract VertexPolicyNFT is VertexPolicy {
    mapping(uint256 => mapping(bytes8 => PermissionIdCheckpoint[])) private tokenPermissionCheckpoints;
    mapping(bytes8 => PermissionIdCheckpoint[]) private permissionSupplyCheckpoints;
    mapping(uint256 => mapping(bytes8 => uint256)) public tokenToPermissionExpirationTimestamp;
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
                grantPolicies(initialPolicyholders[i], initialPermissions[i], expiration);
            }
        }
    }

    function setVertex(address _vertex) external {
        if (vertex != address(0)) revert AlreadyInitialized();
        vertex = _vertex;
    }

    /// @inheritdoc VertexPolicy
    function holderHasPermissionAt(address policyholder, bytes8 permissionSignature, uint256 timestamp) external view override returns (bool) {
        uint256 policyId = uint256(uint160(policyholder));
        PermissionIdCheckpoint[] storage _checkpoints = tokenPermissionCheckpoints[policyId][permissionSignature];
        uint256 length = _checkpoints.length;
        if (length == 0) return false;
        if (timestamp >= _checkpoints[length - 1].timestamp) {
            return hasPermission(policyId, permissionSignature);
        }
        if (timestamp < _checkpoints[0].timestamp) return false;
        uint256 min = 0;
        uint256 max = length - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (_checkpoints[mid].timestamp <= timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        bool hasQuantity = _checkpoints[min].quantity > 0;
        bool expired = tokenToPermissionExpirationTimestamp[policyId][permissionSignature] == 0
            ? false
            : tokenToPermissionExpirationTimestamp[policyId][permissionSignature] < timestamp;
        return hasQuantity && !expired;
    }

    /// @inheritdoc VertexPolicy
    function getSupplyByPermissions(bytes8[] calldata _permissions) external view override returns (uint256) {
        uint256 permissionLength = _permissions.length;
        uint256 supply;
        unchecked {
            for (uint256 i; i < permissionLength; ++i) {
                PermissionIdCheckpoint[] storage _checkpoints = permissionSupplyCheckpoints[_permissions[i]];
                uint256 length = _checkpoints.length;
                if (length != 0) {
                    supply += _checkpoints[length - 1].quantity;
                }
            }
        }
        return supply;
    }

    /// @inheritdoc VertexPolicy
    function batchGrantPolicies(address[] calldata to, bytes8[][] memory userPermissions, uint256[][] memory expirationTimestamps) public override onlyVertex {
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
            grantPolicies(to[i], userPermissions[i], expiration);
        }
        emit PoliciesAdded(to, userPermissions, expirationTimestamps);
    }

    /// @inheritdoc VertexPolicy
    function batchUpdatePermissions(BatchUpdateData[] calldata updateData) public override onlyVertex {
        uint256 length = updateData.length;
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                updatePermissions(updateData[i]);
                emit PermissionUpdated(updateData[i]);
            }
        }
    }

    /// @inheritdoc VertexPolicy
    function batchRevokePolicies(uint256[] calldata _policyIds, bytes8[][] calldata permissionsToRevoke) public override onlyVertex {
        uint256 length = _policyIds.length;
        if (length == 0 || length != permissionsToRevoke.length) revert InvalidInput();
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                revokePolicies(_policyIds[i], permissionsToRevoke[i]);
            }
        }
        emit PoliciesRevoked(_policyIds, permissionsToRevoke);
    }

    /// @dev hashes a permission
    /// @param _permission the permission to hash
    function hashPermission(PermissionData calldata _permission) public pure returns (bytes8) {
        return bytes8(keccak256(abi.encode(_permission)));
    }

    /// @dev hashes an array of permissions
    /// @param _permissions the permissions array to hash
    function hashPermissions(PermissionData[] calldata _permissions) external pure returns (bytes8[] memory) {
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
        PermissionIdCheckpoint[] storage _permissionIdCheckpoint = tokenPermissionCheckpoints[policyId][permissionSignature];
        uint256 length = _permissionIdCheckpoint.length;
        bool expired = isPermissionExpired(policyId, permissionSignature);
        bool hasQuantity = length > 0 ? _permissionIdCheckpoint[length - 1].quantity > 0 : false;
        return hasQuantity && !expired;
    }

    /// @notice updates a policyID with a new set of permissions
    /// @notice will delete and add permissions as needed
    /// @param updateData the policy token Id being updated
    function updatePermissions(BatchUpdateData calldata updateData) private {
        if (ownerOf(updateData.policyId) == address(0)) revert InvalidInput();
        uint256 permissionsToAddLength = updateData.permissionsToAdd.length;
        uint256 permissionsToRemoveLength = updateData.permissionsToRemove.length;
        unchecked {
            for (uint256 i; i < permissionsToRemoveLength; ++i) {
                PermissionChangeData calldata data = updateData.permissionsToRemove[i];
                tokenPermissionCheckpoints[updateData.policyId][data.permissionId].push(PermissionIdCheckpoint(uint224(block.timestamp), 0));
                PermissionIdCheckpoint[] storage supplyCheckpoint = permissionSupplyCheckpoints[data.permissionId];
                uint256 supplyIndex = supplyCheckpoint.length > 0 ? supplyCheckpoint.length - 1 : 0;
                supplyCheckpoint.push(PermissionIdCheckpoint(uint224(block.timestamp), supplyCheckpoint[supplyIndex].quantity - 1));
            }
            for (uint256 j; j < permissionsToAddLength; ++j) {
                PermissionChangeData calldata data = updateData.permissionsToAdd[j];
                bool _hasPermission = hasPermission(updateData.policyId, data.permissionId);
                if (!_hasPermission) {
                    tokenPermissionCheckpoints[updateData.policyId][data.permissionId].push(PermissionIdCheckpoint(uint224(block.timestamp), 1));
                    PermissionIdCheckpoint[] storage checkpoints = permissionSupplyCheckpoints[data.permissionId];
                    uint32 quantity = checkpoints.length > 0 ? checkpoints[checkpoints.length - 1].quantity : 0;
                    checkpoints.push(PermissionIdCheckpoint(uint224(block.timestamp), quantity + 1));
                }
                if (data.expirationTimestamp > 0 && data.expirationTimestamp != tokenToPermissionExpirationTimestamp[updateData.policyId][data.permissionId]) {
                    if (data.expirationTimestamp < block.timestamp) revert Expired();
                    tokenToPermissionExpirationTimestamp[updateData.policyId][data.permissionId] = data.expirationTimestamp;
                }
            }
        }
    }

    /// @notice mints a new policy token with the given permissions
    /// @param to the address to mint the policy token to
    /// @param permissionSignatures the permission signature's to be granted to the policyholder
    /// @param expirationTimestamp the expiration timestamp for each permission signature in the permissionSignatures array
    function grantPolicies(address to, bytes8[] memory permissionSignatures, uint256[] memory expirationTimestamp) private {
        if (balanceOf(to) != 0) revert OnlyOnePolicyPerHolder();
        uint256 length = permissionSignatures.length;
        if (length == 0 || (expirationTimestamp.length != 0 && expirationTimestamp.length != length)) revert InvalidInput();
        uint256 policyId = uint256(uint160(to));
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                if (!hasPermission(policyId, permissionSignatures[i])) {
                    uint256 expiration = calculateExpiration(expirationTimestamp, i);
                    if (expiration > 0) {
                        if (expiration < block.timestamp) revert Expired();
                        tokenToPermissionExpirationTimestamp[policyId][permissionSignatures[i]] = expiration;
                    }
                    tokenPermissionCheckpoints[policyId][permissionSignatures[i]].push(PermissionIdCheckpoint(uint224(block.timestamp), 1));
                    PermissionIdCheckpoint[] storage checkpoints = permissionSupplyCheckpoints[permissionSignatures[i]];
                    uint256 checkpointsLength = checkpoints.length;
                    uint32 quantity = checkpointsLength > 0 ? checkpoints[checkpointsLength - 1].quantity : 0;
                    checkpoints.push(PermissionIdCheckpoint(uint224(block.timestamp), quantity + 1));
                }
            }
            ++_totalSupply;
            policyIds.push(policyId);
            _mint(to, policyId);
        }
    }

    /// @notice revokes given permissions from a policy token
    /// @param policyId the id of the policy token to revoke permissions from
    /// @param _permissions the permissions to revoke from the policy token
    function revokePolicies(uint256 policyId, bytes8[] calldata _permissions) private {
        if (ownerOf(policyId) == address(0)) revert InvalidInput();
        unchecked {
            uint256 permissionsLength = _permissions.length;
            for (uint256 i = 0; i < permissionsLength; ++i) {
                tokenPermissionCheckpoints[policyId][_permissions[i]].push(PermissionIdCheckpoint(uint224(block.timestamp), 0));
                PermissionIdCheckpoint[] storage supplyCheckpoint = permissionSupplyCheckpoints[_permissions[i]];
                supplyCheckpoint.push(PermissionIdCheckpoint(uint224(block.timestamp), supplyCheckpoint[supplyCheckpoint.length - 1].quantity - 1));
            }
            _totalSupply--;
            _burn(policyId);
        }
    }

    function calculateExpiration(uint256[] memory expirationTimestamp, uint256 i) private pure returns (uint256) {
        return expirationTimestamp.length > 0 ? expirationTimestamp[i] : 0;
    }

    function isPermissionExpired(uint256 _policyId, bytes8 _permissionSignature) internal view returns (bool) {
        uint256 _expiration = tokenToPermissionExpirationTimestamp[_policyId][_permissionSignature];
        return _expiration < block.timestamp && _expiration != 0;
    }

    /// @inheritdoc VertexPolicy
    function revokeExpiredPermission(uint256 policyId, bytes8 permissionSignature) external override returns (bool expired) {
        expired = isPermissionExpired(policyId, permissionSignature);
        if (expired) {
            tokenPermissionCheckpoints[policyId][permissionSignature].push(PermissionIdCheckpoint(uint224(block.timestamp), 0));
            PermissionIdCheckpoint[] storage supplyCheckpoint = permissionSupplyCheckpoints[permissionSignature];
            supplyCheckpoint.push(PermissionIdCheckpoint(uint224(block.timestamp), supplyCheckpoint[supplyCheckpoint.length - 1].quantity - 1));
        }
    }

    /// @notice sets the base URI for the contract
    /// @param _baseURI the base URI string to set
    function setBaseURI(string calldata _baseURI) public override onlyVertex {
        baseURI = _baseURI;
    }

    /// @dev overriding transferFrom to disable transfers for SBTs
    /// @dev this is a temporary solution, we will need to conform to a Souldbound standard
    function transferFrom(address, /* from */ address, /* to */ uint256 /* policyId */ ) public pure override {
        revert SoulboundToken();
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
