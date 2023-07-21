// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {LlamaAbsoluteStrategyBaseTest} from "test/strategies/absolute/LlamaAbsoluteStrategyBase.t.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";
import {Roles} from "test/utils/LlamaTestSetup.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaAbsolutePeerReview} from "src/strategies/absolute/LlamaAbsolutePeerReview.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/absolute/LlamaAbsoluteStrategyBase.sol";

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaAbsolutePeerReviewTest is LlamaAbsoluteStrategyBaseTest {}

contract ValidateActionCreation is LlamaAbsolutePeerReviewTest {
  function createAbsolutePeerReviewWithDisproportionateQuantity(
    bool isApproval,
    uint96 threshold,
    uint256 _roleQuantity,
    uint256 _otherRoleHolders
  ) internal returns (ILlamaStrategy testStrategy) {
    _roleQuantity = bound(_roleQuantity, 100, 1000);
    _otherRoleHolders = bound(_otherRoleHolders, 1, 10);

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(this), uint96(_roleQuantity), type(uint64).max);

    generateAndSetRoleHolders(_otherRoleHolders);

    vm.prank(address(mpExecutor));
    mpCore.setStrategyLogicAuthorization(absolutePeerReviewLogic, true);

    testStrategy = deployAbsolutePeerReview(
      uint8(Roles.TestRole1),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      false,
      isApproval ? threshold : 0,
      isApproval ? 0 : threshold,
      new uint8[](0),
      new uint8[](0)
    );

    bytes32 newPermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy));

    vm.prank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), newPermissionId, true);
  }

  function testFuzz_RevertIf_NotEnoughApprovalQuantity(uint256 _roleQuantity, uint256 _otherRoleHolders) external {
    _roleQuantity = bound(_roleQuantity, 100, 1000);
    uint256 threshold = _roleQuantity / 2;
    ILlamaStrategy testStrategy =
      createAbsolutePeerReviewWithDisproportionateQuantity(true, toUint96(threshold), _roleQuantity, _otherRoleHolders);

    vm.expectRevert(LlamaAbsoluteStrategyBase.InsufficientApprovalQuantity.selector);
    mpCore.createAction(
      uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
  }

  function testFuzz_RevertIf_NotEnoughDisapprovalQuantity(uint256 _roleQuantity, uint256 _otherRoleHolders) external {
    _roleQuantity = bound(_roleQuantity, 100, 1000);
    uint256 threshold = _roleQuantity / 2;

    ILlamaStrategy testStrategy =
      createAbsolutePeerReviewWithDisproportionateQuantity(false, toUint96(threshold), _roleQuantity, _otherRoleHolders);

    vm.expectRevert(LlamaAbsoluteStrategyBase.InsufficientDisapprovalQuantity.selector);
    mpCore.createAction(
      uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
  }

  function testFuzz_DisableDisapprovals(uint256 _roleQuantity, uint256 _otherRoleHolders) external {
    ILlamaStrategy testStrategy =
      createAbsolutePeerReviewWithDisproportionateQuantity(false, type(uint96).max, _roleQuantity, _otherRoleHolders);

    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
    ActionInfo memory actionInfo = ActionInfo(
      actionId,
      address(this),
      uint8(Roles.TestRole1),
      testStrategy,
      address(mockProtocol),
      0,
      abi.encodeCall(MockProtocol.pause, (true))
    );

    vm.warp(block.timestamp + 1);

    mpCore.queueAction(actionInfo);

    vm.expectRevert(LlamaAbsoluteStrategyBase.DisapprovalDisabled.selector);

    mpCore.castDisapproval(uint8(Roles.TestRole1), actionInfo, "");
  }
}

contract IsApprovalEnabled is LlamaAbsolutePeerReviewTest {
  function test_PassesWhenCorrectRoleIsPassed() public {
    ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(absolutePeerReview);
    absolutePeerReview.checkIfApprovalEnabled(actionInfo, address(0), uint8(Roles.Approver));
  }

  function test_RevertIf_WrongRoleIsPassed() public {
    ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(absolutePeerReview);
    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.Approver)));
    absolutePeerReview.checkIfApprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
  }

  function test_ActionCreatorCannotApprove() public {
    ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(absolutePeerReview);
    vm.expectRevert(LlamaAbsolutePeerReview.ActionCreatorCannotCast.selector);
    absolutePeerReview.checkIfApprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Approver));
  }
}

contract IsDisapprovalEnabled is LlamaAbsolutePeerReviewTest {
  function test_PassesWhenCorrectRoleIsPassed() public {
    ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(absolutePeerReview);
    absolutePeerReview.checkIfDisapprovalEnabled(actionInfo, address(0), uint8(Roles.Disapprover));
  }

  function test_RevertIf_WrongRoleIsPassed() public {
    ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(absolutePeerReview);
    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.Disapprover)));
    absolutePeerReview.checkIfDisapprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
  }

  function test_ActionCreatorCannotDisapprove() public {
    ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      0,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createAction(absolutePeerReview);
    vm.expectRevert(LlamaAbsolutePeerReview.ActionCreatorCannotCast.selector);
    absolutePeerReview.checkIfDisapprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Disapprover));
  }
}
