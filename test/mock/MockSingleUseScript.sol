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
contract MockSingleUseScript {
  bytes32 public immutable SELF_PERMISSION_ID;
  address private immutable SELF;
  uint8 public immutable ROLE;

  constructor(ILlamaStrategy strategy, uint8 role, bytes4 selector) {
    SELF = address(this);
    SELF_PERMISSION_ID = keccak256(abi.encode(SELF, selector, strategy));
    ROLE = role;
  }

  /// @dev Add this to your script's methods to unauthorize the script after it has been run once.
  modifier unauthorizeAfterRun() {
    _;
    LlamaCore core = LlamaCore(address(this));
    LlamaPolicy policy = LlamaPolicy(core.policy());
    core.authorizeScript(SELF, false);
    policy.setRolePermission(ROLE, SELF_PERMISSION_ID, false);
  }

  function pauseMockProtocol(MockProtocol mp, bool isPaused) external unauthorizeAfterRun {
    mp.pause(isPaused);
  }
}
