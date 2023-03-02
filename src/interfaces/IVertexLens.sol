// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {IVertexFactory} from "src/interfaces/IVertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, PolicyGrantData, PermissionData} from "src/lib/Structs.sol";
import {IVertexCore} from "src/interfaces/IVertexCore.sol";

interface IVertexLens {
  /// @notice hashes a permission
  /// @param permission the permission to hash
  function hashPermission(PermissionData calldata permission) external pure returns (bytes8);
  /// @notice computes the address of a vertex core with a name value.
  /// @param name The name of this Vertex instance.
  /// @param vertexCoreLogic The VertexCore logic contract.
  /// @param factory The factory address.
  /// @return the computed address of the VertexCore contract.

  function computeVertexCoreAddress(string memory name, address vertexCoreLogic, address factory)
    external
    pure
    returns (VertexCore);

  /// @notice computes the address of a vertex policy with a name and symbol value.
  /// @param _name The name of this Vertex instance.
  /// @param _symbol The symbol of this Vertex instance.
  /// @param _initialPolicies The initial policies to be set.
  /// @param factory The factory address.
  /// @return the computed address of the VertexPolicy contract.
  function computeVertexPolicyAddress(
    string memory _name,
    string memory _symbol,
    PolicyGrantData[] memory _initialPolicies,
    address factory
  ) external view returns (VertexPolicy);

  /// @notice computes the address of a vertex strategy with a strategy value.
  /// @param _strategy The strategy to be set.
  /// @param _policy The policy to be set.
  /// @param _vertex The vertex to be set.
  /// @return the computed address of the VertexStrategy contract.
  function computeVertexStrategyAddress(Strategy memory _strategy, VertexPolicy _policy, VertexCore _vertex)
    external
    pure
    returns (VertexStrategy);
}
