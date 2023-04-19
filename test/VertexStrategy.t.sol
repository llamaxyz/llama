// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {Roles, VertexTestSetup} from "test/utils/VertexTestSetup.sol";

import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {DefaultStrategy} from "src/strategies/DefaultStrategy.sol";
import {RoleHolderData, RolePermissionData, DefaultStrategyConfig} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

contract VertexStrategyTest is VertexTestSetup {
  event NewStrategyCreated(VertexCore vertex, VertexPolicy policy);
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
  ) internal returns (IVertexStrategy newStrategy) {
    {
      // Initialize roles if required.
      initializeRolesUpTo(max(_role, _forceApprovalRoles, _forceDisapprovalRoles));

      bytes[] memory roleAndPermissionAssignments = new bytes[](2);
      roleAndPermissionAssignments[0] =
        abi.encodeCall(VertexPolicy.setRoleHolder, (_role, _policyHolder, 1, type(uint64).max));
      roleAndPermissionAssignments[1] = abi.encodeCall(VertexPolicy.setRolePermission, (_role, _permission, true));

      vm.prank(address(mpCore));
      mpPolicy.aggregate(roleAndPermissionAssignments);
    }

    DefaultStrategyConfig memory strategyConfig = DefaultStrategyConfig({
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

    DefaultStrategyConfig[] memory strategyConfigs = new DefaultStrategyConfig[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpCore));

    mpCore.createAndAuthorizeStrategies(strategyLogic, encodeStrategyConfigs(strategyConfigs));

    newStrategy =
      lens.computeVertexStrategyAddress(address(strategyLogic), encodeStrategy(strategyConfig), address(mpCore));
  }

  function deployTestStrategy() internal returns (IVertexStrategy testStrategy) {
    DefaultStrategyConfig memory testStrategyData = DefaultStrategyConfig({
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
    testStrategy =
      lens.computeVertexStrategyAddress(address(strategyLogic), encodeStrategy(testStrategyData), address(mpCore));
    DefaultStrategyConfig[] memory testStrategies = new DefaultStrategyConfig[](1);
    testStrategies[0] = testStrategyData;
    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeStrategies(strategyLogic, encodeStrategyConfigs(testStrategies));
  }

  function deployTestStrategyWithForceApproval() internal returns (IVertexStrategy testStrategy) {
    // Define strategy parameters.
    uint8[] memory forceApproveRoles = new uint8[](1);
    forceApproveRoles[0] = uint8(Roles.ForceApprover);
    uint8[] memory forceDisapproveRoles = new uint8[](1);
    forceDisapproveRoles[0] = uint8(Roles.ForceDisapprover);

    DefaultStrategyConfig memory testStrategyData = DefaultStrategyConfig({
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
    testStrategy =
      lens.computeVertexStrategyAddress(address(strategyLogic), encodeStrategy(testStrategyData), address(mpCore));

    // Create and authorize the strategy.
    DefaultStrategyConfig[] memory testStrategies = new DefaultStrategyConfig[](1);
    testStrategies[0] = testStrategyData;
    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeStrategies(strategyLogic, encodeStrategyConfigs(testStrategies));

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.ForceApprover), address(approverAdam), 1, type(uint64).max);
  }

  function createAction(IVertexStrategy testStrategy) internal returns (uint256 actionId) {
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
    bytes[] memory setRoleHolderCalls = new bytes[](numberOfHolders);

    for (uint256 i = 0; i < numberOfHolders; i++) {
      address _policyHolder = address(uint160(i + 100));
      if (mpPolicy.balanceOf(_policyHolder) == 0) {
        setRoleHolderCalls[i] =
          abi.encodeCall(VertexPolicy.setRoleHolder, (uint8(Roles.TestRole1), _policyHolder, 1, type(uint64).max));
      }
    }
    vm.prank(address(mpCore));
    mpPolicy.aggregate(setRoleHolderCalls);
  }
}

contract Constructor is VertexStrategyTest {
  function testFuzz_SetsStrategyStorageQueuingDuration(uint256 _queuingDuration) public {
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
    assertEq(toDefaultStrategy(newStrategy).queuingPeriod(), _queuingDuration);
  }

  function testFuzz_SetsStrategyStorageExpirationDelay(uint256 _expirationDelay) public {
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
    assertEq(toDefaultStrategy(newStrategy).expirationPeriod(), _expirationDelay);
  }

  function test_SetsStrategyStorageIsFixedLengthApprovalPeriod(bool _isFixedLengthApprovalPeriod) public {
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
    assertEq(toDefaultStrategy(newStrategy).isFixedLengthApprovalPeriod(), _isFixedLengthApprovalPeriod);
  }

  function testFuzz_SetsStrategyStorageApprovalPeriod(uint256 _approvalPeriod) public {
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
    assertEq(toDefaultStrategy(newStrategy).approvalPeriod(), _approvalPeriod);
  }

  function testFuzz_SetsStrategyStoragePolicy( /*TODO fuzz this test */ ) public {
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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

  function testFuzz_SetsStrategyStorageVertex( /*TODO fuzz this test */ ) public {
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
    assertEq(address(newStrategy.vertex()), address(mpCore));
  }

  function testFuzz_SetsStrategyStorageMinApprovalPct(uint256 _percent) public {
    _percent = bound(_percent, 0, 10_000);
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
    assertEq(toDefaultStrategy(newStrategy).minApprovalPct(), _percent);
  }

  function testFuzz_SetsStrategyStorageMinDisapprovalPct(uint256 _percent) public {
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
    assertEq(toDefaultStrategy(newStrategy).minDisapprovalPct(), _percent);
  }

  function testFuzz_SetsForceApprovalRoles(uint8[] memory forceApprovalRoles) public {
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
      assertEq(toDefaultStrategy(newStrategy).forceApprovalRole(forceApprovalRoles[i]), true);
    }
  }

  function testFuzz_SetsForceDisapprovalRoles(uint8[] memory forceDisapprovalRoles) public {
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
      assertEq(toDefaultStrategy(newStrategy).forceDisapprovalRole(forceDisapprovalRoles[i]), true);
    }
  }

  function testFuzz_HandlesDuplicateApprovalRoles(uint8 _role) public {
    uint8[] memory forceApprovalRoles = new uint8[](2);
    forceApprovalRoles[0] = _role;
    forceApprovalRoles[1] = _role;
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
    assertEq(toDefaultStrategy(newStrategy).forceApprovalRole(_role), true);
  }

  function testFuzz_HandlesDuplicateDisapprovalRoles(uint8 _role) public {
    uint8[] memory forceDisapprovalRoles = new uint8[](2);
    forceDisapprovalRoles[0] = _role;
    forceDisapprovalRoles[1] = _role;
    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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
    assertEq(toDefaultStrategy(newStrategy).forceDisapprovalRole(_role), true);
  }

  function testFuzz_EmitsNewStrategyCreatedEvent( /*TODO fuzz this test */ ) public {
    vm.expectEmit();
    emit NewStrategyCreated(mpCore, mpPolicy);
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

contract IsActionPassed is VertexStrategyTest {
  function testFuzz_ReturnsTrueForPassedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals =
      bound(_actionApprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000), _numberOfPolicies);

    IVertexStrategy testStrategy = deployTestStrategy();

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    approveAction(_actionApprovals, actionId);

    bool isActionPassed = testStrategy.isActionPassed(actionId);

    assertEq(isActionPassed, true);
  }

  function testFuzz_ReturnsFalseForFailedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals = bound(_actionApprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000) - 1);

    IVertexStrategy testStrategy = deployTestStrategy();

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    approveAction(_actionApprovals, actionId);

    bool isActionPassed = testStrategy.isActionPassed(actionId);

    assertEq(isActionPassed, false);
  }

  function testFuzz_RevertForNonExistentActionId(uint256 _actionId) public {
    vm.expectRevert(VertexCore.InvalidActionId.selector);
    vm.prank(address(approverAdam));
    mpCore.castApproval(_actionId, uint8(Roles.Approver));
  }
}

contract IsActionCancelationValid is VertexStrategyTest {
  function testFuzz_ReturnsTrueForDisapprovedActions(uint256 _actionDisapprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals =
      bound(_actionDisapprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000), _numberOfPolicies);

    IVertexStrategy testStrategy = deployTestStrategyWithForceApproval();

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    vm.prank(address(approverAdam));
    mpCore.castApproval(actionId, uint8(Roles.ForceApprover));

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

    IVertexStrategy testStrategy = deployTestStrategyWithForceApproval();

    generateAndSetRoleHolders(_numberOfPolicies);

    uint256 actionId = createAction(testStrategy);

    vm.prank(address(approverAdam));
    mpCore.castApproval(actionId, uint8(Roles.ForceApprover));

    mpCore.queueAction(actionId);

    disapproveAction(_actionDisapprovals, actionId);

    bool isActionCancelled = testStrategy.isActionCancelationValid(actionId, address(this));

    assertEq(isActionCancelled, false);
  }

  function testFuzz_RevertForNonExistentActionId(uint256 _actionId) public {
    vm.expectRevert(VertexCore.InvalidActionId.selector);
    vm.prank(address(disapproverDave));
    mpCore.castDisapproval(_actionId, uint8(Roles.Disapprover));
  }
}

contract GetApprovalQuantityAt is VertexStrategyTest {
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

    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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

    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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

    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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

    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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

contract GetDisapprovalQuantityAt is VertexStrategyTest {
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

    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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

    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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

    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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

    IVertexStrategy newStrategy = deployStrategyAndSetRole(
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

contract DefaultStrategyHarness is DefaultStrategy {
  function exposed_getMinimumAmountNeeded(uint256 supply, uint256 minPct) external pure returns (uint256) {
    return _getMinimumAmountNeeded(supply, minPct);
  }
}

contract GetMinimumAmountNeeded is VertexStrategyTest {
  function testFuzz_calculatesMinimumAmountCorrectly(uint256 supply, uint256 minPct) public {
    DefaultStrategyHarness newStrategy = new DefaultStrategyHarness();
    minPct = bound(minPct, 0, 10_000);
    vm.assume(minPct == 0 || supply <= type(uint256).max / minPct); // avoid solmate revert statement

    uint256 product = FixedPointMathLib.mulDivUp(supply, minPct, 10_000);
    assertEq(newStrategy.exposed_getMinimumAmountNeeded(supply, minPct), product);
  }
}
