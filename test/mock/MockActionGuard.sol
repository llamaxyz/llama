// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IActionGuard} from "src/interfaces/IActionGuard.sol";

contract MockActionGuard is IActionGuard {
  bool creationAllowed;
  bytes32 creationReason;

  bool executionAllowed;
  bytes32 executionReason;

  constructor(bool _creationAllowed, bytes32 _creationReason, bool _executionAllowed, bytes32 _executionReason) {
    creationAllowed = _creationAllowed;
    creationReason = _creationReason;
    executionAllowed = _executionAllowed;
    executionReason = _executionReason;
  }

  function validateActionCreation(uint256 /* actionId */ )
    external
    view
    override
    returns (bool allowed, bytes32 reason)
  {
    return (creationAllowed, creationReason);
  }

  function validateActionExecution(uint256 /* actionId */ )
    external
    view
    override
    returns (bool allowed, bytes32 reason)
  {
    return (executionAllowed, executionReason);
  }
}
