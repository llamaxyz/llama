// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ProtectedSetRoleHoldersGuard} from "src/guards/ProtectedSetRoleHoldersGuard.sol";

/// @title Protected Set Role Holder Guard Factory
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A factory contract that deploys `ProtectedSetRoleHoldersGuard` contracts.
contract ProtectedSetRoleHoldersGuardFactory {
  /// @notice Emitted when a new `ProtectedSetRoleHoldersGuard` contract is deployed.
  event ProtectedSetRoleHoldersGuardDeployed(
    address indexed guard, uint8 indexed bypassProtectionRole, address indexed executor
  );

  /// @notice Deploys a new `ProtectedSetRoleHoldersGuard` contract.
  /// @param bypassProtectionRole The role that can bypass the protection.
  /// @param executor The address of the executor contract.
  function deployProtectedSetRoleHoldersGuard(uint8 bypassProtectionRole, address executor)
    external
    returns (ProtectedSetRoleHoldersGuard guard)
  {
    guard = new ProtectedSetRoleHoldersGuard(bypassProtectionRole, executor);
    emit ProtectedSetRoleHoldersGuardDeployed(address(guard), bypassProtectionRole, executor);
  }
}
