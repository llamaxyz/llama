// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ActionInfo, RoleHolderData} from "src/lib/Structs.sol";
import {ILlamaActionGuard} from "src/interfaces/ILlamaActionGuard.sol";
import {Test, console2} from "forge-std/Test.sol";

/// @title Protected Set Role Holder Guard
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A guard that protects against unauthorized calls to setRoleHolders on the LlamaGovernanceScript.
contract ProtectedSetRoleHoldersGuard is ILlamaActionGuard {
  error OnlyLlamaExecutor();
  error UnauthorizedSetRoleHolder(uint8 setterRole, uint8 targetRole);

  /// @notice bypassProtectionRole can be set to 0 to disable this feature.
  /// This also means the all holders role cannot be set as the bypassProtectionRole.
  uint8 public immutable bypassProtectionRole;
  address public immutable llamaExecutor;

  mapping(uint8 => mapping(uint8 => bool)) public authorizedSetRoleHolder;

  constructor(uint8 _bypassProtectionRole, address _llamaExecutor) {
    bypassProtectionRole = _bypassProtectionRole;
    llamaExecutor = _llamaExecutor;
  }

  /// @notice Reverts if action creation is not allowed.
  /// @param actionInfo Data required to create an action.
  function validateActionCreation(ActionInfo calldata actionInfo) external {
    if (bypassProtectionRole == 0 || actionInfo.creatorRole != bypassProtectionRole) {
      RoleHolderData[] memory roleHolderData = abi.decode(actionInfo.data[4:], (RoleHolderData[]));
      for (uint256 i = 0; i < roleHolderData.length; i++) {
        if (!authorizedSetRoleHolder[actionInfo.creatorRole][roleHolderData[i].role]) {
          revert UnauthorizedSetRoleHolder(actionInfo.creatorRole, roleHolderData[i].role);
        }
      }
    }
  }

  function setAuthorizedSetRoleHolder(uint8 setterRole, uint8 targetRole, bool isAuthorized) external {
    if (msg.sender != llamaExecutor) revert OnlyLlamaExecutor();
    authorizedSetRoleHolder[setterRole][targetRole] = isAuthorized;
  }

  /// @notice Called immediately before action execution, and reverts if the action is not allowed
  /// to be executed.
  /// @param actionInfo Data required to create an action.
  function validatePreActionExecution(ActionInfo calldata actionInfo) external {}

  /// @notice Called immediately after action execution, and reverts if the just-executed
  /// action should not have been allowed to execute.
  /// @param actionInfo Data required to create an action.
  function validatePostActionExecution(ActionInfo calldata actionInfo) external {}
}
