// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaLens} from "src/LlamaLens.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaPolicyTokenURI} from "src/LlamaPolicyTokenURI.sol";
import {LlamaPolicyTokenURIParamRegistry} from "src/LlamaPolicyTokenURIParamRegistry.sol";
import {AbsoluteStrategy} from "src/strategies/AbsoluteStrategy.sol";
import {RelativeStrategy} from "src/strategies/RelativeStrategy.sol";
import {AbsoluteStrategyConfig, RelativeStrategyConfig, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract DeployLlama is Script {
  using stdJson for string;

  // Logic contracts.
  LlamaCore coreLogic;
  RelativeStrategy relativeStrategyLogic;
  AbsoluteStrategy absoluteStrategyLogic;
  LlamaAccount accountLogic;
  LlamaPolicy policyLogic;

  // Core Protocol.
  LlamaFactory factory;
  LlamaPolicyTokenURI policyTokenURI;
  LlamaPolicyTokenURIParamRegistry policyTokenURIParamRegistry;
  LlamaLens lens;

  function run() public {
    print(string.concat("Deploying Llama framework to chain:", vm.toString(block.chainid)));

    vm.broadcast();
    coreLogic = new LlamaCore();
    print(string.concat("  LlamaCoreLogic:", vm.toString(address(coreLogic))));

    vm.broadcast();
    relativeStrategyLogic = new RelativeStrategy();
    print(string.concat("  LlamaRelativeStrategyLogic:", vm.toString(address(relativeStrategyLogic))));

    vm.broadcast();
    absoluteStrategyLogic = new AbsoluteStrategy();
    print(string.concat("  LlamaAbsoluteStrategyLogic:", vm.toString(address(absoluteStrategyLogic))));

    vm.broadcast();
    accountLogic = new LlamaAccount();
    print(string.concat("  LlamaAccountLogic:", vm.toString(address(accountLogic))));

    vm.broadcast();
    policyLogic = new LlamaPolicy();
    print(string.concat("  LlamaPolicyLogic:", vm.toString(address(policyLogic))));

    vm.broadcast();
    policyTokenURI = new LlamaPolicyTokenURI();
    print(string.concat("  LlamaPolicyTokenURI:", vm.toString(address(policyTokenURI))));

    string memory jsonInput = DeployUtils.readScriptInput("deployLlama.json");

    vm.broadcast();
    factory = new LlamaFactory(
      coreLogic,
      relativeStrategyLogic,
      accountLogic,
      policyLogic,
      policyTokenURI,
      jsonInput.readString(".rootLlamaName"),
      DeployUtils.readRelativeStrategies(jsonInput),
      jsonInput.readStringArray(".initialAccountNames"),
      DeployUtils.readRoleDescriptions(jsonInput),
      DeployUtils.readRoleHolders(jsonInput),
      DeployUtils.readRolePermissions(jsonInput)
    );
    print(string.concat("  LlamaFactory:", vm.toString(address(factory))));

    policyTokenURIParamRegistry = factory.LLAMA_POLICY_TOKEN_URI_PARAM_REGISTRY();
    print(string.concat("  LlamaPolicyTokenURIParamRegistry:", vm.toString(address(policyTokenURIParamRegistry))));

    vm.broadcast();
    lens = new LlamaLens();
    print(string.concat("  LlamaLens:", vm.toString(address(lens))));
  }

  function print(string memory message) internal view {
    // Avoid getting flooded with logs during tests. Note that fork tests will show logs with this
    // approach, because there's currently no way to tell which environment we're in, e.g. script
    // or test. This is being tracked in https://github.com/foundry-rs/foundry/issues/2900.
    if (block.chainid != 31_337) console2.log(message);
  }
}
