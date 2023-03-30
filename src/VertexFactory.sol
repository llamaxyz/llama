// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicyMetadata} from "src/VertexPolicyMetadata.sol";
import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";

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

  /// @notice The Vertex Policy Metadata contract.
  VertexPolicyMetadata public vertexPolicyMetadata;

  /// @notice The current number of vertex systems created.
  uint256 public vertexCount;

  constructor(
    VertexCore vertexCoreLogic,
    address initialVertexStrategyLogic,
    address initialVertexAccountLogic,
    VertexPolicy vertexPolicyLogic,
    VertexPolicyMetadata _vertexPolicyMetadata,
    string memory name,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    string[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) {
    VERTEX_CORE_LOGIC = vertexCoreLogic;
    VERTEX_POLICY_LOGIC = vertexPolicyLogic;
    vertexPolicyMetadata = _vertexPolicyMetadata;

    _authorizeStrategyLogic(initialVertexStrategyLogic);
    _authorizeAccountLogic(initialVertexAccountLogic);

    ROOT_VERTEX = _deploy(
      name,
      initialVertexStrategyLogic,
      initialVertexAccountLogic,
      initialStrategies,
      initialAccounts,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions
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
  /// @param initialRoleDescriptions The list of initial role descriptions.
  /// @param initialRoleHolders The list of initial role holders and their role expirations.
  /// @param initialRolePermissions The list initial permissions given to roles.
  /// @return the address of the VertexCore contract of the newly created system.
  function deploy(
    string memory name,
    address strategyLogic,
    address accountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    string[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) external onlyRootVertex returns (VertexCore) {
    return _deploy(
      name,
      strategyLogic,
      accountLogic,
      initialStrategies,
      initialAccounts,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions
    );
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

  /// @notice Returns the token URI for a given Vertex Policy Holder.
  /// @param name The name of the Vertex system.
  /// @param symbol The symbol of the Vertex system.
  /// @param tokenId The token ID of the Vertex Policy Holder.
  function tokenURI(string memory name, string memory symbol, uint256 tokenId) external view returns (string memory) {
    return vertexPolicyMetadata.tokenURI(name, symbol, tokenId);
  }

  /// @notice Sets the Vertex Policy Metadata contract.
  /// @param _vertexPolicyMetadata The Vertex Policy Metadata contract.
  function setPolicyMetadata(VertexPolicyMetadata _vertexPolicyMetadata) public onlyRootVertex {
    vertexPolicyMetadata = _vertexPolicyMetadata;
  }

  function _deploy(
    string memory name,
    address strategyLogic,
    address accountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    string[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) internal returns (VertexCore vertex) {
    // Deploy the system.
    VertexPolicy policy =
      VertexPolicy(Clones.cloneDeterministic(address(VERTEX_POLICY_LOGIC), keccak256(abi.encode(name))));
    policy.initialize(name, initialRoleDescriptions, initialRoleHolders, initialRolePermissions);

    vertex = VertexCore(Clones.cloneDeterministic(address(VERTEX_CORE_LOGIC), keccak256(abi.encode(name))));
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
