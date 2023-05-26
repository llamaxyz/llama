// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Llama Account Logic Interface
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the interface for Llama accounts which can be used to hold assets for a Llama instance.
interface ILlamaAccount {
  // -------- For Inspection --------

  /// @notice Returns the address of the Llama instance's executor.
  function llamaExecutor() external view returns (address);

  /// @notice Returns the name of the Llama account.
  function name() external view returns (string memory);

  // -------- At Account Creation --------

  /// @notice Initializes a new clone of the account.
  /// @param name The name of the `LlamaAccount` clone.
  function initialize(string memory name) external;

  // -------- Native Token --------

  /// @notice Function for Vertex Account to receive native token
  receive() external payable;
}
