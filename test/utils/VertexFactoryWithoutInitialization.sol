// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

/// @title Vertex Factory
/// @author Llama (vertex@llama.xyz)
/// @notice Factory for deploying new Vertex systems.
contract VertexFactoryWithoutInitialization is VertexFactory {
  constructor(
    VertexCore _vertexCoreLogic,
    VertexStrategy initialVertexStrategyLogic,
    VertexAccount initialVertexAccountLogic,
    VertexPolicy _vertexPolicyLogic,
    VertexPolicyTokenURI _vertexPolicyTokenUri,
    string memory name,
    bytes[] memory initialStrategies,
    string[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  )
    VertexFactory(
      _vertexCoreLogic,
      initialVertexStrategyLogic,
      initialVertexAccountLogic,
      _vertexPolicyLogic,
      _vertexPolicyTokenUri,
      name,
      initialStrategies,
      initialAccounts,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions
    )
  {}

  /// @notice Deploys a new Vertex system. This function can only be called by the initial Vertex system.
  /// @param name The name of this Vertex system.
  /// @param initialRoleDescriptions The list of initial role descriptions.
  /// @param initialRoleHolders The list of initial role holders and their role expirations.
  /// @param initialRolePermissions The list initial permissions given to roles.
  /// @return vertex the address of the VertexCore contract of the newly created system.
  function deployWithoutInitialization(
    string memory name,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  ) external returns (VertexCore vertex, VertexPolicy policy) {
    // Deploy the system.
    policy = VertexPolicy(Clones.cloneDeterministic(address(VERTEX_POLICY_LOGIC), keccak256(abi.encode(name))));
    policy.initialize(name, initialRoleDescriptions, initialRoleHolders, initialRolePermissions);

    vertex = VertexCore(Clones.cloneDeterministic(address(VERTEX_CORE_LOGIC), keccak256(abi.encode(name))));
    policy.setVertex(address(vertex));

    unchecked {
      emit VertexCreated(vertexCount++, name, address(vertex), address(policy));
    }
  }

  function initialize(
    VertexCore vertex,
    VertexPolicy policy,
    string memory name,
    VertexStrategy strategyLogic,
    VertexAccount accountLogic,
    bytes[] memory initialStrategies,
    string[] memory initialAccounts
  ) external {
    vertex.initialize(name, policy, strategyLogic, accountLogic, initialStrategies, initialAccounts);
  }
}
