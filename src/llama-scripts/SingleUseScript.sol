// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LlamaCore} from "src/LlamaCore.sol";

/// @notice This script is a template for creating new scripts, and should not be used directly.
/// @dev A mock script that can be configured for testing.
/// @dev This script is meant to be delegate called by the core contract, which informs our use of `SELF` and
/// `address(this)`.
abstract contract SingleUseScript {
  address private immutable SELF;
  LlamaCore core;

  constructor() {
    SELF = address(this);
  }

  /// @dev Add this to your script's methods and to unauthorize the script after it has been run once.
  modifier unauthorizeAfterRun() {
    _;
    core = LlamaCore(address(this));
    core.authorizeScript(SELF, false);
  }
}
