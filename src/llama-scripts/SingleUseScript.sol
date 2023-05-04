// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";

/// @notice This script is a template for creating new scripts, and should not be used directly.
/// @dev A mock script that can be configured for testing.
/// @dev This script is meant to be delegate called by the core contract, which informs our use of `SELF` and
/// `address(this)`.
abstract contract SingleUseScript {
  address public immutable SELF;

  constructor() {
    SELF = address(this);
  }

  /// @dev Add this to your script's methods to unauthorize the script after it has been run once.
  modifier unauthorizeAfterRun() {
    _;
    // First we unauthorize the script itself.
    LlamaCore core = LlamaCore(address(this));
    LlamaPolicy policy = LlamaPolicy(core.policy());
    core.authorizeScript(SELF, false);

    // Now we remove permission for the role to call this script.
    // Usage of this approach requires "hidden" calldata to be appended to the delegatecall, i.e.
    // extra data not necessarily required by the script's signature. The specific data we need
    // is just the role, selector, and strategy address, which we expect to be ABI encoded as the
    // last 3 words of calldata.
    (uint8 role, bytes4 selector, address strategy) =
      abi.decode(msg.data[msg.data.length - 96:], (uint8, bytes4, address));

    bytes32 permissionId = keccak256(abi.encode(SELF, selector, strategy));
    policy.setRolePermission(role, permissionId, false);
  }
}
