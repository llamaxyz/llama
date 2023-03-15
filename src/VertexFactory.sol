// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {IVertexFactory} from "src/interfaces/IVertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, PolicyGrantData} from "src/lib/Structs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory is IVertexFactory {
  /// @notice The VertexCore implementation (logic) contract.
  VertexCore public immutable vertexCoreLogic;

  /// @notice The Vertex Policy implementation (logic) contract.
  VertexPolicy public immutable vertexPolicyLogic;

  /// @notice Mapping of all authorized Vertex Strategy implementation (logic) contracts.
  mapping(address => bool) public authorizedStrategyLogics;

  /// @notice Mapping of all authorized Vertex Account implementation (logic) contracts.
  mapping(address => bool) public authorizedAccountLogics;

  /// @notice The Vertex instance responsible for deploying new Vertex instances.
  VertexCore public immutable rootVertex;

  /// @notice The current number of vertex systems created.
  uint256 public vertexCount;

  constructor(
    VertexCore _vertexCoreLogic,
    address initialVertexStrategyLogic,
    address initialVertexAccountLogic,
    VertexPolicy _vertexPolicyLogic,
    string memory name,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) {
    vertexCoreLogic = _vertexCoreLogic;
    vertexPolicyLogic = _vertexPolicyLogic;
    authorizedStrategyLogics[initialVertexStrategyLogic] = true;
    authorizedAccountLogics[initialVertexAccountLogic] = true;

    rootVertex = _deploy(
      name, initialVertexStrategyLogic, initialVertexAccountLogic, initialStrategies, initialAccounts, initialPolicies
    );
  }

  modifier onlyRootVertex() {
    if (msg.sender != address(rootVertex)) revert OnlyVertex();
    _;
  }

  /// @inheritdoc IVertexFactory
  function deploy(
    string memory name,
    address strategyLogic,
    address accountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) external override onlyRootVertex returns (VertexCore) {
    return _deploy(name, strategyLogic, accountLogic, initialStrategies, initialAccounts, initialPolicies);
  }

  /// @inheritdoc IVertexFactory
  function authorizeStrategyLogic(address strategyLogic) external override onlyRootVertex {
    authorizedStrategyLogics[strategyLogic] = true;
    emit StrategyLogicAuthorized(strategyLogic);
  }

  /// @inheritdoc IVertexFactory
  function unauthorizeStrategyLogic(address strategyLogic) external override onlyRootVertex {
    delete authorizedStrategyLogics[strategyLogic];
    emit StrategyLogicUnauthorized(strategyLogic);
  }

  /// @inheritdoc IVertexFactory
  function authorizeAccountLogic(address accountLogic) external override onlyRootVertex {
    authorizedAccountLogics[accountLogic] = true;
    emit AccountLogicAuthorized(accountLogic);
  }

  /// @inheritdoc IVertexFactory
  function unauthorizeAccountLogic(address accountLogic) external override onlyRootVertex {
    delete authorizedAccountLogics[accountLogic];
    emit AccountLogicUnauthorized(accountLogic);
  }

  function _deploy(
    string memory name,
    address vertexStrategyLogic,
    address vertexAccountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) internal returns (VertexCore vertex) {
    if (!authorizedStrategyLogics[vertexStrategyLogic]) revert UnauthorizedStrategyLogic();
    if (!authorizedAccountLogics[vertexAccountLogic]) revert UnauthorizedAccountLogic();

    VertexPolicy policy =
      VertexPolicy(Clones.cloneDeterministic(address(vertexPolicyLogic), keccak256(abi.encode(name))));
    policy.initialize(name, initialPolicies);

    vertex = VertexCore(Clones.cloneDeterministic(address(vertexCoreLogic), keccak256(abi.encode(name))));
    vertex.initialize(
      name,
      IVertexFactory(address(this)),
      policy,
      vertexStrategyLogic,
      vertexAccountLogic,
      initialStrategies,
      initialAccounts
    );

    policy.setVertex(address(vertex));

    unchecked {
      emit VertexCreated(vertexCount++, name, address(vertex), address(policy));
    }
  }
}
