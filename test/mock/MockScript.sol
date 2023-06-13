// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev A mock script that can be configured for testing.
contract MockScript {
  function executeScript() external view returns (address) {
    return msg.sender;
  }

  function executeScriptWithValue() external payable returns (uint256) {
    return msg.value;
  }
}
