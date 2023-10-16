// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaBaseScript} from "src/llama-scripts/LlamaBaseScript.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

abstract contract LlamaInstanceConfigScript is LlamaBaseScript {
  uint8 constant CONFIG_ROLE = 1;
  /// @dev Address of the executor contract. We save it off in order to access the setScriptAuthorization method in
  /// `LlamaCore`.
  LlamaExecutor internal immutable EXECUTOR;

  LlamaPolicy immutable policy;
  LlamaCore immutable core;

  /// @dev Add this to your script's methods to unauthorize itself after it has been run once. Any subsequent calls will
  /// fail unless the script is reauthorized. Best if used in tandem with the `onlyDelegateCall` from `BaseScript.sol`.
  modifier removeConfigAccess(
    address configPolicyHolder,
    ILlamaStrategy bootstrapStrategy,
    RoleDescription description
  ) {
    // Rename role 1 description
    policy.updateRoleDescription(CONFIG_ROLE, description);
    _;
    core.setScriptAuthorization(SELF, false);
    policy.revokePolicy(configPolicyHolder);
    core.setStrategyAuthorization(bootstrapStrategy, false);
  }

  constructor(LlamaExecutor executor) {
    EXECUTOR = executor;
    core = LlamaCore(EXECUTOR.LLAMA_CORE());
    policy = core.policy();
  }

  function execute(address configPolicyHolder, ILlamaStrategy bootstrapStrategy, RoleDescription description)
    external
    onlyDelegateCall
    removeConfigAccess(configPolicyHolder, bootstrapStrategy, description)
  {}
}
