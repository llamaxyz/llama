// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ActionInfo, RoleHolderData} from "src/lib/Structs.sol";
import {ILlamaActionGuard} from "src/interfaces/ILlamaActionGuard.sol";

/// @title Protected Set Role Holder Guard
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A guard that protects against unauthorized calls to setRoleHolders on the LlamaGovernanceScript.
contract ProtectedSetRoleHoldersGuard is ILlamaActionGuard {
  /// @dev Throws if called by any account other than the EXECUTOR.
  error OnlyLlamaExecutor();
  /// @dev Throws if the setterRole is not authorized to set the targetRole.
  error UnauthorizedSetRoleHolder(uint8 setterRole, uint8 targetRole);

  /// @dev Emitted when the authorizedSetRoleHolder mapping is updated.
  event AuthorizedSetRoleHolder(uint8 indexed setterRole, uint8 indexed targetRole, bool isAuthorized);

  /// @notice BYPASS_PROTECTION_ROLE can be set to 0 to disable this feature.
  /// This also means the all holders role cannot be set as the BYPASS_PROTECTION_ROLE.
  uint8 public immutable BYPASS_PROTECTION_ROLE;
  /// @notice The `LlamaExecutor` contract address that controls this guard contract.
  address public immutable EXECUTOR;

  /// @notice A mapping to keep track of which roles the setterRole is authorized to set.
  mapping(uint8 => mapping(uint8 => bool)) public authorizedSetRoleHolder;

  constructor(uint8 _BYPASS_PROTECTION_ROLE, address _executor) {
    BYPASS_PROTECTION_ROLE = _BYPASS_PROTECTION_ROLE;
    EXECUTOR = _eExecutor;
  }

  /// @inheritdoc ILlamaActionGuard
  /// @dev Performs a validation check at action creation time that the action creator is authorized to set the role.
  function validateActionCreation(ActionInfo calldata actionInfo) external view {
    if (BYPASS_PROTECTION_ROLE == 0 || actionInfo.creatorRole != BYPASS_PROTECTION_ROLE) {
      RoleHolderData[] memory roleHolderData = abi.decode(actionInfo.data[4:], (RoleHolderData[]));
      for (uint256 i = 0; i < roleHolderData.length; i++) {
        if (!authorizedSetRoleHolder[actionInfo.creatorRole][roleHolderData[i].role]) {
          revert UnauthorizedSetRoleHolder(actionInfo.creatorRole, roleHolderData[i].role);
        }
      }
    }
  }

  /// @notice Allows the EXECUTOR to set the authorizedSetRoleHolder mapping.
  /// @param setterRole The role that is is being authorized or unauthorized to set the targetRole.
  /// @param targetRole The role that the setterRole is being authorized or unauthorized to set.
  /// @param isAuthorized Whether the setterRole is authorized to set the targetRole.
  function setAuthorizedSetRoleHolder(uint8 setterRole, uint8 targetRole, bool isAuthorized) external {
    if (msg.sender != EXECUTOR) revert OnlyLlamaExecutor();
    authorizedSetRoleHolder[setterRole][targetRole] = isAuthorized;
    emit AuthorizedSetRoleHolder(setterRole, targetRole, isAuthorized);
  }

  /// @inheritdoc ILlamaActionGuard
  function validatePreActionExecution(ActionInfo calldata actionInfo) external pure {}

  /// @inheritdoc ILlamaActionGuard
  function validatePostActionExecution(ActionInfo calldata actionInfo) external pure {}
}
