// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, PolicyGrantData} from "src/lib/Structs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactory {
  error OnlyVertex();

  event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicyNFT);
  event StrategyLogicAuthorized(address indexed strategyLogic);
  event AccountLogicAuthorized(address indexed accountLogic);

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
    _authorizeStrategyLogic(initialVertexStrategyLogic);
    _authorizeAccountLogic(initialVertexAccountLogic);

    rootVertex = _deploy(
      name, initialVertexStrategyLogic, initialVertexAccountLogic, initialStrategies, initialAccounts, initialPolicies
    );
  }

  modifier onlyRootVertex() {
    if (msg.sender != address(rootVertex)) revert OnlyVertex();
    _;
  }

  /// @notice Deploys a new Vertex system. This function can only be called by the initial Vertex system.
  /// @param name The name of this Vertex system.
  /// @param strategyLogic The VertexStrategy implementation (logic) contract to use for this Vertex system.
  /// @param accountLogic The VertexAccount implementation (logic) contract to use for this Vertex system.
  /// @param initialStrategies The list of initial strategies.
  /// @param initialAccounts The list of initial accounts.
  /// @param initialPolicies The list of initial policies.
  /// @return the address of the VertexCore contract of the newly created system.
  function deploy(
    string memory name,
    address strategyLogic,
    address accountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) external onlyRootVertex returns (VertexCore) {
    return _deploy(name, strategyLogic, accountLogic, initialStrategies, initialAccounts, initialPolicies);
  }

  /// @notice Authorizes a strategy logic contract.
  /// @param strategyLogic The strategy logic contract to authorize.
  function authorizeStrategyLogic(address strategyLogic) external onlyRootVertex {
    _authorizeStrategyLogic(strategyLogic);
  }

  /// @notice Authorizes an account logic contract.
  /// @param accountLogic The account logic contract to authorize.
  function authorizeAccountLogic(address accountLogic) external onlyRootVertex {
    _authorizeAccountLogic(accountLogic);
  }

  function _deploy(
    string memory name,
    address strategyLogic,
    address accountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) internal returns (VertexCore vertex) {
    VertexPolicy policy =
      VertexPolicy(Clones.cloneDeterministic(address(vertexPolicyLogic), keccak256(abi.encode(name))));
    policy.initialize(name, initialPolicies);

    vertex = VertexCore(Clones.cloneDeterministic(address(vertexCoreLogic), keccak256(abi.encode(name))));
    vertex.initialize(name, policy, strategyLogic, accountLogic, initialStrategies, initialAccounts);

    policy.setVertex(address(vertex));

    unchecked {
      emit VertexCreated(vertexCount++, name, address(vertex), address(policy));
    }
  }

  function _authorizeStrategyLogic(address strategyLogic) internal {
    authorizedStrategyLogics[strategyLogic] = true;
    emit StrategyLogicAuthorized(strategyLogic);
  }

  function _authorizeAccountLogic(address accountLogic) internal {
    authorizedAccountLogics[accountLogic] = true;
    emit AccountLogicAuthorized(accountLogic);
  }
}
