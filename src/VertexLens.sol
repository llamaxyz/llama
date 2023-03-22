// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, PermissionData} from "src/lib/Structs.sol";

/// @title Vertex Lens
/// @author Llama (vertex@llama.xyz)
/// @notice Utility contract to compute Vertex contract addresses.
contract VertexLens {
  /// @notice hashes a permission
  /// @param permission the permission to hash
  /// @return the hash of the permission
  function computePermissionId(PermissionData calldata permission) external pure returns (bytes32) {
    return keccak256(abi.encode(permission));
  }

  /// @notice computes the address of a vertex core with a name value.
  /// @param name The name of this Vertex instance.
  /// @param vertexCoreLogic The VertexCore logic contract.
  /// @param factory The factory address.
  /// @return the computed address of the VertexCore contract.
  function computeVertexCoreAddress(string memory name, address vertexCoreLogic, address factory)
    external
    pure
    returns (VertexCore)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      vertexCoreLogic,
      keccak256(abi.encode(name)), // salt
      factory // deployer
    );
    return VertexCore(_computedAddress);
  }

  /// @notice computes the address of a vertex policy with a name value.
  /// @param name The name of this Vertex instance.
  /// @param vertexPolicyLogic The VertexPolicy logic contract.
  /// @param factory The factory address.
  /// @return the computed address of the VertexPolicy contract.
  function computeVertexPolicyAddress(string memory name, address vertexPolicyLogic, address factory)
    external
    pure
    returns (VertexPolicy)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      vertexPolicyLogic,
      keccak256(abi.encode(name)), // salt
      factory // deployer
    );
    return VertexPolicy(_computedAddress);
  }

  /// @notice computes the address of a vertex strategy with a strategy value.
  /// @param vertexStrategyLogic The Vertex Strategy logic contract.
  /// @param _strategy The strategy to be set.
  /// @param _vertexCore The vertex core to be set.
  /// @return the computed address of the VertexStrategy contract.
  function computeVertexStrategyAddress(address vertexStrategyLogic, Strategy memory _strategy, address _vertexCore)
    external
    pure
    returns (VertexStrategy)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      vertexStrategyLogic,
      keccak256(
        abi.encode(
          _strategy.approvalPeriod,
          _strategy.queuingPeriod,
          _strategy.expirationPeriod,
          _strategy.minApprovalPct,
          _strategy.minDisapprovalPct,
          _strategy.isFixedLengthApprovalPeriod
        )
      ), // salt
      _vertexCore // deployer
    );
    return VertexStrategy(_computedAddress);
  }

  /// @notice computes the address of a vertex account with a name (account) value.
  /// @param vertexAccountLogic The Vertex Account logic contract.
  /// @param _account The account to be set.
  /// @param _vertexCore The vertex core to be set.
  /// @return the computed address of the VertexAccount contract.
  function computeVertexAccountAddress(address vertexAccountLogic, string calldata _account, address _vertexCore)
    external
    pure
    returns (VertexAccount)
  {
    address _computedAddress = Clones.predictDeterministicAddress(
      vertexAccountLogic,
      keccak256(abi.encode(_account)), // salt
      _vertexCore // deployer
    );
    return VertexAccount(payable(_computedAddress));
  }
}
