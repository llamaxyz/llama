// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {Action} from "src/lib/Structs.sol";
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

contract CreateActionTest is Test, DeployLlama, CreateAction {
  LlamaCore rootLlama;

  function setUp() public virtual {
    // Deploy the root llama infra.
    DeployLlama.run();
    rootLlama = factory.ROOT_LLAMA();
  }
}

contract Run is CreateActionTest {
  // This is the address that we're using with the CreateAction script to
  // automate action creation to deploy new Llama instances. It could be
  // replaced with any address that we hold the private key for.
  address LLAMA_INSTANCE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;

  uint8 ACTION_CREATOR_ROLE_ID = 1;

  function test_deploy() public {
    // TODO revert if root llama is not at the address in the deploy script
    // TODO revert if initial role holder role ID in input is not ActionCreator
    // TODO revert if initial role holder quantity in input is not the DEFAULT_ROLE_QTY
  }

  struct VarsForCreatesAnActionOnTheRootLlama {
    string name;
    ILlamaStrategy strategyLogic;
    bytes[] initialStrategies;
    string[] initialAccounts;
    RoleDescription[] initialRoleDescriptions;
    RoleHolderData[] initialRoleHolders;
    RolePermissionData[] initialRolePermissions;
  }

  function test_createsAnActionOnTheRootLlama() public {
    uint256 initActionCount = rootLlama.actionsCount();

    CreateAction.run(LLAMA_INSTANCE_DEPLOYER);

    uint256 newActionCount = rootLlama.actionsCount();
    assertEq(initActionCount + 1, newActionCount);

    uint256 newActionId = initActionCount;
    Action memory action = rootLlama.getAction(newActionId);

    assertEq(action.creator, LLAMA_INSTANCE_DEPLOYER);
    assertFalse(action.executed);
    assertFalse(action.canceled);
    assertEq(action.selector, LlamaFactory.deploy.selector);
    assertEq(action.target, address(factory));
    VarsForCreatesAnActionOnTheRootLlama memory vars;
    (
      vars.name,
      vars.strategyLogic,
      vars.initialStrategies,
      vars.initialAccounts,
      vars.initialRoleDescriptions,
      vars.initialRoleHolders,
      vars.initialRolePermissions
    ) = abi.decode(
      action.data,
      (
        string, // Name.
        ILlamaStrategy,
        bytes[], // initialStrategies.
        string[], // initialAccounts.
        RoleDescription[],
        RoleHolderData[],
        RolePermissionData[]
      )
    );

    assertEq(vars.name, "Mock Protocol Llama");
    assertEq(address(vars.strategyLogic), 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496);
    assertEq(keccak256(abi.encodePacked(vars.initialAccounts[0])), keccak256("MP Treasury"));
    assertEq(keccak256(abi.encodePacked(vars.initialAccounts[1])), keccak256("MP Grants"));
    // TODO assert against more action.data
    assertEq(uint8(rootLlama.getActionState(newActionId)), uint8(ActionState.Active));
  }

  function test_actionCanBeExecuted() public {
    CreateAction.run(LLAMA_INSTANCE_DEPLOYER);

    // Advance the clock so that checkpoints take effect.
    vm.roll(block.number + 1);
    vm.warp(block.timestamp + 1);

    uint256 deployActionId = 0;

    assertEq(uint8(rootLlama.getActionState(deployActionId)), uint8(ActionState.Active));

    vm.prank(LLAMA_INSTANCE_DEPLOYER); // This EOA has force-approval permissions.
    rootLlama.castApproval(deployActionId, ACTION_CREATOR_ROLE_ID);

    assertEq(uint8(rootLlama.getActionState(deployActionId)), uint8(ActionState.Approved));

    rootLlama.queueAction(deployActionId);

    // Advance the clock to execute the action.
    vm.roll(block.number + 1);
    Action memory action = rootLlama.getAction(deployActionId);
    vm.warp(action.minExecutionTime + 1);

    // Confirm that a new llama instance was created.
    assertEq(factory.llamaCount(), 1);
    vm.recordLogs();
    rootLlama.executeAction(deployActionId);
    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();
    assertEq(factory.llamaCount(), 2);

    // There are two strategies we expect to have been deployed.
    RelativeStrategy[] memory strategiesAuthorized = new RelativeStrategy[](2);
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
    assertEq(llamaInstance.authorizedStrategies(firstStrategy), true);
    assertEq(firstStrategy.approvalPeriod(), 172_800);
    assertEq(firstStrategy.approvalRole(), 2);
    assertEq(firstStrategy.disapprovalRole(), 3);
    assertEq(firstStrategy.expirationPeriod(), 86_400);
    assertEq(firstStrategy.isFixedLengthApprovalPeriod(), false);
    assertEq(firstStrategy.minApprovalPct(), 8000);
    assertEq(firstStrategy.minDisapprovalPct(), 10_001);
    assertEq(firstStrategy.queuingPeriod(), 0);
    assertEq(firstStrategy.forceApprovalRole(1), true);
    assertEq(firstStrategy.forceDisapprovalRole(1), true);

    RelativeStrategy secondStrategy = strategiesAuthorized[1];
    assertEq(llamaInstance.authorizedStrategies(secondStrategy), true);
    assertEq(secondStrategy.approvalPeriod(), 172_800);
    assertEq(secondStrategy.approvalRole(), 2);
    assertEq(secondStrategy.disapprovalRole(), 3);
    assertEq(secondStrategy.expirationPeriod(), 691_200);
    assertEq(secondStrategy.isFixedLengthApprovalPeriod(), true);
    assertEq(secondStrategy.minApprovalPct(), 4000);
    assertEq(secondStrategy.minDisapprovalPct(), 2000);
    assertEq(secondStrategy.queuingPeriod(), 345_600);
    assertEq(secondStrategy.forceApprovalRole(1), false);
    assertEq(secondStrategy.forceDisapprovalRole(1), false);

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
