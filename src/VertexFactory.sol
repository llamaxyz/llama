// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
  error MissingAdmin();
  error OnlyVertex();

  event VertexCreated(uint256 indexed id, string indexed name, address vertexCore, address vertexPolicyNFT);
  event StrategyLogicAuthorized(address indexed strategyLogic);
  event AccountLogicAuthorized(address indexed accountLogic);

  /// @notice A special role to designate an Admin, who can always create actions.
  bytes32 public constant ADMIN_ROLE = "admin";

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
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) {
    vertexCoreLogic = _vertexCoreLogic;
    vertexPolicyLogic = _vertexPolicyLogic;
    vertexPolicyMetadata = _vertexPolicyMetadata;

    _authorizeStrategyLogic(initialVertexStrategyLogic);
    _authorizeAccountLogic(initialVertexAccountLogic);

    rootVertex = _deploy(
      name,
      initialVertexStrategyLogic,
      initialVertexAccountLogic,
      initialStrategies,
      initialAccounts,
      initialRoleHolders,
      initialRolePermissions
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
  /// @param initialRoleHolders The list of initial role holders and their role expirations.
  /// @param initialRolePermissions The list initial permissions given to roles.
  /// @return the address of the VertexCore contract of the newly created system.
  function deploy(
    string memory name,
    address strategyLogic,
    address accountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) external onlyRootVertex returns (VertexCore) {
    return _deploy(
      name, strategyLogic, accountLogic, initialStrategies, initialAccounts, initialRoleHolders, initialRolePermissions
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

  function _deploy(
    string memory name,
    address strategyLogic,
    address accountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) internal returns (VertexCore vertex) {
    // Verify that at least one user is an admin to avoid the system being locked.
    bool hasAdmin = false;
    for (uint256 i = 0; i < initialRoleHolders.length; i = _uncheckedIncrement(i)) {
      if (initialRoleHolders[i].role == ADMIN_ROLE && initialRoleHolders[i].expiration == type(uint64).max) {
        hasAdmin = true;
        break;
      }
    }
    if (!hasAdmin) revert MissingAdmin();

    // Deploy the system.
    VertexPolicy policy =
      VertexPolicy(Clones.cloneDeterministic(address(vertexPolicyLogic), keccak256(abi.encode(name))));
    policy.initialize(name, address(this), initialRoleHolders, initialRolePermissions);

    vertex = VertexCore(Clones.cloneDeterministic(address(vertexCoreLogic), keccak256(abi.encode(name))));
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

  function _uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }
}
