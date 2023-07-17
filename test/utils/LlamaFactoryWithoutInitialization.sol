// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaPolicyMetadata} from "src/LlamaPolicyMetadata.sol";

/// @title Llama Factory
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Factory for deploying new Llama systems.
contract LlamaFactoryWithoutInitialization is LlamaFactory {
  constructor(
    LlamaCore _llamaCoreLogic,
    ILlamaStrategy initialLlamaStrategyLogic,
    ILlamaAccount initialLlamaAccountLogic,
    LlamaPolicy _llamaPolicyLogic,
    LlamaPolicyMetadata _llamaPolicyMetadata,
    string memory name,
    bytes[] memory initialStrategies,
    bytes[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions
  )
    LlamaFactory(
      _llamaCoreLogic,
      initialLlamaStrategyLogic,
      initialLlamaAccountLogic,
      _llamaPolicyLogic,
      _llamaPolicyMetadata,
      name,
      initialStrategies,
      initialAccounts,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions
    )
  {}

  /// @notice Deploys a new Llama system. This function can only be called by the initial Llama system.
  /// @param name The name of this Llama system.
  /// @param initialRoleDescriptions The list of initial role descriptions.
  /// @param initialRoleHolders The list of initial role holders and their role expirations.
  /// @param initialRolePermissions The list initial permissions given to roles.
  /// @return llama the address of the LlamaCore contract of the newly created system.
  function deployWithoutInitialization(
    string memory name,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions,
    string memory color,
    string memory logo
  ) external returns (LlamaCore llama, LlamaPolicy policy) {
    // Deploy the system.
    policy = LlamaPolicy(Clones.cloneDeterministic(address(LLAMA_POLICY_LOGIC), keccak256(abi.encode(name))));
    policy.initialize(
      name, initialRoleDescriptions, initialRoleHolders, initialRolePermissions, llamaPolicyMetadata, color, logo
    );

    llama = LlamaCore(Clones.cloneDeterministic(address(LLAMA_CORE_LOGIC), keccak256(abi.encode(name))));

    policy.finalizeInitialization(address(llama), bytes32(0));

    llamaCount = LlamaUtils.uncheckedIncrement(llamaCount);
  }

  function initialize(
    LlamaCore llama,
    LlamaPolicy policy,
    string memory name,
    ILlamaStrategy relativeQuorumLogic,
    ILlamaAccount accountLogic,
    bytes[] memory initialStrategies,
    bytes[] memory initialAccounts
  ) external returns (LlamaExecutor llamaExecutor) {
    llama.initialize(name, policy, relativeQuorumLogic, accountLogic, initialStrategies, initialAccounts);
    llamaExecutor = llama.executor();
  }
}
