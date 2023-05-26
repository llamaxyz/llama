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
import {AbsolutePeerReview} from "src/strategies/AbsolutePeerReview.sol";
import {RelativeQuorum} from "src/strategies/RelativeQuorum.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract DeployLlama is Script {
  using stdJson for string;

  // Logic contracts.
  LlamaCore coreLogic;
  RelativeQuorum relativeQuorumLogic;
  AbsolutePeerReview absolutePeerReviewLogic;
  AbsoluteQuorum absoluteQuorumLogic;
  LlamaAccount accountLogic;
  LlamaPolicy policyLogic;

  // Core Protocol.
  LlamaFactory factory;
  LlamaPolicyMetadata policyMetadata;
  LlamaPolicyMetadataParamRegistry policyMetadataParamRegistry;
  LlamaLens lens;

  function run() public {
    DeployUtils.print(string.concat("Deploying Llama framework to chain:", vm.toString(block.chainid)));

    vm.broadcast();
    coreLogic = new LlamaCore();
    DeployUtils.print(string.concat("  LlamaCoreLogic:", vm.toString(address(coreLogic))));

    vm.broadcast();
    relativeQuorumLogic = new RelativeQuorum();
    DeployUtils.print(string.concat("  LlamaRelativeQuorumLogic:", vm.toString(address(relativeQuorumLogic))));

    vm.broadcast();
    absolutePeerReviewLogic = new AbsolutePeerReview();
    DeployUtils.print(string.concat("  LlamaAbsolutePeerReviewLogic:", vm.toString(address(absolutePeerReviewLogic))));

    vm.broadcast();
    accountLogic = new LlamaAccount();
    DeployUtils.print(string.concat("  LlamaAccountLogic:", vm.toString(address(accountLogic))));

    vm.broadcast();
    policyLogic = new LlamaPolicy();
    DeployUtils.print(string.concat("  LlamaPolicyLogic:", vm.toString(address(policyLogic))));

    vm.broadcast();
    policyMetadata = new LlamaPolicyMetadata();
    DeployUtils.print(string.concat("  LlamaPolicyMetadata:", vm.toString(address(policyMetadata))));

    // ======== START SAFETY CHECK ========
    // Before deploying the factory, we ensure the bootstrap strategy is configured properly to
    // ensure it can be used to pass actions.
    // NOTE: This check currently only supports relative strategies.
    string memory filename = "deployLlama.json";
    DeployUtils.bootstrapSafetyCheck(filename);
    // ======== END SAFETY CHECK ========

    string memory jsonInput = DeployUtils.readScriptInput(filename);
    vm.broadcast();
    factory = new LlamaFactory(
      coreLogic,
      relativeQuorumLogic,
      accountLogic,
      policyLogic,
      policyMetadata,
      jsonInput.readString(".rootLlamaName"),
      DeployUtils.readRelativeStrategies(jsonInput),
      jsonInput.readStringArray(".initialAccountNames"),
      DeployUtils.readRoleDescriptions(jsonInput),
      DeployUtils.readRoleHolders(jsonInput),
      DeployUtils.readRolePermissions(jsonInput)
    );
    DeployUtils.print(string.concat("  LlamaFactory:", vm.toString(address(factory))));

    policyMetadataParamRegistry = factory.LLAMA_POLICY_METADATA_PARAM_REGISTRY();
    DeployUtils.print(
      string.concat("  LlamaPolicyMetadataParamRegistry:", vm.toString(address(policyMetadataParamRegistry)))
    );

    vm.broadcast();
    lens = new LlamaLens(address(factory));
    DeployUtils.print(string.concat("  LlamaLens:", vm.toString(address(lens))));
  }
}
