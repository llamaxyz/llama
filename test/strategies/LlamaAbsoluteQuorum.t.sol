// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {MockProtocol} from "test/mock/MockProtocol.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaAbsoluteQuorum} from "src/strategies/LlamaAbsoluteQuorum.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/LlamaAbsoluteStrategyBase.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaStrategyTest is LlamaTestSetup {
  event StrategyCreated(LlamaCore llama, LlamaPolicy policy);
  event ApprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);

  function max(uint8 role, uint8[] memory forceApprovalRoles, uint8[] memory forceDisapprovalRoles)
    internal
    pure
    returns (uint8 largest)
  {
    largest = role;
    for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
      if (forceApprovalRoles[i] > largest) largest = forceApprovalRoles[i];
    }
    for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
      if (forceDisapprovalRoles[i] > largest) largest = forceDisapprovalRoles[i];
    }
  }

  function initializeRolesUpTo(uint8 role) internal {
    while (mpPolicy.numRoles() < role) {
      vm.prank(address(mpExecutor));
      mpPolicy.initializeRole(RoleDescription.wrap("Test Role"));
    }
  }

  function deployAbsoluteQuorumAndSetRole(
    uint8 _role,
    bytes32 _permission,
    address _policyHolder,
    uint64 _queuingDuration,
    uint64 _expirationDelay,
    uint64 _approvalPeriod,
    bool _isFixedLengthApprovalPeriod,
    uint128 _minApprovals,
    uint128 _minDisapprovals,
    uint8[] memory _forceApprovalRoles,
    uint8[] memory _forceDisapprovalRoles
  ) internal returns (ILlamaStrategy newStrategy) {
    {
      vm.prank(address(rootExecutor));
      factory.authorizeStrategyLogic(absoluteQuorumLogic);
      // Initialize roles if required.
      initializeRolesUpTo(max(_role, _forceApprovalRoles, _forceDisapprovalRoles));

      vm.startPrank(address(mpExecutor));
      mpPolicy.setRoleHolder(_role, _policyHolder, 1, type(uint64).max);
      mpPolicy.setRolePermission(_role, _permission, true);
      vm.stopPrank();
    }

    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: _approvalPeriod,
      queuingPeriod: _queuingDuration,
      expirationPeriod: _expirationDelay,
      isFixedLengthApprovalPeriod: _isFixedLengthApprovalPeriod,
      minApprovals: _minApprovals,
      minDisapprovals: _minDisapprovals,
      approvalRole: _role,
      disapprovalRole: _role,
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    mpCore.createStrategies(absoluteQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

    newStrategy = lens.computeLlamaStrategyAddress(
      address(absoluteQuorumLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
    );
  }

  function createAction(ILlamaStrategy testStrategy) internal returns (ActionInfo memory actionInfo) {
    // Give the action creator the ability to use this strategy.
    bytes32 newPermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy));
    vm.prank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), newPermissionId, true);

    // Create the action.
    bytes memory data = abi.encodeCall(MockProtocol.pause, (true));
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), testStrategy, address(mockProtocol), 0, data, "");

    actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), testStrategy, address(mockProtocol), 0, data);

    vm.warp(block.timestamp + 1);
  }

  function approveAction(uint256 numberOfApprovals, ActionInfo memory actionInfo) internal {
    for (uint256 i = 0; i < numberOfApprovals; i++) {
      address _policyholder = address(uint160(i + 100));
      vm.prank(_policyholder);
      mpCore.castApproval(uint8(Roles.TestRole1), actionInfo, "");
    }
  }

  function disapproveAction(uint256 numberOfDisapprovals, ActionInfo memory actionInfo) internal {
    for (uint256 i = 0; i < numberOfDisapprovals; i++) {
      address _policyholder = address(uint160(i + 100));
      vm.prank(_policyholder);
      mpCore.castDisapproval(uint8(Roles.TestRole1), actionInfo, "");
    }
  }

  function generateAndSetRoleHolders(uint256 numberOfHolders) internal {
    for (uint256 i = 0; i < numberOfHolders; i++) {
      address _policyHolder = address(uint160(i + 100));
      if (mpPolicy.balanceOf(_policyHolder) == 0) {
        vm.prank(address(mpExecutor));
        mpPolicy.setRoleHolder(uint8(Roles.TestRole1), _policyHolder, 1, type(uint64).max);
      }
    }
  }
}

contract Initialize is LlamaStrategyTest {
  function testFuzz_SetsStrategyStorageMinApprovals(uint128 _approvals) public {
    _approvals = toUint128(bound(_approvals, 0, mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1))));
    ILlamaStrategy newStrategy = deployAbsoluteQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      _approvals,
      5,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toAbsoluteQuorum(newStrategy).minApprovals(), _approvals);
  }

  function testFuzz_SetsStrategyStorageMinDisapprovals(uint128 _disapprovals) public {
    ILlamaStrategy newStrategy = deployAbsoluteQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      1,
      _disapprovals,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toAbsoluteQuorum(newStrategy).minDisapprovals(), _disapprovals);
  }

  function testFuzz_RevertIf_InvalidMinApprovalsPeerReview(uint256 _numberOfPolicies, uint256 _minApprovalIncrease)
    public
  {
    _minApprovalIncrease = bound(_minApprovalIncrease, 1, 1000);
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    generateAndSetRoleHolders(_numberOfPolicies);
    uint256 totalQuantity = mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1));
    uint256 minApprovals = totalQuantity + _minApprovalIncrease;

    vm.prank(address(rootExecutor));
    factory.authorizeStrategyLogic(absoluteQuorumLogic);

    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: 1 days,
      queuingPeriod: 1 days,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovals: toUint128(minApprovals),
      minDisapprovals: 0,
      approvalRole: uint8(Roles.TestRole1),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(rootExecutor));

    factory.authorizeStrategyLogic(absoluteQuorumLogic);

    vm.prank(address(mpExecutor));

    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidMinApprovals.selector, minApprovals));
    mpCore.createStrategies(absoluteQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
  }

  function test_RevertIf_SetAllHoldersRoleAsForceApprovalRoleAbsolute() public {
    uint8[] memory _forceApprovalRoles = new uint8[](1);
    _forceApprovalRoles[0] = uint8(Roles.AllHolders);
    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: 1 days,
      queuingPeriod: 1 days,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovals: 1,
      minDisapprovals: 1,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: new uint8[](0)
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(rootExecutor));

    factory.authorizeStrategyLogic(absoluteQuorumLogic);

    vm.prank(address(mpExecutor));
    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.AllHolders)));
    mpCore.createStrategies(absoluteQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
  }

  function test_RevertIf_SetAllHoldersRoleAsForceDisapprovalRole() public {
    uint8[] memory _forceDisapprovalRoles = new uint8[](1);
    _forceDisapprovalRoles[0] = uint8(Roles.AllHolders);
    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: 1 days,
      queuingPeriod: 1 days,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovals: 1,
      minDisapprovals: 1,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(rootExecutor));

    factory.authorizeStrategyLogic(absoluteQuorumLogic);

    vm.prank(address(mpExecutor));

    vm.expectRevert(abi.encodeWithSelector(LlamaAbsoluteStrategyBase.InvalidRole.selector, uint8(Roles.AllHolders)));
    mpCore.createStrategies(absoluteQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));
  }
}

contract IsActionApproved is LlamaStrategyTest {
  function testFuzz_ReturnsTrueForPassedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals =
      bound(_actionApprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000), _numberOfPolicies);

    generateAndSetRoleHolders(_numberOfPolicies);

    ILlamaStrategy testStrategy = deployAbsoluteQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      toUint128(_actionApprovals),
      2,
      new uint8[](0),
      new uint8[](0)
    );

    ActionInfo memory actionInfo = createAction(testStrategy);

    approveAction(_actionApprovals, actionInfo);

    bool _isActionApproved = testStrategy.isActionApproved(actionInfo);

    assertEq(_isActionApproved, true);
  }

  function testFuzz_ReturnsFalseForFailedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals = bound(_actionApprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000) - 1);

    generateAndSetRoleHolders(_numberOfPolicies);

    ILlamaStrategy testStrategy = deployAbsoluteQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      uint128(_numberOfPolicies),
      2,
      new uint8[](0),
      new uint8[](0)
    );

    ActionInfo memory actionInfo = createAction(testStrategy);

    approveAction(_actionApprovals, actionInfo);

    assertFalse(testStrategy.isActionApproved(actionInfo));
  }

  function testFuzz_RevertForNonExistentActionId(ActionInfo calldata actionInfo) public {
    vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
    vm.prank(address(approverAdam));
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
  }
}

contract ValidateActionCancelation is LlamaStrategyTest {
  function testFuzz_RevertIf_ActionNotFullyDisapprovedAndCallerIsNotCreator(
    uint256 _actionDisapprovals,
    uint256 _numberOfPolicies
  ) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) - 1);
    uint256 disapprovalThreshold = FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000);

    ILlamaStrategy testStrategy = deployAbsoluteQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      false,
      0,
      toUint128(disapprovalThreshold),
      new uint8[](0),
      new uint8[](0)
    );

    generateAndSetRoleHolders(_numberOfPolicies);

    ActionInfo memory actionInfo = createAction(testStrategy);

    mpCore.queueAction(actionInfo);

    disapproveAction(_actionDisapprovals, actionInfo);
    assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));

    vm.expectRevert(LlamaAbsoluteStrategyBase.OnlyActionCreator.selector);
    testStrategy.validateActionCancelation(actionInfo, address(this));
  }

  function testFuzz_NoRevertIf_ActionNotFullyDisapprovedAndCallerIsNotCreator(
    uint256 _actionDisapprovals,
    uint256 _numberOfPolicies
  ) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) - 1);
    uint256 disapprovalThreshold = FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000);

    ILlamaStrategy testStrategy = deployAbsoluteQuorumAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      false,
      0,
      toUint128(disapprovalThreshold),
      new uint8[](0),
      new uint8[](0)
    );

    generateAndSetRoleHolders(_numberOfPolicies);

    ActionInfo memory actionInfo = createAction(testStrategy);

    mpCore.queueAction(actionInfo);

    disapproveAction(_actionDisapprovals, actionInfo);
    assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));

    testStrategy.validateActionCancelation(actionInfo, actionInfo.creator); // This should not revert.
  }

  function testFuzz_RevertForNonExistentActionId(ActionInfo calldata actionInfo) public {
    vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
    vm.prank(address(disapproverDave));
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");
  }
}

contract ValidateActionCreation is LlamaStrategyTest {
  function createAbsoluteQuorumWithDisproportionateQuantity(
    bool isApproval,
    uint128 threshold,
    uint256 _roleQuantity,
    uint256 _otherRoleHolders
  ) internal returns (ILlamaStrategy testStrategy) {
    _roleQuantity = bound(_roleQuantity, 100, 1000);
    _otherRoleHolders = bound(_otherRoleHolders, 1, 10);

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(this), uint128(_roleQuantity), type(uint64).max);

    generateAndSetRoleHolders(_otherRoleHolders);

    vm.prank(address(rootExecutor));
    factory.authorizeStrategyLogic(absoluteQuorumLogic);

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
    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(this), 1, type(uint64).max); // for action creation
      // permission
    uint128 roleQuantity = mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1));
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
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(uint160(100)), 0, 0); // removing role holder from an address
      // created in `generateAndSetRoleHolders`
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
      createAbsoluteQuorumWithDisproportionateQuantity(false, toUint128(threshold), _roleQuantity, _otherRoleHolders);

    vm.expectRevert(LlamaAbsoluteStrategyBase.InsufficientDisapprovalQuantity.selector);
    mpCore.createAction(
      uint8(Roles.TestRole1), testStrategy, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
  }

  function testFuzz_DisableDisapprovals(uint256 _roleQuantity, uint256 _otherRoleHolders) external {
    ILlamaStrategy testStrategy =
      createAbsoluteQuorumWithDisproportionateQuantity(false, type(uint128).max, _roleQuantity, _otherRoleHolders);

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

contract IsApprovalEnabled is LlamaStrategyTest {
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
    testStrategy.isApprovalEnabled(actionInfo, address(0), uint8(Roles.Approver));
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
    testStrategy.isApprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
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
    absoluteQuorum.isApprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Approver));
  }
}

contract IsDisapprovalEnabled is LlamaStrategyTest {
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
    testStrategy.isDisapprovalEnabled(actionInfo, address(0), uint8(Roles.Disapprover));
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
    testStrategy.isDisapprovalEnabled(actionInfo, address(0), uint8(Roles.TestRole1));
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
    absoluteQuorum.isDisapprovalEnabled(actionInfo, actionCreatorAaron, uint8(Roles.Disapprover));
  }
}
