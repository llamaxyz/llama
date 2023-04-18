// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
// TODO rename JsonUtils??
import {DeployUtils} from "script/DeployUtils.sol";

contract CreateActionToDeployVertexInstance is Script {
  using stdJson for string;

  function run(address deployer) public {
    // TODO
    // * grant the ActionCreator role to an account we have keys to
    // * run this with an EOA that has the ActionCreator role
    string memory jsonInput = DeployUtils.readScriptInput("createActionToDeployVertexInstance.json");

    // TODO console.logs
    // TODO sort the input json

    bytes memory deployData = abi.encode(
      jsonInput.readString(".newVertexName"),
      uint8(jsonInput.readUint(".rootVertexActionCreatorRole")),
      jsonInput.readAddress(".strategyLogic"),
      jsonInput.readAddress(".accountLogic"),
      DeployUtils.readStrategies(jsonInput),
      jsonInput.readStringArray(".newAccountNames"),
      DeployUtils.readRoleDescriptions(jsonInput),
      DeployUtils.readRoleHolders(jsonInput),
      DeployUtils.readRolePermissions(jsonInput)
    );

    VertexFactory factory = VertexFactory(jsonInput.readAddress(".factory"));
    VertexCore rootVertex = factory.ROOT_VERTEX();

    vm.broadcast(deployer);
    rootVertex.createAction(
      uint8(jsonInput.readUint(".rootVertexActionCreatorRole")),
      VertexStrategy(jsonInput.readAddress(".rootVertexActionCreationStrategy")),
      jsonInput.readAddress(".factory"),
      0, // No ETH needs to be sent to deploy a new vertex instance.
      VertexFactory.deploy.selector,
      deployData
    );
  }
}
