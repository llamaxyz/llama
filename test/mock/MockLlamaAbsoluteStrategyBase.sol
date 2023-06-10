// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ActionInfo} from "src/lib/Structs.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/LlamaAbsoluteStrategyBase.sol";

// @dev A mock account implementation (logic) contract that doesn't have `name` or other functions. To be used for
/// testing.
contract MockLlamaAbsoluteStrategyBase is LlamaAbsoluteStrategyBase {
  function validateActionCreation(ActionInfo calldata) external view override {}

  function isApprovalEnabled(ActionInfo calldata, address, uint8) external view override {}

  function isDisapprovalEnabled(ActionInfo calldata, address, uint8) external view override {}
}
