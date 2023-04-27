// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract CreateAction is Script {
  using stdJson for string;

  // The ID of the action created on the root vertex.
  uint256 deployActionId;

  // The data needed to for the Factory.deploy call
  bytes createActionCallData;

  function run(address deployer) public {
    string memory jsonInput = DeployUtils.readScriptInput("createAction.json");

    createActionCallData = abi.encodeCall(
      LlamaFactory.deploy,
      (
        jsonInput.readString(".newLlamaName"),
        ILlamaStrategy(jsonInput.readAddress(".strategyLogic")),
        DeployUtils.readRelativeStrategies(jsonInput),
        jsonInput.readStringArray(".newAccountNames"),
        DeployUtils.readRoleDescriptions(jsonInput),
        DeployUtils.readRoleHolders(jsonInput),
        DeployUtils.readRolePermissions(jsonInput)
      )
    );

    LlamaFactory factory = LlamaFactory(jsonInput.readAddress(".factory"));
    LlamaCore rootCore = factory.ROOT_LLAMA();

    vm.broadcast(deployer);
    deployActionId = rootCore.createAction(
      uint8(jsonInput.readUint(".rootLlamaActionCreatorRole")),
      ILlamaStrategy(jsonInput.readAddress(".rootLlamaActionCreationStrategy")),
      jsonInput.readAddress(".factory"),
      0, // No ETH needs to be sent to deploy a new core instance.
      createActionCallData
    );

    if (block.chainid != 31_337) console2.log("Created action ID", deployActionId);
  }
}
