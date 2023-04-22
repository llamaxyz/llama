// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {AbsoluteStrategyConfig, RelativeStrategyConfig} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {AbsoluteStrategy} from "src/strategies/AbsoluteStrategy.sol";
import {RelativeStrategy} from "src/strategies/RelativeStrategy.sol";
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
      vm.prank(address(mpCore));
      mpPolicy.initializeRole(RoleDescription.wrap("Test Role"));
    }
  }

  function deployStrategyAndSetRole(
    uint8 _role,
    bytes32 _permission,
    address _policyHolder,
    uint256 _queuingDuration,
    uint256 _expirationDelay,
    uint256 _approvalPeriod,
    bool _isFixedLengthApprovalPeriod,
    uint256 _minApprovalPct,
    uint256 _minDisapprovalPct,
    uint8[] memory _forceApprovalRoles,
    uint8[] memory _forceDisapprovalRoles
  ) internal returns (ILlamaStrategy newStrategy) {
    {
      // Initialize roles if required.
      initializeRolesUpTo(max(_role, _forceApprovalRoles, _forceDisapprovalRoles));

      vm.prank(address(mpCore));
      mpPolicy.setRoleHolder(_role, _policyHolder, 1, type(uint64).max);
      vm.prank(address(mpCore));
      mpPolicy.setRolePermission(_role, _permission, true);
    }

    RelativeStrategyConfig memory strategyConfig = RelativeStrategyConfig({
      approvalPeriod: _approvalPeriod,
      queuingPeriod: _queuingDuration,
      expirationPeriod: _expirationDelay,
      isFixedLengthApprovalPeriod: _isFixedLengthApprovalPeriod,
      minApprovalPct: _minApprovalPct,
      minDisapprovalPct: _minDisapprovalPct,
      approvalRole: _role,
      disapprovalRole: _role,
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    RelativeStrategyConfig[] memory strategyConfigs = new RelativeStrategyConfig[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpCore));

    mpCore.createAndAuthorizeStrategies(relativeStrategyLogic, encodeStrategyConfigs(strategyConfigs));

    newStrategy =
      lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), encodeStrategy(strategyConfig), address(mpCore));
  }

  function deployAbsoluteStrategyAndSetRole(
    uint8 _role,
    bytes32 _permission,
    address _policyHolder,
    uint256 _queuingDuration,
    uint256 _expirationDelay,
    uint256 _approvalPeriod,
    bool _isFixedLengthApprovalPeriod,
    uint256 _minApprovals,
    uint256 _minDisapprovals,
    uint8[] memory _forceApprovalRoles,
    uint8[] memory _forceDisapprovalRoles
  ) internal returns (ILlamaStrategy newStrategy) {
    {
      vm.prank(address(rootCore));
      factory.authorizeStrategyLogic(absoluteStrategyLogic);
      // Initialize roles if required.
      initializeRolesUpTo(max(_role, _forceApprovalRoles, _forceDisapprovalRoles));

      vm.startPrank(address(mpCore));
      mpPolicy.setRoleHolder(_role, _policyHolder, 1, type(uint64).max);
      mpPolicy.setRolePermission(_role, _permission, true);
      vm.stopPrank();
    }

    AbsoluteStrategyConfig memory strategyConfig = AbsoluteStrategyConfig({
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

    AbsoluteStrategyConfig[] memory strategyConfigs = new AbsoluteStrategyConfig[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpCore));

    mpCore.createAndAuthorizeStrategies(absoluteStrategyLogic, encodeStrategyConfigs(strategyConfigs));

    newStrategy =
      lens.computeLlamaStrategyAddress(address(absoluteStrategyLogic), encodeStrategy(strategyConfig), address(mpCore));
  }

  function deployTestStrategy() internal returns (ILlamaStrategy testStrategy) {
    RelativeStrategyConfig memory testStrategyData = RelativeStrategyConfig({
      approvalPeriod: 1 days,
      queuingPeriod: 2 days,
      expirationPeriod: 8 days,
      isFixedLengthApprovalPeriod: true,
      minApprovalPct: 4000,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.TestRole1),
      disapprovalRole: uint8(Roles.TestRole1),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });
    testStrategy = lens.computeLlamaStrategyAddress(
      address(relativeStrategyLogic), encodeStrategy(testStrategyData), address(mpCore)
    );
    RelativeStrategyConfig[] memory testStrategies = new RelativeStrategyConfig[](1);
    testStrategies[0] = testStrategyData;
    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeStrategies(relativeStrategyLogic, encodeStrategyConfigs(testStrategies));
  }

  function deployTestStrategyWithForceApproval() internal returns (ILlamaStrategy testStrategy) {
    // Define strategy parameters.
    uint8[] memory forceApproveRoles = new uint8[](1);
    forceApproveRoles[0] = uint8(Roles.ForceApprover);
    uint8[] memory forceDisapproveRoles = new uint8[](1);
    forceDisapproveRoles[0] = uint8(Roles.ForceDisapprover);

    RelativeStrategyConfig memory testStrategyData = RelativeStrategyConfig({
      approvalPeriod: 1 days,
      queuingPeriod: 2 days,
      expirationPeriod: 8 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 4000,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.TestRole1),
      disapprovalRole: uint8(Roles.TestRole1),
      forceApprovalRoles: forceApproveRoles,
      forceDisapprovalRoles: forceDisapproveRoles
    });

    // Get the address of the strategy we'll deploy.
    testStrategy = lens.computeLlamaStrategyAddress(
      address(relativeStrategyLogic), encodeStrategy(testStrategyData), address(mpCore)
    );

    // Create and authorize the strategy.
    RelativeStrategyConfig[] memory testStrategies = new RelativeStrategyConfig[](1);
    testStrategies[0] = testStrategyData;
    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeStrategies(relativeStrategyLogic, encodeStrategyConfigs(testStrategies));

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.ForceApprover), address(approverAdam), 1, type(uint64).max);
  }

  function createAction(ILlamaStrategy testStrategy) internal returns (uint256 actionId) {
    // Give the action creator the ability to use this strategy.
    bytes32 newPermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy));
    vm.prank(address(mpCore));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), newPermissionId, true);

    // Create the action.
    vm.prank(actionCreatorAaron);
    actionId = mpCore.createAction(
      uint8(Roles.ActionCreator),
      testStrategy,
      address(mockProtocol),
      0, // value
      PAUSE_SELECTOR,
      abi.encode(true)
    );

    vm.warp(block.timestamp + 1);
  }

  function approveAction(uint256 numberOfApprovals, uint256 actionId) internal {
    for (uint256 i; i < numberOfApprovals; i++) {
      address _policyholder = address(uint160(i + 100));
      vm.prank(_policyholder);
      mpCore.castApproval(actionId, uint8(Roles.TestRole1));
    }
  }

  function disapproveAction(uint256 numberOfDisapprovals, uint256 actionId) internal {
    for (uint256 i; i < numberOfDisapprovals; i++) {
      address _policyholder = address(uint160(i + 100));
      vm.prank(_policyholder);
      mpCore.castDisapproval(actionId, uint8(Roles.TestRole1));
    }
  }

  function generateAndSetRoleHolders(uint256 numberOfHolders) internal {
    for (uint256 i = 0; i < numberOfHolders; i++) {
      address _policyHolder = address(uint160(i + 100));
      if (mpPolicy.balanceOf(_policyHolder) == 0) {
        vm.prank(address(mpCore));
        mpPolicy.setRoleHolder(uint8(Roles.TestRole1), _policyHolder, 1, type(uint64).max);
      }
    }
  }
}

contract Constructor is LlamaStrategyTest {
  function testFuzz_SetsStrategyStorageQueuingDuration(uint256 _queuingDuration) public {
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      _queuingDuration,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategy(newStrategy).queuingPeriod(), _queuingDuration);
  }

  function testFuzz_SetsStrategyStorageExpirationDelay(uint256 _expirationDelay) public {
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      _expirationDelay,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategy(newStrategy).expirationPeriod(), _expirationDelay);
  }

  function test_SetsStrategyStorageIsFixedLengthApprovalPeriod(bool _isFixedLengthApprovalPeriod) public {
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      _isFixedLengthApprovalPeriod,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategy(newStrategy).isFixedLengthApprovalPeriod(), _isFixedLengthApprovalPeriod);
  }

  function testFuzz_SetsStrategyStorageApprovalPeriod(uint256 _approvalPeriod) public {
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      _approvalPeriod,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategy(newStrategy).approvalPeriod(), _approvalPeriod);
  }

  function test_SetsStrategyStoragePolicy() public {
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(address(newStrategy.policy()), address(mpPolicy));
  }

  function test_SetsStrategyStorageLlama() public {
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(address(newStrategy.llamaCore()), address(mpCore));
  }

  function testFuzz_SetsStrategyStorageMinApprovalPct(uint256 _percent) public {
    _percent = bound(_percent, 0, 10_000);
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      _percent,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategy(newStrategy).minApprovalPct(), _percent);
  }

  function testFuzz_SetsStrategyStorageMinApprovals(uint256 _approvals) public {
    _approvals = bound(_approvals, 0, mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)));
    ILlamaStrategy newStrategy = deployAbsoluteStrategyAndSetRole(
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
    assertEq(toAbsoluteStrategy(newStrategy).minApprovals(), _approvals);
  }

  function testFuzz_SetsStrategyStorageMinDisapprovalPct(uint256 _percent) public {
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      _percent,
      new uint8[](0),
      new uint8[](0)
    );
    assertEq(toRelativeStrategy(newStrategy).minDisapprovalPct(), _percent);
  }

  function testFuzz_SetsStrategyStorageMinDisapprovals(uint256 _disapprovals) public {
    ILlamaStrategy newStrategy = deployAbsoluteStrategyAndSetRole(
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
    assertEq(toAbsoluteStrategy(newStrategy).minDisapprovals(), _disapprovals);
  }

  function testFuzz_SetsForceApprovalRoles(uint8[] memory forceApprovalRoles) public {
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      forceApprovalRoles,
      new uint8[](0)
    );
    for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
      assertEq(toRelativeStrategy(newStrategy).forceApprovalRole(forceApprovalRoles[i]), true);
    }
  }

  function testFuzz_SetsForceDisapprovalRoles(uint8[] memory forceDisapprovalRoles) public {
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      forceDisapprovalRoles
    );
    for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
      assertEq(toRelativeStrategy(newStrategy).forceDisapprovalRole(forceDisapprovalRoles[i]), true);
    }
  }

  function testFuzz_HandlesDuplicateApprovalRoles(uint8 _role) public {
    uint8[] memory forceApprovalRoles = new uint8[](2);
    forceApprovalRoles[0] = _role;
    forceApprovalRoles[1] = _role;
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      forceApprovalRoles,
      new uint8[](0)
    );
    assertEq(toRelativeStrategy(newStrategy).forceApprovalRole(_role), true);
  }

  function testFuzz_HandlesDuplicateDisapprovalRoles(uint8 _role) public {
    uint8[] memory forceDisapprovalRoles = new uint8[](2);
    forceDisapprovalRoles[0] = _role;
    forceDisapprovalRoles[1] = _role;
    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      forceDisapprovalRoles
    );
    assertEq(toRelativeStrategy(newStrategy).forceDisapprovalRole(_role), true);
  }

  function testFuzz_EmitsStrategyCreatedEvent( /*TODO fuzz this test */ ) public {
    vm.expectEmit();
    emit StrategyCreated(mpCore, mpPolicy);
    deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
  }
}

contract IsActionPassed is LlamaStrategyTest {
  function testFuzz_ReturnsTrueForPassedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals =
      bound(_actionApprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000), _numberOfPolicies);

    ILlamaStrategy testStrategy = deployTestStrategy();

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    approveAction(_actionApprovals, actionId);

    bool isActionPassed = testStrategy.isActionPassed(actionId);

    assertEq(isActionPassed, true);
  }

  function testFuzz_AbsoluteStrategy_ReturnsTrueForPassedActions(uint256 _actionApprovals, uint256 _numberOfPolicies)
    public
  {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals =
      bound(_actionApprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000), _numberOfPolicies);

    generateAndSetRoleHolders(_numberOfPolicies);

    ILlamaStrategy testStrategy = deployAbsoluteStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      _actionApprovals,
      5,
      new uint8[](0),
      new uint8[](0)
    );

    uint256 actionId = createAction(testStrategy);

    approveAction(_actionApprovals, actionId);

    bool isActionPassed = testStrategy.isActionPassed(actionId);

    assertEq(isActionPassed, true);
  }

  function testFuzz_ReturnsFalseForFailedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals = bound(_actionApprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000) - 1);

    ILlamaStrategy testStrategy = deployTestStrategy();

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    approveAction(_actionApprovals, actionId);

    bool isActionPassed = testStrategy.isActionPassed(actionId);

    assertEq(isActionPassed, false);
  }

  function testFuzz_AbsoluteStrategy_ReturnsFalseForFailedActions(uint256 _actionApprovals, uint256 _numberOfPolicies)
    public
  {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals = bound(_actionApprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 3000, 10_000) - 1);
    uint256 approvalThreshold = FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000);

    generateAndSetRoleHolders(_numberOfPolicies);

    ILlamaStrategy testStrategy = deployAbsoluteStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      approvalThreshold,
      5,
      new uint8[](0),
      new uint8[](0)
    );

    uint256 actionId = createAction(testStrategy);

    approveAction(_actionApprovals, actionId);

    bool isActionPassed = testStrategy.isActionPassed(actionId);

    assertEq(isActionPassed, false);
  }

  function testFuzz_RevertForNonExistentActionId(uint256 _actionId) public {
    vm.expectRevert(LlamaCore.InvalidActionId.selector);
    vm.prank(address(approverAdam));
    mpCore.castApproval(_actionId, uint8(Roles.Approver));
  }
}

contract IsActionCancelationValid is LlamaStrategyTest {
  function testFuzz_ReturnsTrueForDisapprovedActions(uint256 _actionDisapprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals =
      bound(_actionDisapprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000), _numberOfPolicies);

    ILlamaStrategy testStrategy = deployTestStrategyWithForceApproval();

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    vm.prank(address(approverAdam));
    mpCore.castApproval(actionId, uint8(Roles.ForceApprover));

    mpCore.queueAction(actionId);

    disapproveAction(_actionDisapprovals, actionId);

    bool isActionCancelled = testStrategy.isActionCancelationValid(actionId, address(this));

    assertEq(isActionCancelled, true);
  }

  function testFuzz_AbsoluteStrategy_ReturnsTrueForDisapprovedActions(
    uint256 _actionDisapprovals,
    uint256 _numberOfPolicies
  ) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals =
      bound(_actionDisapprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000), _numberOfPolicies);

    ILlamaStrategy testStrategy = deployAbsoluteStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      false,
      0,
      _actionDisapprovals,
      new uint8[](0),
      new uint8[](0)
    );

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    mpCore.queueAction(actionId);

    disapproveAction(_actionDisapprovals, actionId);

    bool isActionCancelled = testStrategy.isActionCancelationValid(actionId, address(this));

    assertEq(isActionCancelled, true);
  }

  function testFuzz_ReturnsFalseForActionsNotFullyDisapproved(uint256 _actionDisapprovals, uint256 _numberOfPolicies)
    public
  {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) - 1);

    ILlamaStrategy testStrategy = deployTestStrategyWithForceApproval();

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    vm.prank(address(approverAdam));
    mpCore.castApproval(actionId, uint8(Roles.ForceApprover));

    mpCore.queueAction(actionId);

    disapproveAction(_actionDisapprovals, actionId);

    bool isActionCancelled = testStrategy.isActionCancelationValid(actionId, address(this));

    assertEq(isActionCancelled, false);
  }

  function testFuzz_AbsoluteStrategy_ReturnsFalseForActionsNotFullyDisapproved(
    uint256 _actionDisapprovals,
    uint256 _numberOfPolicies
  ) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) - 1);
    uint256 disapprovalThreshold = FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000);

    ILlamaStrategy testStrategy = deployAbsoluteStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      false,
      0,
      disapprovalThreshold,
      new uint8[](0),
      new uint8[](0)
    );

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    mpCore.queueAction(actionId);

    disapproveAction(_actionDisapprovals, actionId);

    bool isActionCancelled = testStrategy.isActionCancelationValid(actionId, address(this));

    assertEq(isActionCancelled, false);
  }

  function testFuzz_RevertForNonExistentActionId(uint256 _actionId) public {
    vm.expectRevert(LlamaCore.InvalidActionId.selector);
    vm.prank(address(disapproverDave));
    mpCore.castDisapproval(_actionId, uint8(Roles.Disapprover));
  }
}

contract GetApprovalQuantityAt is LlamaStrategyTest {
  function testFuzz_ReturnsZeroQuantityPriorToAccountGainingPermission(
    uint256 _timeUntilPermission,
    uint8 _role,
    bytes32 _permission,
    address _policyHolder
  ) public {
    vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    vm.warp(_timeUntilPermission);

    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    assertEq(
      newStrategy.getApprovalQuantityAt(_policyHolder, _role, _referenceTime),
      0 // there should be zero quantity before permission was granted
    );
  }

  function testFuzz_ReturnsQuantityAfterBlockThatAccountGainedPermission(
    uint256 _timeSincePermission, // no assume for this param, we want 0 tested
    bytes32 _permission,
    uint8 _role,
    address _policyHolder
  ) public {
    vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));

    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );
    vm.warp(_timeSincePermission);
    assertEq(
      newStrategy.getApprovalQuantityAt(
        _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
      ),
      1 // the account should still have the quantity
    );
  }

  function testFuzz_ReturnsZeroQuantityForNonPolicyHolders(uint64 _timestamp, uint8 _role, address _nonPolicyHolder)
    public
  {
    _timestamp = uint64(bound(_timestamp, block.timestamp + 1, type(uint64).max));
    vm.assume(_nonPolicyHolder != address(0));
    vm.assume(_nonPolicyHolder != address(0xdeadbeef)); // Given a policy below.
    vm.assume(mpPolicy.balanceOf(_nonPolicyHolder) == 0);
    vm.assume(_role != 0);

    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      _role, bytes32(0), address(0xdeadbeef), 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getApprovalQuantityAt(_nonPolicyHolder, _role, _timestamp - 1),
      0 // the account should not have a quantity
    );
  }

  function testFuzz_ReturnsDefaultQuantityForPolicyHolderWithoutExplicitQuantity(
    uint256 _timestamp,
    uint8 _role,
    address _policyHolder
  ) public {
    _timestamp = bound(_timestamp, block.timestamp - 1, type(uint64).max);
    _role = uint8(bound(_role, 8, 255)); // ignoring all roles in the test setup to avoid conflicts with pre-assigned
      // roles
    vm.assume(_policyHolder != address(0));

    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      _policyHolder,
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getApprovalQuantityAt(_policyHolder, _role, _timestamp - 1),
      0 // the account should not have a quantity
    );
  }
}

contract GetDisapprovalQuantityAt is LlamaStrategyTest {
  function testFuzz_ReturnsZeroQuantityPriorToAccountGainingPermission(
    uint256 _timeUntilPermission,
    bytes32 _permission,
    uint8 _role,
    address _policyHolder
  ) public {
    vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    vm.warp(_timeUntilPermission);

    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    assertEq(
      newStrategy.getDisapprovalQuantityAt(_policyHolder, _role, _referenceTime),
      0 // there should be zero quantity before permission was granted
    );
  }

  function testFuzz_ReturnsQuantityAfterBlockThatAccountGainedPermission(
    uint256 _timeSincePermission, // no assume for this param, we want 0 tested
    bytes32 _permission,
    uint8 _role,
    address _policyHolder
  ) public {
    vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));

    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );
    vm.warp(_timeSincePermission);
    assertEq(
      newStrategy.getDisapprovalQuantityAt(
        _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
      ),
      1 // the account should still have the quantity
    );
  }

  function testFuzz_ReturnsZeroQuantityForNonPolicyHolders(uint256 _timestamp, uint8 _role, address _nonPolicyHolder)
    public
  {
    vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
    vm.assume(_nonPolicyHolder != address(0));
    vm.assume(_nonPolicyHolder != address(0xdeadbeef)); // Given a policy below.
    vm.assume(mpPolicy.balanceOf(_nonPolicyHolder) == 0);
    vm.assume(_role != 0);

    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      _role, bytes32(0), address(0xdeadbeef), 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getDisapprovalQuantityAt(_nonPolicyHolder, _role, _timestamp - 1),
      0 // the account should not have a quantity
    );
  }

  function testFuzz_ReturnsDefaultQuantityForPolicyHolderWithoutExplicitQuantity(
    uint256 _timestamp,
    uint8 _role,
    address _policyHolder
  ) public {
    _timestamp = bound(_timestamp, block.timestamp - 1, type(uint64).max);
    _role = uint8(bound(_role, 8, 255)); // ignoring all roles in the test setup to avoid conflicts with pre-assigned
      // roles
    vm.assume(_policyHolder != address(0));

    ILlamaStrategy newStrategy = deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      _policyHolder,
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getDisapprovalQuantityAt(_policyHolder, _role, _timestamp - 1),
      0 // the account should not have a quantity
    );
  }
}

contract RelativeStrategyHarness is RelativeStrategy {
  function exposed_getMinimumAmountNeeded(uint256 supply, uint256 minPct) external pure returns (uint256) {
    return _getMinimumAmountNeeded(supply, minPct);
  }
}

contract GetMinimumAmountNeeded is LlamaStrategyTest {
  function testFuzz_calculatesMinimumAmountCorrectly(uint256 supply, uint256 minPct) public {
    RelativeStrategyHarness newStrategy = new RelativeStrategyHarness();
    minPct = bound(minPct, 0, 10_000);
    vm.assume(minPct == 0 || supply <= type(uint256).max / minPct); // avoid solmate revert statement

    uint256 product = FixedPointMathLib.mulDivUp(supply, minPct, 10_000);
    assertEq(newStrategy.exposed_getMinimumAmountNeeded(supply, minPct), product);
  }
}