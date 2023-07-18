// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaLens} from "src/LlamaLens.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaPolicyMetadata} from "src/LlamaPolicyMetadata.sol";
import {LlamaAbsolutePeerReview} from "src/strategies/LlamaAbsolutePeerReview.sol";
import {LlamaAbsoluteQuorum} from "src/strategies/LlamaAbsoluteQuorum.sol";
import {LlamaRelativeHolderQuorum} from "src/strategies/LlamaRelativeHolderQuorum.sol";
import {LlamaRelativeQuantityQuorum} from "src/strategies/LlamaRelativeQuantityQuorum.sol";
import {LlamaRelativeUniqueHolderQuorum} from "src/strategies/LlamaRelativeUniqueHolderQuorum.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract DeployLlama is Script {
  using stdJson for string;

  // Logic contracts.
  LlamaCore coreLogic;
  LlamaRelativeHolderQuorum relativeHolderQuorumLogic;
  LlamaRelativeQuantityQuorum relativeQuantityQuorumLogic;
  LlamaRelativeUniqueHolderQuorum relativeUniqueHolderQuorumLogic;
  LlamaAbsolutePeerReview absolutePeerReviewLogic;
  LlamaAbsoluteQuorum absoluteQuorumLogic;
  LlamaAccount accountLogic;
  LlamaPolicy policyLogic;

  // Core Protocol.
  LlamaFactory factory;
  LlamaPolicyMetadata policyMetadata;
  LlamaLens lens;

  function run() public {
    DeployUtils.print(string.concat("Deploying Llama framework to chain:", vm.toString(block.chainid)));

    vm.broadcast();
    coreLogic = new LlamaCore();
    DeployUtils.print(string.concat("  LlamaCoreLogic:", vm.toString(address(coreLogic))));

    vm.broadcast();
    relativeHolderQuorumLogic = new LlamaRelativeHolderQuorum();
    DeployUtils.print(
      string.concat("  LlamaRelativeHolderQuorumLogic:", vm.toString(address(relativeHolderQuorumLogic)))
    );

    vm.broadcast();
    relativeQuantityQuorumLogic = new LlamaRelativeQuantityQuorum();
    DeployUtils.print(
      string.concat("  LlamaRelativeQuantityQuorumLogic:", vm.toString(address(relativeQuantityQuorumLogic)))
    );

    vm.broadcast();
    relativeUniqueHolderQuorumLogic = new LlamaRelativeUniqueHolderQuorum();
    DeployUtils.print(
      string.concat("  LlamaRelativeUniqueHolderQuorumLogic:", vm.toString(address(relativeUniqueHolderQuorumLogic)))
    );

    vm.broadcast();
    absolutePeerReviewLogic = new LlamaAbsolutePeerReview();
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
      relativeHolderQuorumLogic,
      accountLogic,
      policyLogic,
      policyMetadata,
      jsonInput.readString(".rootLlamaName"),
      DeployUtils.readRelativeStrategies(jsonInput),
      DeployUtils.readAccounts(jsonInput),
      DeployUtils.readRoleDescriptions(jsonInput),
      DeployUtils.readRoleHolders(jsonInput),
      DeployUtils.readRolePermissions(jsonInput)
    );
    DeployUtils.print(string.concat("  LlamaFactory:", vm.toString(address(factory))));

    vm.broadcast();
    lens = new LlamaLens(address(factory));
    DeployUtils.print(string.concat("  LlamaLens:", vm.toString(address(lens))));

    vm.broadcast();
    absoluteQuorumLogic = new LlamaAbsoluteQuorum();
    DeployUtils.print(string.concat("  LlamaAbsoluteQuorumLogic:", vm.toString(address(absoluteQuorumLogic))));
  }
}
