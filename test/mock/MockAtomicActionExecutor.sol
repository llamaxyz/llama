// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";

/// @dev A mock contract that can create, queue, and execute actions in a single function.
contract MockAtomicActionExecutor {
  LlamaCore immutable CORE;

  constructor(LlamaCore _core) {
    core = _core;
  }

  function createQueueAndExecute(
    address policyholder,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    string memory description,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 actionId) {
    actionId = core.createActionBySig(policyholder, role, strategy, target, value, data, description, v, r, s);

    ActionInfo memory actionInfo = ActionInfo(actionId, policyholder, role, strategy, target, value, data);
    core.queueAction(actionInfo);
    core.executeAction(actionInfo);
  }
}
