// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {LlamaCoreInitializationConfig, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
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
  LlamaCore public lastDeployedLlamaCore;

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
  ) LlamaFactory(_llamaCoreLogic, _llamaPolicyLogic, _llamaPolicyMetadata) {}

  /// @notice Deploys a new Llama system. This function can only be called by the initial Llama system.
  /// @param name The name of this Llama system.
  /// @return llama the address of the LlamaCore contract of the newly created system.
  function deployWithoutInitialization(string memory name) external returns (LlamaCore llama) {
    llama = LlamaCore(Clones.cloneDeterministic(address(LLAMA_CORE_LOGIC), keccak256(abi.encode(name, msg.sender))));
    lastDeployedLlamaCore = llama;
    llamaCount = LlamaUtils.uncheckedIncrement(llamaCount);
  }

  function initialize(
    string memory name,
    ILlamaStrategy relativeQuorumLogic,
    ILlamaAccount accountLogic,
    bytes[] memory initialStrategies,
    bytes[] memory initialAccounts,
    RoleDescription[] memory initialRoleDescriptions,
    RoleHolderData[] memory initialRoleHolders,
    RolePermissionData[] memory initialRolePermissions,
    LlamaPolicyMetadata _llamaPolicyMetadata,
    string memory color,
    string memory logo
  ) external {
    LlamaCoreInitializationConfig memory config = LlamaCoreInitializationConfig(
      name,
      LLAMA_POLICY_LOGIC,
      relativeQuorumLogic,
      accountLogic,
      initialStrategies,
      initialAccounts,
      initialRoleDescriptions,
      initialRoleHolders,
      initialRolePermissions,
      _llamaPolicyMetadata,
      color,
      logo,
      msg.sender
    );

    lastDeployedLlamaCore.initialize(config);
  }
}
