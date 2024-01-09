// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SetRoleHoldersGuard} from "src/guards/set-role-holders/SetRoleHoldersGuard.sol";

/// @title Set Role Holders Guard Factory
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A factory contract that deploys `SetRoleHoldersGuard` contracts.
/// The `SetRoleHoldersGuard` contract is used to specify which roles are allowed to set other roles, by setting a guard
/// on the `setRoleHolders` function in the `LlamaGovernanceScript` contract.
contract SetRoleHoldersGuardFactory {
  /// @notice Emitted when a new `SetRoleHoldersGuard` contract is deployed.
  event SetRoleHoldersGuardCreated(
    address indexed deployer, address indexed executor, address guard, uint8 bypassProtectionRole
  );

  /// @notice Deploys a new `SetRoleHoldersGuard` contract.
  /// @param bypassProtectionRole The role that can bypass the protection.
  /// @param executor The address of the executor contract.
  function deploySetRoleHoldersGuard(uint8 bypassProtectionRole, address executor)
    external
    returns (SetRoleHoldersGuard guard)
  {
    guard = new SetRoleHoldersGuard(bypassProtectionRole, executor);
    emit SetRoleHoldersGuardCreated(msg.sender, executor, address(guard), bypassProtectionRole);
  }
}
