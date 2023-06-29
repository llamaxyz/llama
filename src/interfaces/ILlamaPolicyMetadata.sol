// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Llama Policy Metadata
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Interface for utility contract to compute Llama policy metadata.
interface ILlamaPolicyMetadata {
  /// @notice Returns the token URI for a given Llama policyholder.
  /// @param config The parameter configuration, encoded as bytes to support differing arguments in
  /// different metadata contracts.
  function tokenURI(bytes memory config) external pure returns (string memory);

  /// @notice Returns the contract URI for a Llama instance's policies.
  /// @param config The parameter configuration, encoded as bytes to support differing arguments in
  /// different metadata contracts.
  function contractURI(bytes memory config) external pure returns (string memory);
}
