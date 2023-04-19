// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Action Guard
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Executes checks on action creation and execution to verify that the action is allowed.
/// @dev Methods are not `view` because an action guard may write to it's own storage. This can be
/// useful to persist state between calls to the various guard methods. For example, a guard may:
///   - Store the USD price of a token during action creation in `validateActionCreation`.
///   - Verify the price has not changed by more than a given amount during `validatePreActionExecution`
///     and save off the current USD value of an account.
///   - Verify the USD value of an account has not decreased by more than a certain amount during
///     execution, i.e. between `validatePreActionExecution` and `validatePostActionExecution`.
/// than a certain amount.
/// @dev These interfaces only take `actionId` as an argument. This is because the action guard may
/// read any state it needs from the VertexCore contracts.
interface IActionGuard {
  /// @notice Returns `true` if `actionId` is allowed to be created, and `false` otherwise. May
  /// also return a reason string for why the action is not allowed.
  /// @dev Reason string is limited to `bytes32` to reduce the risk of a revert due to a large
  /// string that consumes too much gas when copied to memory.
  function validateActionCreation(uint256 actionId) external returns (bool allowed, bytes32 reason);

  /// @notice Called immediately before action execution, and returns `true` if the upcoming
  /// `actionId` is allowed to be executed, and `false` otherwise. May also return a reason string
  /// for why the action is not allowed.
  /// @dev Reason string is limited to `bytes32` to reduce the risk of a revert due to a large
  /// string that consumes too much gas when copied to memory.
  function validatePreActionExecution(uint256 actionId) external returns (bool allowed, bytes32 reason);

  /// @notice Called immediately after action execution, and returns `true` if the just-executed
  /// `actionId` was allowed to be executed, and `false` otherwise. May also return a reason string
  /// for why the action is not allowed.
  /// @dev Reason string is limited to `bytes32` to reduce the risk of a revert due to a large
  /// string that consumes too much gas when copied to memory.
  function validatePostActionExecution(uint256 actionId) external returns (bool allowed, bytes32 reason);
}
