// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Action Guard
/// @author Llama (vertex@llama.xyz)
/// @notice Executes checks on action creation and execution to verify that the action is allowed.
/// @dev Methods are not `view` because an action guard may write to it's own storage. This can be
/// useful to persist state between calls to `validateActionCreation` and `validateActionExecution`.
/// For example, `validateActionCreation` may want to store USD price of a token during action
/// creation, and `validateActionExecution` may want to check that the price has not changed by more
/// than a certain amount.
/// @dev These interfaces only take `actionId` as an argument. This is because the action guard may
/// read any state it needs from the VertexCore contracts.
interface IActionGuard {
  /// @notice Returns `true` if `actionId` is allowed to be created, and `false` otherwise. May
  /// also return a reason string for why the action is not allowed.
  /// @dev Reason string is limited to `bytes32` to reduce the risk of a revert due to a large
  /// string that consumes too much gas when copied to memory.
  function validateActionCreation(uint256 actionId) external returns (bool allowed, bytes32 reason);

  /// @notice Returns `true` if `actionId` is allowed to be executed, and `false` otherwise. May
  /// also return a reason string for why the action is not allowed.
  /// @dev Reason string is limited to `bytes32` to reduce the risk of a revert due to a large
  /// string that consumes too much gas when copied to memory.
  function validateActionExecution(uint256 actionId) external returns (bool allowed, bytes32 reason);
}
