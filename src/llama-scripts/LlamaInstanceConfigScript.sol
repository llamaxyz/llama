// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaBaseScript} from "src/llama-scripts/LlamaBaseScript.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {PermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

contract LlamaInstanceConfigScript is LlamaBaseScript {
  uint8 constant CONFIG_ROLE = 1;

  function _postConfigurationCleanup(
    address configPolicyHolder,
    LlamaCore core,
    ILlamaStrategy bootstrapStrategy,
    RoleDescription description
  ) internal {
    LlamaPolicy policy = core.policy();
    PermissionData memory authorizePermission =
      PermissionData(address(core), LlamaCore.setScriptAuthorization.selector, bootstrapStrategy);
    PermissionData memory executePermission =
      PermissionData(SELF, LlamaInstanceConfigScript.execute.selector, bootstrapStrategy);

    // Rename role #1 description
    policy.updateRoleDescription(CONFIG_ROLE, description);

    // Unauthorize configuration script
    core.setScriptAuthorization(SELF, false);

    // Remove configuration policyholder
    policy.revokePolicy(configPolicyHolder);

    // Unauthorize instant execution strategy
    core.setStrategyAuthorization(bootstrapStrategy, false);

    // Remove role #1 permissions to authorize and execute scripts
    policy.setRolePermission(CONFIG_ROLE, authorizePermission, false);
    policy.setRolePermission(CONFIG_ROLE, executePermission, false);
  }

  function execute(address configPolicyHolder, ILlamaStrategy bootstrapStrategy, RoleDescription description)
    external
    onlyDelegateCall
  {
    // Insert configuration code here

    _postConfigurationCleanup(configPolicyHolder, LlamaCore(msg.sender), bootstrapStrategy, description);
  }
}
