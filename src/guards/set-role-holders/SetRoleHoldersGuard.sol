// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILlamaActionGuard} from "src/interfaces/ILlamaActionGuard.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {ActionInfo, RoleHolderData} from "src/lib/Structs.sol";

/// @title Protected Set Role Holder Guard
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

  /// @notice BYPASS_PROTECTION_ROLE can be set to 0 to disable this feature.
  /// This also means the all holders role cannot be set as the BYPASS_PROTECTION_ROLE.
  uint8 public immutable BYPASS_PROTECTION_ROLE;
  /// @notice The `LlamaExecutor` contract address that controls this guard contract.
  address public immutable EXECUTOR;

  /// @notice A mapping to keep track of which roles the actionCreatorRole is authorized to set.
  mapping(uint8 actionCreatorRole => mapping(uint8 targetRole => bool hasAuthorization)) public authorizedSetRoleHolder;

  // ===================================
  // ======== Contract Creation ========
  // ===================================

  constructor(uint8 _BYPASS_PROTECTION_ROLE, address _executor) {
    BYPASS_PROTECTION_ROLE = _BYPASS_PROTECTION_ROLE;
    EXECUTOR = _executor;
  }

  // ================================
  // ======== External Logic ========
  // ================================

  /// @inheritdoc ILlamaActionGuard
  /// @notice Performs a validation check at action creation time that the action creator is authorized to set the role.
  function validateActionCreation(ActionInfo calldata actionInfo) external view {
    if (BYPASS_PROTECTION_ROLE == 0 || actionInfo.creatorRole != BYPASS_PROTECTION_ROLE) {
      RoleHolderData[] memory roleHolderData = abi.decode(actionInfo.data[4:], (RoleHolderData[])); // skip selector
      uint256 length = roleHolderData.length;
      for (uint256 i = 0; i < length; LlamaUtils.uncheckedIncrement(i)) {
        if (!authorizedSetRoleHolder[actionInfo.creatorRole][roleHolderData[i].role]) {
          revert UnauthorizedSetRoleHolder(actionInfo.creatorRole, roleHolderData[i].role);
        }
      }
    }
  }

  /// @notice Allows the EXECUTOR to set the authorizedSetRoleHolder mapping.
  /// @param actionCreatorRole The role that is is being authorized or unauthorized to set the targetRole.
  /// @param targetRole The role that the actionCreatorRole is being authorized or unauthorized to set.
  /// @param isAuthorized Whether the actionCreatorRole is authorized to set the targetRole.
  function setAuthorizedSetRoleHolder(uint8 actionCreatorRole, uint8 targetRole, bool isAuthorized) external {
    if (msg.sender != EXECUTOR) revert OnlyLlamaExecutor();
    authorizedSetRoleHolder[actionCreatorRole][targetRole] = isAuthorized;
    emit AuthorizedSetRoleHolder(actionCreatorRole, targetRole, isAuthorized);
  }

  /// @inheritdoc ILlamaActionGuard
  function validatePreActionExecution(ActionInfo calldata actionInfo) external pure {}

  /// @inheritdoc ILlamaActionGuard
  function validatePostActionExecution(ActionInfo calldata actionInfo) external pure {}
}
