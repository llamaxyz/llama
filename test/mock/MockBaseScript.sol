// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LlamaBaseScript} from "src/llama-scripts/LlamaBaseScript.sol";

/// @dev This is a mock contract that inherits from the base script for testing purposes
contract MockBaseScript is LlamaBaseScript {
  event SuccessfulCall();

  function run() external onlyDelegateCall {
    emit SuccessfulCall();
  }
}
