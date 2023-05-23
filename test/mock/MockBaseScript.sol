// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseScript} from "src/llama-scripts/BaseScript.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";

/// @notice This is a mock contract that inherits from the base script for testing purposes
contract MockBaseScript is BaseScript {
  uint256 public counter;

  function run() external onlyDelegateCall {
    counter++;
  }
}
