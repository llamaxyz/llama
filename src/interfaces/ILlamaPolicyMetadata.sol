// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Llama Policy Metadata
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Interface for utility contract to compute Llama policy metadata.
interface ILlamaPolicyMetadata {
  /// @notice Initializes a new clone of the policy metadata contract.
  /// @param config The policy metadata configuration, encoded as bytes to support differing initialization arguments in
  /// different policy metadata logic contracts.
  function initialize(bytes memory config) external;

  /// @notice Returns the token URI for a given Llama policyholder.
  /// @param name The name of the Llama instance.
  /// @param tokenId The token ID of the Llama policyholder.
  function tokenURI(string memory name, uint256 tokenId) external view returns (string memory);

  /// @notice Returns the contract URI for a Llama instance's policies.
  /// @param name The name of the Llama instance.
  function contractURI(string memory name) external pure returns (string memory);
}