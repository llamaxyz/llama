// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {VertexPolicyTokenURIParamRegistry} from "src/VertexPolicyTokenURIParamRegistry.sol";
import {DefaultStrategyConfig, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex instances.
contract VertexFactory {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error OnlyRootVertex();

  modifier onlyRootVertex() {
    if (msg.sender != address(ROOT_VERTEX)) revert OnlyRootVertex();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  /// @dev Emitted when a new Vertex instance is created.
  event VertexCreated(
    uint256 indexed id, string indexed name, address vertexCore, address vertexPolicyNFT, uint256 chainId
  );
  /// @dev Emitted when a new Strategy implementation (logic) contract is authorized to be used by Vertex Instances.
  event StrategyLogicAuthorized(IVertexStrategy indexed strategyLogic);
  /// @dev Emitted when a new Account implementation (logic) contract is authorized to be used by Vertex Instances.
  event AccountLogicAuthorized(VertexAccount indexed accountLogic);
  /// @dev Emitted when the Vertex Policy Token URI contract is updated.
  event PolicyTokenURIUpdated(VertexPolicyTokenURI indexed vertexPolicyTokenURI);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice The Vertex Core implementation (logic) contract.
  VertexCore public immutable VERTEX_CORE_LOGIC;

  /// @notice The Vertex Policy implementation (logic) contract.
  VertexPolicy public immutable VERTEX_POLICY_LOGIC;

  /// @notice Mapping of all authorized Vertex Strategy implementation (logic) contracts.
  mapping(IVertexStrategy => bool) public authorizedStrategyLogics;

  /// @notice Mapping of all authorized Vertex Account implementation (logic) contracts.
  mapping(VertexAccount => bool) public authorizedAccountLogics;

  /// @notice The Vertex instance responsible for governing the Vertex Factory.
  VertexCore public immutable ROOT_VERTEX;

  /// @notice The Vertex Policy Token URI contract.
  VertexPolicyTokenURI public vertexPolicyTokenURI;

  /// @notice The Vertex Policy Token URI Parameter Registry contract for onchain image formats.
  VertexPolicyTokenURIParamRegistry public immutable VERTEX_POLICY_TOKEN_URI_PARAM_REGISTRY;

  /// @notice The current number of Vertex instances created.
  uint256 public vertexCount;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor(
    VertexCore vertexCoreLogic,
    IVertexStrategy initialVertexStrategyLogic,
    VertexAccount initialVertexAccountLogic,
    VertexPolicy vertexPolicyLogic,
    VertexPolicyTokenURI _vertexPolicyTokenURI,
    string memory name,
    bytes[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) {
    VERTEX_CORE_LOGIC = vertexCoreLogic;
    VERTEX_POLICY_LOGIC = vertexPolicyLogic;

    _setPolicyTokenURI(_vertexPolicyTokenURI);
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

    VERTEX_POLICY_TOKEN_URI_PARAM_REGISTRY = new VertexPolicyTokenURIParamRegistry(ROOT_VERTEX);
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Deploys a new Vertex instance.
  /// @dev This function can only be called by the root Vertex instance.
  /// @param name The name of this Vertex instance.
  /// @param strategyLogic The IVertexStrategy implementation (logic) contract to use for this Vertex instance.
  /// @param accountLogic The VertexAccount implementation (logic) contract to use for this Vertex instance.
  /// @param initialStrategies The list of initial strategies.
  /// @param initialAccounts The list of initial accounts.
  /// @param initialRoleDescriptions The list of initial role descriptions.
  /// @param initialRoleHolders The list of initial role holders, their quantities and their role expirations.
  /// @param initialRolePermissions The list of initial permissions given to roles.
  /// @return The address of the Vertex Core of the newly created instances.
  function deploy(
    string memory name,
    IVertexStrategy strategyLogic,
    VertexAccount accountLogic,
    bytes[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
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

  /// @notice Authorizes a strategy implementation (logic) contract.
  /// @dev This function can only be called by the root Vertex instance.
  /// @param strategyLogic The strategy logic contract to authorize.
  function authorizeStrategyLogic(IVertexStrategy strategyLogic) external onlyRootVertex {
    _authorizeStrategyLogic(strategyLogic);
  }

  /// @notice Authorizes an account implementation (logic) contract.
  /// @dev This function can only be called by the root Vertex instance.
  /// @param accountLogic The account logic contract to authorize.
  function authorizeAccountLogic(VertexAccount accountLogic) external onlyRootVertex {
    _authorizeAccountLogic(accountLogic);
  }

  /// @notice Sets the Vertex Policy Token URI contract.
  /// @dev This function can only be called by the root Vertex instance.
  /// @param _vertexPolicyTokenURI The Vertex Policy Token URI contract.
  function setPolicyTokenURI(VertexPolicyTokenURI _vertexPolicyTokenURI) external onlyRootVertex {
    _setPolicyTokenURI(_vertexPolicyTokenURI);
  }

  /// @notice Returns the token URI for a given Vertex Policy Holder.
  /// @param name The name of the Vertex system.
  /// @param symbol The symbol of the Vertex system.
  /// @param tokenId The token ID of the Vertex Policy Holder.
  /// @return The token URI for the given Vertex Policy Holder.
  function tokenURI(VertexCore vertexCore, string memory name, string memory symbol, uint256 tokenId)
    external
    view
    returns (string memory)
  {
    (string memory color, string memory logo) = VERTEX_POLICY_TOKEN_URI_PARAM_REGISTRY.getMetadata(vertexCore);
    return vertexPolicyTokenURI.tokenURI(name, symbol, tokenId, color, logo);
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Deploys a new Vertex instance.
  function _deploy(
    string memory name,
    IVertexStrategy strategyLogic,
    VertexAccount accountLogic,
    bytes[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
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

    emit VertexCreated(vertexCount, name, address(vertex), address(policy), block.chainid);

    unchecked {
      ++vertexCount;
    }
  }

  /// @dev Authorizes a strategy implementation (logic) contract.
  function _authorizeStrategyLogic(IVertexStrategy strategyLogic) internal {
    authorizedStrategyLogics[strategyLogic] = true;
    emit StrategyLogicAuthorized(strategyLogic);
  }

  /// @dev Authorizes an account implementation (logic) contract.
  function _authorizeAccountLogic(VertexAccount accountLogic) internal {
    authorizedAccountLogics[accountLogic] = true;
    emit AccountLogicAuthorized(accountLogic);
  }

  /// @dev Sets the Vertex Policy Token URI contract.
  function _setPolicyTokenURI(VertexPolicyTokenURI _vertexPolicyTokenURI) internal {
    vertexPolicyTokenURI = _vertexPolicyTokenURI;
    emit PolicyTokenURIUpdated(_vertexPolicyTokenURI);
  }
}
