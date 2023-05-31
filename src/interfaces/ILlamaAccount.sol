// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Llama Account Logic Interface
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the interface for Llama accounts which can be used to hold assets for a Llama instance.
interface ILlamaAccount {
  // -------- For Inspection --------

  /// @notice Returns the address of the Llama instance's executor.
  function llamaExecutor() external view returns (address);

  // -------- At Account Creation --------

  /// @notice Initializes a new clone of the account.
  /// @param config The account configuration, encoded as bytes to support differing constructor arguments in
  /// different account logic contracts.
  function initialize(bytes memory config) external;
}
