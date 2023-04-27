// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaLens} from "src/LlamaLens.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaPolicyMetadata} from "src/LlamaPolicyMetadata.sol";
import {LlamaPolicyMetadataParamRegistry} from "src/LlamaPolicyMetadataParamRegistry.sol";
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
  LlamaPolicyMetadata policyTokenURI;
  LlamaPolicyMetadataParamRegistry policyTokenURIParamRegistry;
  LlamaLens lens;

  function run() public {
    DeployUtils.print(string.concat("Deploying Llama framework to chain:", vm.toString(block.chainid)));

    vm.broadcast();
    coreLogic = new LlamaCore();
    DeployUtils.print(string.concat("  LlamaCoreLogic:", vm.toString(address(coreLogic))));

    vm.broadcast();
    relativeStrategyLogic = new RelativeStrategy();
    DeployUtils.print(string.concat("  LlamaRelativeStrategyLogic:", vm.toString(address(relativeStrategyLogic))));

    vm.broadcast();
    absoluteStrategyLogic = new AbsoluteStrategy();
    DeployUtils.print(string.concat("  LlamaAbsoluteStrategyLogic:", vm.toString(address(absoluteStrategyLogic))));

    vm.broadcast();
    accountLogic = new LlamaAccount();
    DeployUtils.print(string.concat("  LlamaAccountLogic:", vm.toString(address(accountLogic))));

    vm.broadcast();
    policyLogic = new LlamaPolicy();
    DeployUtils.print(string.concat("  LlamaPolicyLogic:", vm.toString(address(policyLogic))));

    vm.broadcast();
    policyTokenURI = new LlamaPolicyMetadata();
    DeployUtils.print(string.concat("  LlamaPolicyMetadata:", vm.toString(address(policyTokenURI))));

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
    DeployUtils.print(string.concat("  LlamaFactory:", vm.toString(address(factory))));

    policyTokenURIParamRegistry = factory.LLAMA_POLICY_TOKEN_URI_PARAM_REGISTRY();
    DeployUtils.print(
      string.concat("  LlamaPolicyMetadataParamRegistry:", vm.toString(address(policyTokenURIParamRegistry)))
    );

    vm.broadcast();
    lens = new LlamaLens();
    DeployUtils.print(string.concat("  LlamaLens:", vm.toString(address(lens))));
  }
}
