// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {Action} from "src/lib/Structs.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Checkpoints} from "src/lib/Checkpoints.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployVertex} from "script/DeployVertex.s.sol";
import {CreateAction} from "script/CreateAction.s.sol";

contract CreateActionTest is Test, DeployVertex, CreateAction {
  VertexCore rootVertex;

  function setUp() public virtual {
    // Deploy the root vertex infra.
    DeployVertex.run();
    rootVertex = factory.ROOT_VERTEX();
  }
}

contract Run is CreateActionTest {
  // This is the address that we're using with the CreateAction script to
  // automate action creation to deploy new Vertex instances. It could be
  // replaced with any address that we hold the private key for.
  address VERTEX_INSTANCE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;

  uint8 ACTION_CREATOR_ROLE_ID = 1;

  function test_deploy() public {
    // TODO revert if root vertex is not at the address in the deploy script
    // TODO revert if initial role holder role ID in input is not ActionCreator
    // TODO revert if initial role holder quantity in input is not the DEFAULT_ROLE_QTY
  }

  struct VarsForCreatesAnActionOnTheRootVertex {
    string name;
    VertexStrategy strategyLogic;
    VertexAccount accountLogic;
    Strategy[] initialStrategies;
    string[] initialAccounts;
    RoleDescription[] initialRoleDescriptions;
    RoleHolderData[] initialRoleHolders;
    RolePermissionData[] initialRolePermissions;
  }

  function test_createsAnActionOnTheRootVertex() public {
    uint256 initActionCount = rootVertex.actionsCount();

    CreateAction.run(VERTEX_INSTANCE_DEPLOYER);

    uint256 newActionCount = rootVertex.actionsCount();
    assertEq(initActionCount + 1, newActionCount);

    uint256 newActionId = initActionCount;
    Action memory action = rootVertex.getAction(newActionId);

    assertEq(action.creator, VERTEX_INSTANCE_DEPLOYER);
    assertFalse(action.executed);
    assertFalse(action.canceled);
    assertEq(action.selector, VertexFactory.deploy.selector);
    assertEq(action.target, address(factory));
    VarsForCreatesAnActionOnTheRootVertex memory vars;
    (
      vars.name,
      vars.strategyLogic,
      vars.accountLogic,
      vars.initialStrategies,
      vars.initialAccounts,
      vars.initialRoleDescriptions,
      vars.initialRoleHolders,
      vars.initialRolePermissions
    ) = abi.decode(action.data, (
      string, // Name.
      VertexStrategy,
      VertexAccount,
      Strategy[],
      string[], // Account names.
      RoleDescription[],
      RoleHolderData[],
      RolePermissionData[]
    ));
    assertEq(vars.name, "Mock Protocol Vertex");
    assertEq(address(vars.strategyLogic), 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496);
    assertEq(address(vars.accountLogic), 0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3);
    assertEq(
      keccak256(abi.encodePacked(vars.initialAccounts[0])),
      keccak256("MP Treasury")
    );
    assertEq(
      keccak256(abi.encodePacked(vars.initialAccounts[1])),
      keccak256("MP Grants")
    );
    // TODO assert against more action.data
    assertEq(
      uint8(rootVertex.getActionState(newActionId)),
      uint8(ActionState.Active)
    );
  }

  function test_actionCanBeExecuted() public {
    CreateAction.run(VERTEX_INSTANCE_DEPLOYER);

    // Advance the clock so that checkpoints take effect.
    vm.roll(block.number + 1);
    vm.warp(block.timestamp + 1);

    uint256 deployActionId = 0;

    assertEq(
      uint8(rootVertex.getActionState(deployActionId)),
      uint8(ActionState.Active)
    );

    vm.prank(VERTEX_INSTANCE_DEPLOYER); // This EOA has force-approval permissions.
    rootVertex.castApproval(deployActionId, ACTION_CREATOR_ROLE_ID);

    assertEq(
      uint8(rootVertex.getActionState(deployActionId)),
      uint8(ActionState.Approved)
    );

    rootVertex.queueAction(deployActionId);

    // Advance the clock to execute the action.
    vm.roll(block.number + 1);
    Action memory action = rootVertex.getAction(deployActionId);
    vm.warp(action.minExecutionTime + 1);

    // Confirm that a new vertex instance was created.
    assertEq(factory.vertexCount(), 1);
    vm.recordLogs();
    bytes memory deployResult = rootVertex.executeAction(deployActionId);
    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();
    assertEq(factory.vertexCount(), 2);
    VertexCore vertexInstance = abi.decode(deployResult, (VertexCore));
    assertEq(address(vertexInstance.factory()), address(factory));
    assertNotEq(address(vertexInstance), address(rootVertex));

    // Confirm new vertex instance has the desired properties.

    // There are two strategies we expect to have been deployed.
    VertexStrategy[] memory strategiesAuthorized = new VertexStrategy[](2);
    uint8 strategiesCount;
    bytes32 strategiesAuthorizedSig = keccak256(
      "StrategyAuthorized(address,address,(uint256,uint256,uint256,uint256,uint256,bool,uint8,uint8,uint8[],uint8[]))"
    );

    // There are two accounts we expect to have been deployed.
    VertexAccount[] memory accountsAuthorized = new VertexAccount[](2);
    uint8 accountsCount;
    bytes32 accountAuthorizedSig = keccak256("AccountAuthorized(address,address,string)");

    Vm.Log memory _event;
    for (uint256 i; i < emittedEvents.length; i++) {
      _event = emittedEvents[i];
      if (_event.topics[0] == strategiesAuthorizedSig) {
        // event StrategyAuthorized(
        //   VertexStrategy indexed strategy,  <-- The topic we want.
        //   address indexed strategyLogic,
        //   Strategy strategyData
        // );
        address strategy = address(uint160(uint256(_event.topics[1])));
        strategiesAuthorized[strategiesCount++] = VertexStrategy(strategy);
      }
      if (_event.topics[0] == accountAuthorizedSig) {
        // event AccountAuthorized(
        //   VertexAccount indexed account,  <-- The topic we want.
        //   address indexed accountLogic,
        //   string name
        // );
        address payable account = payable(address(uint160(uint256(_event.topics[1]))));
        accountsAuthorized[accountsCount++] = VertexAccount(account);
      }
    }

    VertexStrategy firstStrategy = strategiesAuthorized[0];
    assertEq(vertexInstance.authorizedStrategies(firstStrategy), true);
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

    VertexStrategy secondStrategy = strategiesAuthorized[1];
    assertEq(vertexInstance.authorizedStrategies(secondStrategy), true);
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

    VertexAccount firstAccount = accountsAuthorized[0];
    assertEq(firstAccount.vertex(), address(vertexInstance));
    assertEq(
      keccak256(abi.encodePacked(firstAccount.name())), // Encode to compare.
      keccak256("MP Treasury")
    );

    VertexAccount secondAccount = accountsAuthorized[1];
    assertEq(secondAccount.vertex(), address(vertexInstance));
    assertEq(
      keccak256(abi.encodePacked(secondAccount.name())), // Encode to compare.
      keccak256("MP Grants")
    );

    VertexPolicy policy = vertexInstance.policy();
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
