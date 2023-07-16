// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract DeployLlamaInstance is Script {
  using stdJson for string;

  // The core of the deployed Llama instance.
  LlamaCore core;

  function run(address deployer) public {
    // ======== START SAFETY CHECK ========
    // Before deploying the factory, we ensure the bootstrap strategy is configured properly to
    // ensure it can be used to pass actions.
    // NOTE: This check currently only supports relative strategies.
    string memory filename = "createAction.json";
    DeployUtils.bootstrapSafetyCheck(filename);
    // ======== END SAFETY CHECK ========

    string memory jsonInput = DeployUtils.readScriptInput(filename);
    string memory llamaInstanceName = jsonInput.readString(".newLlamaName");

    LlamaFactory factory = LlamaFactory(jsonInput.readAddress(".factory"));

    vm.broadcast(deployer);
    core = factory.deploy(
      llamaInstanceName,
      ILlamaStrategy(jsonInput.readAddress(".strategyLogic")),
      ILlamaAccount(jsonInput.readAddress(".accountLogic")),
      DeployUtils.readRelativeStrategies(jsonInput),
      DeployUtils.readAccounts(jsonInput),
      DeployUtils.readRoleDescriptions(jsonInput),
      DeployUtils.readRoleHolders(jsonInput),
      DeployUtils.readRolePermissions(jsonInput),
      jsonInput.readString(".newLlamaColor"),
      jsonInput.readString(".newLlamaLogo")
    );

    DeployUtils.print(string.concat("Deploy Llama Instance core:", vm.toString(address(core))));
  }
}
