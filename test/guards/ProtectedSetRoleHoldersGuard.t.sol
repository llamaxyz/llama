// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {ProtectedSetRoleHoldersGuard} from "src/guards/ProtectedSetRoleHoldersGuard.sol";
import {ActionInfo, PermissionData, RoleHolderData} from "src/lib/Structs.sol";
import {LlamaGovernanceScript} from "src/llama-scripts/LlamaGovernanceScript.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";
import {LlamaGovernanceScriptTest} from "test/llama-scripts/LlamaGovernanceScript.t.sol";

contract ProtectedSetRoleHolderTest is LlamaGovernanceScriptTest {

  ProtectedSetRoleHoldersGuard public guard;

  function setUp() public override {
    LlamaGovernanceScriptTest.setUp();
    guard = new ProtectedSetRoleHoldersGuard(uint8(0), address(mpExecutor));
    vm.prank(address(mpExecutor));
    mpCore.setGuard(address(govScript), SET_ROLE_HOLDERS_SELECTOR, guard);
  }

  function _createAndApproveAndQueueActionWithRole(bytes memory data, uint8 role)
    internal
    returns (ActionInfo memory actionInfo)
  {
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(govScript), 0, data, "");
    actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy2, address(govScript), 0, data);
    vm.warp(block.timestamp + 1);
    _approveAction(actionInfo);
  }
}

contract ValidateActionCreation is ProtectedSetRoleHolderTest {
  function test_RevertIf_UnauthorizedSetRoleHolder(uint8 targetRole) public {
    targetRole = uint8(bound(targetRole, 0, 8));

    RoleHolderData[] memory roleHolderData = new RoleHolderData[](1);
    roleHolderData[0] = RoleHolderData({role: targetRole, policyholder: approverAdam, quantity: 1, expiration: 0});

    bytes memory data = abi.encodeWithSelector(SET_ROLE_HOLDERS_SELECTOR, roleHolderData);

    ActionInfo memory actionInfo = ActionInfo(
      0,
      actionCreatorAaron,
      uint8(Roles.ActionCreator),
      mpStrategy2,
      address(govScript),
      0,
      data
    );

    vm.expectRevert(
      abi.encodeWithSelector(ProtectedSetRoleHoldersGuard.UnauthorizedSetRoleHolder.selector, uint8(Roles.ActionCreator), targetRole)
    );
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(govScript), 0, data, "");
  }
}
