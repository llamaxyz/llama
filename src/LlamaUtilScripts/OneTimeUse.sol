// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev A mock script that can be configured for testing.
contract OneTimeUse { // is BaseScript
  bool public hasBeenUsed;

  modifier onlyOnce() {
    require(!hasBeenUsed, "OneTimeUse: already used");
    hasBeenUsed = true;
    _;
  }
}
