// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicyMetadata} from "src/VertexPolicyMetadata.sol";
import {Strategy, PolicyGrantData} from "src/lib/Structs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory {
  error OnlyVertex();

  event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicyNFT);

  /// @notice The VertexCore implementation (logic) contract.
  VertexCore public immutable vertexCoreLogic;

  /// @notice The Vertex Strategy implementation (logic) contract.
  VertexStrategy public immutable vertexStrategyLogic;

  /// @notice The Vertex Account implementation (logic) contract.
  VertexAccount public immutable vertexAccountLogic;

  /// @notice The Vertex Policy implementation (logic) contract.
  VertexPolicy public immutable vertexPolicyLogic;

  /// @notice The Vertex instance responsible for deploying new Vertex instances.
  VertexCore public immutable rootVertex;

  VertexPolicyMetadata public vertexPolicyMetadata;

  /// @notice The current number of vertex systems created.
  uint256 public vertexCount;

  constructor(
    VertexCore _vertexCoreLogic,
    VertexStrategy _vertexStrategyLogic,
    VertexAccount _vertexAccountLogic,
    VertexPolicy _vertexPolicyLogic,
    VertexPolicyMetadata _vertexPolicyMetadata,
    string memory name,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) {
    vertexCoreLogic = _vertexCoreLogic;
    vertexStrategyLogic = _vertexStrategyLogic;
    vertexAccountLogic = _vertexAccountLogic;
    vertexPolicyLogic = _vertexPolicyLogic;
    vertexPolicyMetadata = _vertexPolicyMetadata;
    rootVertex = _deploy(name, initialStrategies, initialAccounts, initialPolicies);
  }

  modifier onlyRootVertex() {
    if (msg.sender != address(rootVertex)) revert OnlyVertex();
    _;
  }

  /// @notice Deploys a new Vertex system. This function can only be called by the initial Vertex system.
  /// @param name The name of this Vertex system.
  /// @param initialStrategies The list of initial strategies.
  /// @param initialAccounts The list of initial accounts.
  /// @param initialPolicies The list of initial policies.
  /// @return the address of the VertexCore contract of the newly created system.
  function deploy(
    string memory name,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) external onlyRootVertex returns (VertexCore) {
    return _deploy(name, initialStrategies, initialAccounts, initialPolicies);
  }

  function _deploy(
    string memory name,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) internal returns (VertexCore vertex) {
    VertexPolicy policy =
      VertexPolicy(Clones.cloneDeterministic(address(vertexPolicyLogic), keccak256(abi.encode(name))));
    policy.initialize(name, initialPolicies, address(this));
    vertex = VertexCore(Clones.cloneDeterministic(address(vertexCoreLogic), keccak256(abi.encode(name))));
    vertex.initialize(name, policy, vertexStrategyLogic, vertexAccountLogic, initialStrategies, initialAccounts);

    policy.setVertex(address(vertex));
    unchecked {
      emit VertexCreated(vertexCount++, name, address(vertex), address(policy));
    }
  }

  function tokenURI(string memory _name, string memory symbol, uint256 tokenId) external view returns (string memory) {
    return vertexPolicyMetadata.tokenURI(_name, symbol, tokenId);
  }

  function setPolicyMetadata(VertexPolicyMetadata _vertexPolicyMetadata) public onlyRootVertex {
    vertexPolicyMetadata = _vertexPolicyMetadata;
  }
}
