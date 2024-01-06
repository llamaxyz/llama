// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {ProtectedSetRoleHoldersGuard} from "src/guards/ProtectedSetRoleHoldersGuard.sol";
import {ProtectedSetRoleHoldersGuardFactory} from "src/guards/ProtectedSetRoleHoldersGuardFactory.sol";
import {ActionInfo, PermissionData, RoleHolderData} from "src/lib/Structs.sol";
import {LlamaGovernanceScript} from "src/llama-scripts/LlamaGovernanceScript.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";
import {LlamaGovernanceScriptTest} from "test/llama-scripts/LlamaGovernanceScript.t.sol";

contract ProtectedSetRoleHolderTest is LlamaGovernanceScriptTest {
  event AuthorizedSetRoleHolder(uint8 indexed setterRole, uint8 indexed targetRole, bool isAuthorized);

  ProtectedSetRoleHoldersGuard public guard;
  ProtectedSetRoleHoldersGuardFactory public protectedSetRoleHoldersGuardFactory;

  function setUp() public override {
    LlamaGovernanceScriptTest.setUp();
    protectedSetRoleHoldersGuardFactory = new ProtectedSetRoleHoldersGuardFactory();
    guard = protectedSetRoleHoldersGuardFactory.deployProtectedSetRoleHoldersGuard(uint8(0), address(mpExecutor));
    vm.prank(address(mpExecutor));
    mpCore.setGuard(address(govScript), SET_ROLE_HOLDERS_SELECTOR, guard);
  }
}

contract ValidateActionCreation is ProtectedSetRoleHolderTest {
  function test_RevertIf_UnauthorizedSetRoleHolder(uint8 targetRole) public {
    targetRole = uint8(bound(targetRole, 1, 8)); // number of existing roles excluding all holders role

    RoleHolderData[] memory roleHolderData = new RoleHolderData[](1);
    roleHolderData[0] = RoleHolderData({role: targetRole, policyholder: approverAdam, quantity: 1, expiration: 0});

    bytes memory data = abi.encodeWithSelector(SET_ROLE_HOLDERS_SELECTOR, roleHolderData);

    // There is no bypass role, and we have not set any authorizations, so this should always revert.
    vm.expectRevert(
      abi.encodeWithSelector(
        ProtectedSetRoleHoldersGuard.UnauthorizedSetRoleHolder.selector, uint8(Roles.ActionCreator), targetRole
      )
    );
    vm.prank(actionCreatorAaron);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(govScript), 0, data, "");
  }

  function test_BypassProtectionRoleWorksWithAllExisingRoles(uint8 targetRole) public {
    targetRole = uint8(bound(targetRole, 1, 8)); // number of existing roles excluding all holders role

    // create a new guard with a bypass role
    guard = protectedSetRoleHoldersGuardFactory.deployProtectedSetRoleHoldersGuard(
      uint8(Roles.ActionCreator), address(mpExecutor)
    );
    vm.prank(address(mpExecutor));
    mpCore.setGuard(address(govScript), SET_ROLE_HOLDERS_SELECTOR, guard);

    RoleHolderData[] memory roleHolderData = new RoleHolderData[](1);
    roleHolderData[0] =
      RoleHolderData({role: targetRole, policyholder: approverAdam, quantity: 1, expiration: type(uint64).max});

    bytes memory data = abi.encodeWithSelector(SET_ROLE_HOLDERS_SELECTOR, roleHolderData);

    ActionInfo memory actionInfo = _createAndApproveAndQueueAction(data);
    mpCore.executeAction(actionInfo);

    assertEq(mpPolicy.hasRole(approverAdam, targetRole), true);
  }

  function test_AuthorizedSetRoleHolder(uint8 targetRole) public {
    targetRole = uint8(bound(targetRole, 1, 8)); // number of existing roles excluding all holders role

    // set role authorization
    vm.prank(address(mpExecutor));
    vm.expectEmit();
    emit AuthorizedSetRoleHolder(uint8(Roles.ActionCreator), targetRole, true);
    guard.setAuthorizedSetRoleHolder(uint8(Roles.ActionCreator), targetRole, true);

    RoleHolderData[] memory roleHolderData = new RoleHolderData[](1);
    roleHolderData[0] =
      RoleHolderData({role: targetRole, policyholder: approverAdam, quantity: 1, expiration: type(uint64).max});

    bytes memory data = abi.encodeWithSelector(SET_ROLE_HOLDERS_SELECTOR, roleHolderData);

    ActionInfo memory actionInfo = _createAndApproveAndQueueAction(data);

    mpCore.executeAction(actionInfo);

    assertEq(mpPolicy.hasRole(approverAdam, targetRole), true);
  }

  function test_IfAuthorizationChangesBeforeExecution(uint8 targetRole) public {
    targetRole = uint8(bound(targetRole, 1, 8)); // number of existing roles excluding all holders role

    // set role authorization
    vm.prank(address(mpExecutor));
    vm.expectEmit();
    emit AuthorizedSetRoleHolder(uint8(Roles.ActionCreator), targetRole, true);
    guard.setAuthorizedSetRoleHolder(uint8(Roles.ActionCreator), targetRole, true);

    RoleHolderData[] memory roleHolderData = new RoleHolderData[](1);
    roleHolderData[0] =
      RoleHolderData({role: targetRole, policyholder: approverAdam, quantity: 1, expiration: type(uint64).max});

    bytes memory data = abi.encodeWithSelector(SET_ROLE_HOLDERS_SELECTOR, roleHolderData);

    ActionInfo memory actionInfo = _createAndApproveAndQueueAction(data);

    // setting role authorization to false mid action
    vm.prank(address(mpExecutor));
    vm.expectEmit();
    emit AuthorizedSetRoleHolder(uint8(Roles.ActionCreator), targetRole, false);
    guard.setAuthorizedSetRoleHolder(uint8(Roles.ActionCreator), targetRole, false);

    mpCore.executeAction(actionInfo);

    assertEq(mpPolicy.hasRole(approverAdam, targetRole), true);
  }
}
