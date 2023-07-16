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
import {LlamaRelativeQuorum} from "src/strategies/LlamaRelativeQuorum.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract DeployLlamaFactory is Script {
  using stdJson for string;

  // Logic contracts.
  LlamaCore coreLogic;
  LlamaRelativeQuorum relativeQuorumLogic;
  LlamaAbsolutePeerReview absolutePeerReviewLogic;
  LlamaAbsoluteQuorum absoluteQuorumLogic;
  LlamaAccount accountLogic;
  LlamaPolicy policyLogic;

  // Core Protocol.
  LlamaFactory factory;
  LlamaPolicyMetadata policyMetadataLogic;
  LlamaLens lens;

  function run() public {
    DeployUtils.print(string.concat("Deploying Llama framework to chain:", vm.toString(block.chainid)));

    vm.broadcast();
    coreLogic = new LlamaCore();
    DeployUtils.print(string.concat("  LlamaCoreLogic:", vm.toString(address(coreLogic))));

    vm.broadcast();
    relativeQuorumLogic = new LlamaRelativeQuorum();
    DeployUtils.print(string.concat("  LlamaRelativeQuorumLogic:", vm.toString(address(relativeQuorumLogic))));

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
    policyMetadataLogic = new LlamaPolicyMetadata();
    DeployUtils.print(string.concat("  LlamaPolicyMetadataLogic:", vm.toString(address(policyMetadataLogic))));

    vm.broadcast();
    factory = new LlamaFactory(
      coreLogic,
      policyLogic,
      policyMetadataLogic
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
