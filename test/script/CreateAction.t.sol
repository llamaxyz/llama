// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {Action} from "src/lib/Structs.sol";
import {ActionState} from "src/lib/Enums.sol";
import {DeployVertex} from "script/DeployVertex.s.sol";
import {CreateActionToDeployVertexInstance} from "script/CreateAction.s.sol";

// TODO probably remove
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

contract CreateActionTest is Test, DeployVertex {
  CreateActionToDeployVertexInstance script;

  VertexCore rootVertex;

  function setUp() public virtual {
    // Deploy the root vertex infra.
    DeployVertex.run();
    rootVertex = factory.ROOT_VERTEX();
    script = new CreateActionToDeployVertexInstance();
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

    script.run(VERTEX_INSTANCE_DEPLOYER);

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
      string,
      VertexStrategy,
      VertexAccount,
      Strategy[],
      string[],
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
    script.run(VERTEX_INSTANCE_DEPLOYER);

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

    Action memory action = rootVertex.getAction(deployActionId);

    // Advance the clock to execute the action.
    vm.roll(block.number + 1);
    vm.warp(action.minExecutionTime + 1);

    // Confirm that a new vertex instance was created.
    bytes memory deployResult = rootVertex.executeAction(deployActionId);
    VertexCore vertexInstance = abi.decode(deployResult, (VertexCore));
    assertEq(address(vertexInstance.factory()), address(factory));
    assertNotEq(address(vertexInstance), address(rootVertex));

    // Confirm new vertex instance has the desired setup.
  }
}
