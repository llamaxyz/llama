// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {IVertexFactory} from "src/interfaces/IVertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {Strategy, PolicyGrantData} from "src/lib/Structs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory is IVertexFactory {
  error OnlyVertex();

  /// @notice The VertexCore implementation (logic) contract.
  VertexCore public immutable vertexCoreLogic;

  /// @notice The Vertex Account implementation (logic) contract.
  VertexAccount public immutable vertexAccountLogic;

  /// @notice The Vertex instance responsible for deploying new Vertex instances.
  VertexCore public immutable rootVertex;

  /// @notice The current number of vertex systems created.
  uint256 public vertexCount;

  constructor(
    VertexCore _vertexCoreLogic,
    VertexAccount _vertexAccountLogic,
    string memory name,
    string memory symbol,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) {
    vertexCoreLogic = _vertexCoreLogic;
    vertexAccountLogic = _vertexAccountLogic;
    rootVertex = _deploy(name, symbol, initialStrategies, initialAccounts, initialPolicies);
  }

  modifier onlyRootVertex() {
    if (msg.sender != address(rootVertex)) revert OnlyVertex();
    _;
  }

  function deploy(
    string memory name,
    string memory symbol,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) external onlyRootVertex returns (VertexCore) {
    return _deploy(name, symbol, initialStrategies, initialAccounts, initialPolicies);
  }

  function _deploy(
    string memory name,
    string memory symbol,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) internal returns (VertexCore vertex) {
    bytes32 salt = bytes32(keccak256(abi.encode(name, symbol)));
    VertexPolicy policy = new VertexPolicy{salt: salt}(name, symbol, initialPolicies);

    vertex = VertexCore(Clones.clone(address(vertexCoreLogic)));
    vertex.initialize(name, policy, vertexAccountLogic, initialStrategies, initialAccounts);

    policy.setVertex(address(vertex));
    unchecked {
      emit VertexCreated(vertexCount++, name, address(vertex), address(policy));
    }
  }
}
