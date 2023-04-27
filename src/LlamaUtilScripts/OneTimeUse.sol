// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LlamaCore} from "src/LlamaCore.sol";

/// @dev A mock script that can be configured for testing.
contract OneTimeUse {
  address immutable private thisAddress;
  LlamaCore core;

  constructor() {
    thisAddress = address(this);
  }

  modifier unauthorizeAfterRun() {
    _;
    core = LlamaCore(address(this));
    core.authorizeScript(thisAddress, false);
  }

  function run() external unauthorizeAfterRun {
    // do something
  }
}
