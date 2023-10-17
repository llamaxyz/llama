// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson} from "forge-std/Script.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaLens} from "src/LlamaLens.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaPolicyMetadata} from "src/LlamaPolicyMetadata.sol";
import {LlamaAbsolutePeerReview} from "src/strategies/absolute/LlamaAbsolutePeerReview.sol";
import {LlamaAbsoluteQuorum} from "src/strategies/absolute/LlamaAbsoluteQuorum.sol";
import {LlamaRelativeHolderQuorum} from "src/strategies/relative/LlamaRelativeHolderQuorum.sol";
import {LlamaRelativeQuantityQuorum} from "src/strategies/relative/LlamaRelativeQuantityQuorum.sol";
import {LlamaRelativeUniqueHolderQuorum} from "src/strategies/relative/LlamaRelativeUniqueHolderQuorum.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract DeployLlamaFactory is Script {
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
  LlamaPolicyMetadata policyMetadataLogic;

  // Factory and lens contracts.
  LlamaFactory factory;
  LlamaLens lens;

  function run() public {
    DeployUtils.print(string.concat("Deploying Llama factory to chain:", vm.toString(block.chainid)));

    vm.broadcast();
    coreLogic = new LlamaCore();
    DeployUtils.print(string.concat("  LlamaCoreLogic:", vm.toString(address(coreLogic))));

    vm.broadcast();
    relativeHolderQuorumLogic = new LlamaRelativeHolderQuorum();
    DeployUtils.print(
      string.concat("  LlamaRelativeHolderQuorumLogic:", vm.toString(address(relativeHolderQuorumLogic)))
    );

    // This 0 value, 0x bytecode self-call ensures that deployments on new chains will maintain address consistency with
    // chains deployed before the absolute strategy update.
    vm.broadcast();
    (bool success,) = msg.sender.call("");
    DeployUtils.print(string.concat("  Self call succeeded? ", vm.toString(success)));

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

    // This 0 value, 0x bytecode self-call ensures that deployments on new chains will maintain address consistency with
    // chains deployed before the absolute strategy update.
    vm.broadcast();
    (success,) = msg.sender.call("");
    DeployUtils.print(string.concat("  Self call succeeded? ", vm.toString(success)));

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

    // These 0 value, 0x bytecode self-calls ensure that deployments on new chains will maintain address consistency
    // with chains deployed before the absolute strategy update.

    vm.broadcast();
    (success,) = msg.sender.call("");
    DeployUtils.print(string.concat("  Self call succeeded? ", vm.toString(success)));

    vm.broadcast();
    (success,) = msg.sender.call("");
    DeployUtils.print(string.concat("  Self call succeeded? ", vm.toString(success)));

    vm.broadcast();
    (success,) = msg.sender.call("");
    DeployUtils.print(string.concat("  Self call succeeded? ", vm.toString(success)));

    vm.broadcast();
    (success,) = msg.sender.call("");
    DeployUtils.print(string.concat("  Self call succeeded? ", vm.toString(success)));

    vm.broadcast();
    absoluteQuorumLogic = new LlamaAbsoluteQuorum();
    DeployUtils.print(string.concat("  LlamaAbsoluteQuorumLogic:", vm.toString(address(absoluteQuorumLogic))));

    vm.broadcast();
    absolutePeerReviewLogic = new LlamaAbsolutePeerReview();
    DeployUtils.print(string.concat("  LlamaAbsolutePeerReviewLogic:", vm.toString(address(absolutePeerReviewLogic))));
  }
}
