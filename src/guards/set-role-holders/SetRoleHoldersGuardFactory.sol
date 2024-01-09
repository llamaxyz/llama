// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SetRoleHoldersGuard} from "src/guards/set-role-holders/SetRoleHoldersGuard.sol";

struct AuthorizeSetRoleHolderData {
  uint8 actionCreatorRole;
  uint8 targetRole;
  bool isAuthorized;
}

/// @title Set Role Holders Guard Factory
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A factory contract that deploys `SetRoleHoldersGuard` contracts.
/// The `SetRoleHoldersGuard` contract is used to specify which roles are allowed to set other roles, by setting a guard
/// on the `setRoleHolders` function in the `LlamaGovernanceScript` contract.
contract SetRoleHoldersGuardFactory {
  /// @notice Emitted when a new `SetRoleHoldersGuard` contract is deployed.
  event SetRoleHoldersGuardCreated(address indexed deployer, address indexed executor, address guard);

  /// @notice Deploys a new `SetRoleHoldersGuard` contract.
  /// @param executor The address of the executor contract.
  /// @param authorizeSetRoleHolderData The initial role authorizations.
  function deploySetRoleHoldersGuard(address executor, AuthorizeSetRoleHolderData[] memory authorizeSetRoleHolderData)
    external
    returns (SetRoleHoldersGuard guard)
  {
    guard = new SetRoleHoldersGuard(executor, authorizeSetRoleHolderData);
    emit SetRoleHoldersGuardCreated(msg.sender, executor, address(guard));
  }
}
