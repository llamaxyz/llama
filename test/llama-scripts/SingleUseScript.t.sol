// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LlamaCore} from "src/LlamaCore.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {SingleUseScript} from "src/llama-scripts/SingleUseScript.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";
import {MockSingleUseScript} from "test/mock/MockSingleUseScript.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";

contract SingleUseScriptTest is LlamaTestSetup {
  MockSingleUseScript singleUseScript;
  MockProtocol mockExternalProtocol;
  bytes32 oneTimePauseProtocolPermission;

  function setUp() public virtual override {
    LlamaTestSetup.setUp();

    singleUseScript =
      new MockSingleUseScript(mpStrategy2, uint8(Roles.ActionCreator), MockSingleUseScript.pauseMockProtocol.selector);
    mockExternalProtocol = new MockProtocol(address(mpCore));

    oneTimePauseProtocolPermission =
      keccak256(abi.encode(address(singleUseScript), MockSingleUseScript.pauseMockProtocol.selector, mpStrategy2));

    vm.startPrank(address(mpCore));
    mpCore.authorizeScript(address(singleUseScript), true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), oneTimePauseProtocolPermission, true);
    vm.stopPrank();
  }

  function _approveAction(ActionInfo memory actionInfo) internal {
    vm.warp(block.timestamp + 1);

    vm.prank(approverAdam);
    mpCore.castApproval(actionInfo, uint8(Roles.Approver));
    vm.prank(approverAlicia);
    mpCore.castApproval(actionInfo, uint8(Roles.Approver));
    vm.prank(approverAndy);
    mpCore.castApproval(actionInfo, uint8(Roles.Approver));
    mpCore.queueAction(actionInfo);
  }
}

contract RunSingleUseScript is SingleUseScriptTest {
  function test_OnlyRunsSuccessfullyOnce(bool isPaused) public {
    bytes memory data =
      abi.encodeWithSelector(MockSingleUseScript.pauseMockProtocol.selector, mockExternalProtocol, isPaused);
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(singleUseScript), 0, data);
    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, mpStrategy2, address(singleUseScript), 0, data);
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
    mpCore.executeAction(actionInfo);
    assertEq(mockExternalProtocol.paused(), isPaused);

    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(singleUseScript), 0, data);
    assertEq(mpCore.authorizedScripts(address(singleUseScript)), false);
    assertEq(mpPolicy.canCreateAction(uint8(Roles.ActionCreator), oneTimePauseProtocolPermission), false);
  }
}
