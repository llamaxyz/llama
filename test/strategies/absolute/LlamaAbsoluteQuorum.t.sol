// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {MockProtocol} from "test/mock/MockProtocol.sol";
import {Roles} from "test/utils/LlamaTestSetup.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/absolute/LlamaAbsoluteStrategyBase.sol";

contract LlamaAbsoluteQuorumTest is LlamaAbsoluteStrategyBaseTest {}

contract ValidateActionCreation is LlamaAbsoluteQuorumTest {
  function createAbsoluteQuorumWithDisproportionateQuantity(
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
    mpCore.setStrategyLogicAuthorization(absoluteQuorumLogic, true);

    testStrategy = deployAbsoluteQuorum(
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

  function testFuzz_RevertIf_NotEnoughApprovalQuantity(uint256 _otherRoleHolders) external {
    _otherRoleHolders = bound(_otherRoleHolders, 1, 10);
    generateAndSetRoleHolders(_otherRoleHolders);

    // Assign role for action creation permission.
    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(this), 1, type(uint64).max);
    mineBlock();

    uint96 roleQuantity = mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1));
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
      uint8(Roles.TestRole1),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      false,
      roleQuantity,
      1,
      new uint8[](0),
      new uint8[](0)
    );

    vm.startPrank(address(mpExecutor));
    mpPolicy.setRolePermission(
      uint8(Roles.TestRole1), keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy)), true
    );
    // Removing role holder from an address created in `generateAndSetRoleHolders`.
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(uint160(100)), 0, 0);
    mineBlock();
    vm.stopPrank();

    vm.expectRevert(LlamaAbsoluteStrategyBase.InsufficientApprovalQuantity.selector);
    mpCore.createAction(
      uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
  }

  function testFuzz_RevertIf_NotEnoughDisapprovalQuantity(uint256 _roleQuantity, uint256 _otherRoleHolders) external {
    _roleQuantity = bound(_roleQuantity, 100, 1000);
    uint256 threshold = _roleQuantity / 2;

    ILlamaStrategy testStrategy =
      createAbsoluteQuorumWithDisproportionateQuantity(false, toUint96(threshold), _roleQuantity, _otherRoleHolders);

    vm.expectRevert(LlamaAbsoluteStrategyBase.InsufficientDisapprovalQuantity.selector);
    mpCore.createAction(
      uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
  }

  function testFuzz_DisableDisapprovals(uint256 _roleQuantity, uint256 _otherRoleHolders) external {
    ILlamaStrategy testStrategy =
      createAbsoluteQuorumWithDisproportionateQuantity(false, type(uint96).max, _roleQuantity, _otherRoleHolders);

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

contract IsApprovalEnabled is LlamaAbsoluteQuorumTest {
  function test_PassesWhenCorrectRoleIsPassed() public {
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
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
    ActionInfo memory actionInfo = createAction(testStrategy);
    testStrategy.checkIfApprovalEnabled(actionInfo, address(0), uint8(Roles.Approver));
  }

  function test_RevertIf_WrongRoleIsPassed() public {
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
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
    ActionInfo memory actionInfo = createAction(testStrategy);
    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.Approver)));
    testStrategy.checkIfApprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
  }

  function test_ActionCreatorCanApprove() public {
    ILlamaStrategy absoluteQuorum = deployAbsoluteQuorum(
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
    ActionInfo memory actionInfo = createAction(absoluteQuorum);
    // function reverts if approval disabled, so it not reverting is behavior we are testing
    absoluteQuorum.checkIfApprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Approver));
  }
}

contract IsDisapprovalEnabled is LlamaAbsoluteQuorumTest {
  function test_PassesWhenCorrectRoleIsPassed() public {
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
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
    ActionInfo memory actionInfo = createAction(testStrategy);
    testStrategy.checkIfDisapprovalEnabled(actionInfo, address(0), uint8(Roles.Disapprover));
  }

  function test_RevertIf_WrongRoleIsPassed() public {
    ILlamaStrategy testStrategy = deployAbsoluteQuorum(
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
    ActionInfo memory actionInfo = createAction(testStrategy);
    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.Disapprover)));
    testStrategy.checkIfDisapprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
  }

  function test_ActionCreatorCanDisapprove() public {
    ILlamaStrategy absoluteQuorum = deployAbsoluteQuorum(
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
    ActionInfo memory actionInfo = createAction(absoluteQuorum);
    // function reverts if disapproval is disabled, so it not reverting is behavior we are testing
    absoluteQuorum.checkIfDisapprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Disapprover));
  }
}
