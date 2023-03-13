// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721MinimalProxy} from "src/lib/ERC721MinimalProxy.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {IVertexPolicy} from "src/interfaces/IVertexPolicy.sol";
import {
  PermissionData,
  PermissionIdCheckpoint,
  PermissionMetadata,
  PolicyUpdateData,
  PolicyGrantData,
  PolicyRevokeData
} from "src/lib/Structs.sol";

/// @title VertexPolicy
/// @author Llama (vertex@llama.xyz)
/// @dev VertexPolicy is a (TODO: pick a soulbound standard) ERC721 contract where each token has permissions
/// @notice The permissions determine how the token can interact with the vertex administrator contract
contract VertexPolicy is ERC721MinimalProxy, IVertexPolicy {
  error SoulboundToken();
  error InvalidInput(); // TODO: Probably need more than one error?
  error OnlyVertex();
  error OnlyOnePolicyPerHolder();
  error AlreadyInitialized();
  error Expired();

  mapping(uint256 => mapping(bytes32 => PermissionIdCheckpoint[])) internal tokenPermissionCheckpoints;
  mapping(bytes32 => PermissionIdCheckpoint[]) internal permissionSupplyCheckpoints;
  mapping(uint256 => mapping(bytes32 => uint256)) public tokenToPermissionExpirationTimestamp;
  uint256[] public policyIds;
  string public baseURI;
  uint256 internal _totalSupply;
  address public vertex;

  modifier onlyVertex() {
    if (msg.sender != vertex) revert OnlyVertex();
    _;
  }

  constructor() initializer {}

  /// @inheritdoc IVertexPolicy
  function initialize(string memory _name, PolicyGrantData[] memory initialPolicies) external initializer {
    string memory firstThreeLetters = LibString.slice(_name, 0, 3);
    __initializeERC721MinimalProxy(_name, string.concat("V_", firstThreeLetters));
    uint256 policyLength = initialPolicies.length;
    for (uint256 i = 0; i < policyLength; ++i) {
      _grantPolicy(initialPolicies[i]);
    }
  }

  /// @inheritdoc IVertexPolicy
  function setVertex(address _vertex) external {
    if (vertex != address(0)) revert AlreadyInitialized();
    vertex = _vertex;
  }

  /// @inheritdoc IVertexPolicy
  function holderWeightAt(address policyholder, bytes32 role, uint256 timestamp)
    external
    view
    override
    returns (uint256)
  {
    uint256 policyId = uint256(uint160(policyholder));
    PermissionIdCheckpoint[] storage _checkpoints = tokenPermissionCheckpoints[policyId][role];
    uint256 length = _checkpoints.length;
    if (length == 0) return 0;
    if (timestamp < _checkpoints[0].timestamp) return 0;
    uint256 min = 0;
    uint256 max = length - 1;
    while (max > min) {
      uint256 mid = (max + min + 1) / 2;
      if (_checkpoints[mid].timestamp <= timestamp) min = mid;
      else max = mid - 1;
    }
    bool expired = tokenToPermissionExpirationTimestamp[policyId][role] == 0 // 0 means no expiration
      ? false
      : tokenToPermissionExpirationTimestamp[policyId][role] < timestamp;
    return expired ? 0 : _checkpoints[min].quantity;
  }

  function totalSupplyAt(bytes32 role, uint256 timestamp) external view returns (uint256) {
    PermissionIdCheckpoint[] storage _checkpoints = permissionSupplyCheckpoints[role];
    uint256 length = _checkpoints.length;
    if (length == 0) return 0;
    if (timestamp < _checkpoints[0].timestamp) return 0;
    uint256 min = 0;
    uint256 max = length - 1;
    while (max > min) {
      uint256 mid = (max + min + 1) / 2;
      if (_checkpoints[mid].timestamp <= timestamp) min = mid;
      else max = mid - 1;
    }

    return _checkpoints[min].quantity;
  }

  /// @inheritdoc IVertexPolicy
  function batchGrantPolicies(PolicyGrantData[] memory policyData) public override onlyVertex {
    uint256 length = policyData.length;
    for (uint256 i = 0; i < length; ++i) {
      _grantPolicy(policyData[i]);
      emit PolicyAdded(policyData[i]);
    }
  }

  /// @inheritdoc IVertexPolicy
  function batchUpdatePermissions(PolicyUpdateData[] calldata updateData) public override onlyVertex {
    uint256 length = updateData.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        if (updateData[i].permissionsToAdd.length == 0 && updateData[i].permissionsToRemove.length == 0) {
          revert InvalidInput();
        }
        _updatePermissions(updateData[i]);
        emit PermissionUpdated(updateData[i]);
      }
    }
  }

  /// @inheritdoc IVertexPolicy
  function batchRevokePolicies(PolicyRevokeData[] calldata policyData) public override onlyVertex {
    uint256 length = policyData.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        _revokePolicy(policyData[i]);
        emit PolicyRevoked(policyData[i]);
      }
    }
  }

  /// @inheritdoc IVertexPolicy
  function hasPermission(uint256 policyId, bytes32 permissionId) public view override returns (bool) {
    PermissionIdCheckpoint[] storage _permissionIdCheckpoint = tokenPermissionCheckpoints[policyId][permissionId];
    uint256 length = _permissionIdCheckpoint.length;
    bool expired = _isPermissionExpired(policyId, permissionId);
    bool hasQuantity = length > 0 ? _permissionIdCheckpoint[length - 1].quantity > 0 : false;
    return hasQuantity && !expired;
  }

  /// @notice updates a policyID with a new set of permissions
  /// @notice will delete and add permissions as needed
  /// @param updateData the policy token Id being updated
  function _updatePermissions(PolicyUpdateData calldata updateData) internal {
    if (ownerOf(updateData.policyId) == address(0)) revert InvalidInput();
    uint256 permissionsToAddLength = updateData.permissionsToAdd.length;
    uint256 permissionsToRemoveLength = updateData.permissionsToRemove.length;
    unchecked {
      for (uint256 i; i < permissionsToRemoveLength; ++i) {
        PermissionMetadata calldata data = updateData.permissionsToRemove[i];
        tokenPermissionCheckpoints[updateData.policyId][data.permissionId].push(
          PermissionIdCheckpoint(uint128(block.timestamp), 0)
        );
        PermissionIdCheckpoint[] storage supplyCheckpoint = permissionSupplyCheckpoints[data.permissionId];
        uint256 supplyIndex = supplyCheckpoint.length > 0 ? supplyCheckpoint.length - 1 : 0;
        supplyCheckpoint.push(
          PermissionIdCheckpoint(uint128(block.timestamp), supplyCheckpoint[supplyIndex].quantity - 1)
        );
      }
      for (uint256 j; j < permissionsToAddLength; ++j) {
        PermissionMetadata calldata data = updateData.permissionsToAdd[j];
        bool _hasPermission = hasPermission(updateData.policyId, data.permissionId);
        if (!_hasPermission) {
          tokenPermissionCheckpoints[updateData.policyId][data.permissionId].push(
            PermissionIdCheckpoint(uint128(block.timestamp), 1)
          );
          PermissionIdCheckpoint[] storage checkpoints = permissionSupplyCheckpoints[data.permissionId];
          uint128 quantity = checkpoints.length > 0 ? checkpoints[checkpoints.length - 1].quantity : 0;
          checkpoints.push(PermissionIdCheckpoint(uint128(block.timestamp), quantity + 1));
        }
        if (data.expirationTimestamp != tokenToPermissionExpirationTimestamp[updateData.policyId][data.permissionId]) {
          if (data.expirationTimestamp != 0 && data.expirationTimestamp < block.timestamp) revert Expired();
          tokenToPermissionExpirationTimestamp[updateData.policyId][data.permissionId] = data.expirationTimestamp;
        }
      }
    }
  }

  /// @notice mints a new policy token with the given permissions
  /// @param policyData the policy data to mint
  function _grantPolicy(PolicyGrantData memory policyData) internal {
    if (balanceOf(policyData.user) != 0) revert OnlyOnePolicyPerHolder();
    uint256 length = policyData.permissionsToAdd.length;
    uint256 policyId = uint256(uint160(policyData.user));
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        uint256 expiration = policyData.permissionsToAdd[i].expirationTimestamp;
        bytes32 permission = policyData.permissionsToAdd[i].permissionId;
        if (!hasPermission(policyId, permission)) {
          if (expiration > 0) {
            if (expiration < block.timestamp) revert Expired();
            tokenToPermissionExpirationTimestamp[policyId][permission] = expiration;
          }
          tokenPermissionCheckpoints[policyId][permission].push(PermissionIdCheckpoint(uint128(block.timestamp), 1));
          PermissionIdCheckpoint[] storage checkpoints = permissionSupplyCheckpoints[permission];
          uint256 checkpointsLength = checkpoints.length;
          uint128 quantity = checkpointsLength > 0 ? checkpoints[checkpointsLength - 1].quantity : 0;
          checkpoints.push(PermissionIdCheckpoint(uint128(block.timestamp), quantity + 1));
        }
      }
      ++_totalSupply;
      policyIds.push(policyId);
      _mint(policyData.user, policyId);
    }
  }

  /// @notice revokes given permissions from a policy token
  /// @param policyData the policy data to revoke
  function _revokePolicy(PolicyRevokeData calldata policyData) internal {
    if (ownerOf(policyData.policyId) == address(0)) revert InvalidInput();
    unchecked {
      uint256 permissionsLength = policyData.permissionIds.length;
      for (uint256 i = 0; i < permissionsLength; ++i) {
        tokenPermissionCheckpoints[policyData.policyId][policyData.permissionIds[i]].push(
          PermissionIdCheckpoint(uint128(block.timestamp), 0)
        );
        PermissionIdCheckpoint[] storage supplyCheckpoint = permissionSupplyCheckpoints[policyData.permissionIds[i]];
        supplyCheckpoint.push(
          PermissionIdCheckpoint(uint128(block.timestamp), supplyCheckpoint[supplyCheckpoint.length - 1].quantity - 1)
        );
      }
      _totalSupply--;
      _burn(policyData.policyId);
    }
  }

  function _isPermissionExpired(uint256 _policyId, bytes32 _permissionId) internal view returns (bool) {
    uint256 _expiration = tokenToPermissionExpirationTimestamp[_policyId][_permissionId];
    return _expiration < block.timestamp && _expiration != 0;
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

  /// @dev overriding approve to disable approvals for SBTs
  function approve(address, /* spender */ uint256 /* id */ ) public override {
    revert SoulboundToken();
  }

  function setApprovalForAll(address, /* operator */ bool /* approved */ ) public override {
    revert SoulboundToken();
  }

  /// @inheritdoc IVertexPolicy
  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  /// @notice returns the location of the policy metadata
  /// @param id the id of the policy token
  function tokenURI(uint256 id) public view override returns (string memory) {
    return string(abi.encodePacked(baseURI, LibString.toString(id)));
  }

  function getTokenPermissionCheckpoints(uint256 policyId, bytes32 permissionId)
    external
    view
    returns (PermissionIdCheckpoint[] memory)
  {
    return tokenPermissionCheckpoints[policyId][permissionId];
  }

  function getTokenPermissionSupplyCheckpoints(bytes32 permissionId)
    external
    view
    returns (PermissionIdCheckpoint[] memory)
  {
    return permissionSupplyCheckpoints[permissionId];
  }
}
