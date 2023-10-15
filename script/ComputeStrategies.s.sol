// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson} from "forge-std/Script.sol";

import {LlamaLens} from "src/LlamaLens.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract ComputeStrategies is Script {
  using stdJson for string;

  error InvalidStrategyType();

  // The core of the deployed Llama instance.
  address core;

  function run(address deployer, LlamaLens lens, string memory configFile, string memory strategyType) public {
    if (
      keccak256(abi.encode(strategyType)) != keccak256(abi.encode("absolute"))
        && keccak256(abi.encode(strategyType)) != keccak256(abi.encode("relative"))
    ) revert InvalidStrategyType();

    string memory jsonInput = DeployUtils.readScriptInput(configFile);
    string memory llamaInstanceName = jsonInput.readString(".instanceName");
    address strategyLogic = address(jsonInput.readAddress(".strategyLogic"));
    core = address(lens.computeLlamaCoreAddress(llamaInstanceName, deployer));

    bytes[] memory encodedStrategies = DeployUtils.readStrategies(jsonInput, strategyType);

    for (uint256 i = 0; i < encodedStrategies.length; i++) {
      address strategy = address(lens.computeLlamaStrategyAddress(strategyLogic, encodedStrategies[i], core));
      DeployUtils.print(string.concat("  Strategy #", vm.toString(i + 1), ":     ", vm.toString(strategy)));
    }
  }
}
