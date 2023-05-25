// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SingleUseScript} from "src/llama-scripts/SingleUseScript.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";

/// @dev This is a mock contract that inherits from the single use script for testing purposes
contract MockSingleUseScript is SingleUseScript {
  event SuccessfulCall();

  constructor(LlamaExecutor executor) SingleUseScript(executor) {}

  function run() external unauthorizeAfterRun onlyDelegateCall {
    emit SuccessfulCall();
  }
}
