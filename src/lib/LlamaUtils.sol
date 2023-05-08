// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library LlamaUtils {
  /// @dev Increments a uint256 without checking for overflow.
  function uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }
}
