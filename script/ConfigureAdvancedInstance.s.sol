// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson} from "forge-std/Script.sol";

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaInstanceConfigScript} from "src/llama-scripts/LlamaInstanceConfigScript.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract ConfigureAdvancedInstance is Script {
  LlamaInstanceConfigScript configurationScript;

  function run(address deployer, LlamaCore core) public {
    vm.broadcast();
    configurationScript = new LlamaInstanceConfigScript();
    DeployUtils.print(string.concat("  LlamaInstanceConfigScript:", vm.toString(address(configurationScript))));

    // CQE action to authorize script
    // CQE to execute script
    // At beginning call:
    // updateRoleDescription(1, "New role 1 name");
    // setRolePermission(1, bootstrapPermission, false); optional
    // At the end script call:
    // revokePolicy(bot);
    // unauth script
    // setStrategyLogicAuthorization(relative, false); optional
    // setStrategyAuthorization(instance, false); optional
  }
}
