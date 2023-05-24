// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseScript} from "src/llama-scripts/BaseScript.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";

/// @dev This script is a template for creating new scripts, and should not be used directly.
/// @dev This script is meant to be delegatecalled by the core contract, which informs our use of `SELF` and
/// `address(this)`.
abstract contract SingleUseScript is BaseScript {
  /// @dev Address of the executor contract. We save it off because during a delegatecall `address(this)` refers to the caller's address, not this script's address.
  LlamaExecutor internal immutable EXECUTOR;

  constructor(LlamaExecutor executor) {
    EXECUTOR = executor;
  }

  /// @dev Add this to your script's methods to unauthorize itself after it has been run once. Any subsequent calls will
  /// fail unless the script is reauthorized. Best if used in tandem with the `onlyDelegateCall` from `BaseScript.sol`.
  modifier unauthorizeAfterRun() {
    _;
    LlamaCore core = LlamaCore(EXECUTOR.LLAMA_CORE());
    core.authorizeScript(SELF, false);
  }
}
