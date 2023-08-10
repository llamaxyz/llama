// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {DeployLlamaInstance} from "script/DeployLlamaInstance.s.sol";
import {DeployUtils} from "script/DeployUtils.sol";

import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {ILlamaPolicyMetadata} from "src/interfaces/ILlamaPolicyMetadata.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaIntegrationsTest is LlamaTestSetup {
  function setUp() public virtual override {
    LlamaTestSetup.setUp();
  }
}

contract Setup is LlamaIntegrationsTest {
  function test_setUp() public {
    assertEq(mpCore.name(), "Mock Protocol Llama");

    assertEqStrategyStatus(mpCore, mpStrategy1, true, true);
    assertEqStrategyStatus(mpCore, mpStrategy2, true, true);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount1.initialize("LlamaAccount0");

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount2.initialize("LlamaAccount1");
  }
}

contract LlamaOrgIntegration is LlamaIntegrationsTest {

  enum LlamaRoles {
  AllHolders,
  Founders,
  Ranchers
}

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

  

  function setUp() public virtual override {
    LlamaTestSetup.setUp();
    (shreyas, shreyasPK) = makeAddrAndKey("Shreyas");
    (austin, austinPK) = makeAddrAndKey("Austin");
    (llamaDev1, llamaDev1PK) = makeAddrAndKey("LlamaDev1");
    (llamaDev2, llamaDev2PK) = makeAddrAndKey("LlamaDev2");
    (llamaDev3, llamaDevPK) = makeAddrAndKey("LlamaDev3");

    // this line overwrites a global variable from LlamaTestSetup, and takes advantage of the helper functions defined in LlamaTestSetup. Because this is in `setUp()`, it will only overwrite this value for the tests in this contract block.
    createActionScriptInput = DeployUtils.readScriptInput("mockLlamaIntegration.json");

    DeployLlamaInstance.run(LLAMA_INSTANCE_DEPLOYER, "mockLlamaIntegration.json");

    llamaInstanceCore = core;
    llamaInstancePolicy = mpCore.policy();
    llamaInstanceExecutor = mpCore.executor();
    llamaInstancePolicyMetadata = mpPolicy.llamaPolicyMetadata();

    bytes[] memory instanceStrategyConfigs = DeployUtils.readRelativeStrategies("mockLlamaIntegration.json");
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
