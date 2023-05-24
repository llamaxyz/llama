// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev This script is a template for creating new scripts, and should not be used directly.
abstract contract BaseScript {
  /// @dev Address of the script contract. We save it off because during a delegatecall `address(this)` refers to the caller's address, not this script's address.
  address internal immutable SELF;

  error OnlyDelegateCall();

  constructor() {
    SELF = address(this);
  }

  /// @dev Add this to your script's methods to only allow access to the llama executor via delegate call.
  modifier onlyDelegateCall() {
    if (address(this) == SELF) revert OnlyDelegateCall();
    _;
  }
}
