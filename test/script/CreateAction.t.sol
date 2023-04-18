// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {Action} from "src/lib/Structs.sol";
import {ActionState} from "src/lib/Enums.sol";
import {DeployVertex} from "script/DeployVertex.s.sol";
import {CreateActionToDeployVertexInstance} from "script/CreateAction.s.sol";

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

    bytes memory deployResult = rootVertex.executeAction(deployActionId);
    VertexCore vertexInstance = abi.decode(deployResult, (VertexCore));
    assertEq(address(vertexInstance.factory()), address(factory));
    // TODO confirm that a new vertex instance is created
    // TODO confirm new vertex instance properties
  }
}
