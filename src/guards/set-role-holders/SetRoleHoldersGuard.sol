// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILlamaActionGuard} from "src/interfaces/ILlamaActionGuard.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {ActionInfo, RoleHolderData} from "src/lib/Structs.sol";
import {AuthorizeSetRoleHolderData} from "src/guards/set-role-holders/SetRoleHoldersGuardFactory.sol";

/// @title Set Role Holders Guard
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A guard that regulates which roles are allowed to set other roles.
/// @dev This guard should be used to protect the `setRoleHolders` function in the `LlamaGovernanceScript` contract
contract SetRoleHoldersGuard is ILlamaActionGuard {
  // =========================
  // ======== Errors  ========
  // =========================

  /// @dev Thrown if called by any account other than the EXECUTOR.
  error OnlyLlamaExecutor();

  /// @dev Thrown if the `actionCreatorRole` is not authorized to set the `targetRole`.
  error UnauthorizedSetRoleHolder(uint8 actionCreatorRole, uint8 targetRole);

  // =========================
  // ======== Events  ========
  // =========================

  /// @dev Emitted when the authorizedSetRoleHolder mapping is updated.
  event AuthorizedSetRoleHolder(uint8 indexed actionCreatorRole, uint8 indexed targetRole, bool isAuthorized);

  // ===================================
  // ======== Storage Variables ========
  // ===================================

  /// @notice The `LlamaExecutor` contract address that controls this guard contract.
  address public immutable EXECUTOR;

  /// @notice A mapping to keep track of which roles the actionCreatorRole is authorized to set.
  mapping(uint8 actionCreatorRole => mapping(uint8 targetRole => bool hasAuthorization)) public authorizedSetRoleHolder;

  // ===================================
  // ======== Contract Creation ========
  // ===================================

  constructor(address _executor, AuthorizeSetRoleHolderData[] memory authorizeSetRoleHolderData) {
    EXECUTOR = _executor;
    _setAuthorizedSetRoleHolder(authorizeSetRoleHolderData);
  }

  // ================================
  // ======== External Logic ========
  // ================================

  /// @inheritdoc ILlamaActionGuard
  /// @notice Performs a validation check at action creation time that the action creator is authorized to set the role.
  function validateActionCreation(ActionInfo calldata actionInfo) external view {
    RoleHolderData[] memory roleHolderData = abi.decode(actionInfo.data[4:], (RoleHolderData[])); // skip selector
    uint256 length = roleHolderData.length;
    for (uint256 i = 0; i < length; LlamaUtils.uncheckedIncrement(i)) {
      if (!authorizedSetRoleHolder[actionInfo.creatorRole][roleHolderData[i].role]) {
        revert UnauthorizedSetRoleHolder(actionInfo.creatorRole, roleHolderData[i].role);
      }
    }
  }

  /// @notice Allows the EXECUTOR to set the authorizedSetRoleHolder mapping.
  /// @param authorizeSetRoleHolderData The data to set the authorizedSetRoleHolder mapping.
  function setAuthorizedSetRoleHolder(AuthorizeSetRoleHolderData[] memory authorizeSetRoleHolderData) external {
    if (msg.sender != EXECUTOR) revert OnlyLlamaExecutor();
    _setAuthorizedSetRoleHolder(authorizeSetRoleHolderData);
  }

  /// @inheritdoc ILlamaActionGuard
  function validatePreActionExecution(ActionInfo calldata actionInfo) external pure {}

  /// @inheritdoc ILlamaActionGuard
  function validatePostActionExecution(ActionInfo calldata actionInfo) external pure {}

  // ================================
  // ======== Internal Logic ========
  // ================================
  function _setAuthorizedSetRoleHolder(AuthorizeSetRoleHolderData[] memory data) internal {
    uint256 length = data.length;
    for (uint256 i = 0; i < length; LlamaUtils.uncheckedIncrement(i)) {
      authorizedSetRoleHolder[data[i].actionCreatorRole][data[i].targetRole] = data[i].isAuthorized;
      emit AuthorizedSetRoleHolder(data[i].actionCreatorRole, data[i].targetRole, data[i].isAuthorized);
    }
  }
}
