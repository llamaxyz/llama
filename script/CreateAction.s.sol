// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaPolicyMetadata} from "src/LlamaPolicyMetadata.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract CreateAction is Script {
  using stdJson for string;

  // The ID of the action created on the root Llama instance.
  uint256 deployActionId;

  // The data needed to for the Factory.deploy call
  bytes createActionCallData;

  LlamaPolicyMetadata policyMetadata;

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

    string memory color = jsonInput.readString(".newLlamaColor");
    string memory logo = jsonInput.readString(".newLlamaLogo");
    bytes memory metadataConfig = abi.encode(color, logo);

    createActionCallData = abi.encodeCall(
      LlamaFactory.deploy,
      (
        llamaInstanceName,
        ILlamaStrategy(jsonInput.readAddress(".strategyLogic")),
        ILlamaAccount(jsonInput.readAddress(".accountLogic")),
        DeployUtils.readRelativeStrategies(jsonInput),
        DeployUtils.readAccounts(jsonInput),
        DeployUtils.readRoleDescriptions(jsonInput),
        DeployUtils.readRoleHolders(jsonInput),
        DeployUtils.readRolePermissions(jsonInput),
        metadataConfig
      )
    );

    LlamaFactory factory = LlamaFactory(jsonInput.readAddress(".factory"));
    LlamaCore rootCore = factory.ROOT_LLAMA_CORE();
    string memory description =
      string.concat("# New Llama Deployment\n\n", "Deploy a Llama instance for ", llamaInstanceName, ".");

    vm.broadcast(deployer);
    deployActionId = rootCore.createAction(
      uint8(jsonInput.readUint(".rootLlamaActionCreatorRole")),
      ILlamaStrategy(jsonInput.readAddress(".rootLlamaActionCreationStrategy")),
      jsonInput.readAddress(".factory"),
      0, // No ETH needs to be sent to deploy a new core instance.
      createActionCallData,
      description
    );

    DeployUtils.print(string.concat("Created action ID", vm.toString(deployActionId)));
  }
}
