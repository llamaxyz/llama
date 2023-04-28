// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LlamaCore} from "src/LlamaCore.sol";

/// @notice This script is a template for creating new scripts, and should not be used directly
/// @dev A mock script that can be configured for testing.
/// @dev this script is meant to be delegate called by the core contract, which informs our use of `SELF` and `address(this)`
contract OneTimeUse {
  address private immutable SELF;
  LlamaCore core;

  constructor() {
    SELF = address(this);
  }

  modifier unauthorizeAfterRun() {
    _;
    core = LlamaCore(address(this));
    core.authorizeScript(SELF, false);
  }

  function run() external unauthorizeAfterRun {
    // do something
  }
}
