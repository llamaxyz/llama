// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @dev Shared helper methods for Llama's contracts.
library LlamaUtils {
  /// @dev Thrown when a value cannot be safely casted to a smaller type.
  error UnsafeCast(uint256 n);

  /// @dev Reverts if `n` does not fit in a `uint64`.
  function toUint64(uint256 n) internal pure returns (uint64) {
    if (n > type(uint64).max) revert UnsafeCast(n);
    return uint64(n);
  }

  /// @dev Reverts if `n` does not fit in a `uint128`.
  function toUint128(uint256 n) internal pure returns (uint128) {
    if (n > type(uint128).max) revert UnsafeCast(n);
    return uint128(n);
  }

  /// @dev Increments a `uint256` without checking for overflow.
  function uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }
}
