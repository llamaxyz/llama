// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseScript} from "src/llama-scripts/BaseScript.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";

/// @notice This script is a template for creating new scripts, and should not be used directly.
/// @dev This script is meant to be delegate called by the core contract, which informs our use of `SELF` and
/// `address(this)`.
abstract contract SingleUseScript is BaseScript {
  LlamaExecutor immutable EXECUTOR;

  constructor(address executor) {
    EXECUTOR = LlamaExecutor(executor);
  }
  /// @dev Add this to your script's methods to unauthorize the script after it has been run once.

  modifier unauthorizeAfterRun() {
    _;
    LlamaCore core = LlamaCore(EXECUTOR.LLAMA_CORE());
    core.authorizeScript(SELF, false);
  }
}
