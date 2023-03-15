// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, PolicyGrantData, PermissionData} from "src/lib/Structs.sol";

interface IVertexLens {
  /// @notice hashes a permission
  /// @param permission the permission to hash
  /// @return the hash of the permission
  function computePermissionId(PermissionData calldata permission) external pure returns (bytes32);

  /// @notice computes the address of a vertex core with a name value.
  /// @param name The name of this Vertex instance.
  /// @param vertexCoreLogic The VertexCore logic contract.
  /// @param factory The factory address.
  /// @return the computed address of the VertexCore contract.
  function computeVertexCoreAddress(string memory name, address vertexCoreLogic, address factory)
    external
    pure
    returns (VertexCore);

  /// @notice computes the address of a vertex policy with a name value.
  /// @param name The name of this Vertex instance.
  /// @param vertexPolicyLogic The VertexPolicy logic contract.
  /// @param factory The factory address.
  /// @return the computed address of the VertexPolicy contract.
  function computeVertexPolicyAddress(string memory name, address vertexPolicyLogic, address factory)
    external
    pure
    returns (VertexPolicy);

  /// @notice computes the address of a vertex strategy with a strategy value.
  /// @param vertexStrategyLogic The Vertex Strategy logic contract.
  /// @param _strategy The strategy to be set.
  /// @param _vertexCore The vertex core to be set.
  /// @return the computed address of the VertexStrategy contract.
  function computeVertexStrategyAddress(address vertexStrategyLogic, Strategy memory _strategy, address _vertexCore)
    external
    pure
    returns (VertexStrategy);

  /// @notice computes the address of a vertex account with a name (account) value.
  /// @param accountLogic The VertexAccount logic contract.
  /// @param _account The account to be set.
  /// @param _vertexCore The vertex core to be set.
  /// @return the computed address of the VertexAccount contract.
  function computeVertexAccountAddress(address accountLogic, string calldata _account, address _vertexCore)
    external
    pure
    returns (VertexAccount);
}
