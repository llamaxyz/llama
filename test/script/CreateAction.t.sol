// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Action, ActionInfo} from "src/lib/Structs.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Checkpoints} from "src/lib/Checkpoints.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {RelativeStrategy} from "src/strategies/RelativeStrategy.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployLlama} from "script/DeployLlama.s.sol";
import {CreateAction} from "script/CreateAction.s.sol";
import {DeployUtils} from "script/DeployUtils.sol";

import {Roles} from "test/utils/LlamaTestSetup.sol";

contract CreateActionTest is Test, DeployLlama, CreateAction {
  LlamaCore rootLlama;

  function setUp() public virtual {
    // Deploy the root llama infra.
    DeployLlama.run();
    rootLlama = factory.ROOT_LLAMA();
  }
}

contract Run is CreateActionTest {
  using stdJson for string;

  // This is the address that we're using with the CreateAction script to
  // automate action creation to deploy new Llama instances. It could be
  // replaced with any address that we hold the private key for.
  address LLAMA_INSTANCE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;

  uint8 ACTION_CREATOR_ROLE_ID = 1;

  function getActionInfo() internal returns (ActionInfo memory) {
    string memory jsonInput = DeployUtils.readScriptInput("createAction.json");
    return ActionInfo(
      deployActionId,
      LLAMA_INSTANCE_DEPLOYER, // creator
      uint8(Roles.ActionCreator), // role
      ILlamaStrategy(jsonInput.readAddress(".rootLlamaActionCreationStrategy")),
      address(factory), // target
      uint256(0), // value
      createActionCallData
    );
  }

  function test_createsAnActionOnTheRootLlama() public {
    uint256 initActionCount = rootLlama.actionsCount();

    CreateAction.run(LLAMA_INSTANCE_DEPLOYER);

    uint256 newActionCount = rootLlama.actionsCount();
    assertEq(initActionCount + 1, newActionCount);

    Action memory action = rootLlama.getAction(deployActionId);
    ActionInfo memory actionInfo = getActionInfo();

    string memory jsonInput = DeployUtils.readScriptInput("createAction.json");
    bytes32 deployActionInfoHash = keccak256(
      abi.encodePacked(
        deployActionId,
        LLAMA_INSTANCE_DEPLOYER, // creator
        uint8(Roles.ActionCreator), // role
        ILlamaStrategy(jsonInput.readAddress(".rootLlamaActionCreationStrategy")),
        address(factory), // target
        uint256(0), // value
        createActionCallData
      )
    );

    // If the infoHash matches, then this validates that all of the Factory.deploy
    // function input data is correct, since the function calldata was passed to
    // the hash function.
    assertEq(deployActionInfoHash, action.infoHash);
    assertFalse(action.executed);
    assertFalse(action.canceled);

    assertEq(uint8(rootLlama.getActionState(actionInfo)), uint8(ActionState.Active));
  }

  function test_actionCanBeExecuted() public {
    CreateAction.run(LLAMA_INSTANCE_DEPLOYER);

    // Advance the clock so that checkpoints take effect.
    vm.roll(block.number + 1);
    vm.warp(block.timestamp + 1);

    ActionInfo memory actionInfo = getActionInfo();
    assertEq(uint8(rootLlama.getActionState(actionInfo)), uint8(ActionState.Active));

    vm.prank(LLAMA_INSTANCE_DEPLOYER); // This EOA has force-approval permissions.
    rootLlama.castApproval(actionInfo, ACTION_CREATOR_ROLE_ID);

    assertEq(uint8(rootLlama.getActionState(actionInfo)), uint8(ActionState.Approved));

    rootLlama.queueAction(actionInfo);

    // Advance the clock to execute the action.
    vm.roll(block.number + 1);
    Action memory action = rootLlama.getAction(deployActionId);
    vm.warp(action.minExecutionTime + 1);

    // Confirm that a new llama instance was created.
    assertEq(factory.llamaCount(), 1);
    vm.recordLogs();
    rootLlama.executeAction(actionInfo);
    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();
    assertEq(factory.llamaCount(), 2);

    // There are three strategies we expect to have been deployed.
    RelativeStrategy[] memory strategiesAuthorized = new RelativeStrategy[](3);
    uint8 strategiesCount;
    bytes32 strategiesAuthorizedSig = keccak256("StrategyAuthorized(address,address,bytes)");

    // There are two accounts we expect to have been deployed.
    LlamaAccount[] memory accountsCreated = new LlamaAccount[](2);
    uint8 accountsCount;
    bytes32 accountCreatedSig = keccak256("AccountCreated(address,string)");

    // Gets emitted when the deploy call completes, exposing the deployed LlamaCore address.
    bytes32 llamaInstanceCreatedSig = keccak256("LlamaInstanceCreated(uint256,string,address,address,uint256)");
    LlamaCore llamaInstance;

    Vm.Log memory _event;
    for (uint256 i; i < emittedEvents.length; i++) {
      _event = emittedEvents[i];
      bytes32 eventSig = _event.topics[0];
      if (eventSig == llamaInstanceCreatedSig) {
        // event LlamaInstanceCreated(
        //   uint256 indexed id,
        //   string indexed name,
        //   address llamaCore,       <--- What we want.
        //   address llamaPolicy,
        //   uint256 chainId
        // )
        (llamaInstance,,) = abi.decode(_event.data, (LlamaCore, address, uint256));
      }
      if (eventSig == strategiesAuthorizedSig) {
        // event StrategyAuthorized(
        //   ILlamaStrategy indexed strategy,  <-- The topic we want.
        //   ILlamaStrategy indexed strategyLogic,
        //   bytes initializationData
        // );
        address strategy = address(uint160(uint256(_event.topics[1])));
        strategiesAuthorized[strategiesCount++] = RelativeStrategy(strategy);
      }
      if (eventSig == accountCreatedSig) {
        // event AccountCreated(
        //   LlamaAccount indexed account, <-- The topic we want.
        //   string name
        // );
        address payable account = payable(address(uint160(uint256(_event.topics[1]))));
        accountsCreated[accountsCount++] = LlamaAccount(account);
      }
    }

    // Confirm new llama instance has the desired properties.
    assertEq(address(llamaInstance.factory()), address(factory));
    assertNotEq(address(llamaInstance), address(rootLlama));

    RelativeStrategy firstStrategy = strategiesAuthorized[0];
    assertEq(llamaInstance.strategies(firstStrategy), true);
    assertEq(firstStrategy.approvalPeriod(), 172_800);
    assertEq(firstStrategy.approvalRole(), 1);
    assertEq(firstStrategy.disapprovalRole(), 3);
    assertEq(firstStrategy.expirationPeriod(), 691_200);
    assertEq(firstStrategy.isFixedLengthApprovalPeriod(), true);
    assertEq(firstStrategy.minApprovalPct(), 4000);
    assertEq(firstStrategy.minDisapprovalPct(), 5100);
    assertEq(firstStrategy.queuingPeriod(), 345_600);
    assertEq(firstStrategy.forceApprovalRole(1), false);
    assertEq(firstStrategy.forceDisapprovalRole(1), false);

    RelativeStrategy secondStrategy = strategiesAuthorized[1];
    assertEq(llamaInstance.strategies(secondStrategy), true);
    assertEq(secondStrategy.approvalPeriod(), 172_800);
    assertEq(secondStrategy.approvalRole(), 2);
    assertEq(secondStrategy.disapprovalRole(), 3);
    assertEq(secondStrategy.expirationPeriod(), 691_200);
    assertEq(secondStrategy.isFixedLengthApprovalPeriod(), true);
    assertEq(secondStrategy.minApprovalPct(), 4000);
    assertEq(secondStrategy.minDisapprovalPct(), 5100);
    assertEq(secondStrategy.queuingPeriod(), 345_600);
    assertEq(secondStrategy.forceApprovalRole(1), false);
    assertEq(secondStrategy.forceDisapprovalRole(1), false);

    RelativeStrategy thirdStrategy = strategiesAuthorized[2];
    assertEq(llamaInstance.strategies(thirdStrategy), true);
    assertEq(thirdStrategy.approvalPeriod(), 172_800);
    assertEq(thirdStrategy.approvalRole(), 2);
    assertEq(thirdStrategy.disapprovalRole(), 3);
    assertEq(thirdStrategy.expirationPeriod(), 86_400);
    assertEq(thirdStrategy.isFixedLengthApprovalPeriod(), false);
    assertEq(thirdStrategy.minApprovalPct(), 8000);
    assertEq(thirdStrategy.minDisapprovalPct(), 10_001);
    assertEq(thirdStrategy.queuingPeriod(), 0);
    assertEq(thirdStrategy.forceApprovalRole(1), true);
    assertEq(thirdStrategy.forceDisapprovalRole(1), true);

    LlamaAccount firstAccount = accountsCreated[0];
    assertEq(firstAccount.llamaCore(), address(llamaInstance));
    assertEq(
      keccak256(abi.encodePacked(firstAccount.name())), // Encode to compare.
      keccak256("MP Treasury")
    );

    LlamaAccount secondAccount = accountsCreated[1];
    assertEq(secondAccount.llamaCore(), address(llamaInstance));
    assertEq(
      keccak256(abi.encodePacked(secondAccount.name())), // Encode to compare.
      keccak256("MP Grants")
    );

    LlamaPolicy policy = llamaInstance.policy();
    assertEq(address(policy.factory()), address(factory));
    assertEq(policy.numRoles(), 8);

    address initRoleHolder = makeAddr("actionCreatorAaron");
    assertEq(policy.hasRole(initRoleHolder, ACTION_CREATOR_ROLE_ID), true);
    Checkpoints.History memory balances = policy.roleBalanceCheckpoints(initRoleHolder, ACTION_CREATOR_ROLE_ID);
    Checkpoints.Checkpoint memory checkpoint = balances._checkpoints[0];
    assertEq(checkpoint.expiration, type(uint64).max);
    assertEq(checkpoint.quantity, 1);
  }
}
