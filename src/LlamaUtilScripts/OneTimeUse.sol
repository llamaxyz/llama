// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LlamaCore} from "src/LlamaCore.sol";

/// @dev A mock script that can be configured for testing.
contract OneTimeUse {
  address private immutable THIS_ADDRESS;
  LlamaCore core;

  constructor() {
    THIS_ADDRESS = address(this);
  }

  modifier unauthorizeAfterRun() {
    _;
    core = LlamaCore(address(this));
    core.authorizeScript(THIS_ADDRESS, false);
  }

  function run() external unauthorizeAfterRun {
    // do something
  }
}
