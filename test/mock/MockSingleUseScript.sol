// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {SingleUseScript} from "src/llama-scripts/SingleUseScript.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";

/// @notice This script is a template for creating new scripts, and should not be used directly.
/// @dev A mock script that can be configured for testing.
/// @dev This script is meant to be delegate called by the core contract, which informs our use of `SELF` and
/// `address(this)`.
contract MockSingleUseScript is SingleUseScript {
  constructor(ILlamaStrategy strategy, uint8 role, bytes4 selector) SingleUseScript() {}

  function pauseMockProtocol(MockProtocol mp, bool isPaused) external unauthorizeAfterRun {
    mp.pause(isPaused);
  }
}
