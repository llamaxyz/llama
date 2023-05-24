// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {ActionInfo, PermissionData} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";

import {LlamaTestSetup, Roles} from "test/utils/LlamaTestSetup.sol";
import {BaseScript} from "src/llama-scripts/BaseScript.sol";
import {MockBaseScript} from "test/mock/MockBaseScript.sol";

contract BaseScriptTest is LlamaTestSetup {
  event SuccessfulCall();

  MockBaseScript baseScript;

  function setUp() public virtual override {
    LlamaTestSetup.setUp();
    baseScript = new MockBaseScript();
  }

  function createPermissionAndActionAndApproveAndQueue() internal returns (ActionInfo memory actionInfo) {
    bytes32 permissionId =
      lens.computePermissionId(PermissionData(address(baseScript), MockBaseScript.run.selector, mpStrategy1));
    bytes memory data = abi.encodeCall(MockBaseScript.run, ());

    vm.prank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), permissionId, true);
    vm.warp(block.timestamp + 1);

    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(baseScript), 0, data);
    actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(baseScript), 0, data);
    vm.warp(block.timestamp + 1);

    vm.prank(approverAdam);
    mpCore.castApproval(actionInfo, uint8(Roles.Approver));
    vm.warp(block.timestamp + 1);
    vm.prank(approverAlicia);
    mpCore.castApproval(actionInfo, uint8(Roles.Approver));
    vm.warp(block.timestamp + 1);
    vm.prank(approverAndy);
    mpCore.castApproval(actionInfo, uint8(Roles.Approver));
    vm.warp(block.timestamp + 2 days);
    mpCore.queueAction(actionInfo);
    vm.warp(block.timestamp + 1 weeks);
  }

}

contract OnlyDelegateCall is BaseScriptTest {
  function test_CanDelegateCallBaseScript() public {
    vm.prank(address(mpExecutor));
    mpCore.authorizeScript(address(baseScript), true);
    ActionInfo memory actionInfo = createPermissionAndActionAndApproveAndQueue();
    vm.expectEmit();
    emit SuccessfulCall();
    mpCore.executeAction(actionInfo);
  }

  function test_RevertIf_NotDelegateCalled() public {
    vm.prank(address(mpExecutor));
    vm.expectRevert(BaseScript.OnlyDelegateCall.selector);
    baseScript.run();

    ActionInfo memory actionInfo = createPermissionAndActionAndApproveAndQueue();
    vm.expectRevert(
      abi.encodeWithSelector(
        LlamaCore.FailedActionExecution.selector, abi.encodeWithSelector(BaseScript.OnlyDelegateCall.selector)
      )
    );
    mpCore.executeAction(actionInfo);
  }
}
