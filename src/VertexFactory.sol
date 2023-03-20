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
  event StrategyLogicAuthorized(address indexed strategyLogic);
  event AccountLogicAuthorized(address indexed accountLogic);

  /// @notice The VertexCore implementation (logic) contract.
  VertexCore public immutable VERTEX_CORE_LOGIC;

  /// @notice The Vertex Policy implementation (logic) contract.
  VertexPolicy public immutable VERTEX_POLICY_LOGIC;

  /// @notice Mapping of all authorized Vertex Strategy implementation (logic) contracts.
  mapping(address => bool) public authorizedStrategyLogics;

  /// @notice Mapping of all authorized Vertex Account implementation (logic) contracts.
  mapping(address => bool) public authorizedAccountLogics;

  /// @notice The Vertex instance responsible for deploying new Vertex instances.
  VertexCore public immutable ROOT_VERTEX;

  VertexPolicyMetadata public vertexPolicyMetadata;

  /// @notice The current number of vertex systems created.
  uint256 public vertexCount;

  constructor(
    VertexCore _vertexCoreLogic,
    address initialVertexStrategyLogic,
    address initialVertexAccountLogic,
    VertexPolicy _vertexPolicyLogic,
    VertexPolicyMetadata _vertexPolicyMetadata,
    string memory name,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    PolicyGrantData[] memory initialPolicies
  ) {
    VERTEX_CORE_LOGIC = _vertexCoreLogic;
    VERTEX_POLICY_LOGIC = _vertexPolicyLogic;
    vertexPolicyMetadata = _vertexPolicyMetadata;

    _authorizeStrategyLogic(initialVertexStrategyLogic);
    _authorizeAccountLogic(initialVertexAccountLogic);

    ROOT_VERTEX = _deploy(
      name, initialVertexStrategyLogic, initialVertexAccountLogic, initialStrategies, initialAccounts, initialPolicies
    );
  }

  modifier onlyRootVertex() {
    if (msg.sender != address(ROOT_VERTEX)) revert OnlyVertex();
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
      VertexPolicy(Clones.cloneDeterministic(address(VERTEX_POLICY_LOGIC), keccak256(abi.encode(name))));
    policy.initialize(name, initialPolicies, address(this));
    vertex = VertexCore(Clones.cloneDeterministic(address(VERTEX_CORE_LOGIC), keccak256(abi.encode(name))));
    vertex.initialize(name, policy, strategyLogic, accountLogic, initialStrategies, initialAccounts);

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

  function _authorizeStrategyLogic(address strategyLogic) internal {
    authorizedStrategyLogics[strategyLogic] = true;
    emit StrategyLogicAuthorized(strategyLogic);
  }

  function _authorizeAccountLogic(address accountLogic) internal {
    authorizedAccountLogics[accountLogic] = true;
    emit AccountLogicAuthorized(accountLogic);
  }
}
