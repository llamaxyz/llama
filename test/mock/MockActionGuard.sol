// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IActionGuard} from "src/interfaces/IActionGuard.sol";

/// @dev A mock action guard that can be configured for testing. We set the return value of each
/// guard method in the constructor, and set the reason string to use for all cases. Tests will only
/// test one case at a time, so this is sufficient.
contract MockActionGuard is IActionGuard {
  bool creationAllowed;
  bool preExecutionAllowed;
  bool postExecutionAllowed;
  bytes32 reason;

  constructor(bool _creationAllowed, bool _preExecutionAllowed, bool _postExecutionAllowed, bytes32 _reason) {
    creationAllowed = _creationAllowed;
    preExecutionAllowed = _preExecutionAllowed;
    postExecutionAllowed = _postExecutionAllowed;
    reason = _reason;
  }

  function validateActionCreation(uint256 /* actionId */ ) external view override returns (bool, bytes32) {
    return (creationAllowed, reason);
  }

  function validatePreActionExecution(uint256 /* actionId */ ) external view override returns (bool, bytes32) {
    return (preExecutionAllowed, reason);
  }

  function validatePostActionExecution(uint256 /* actionId */ ) external view override returns (bool, bytes32) {
    return (postExecutionAllowed, reason);
  }
}
