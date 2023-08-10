// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {DeployLlamaFactory} from "script/DeployLlamaFactory.s.sol";
import {DeployLlamaInstance} from "script/DeployLlamaInstance.s.sol";
import {DeployUtils} from "script/DeployUtils.sol";

import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {ILlamaPolicyMetadata} from "src/interfaces/ILlamaPolicyMetadata.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaIntegrationsTest is DeployLlamaFactory, DeployLlamaInstance, Test {
  // function setUp() public virtual override {
  //   LlamaTestSetup.setUp();
  // }
}

contract Setup {
  // function test_setUp() public {
  //   assertEq(mpCore.name(), "Mock Protocol Llama");

  //   assertEqStrategyStatus(mpCore, mpStrategy1, true, true);
  //   assertEqStrategyStatus(mpCore, mpStrategy2, true, true);

  //   vm.expectRevert(bytes("Initializable: contract is already initialized"));
  //   mpAccount1.initialize("LlamaAccount0");

  //   vm.expectRevert(bytes("Initializable: contract is already initialized"));
  //   mpAccount2.initialize("LlamaAccount1");
  // }
}

contract LlamaOrgIntegration is LlamaIntegrationsTest {

  enum LlamaRoles {
  AllHolders,
  Founders,
  Ranchers
}

  // This is the address that we're using with the CreateAction script to
  // automate action creation to deploy new llamaCore instances. It could be
  // replaced with any address that we hold the private key for.
  address LLAMA_INSTANCE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;

  LlamaCore llamaInstanceCore;
  LlamaExecutor llamaInstanceExecutor;
  LlamaPolicy llamaInstancePolicy;
  ILlamaPolicyMetadata llamaInstancePolicyMetadata;
  ILlamaStrategy llamaInstanceStrategy1;
  ILlamaStrategy llamaInstanceStrategy2;
  ILlamaAccount llamaInstanceAccount1;
  ILlamaAccount llamaInstanceAccount2;

  address shreyas;
  uint256 shreyasPK;
  address austin;
  uint256 austinPK;
  address llamaDev1;
  uint256 llamaDev1PK;
  address llamaDev2;
  uint256 llamaDev2PK;
  address llamaDev3;
  uint256 llamaDevPK;

  function setUp() public virtual {

    // Deploy the factory
    DeployLlamaFactory.run();

    (shreyas, shreyasPK) = makeAddrAndKey("Shreyas");
    (austin, austinPK) = makeAddrAndKey("Austin");
    (llamaDev1, llamaDev1PK) = makeAddrAndKey("LlamaDev1");
    (llamaDev2, llamaDev2PK) = makeAddrAndKey("LlamaDev2");
    (llamaDev3, llamaDevPK) = makeAddrAndKey("LlamaDev3");

    // DeployLlamaInstance.run(LLAMA_INSTANCE_DEPLOYER, "mockLlamaIntegration.json");

    llamaInstanceCore = core;
    llamaInstancePolicy = llamaInstanceCore.policy();
    llamaInstanceExecutor = llamaInstanceCore.executor();
    llamaInstancePolicyMetadata = llamaInstancePolicy.llamaPolicyMetadata();

    // bytes[] memory instanceStrategyConfigs = DeployUtils.readRelativeStrategies("mockLlamaIntegration.json");
    // bytes[] memory rootAccounts = DeployUtils.readAccounts("mockLlamaIntegration.json");

    // llamaInstanceAccount1 = lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[0], address(rootCore));
    // llamaInstanceAccount2 = lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[1], address(rootCore));

    // rootStrategy1 =
    //   lens.computeLlamaStrategyAddress(address(relativeHolderQuorumLogic), instanceStrategyConfigs[1], address(rootCore));
    // rootStrategy2 =
    //   lens.computeLlamaStrategyAddress(address(relativeHolderQuorumLogic), instanceStrategyConfigs[2], address(rootCore));

  }

  function test_CompleteActionFlow() public {
    // TODO
    // We can use _executeCompleteActionFlow() from LlamaCore.t.sol
  }

  function testFuzz_ETHSendFromAccountViaActionApproval(uint256 _ethAmount) public {
    // TODO test that funds can be moved from LlamaAccounts via actions
    // submitted and approved through LlamaIntegrations
  }

  function testFuzz_ERC20SendFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be moved from LlamaAccounts via actions
    // submitted and approved through LlamaIntegrations
  }

  function testFuzz_ERC20ApprovalFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be approved + transferred from LlamaAccounts via actions
    // submitted and approved through LlamaIntegrations
  }
}
