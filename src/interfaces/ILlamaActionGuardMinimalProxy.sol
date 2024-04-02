// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILlamaActionGuard} from "src/interfaces/ILlamaActionGuard.sol";

/// @title Llama Action Guard Minimal Proxy Interface
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the interface for minimal proxy action guards.
interface ILlamaActionGuardMinimalProxy is ILlamaActionGuard {
  /// @notice Initializes a new clone of the action guard.
  /// @dev This function is called by the `deploy` function in the `LlamaActionGuardFactory` contract. The `initializer`
  /// modifier ensures that this function can be invoked at most once.
  /// @param llamaExecutor The address of the Llama executor.
  /// @param config The guard configuration, encoded as bytes to support differing constructor arguments in
  /// different guard logic contracts.
  /// @return This return statement must be hardcoded to `true` to ensure that initializing an EOA
  /// (like the zero address) will revert.
  function initialize(address llamaExecutor, bytes memory config) external returns (bool);
}
