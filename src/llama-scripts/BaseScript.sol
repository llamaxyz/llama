// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice This script is a template for creating new scripts, and should not be used directly.
abstract contract BaseScript {
  address public immutable SELF;

  constructor() {
    SELF = address(this);
  }

  /// @dev Add this to your script's methods to only allow access to the llama executor via delegate call.
  modifier onlyDelegateCall() {
    require(address(this) != SELF);
    _;
  }
}