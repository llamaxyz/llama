// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Roles, VertexTestSetup} from "test/utils/VertexTestSetup.sol";
import {RoleHolderData, RolePermissionData, Strategy} from "src/lib/Structs.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract VertexStrategyTest is VertexTestSetup {
  RoleHolderData[] roleHolders;
  mapping(address => bool) public isRoleHolder;
  RolePermissionData[] rolePermissions;
  Strategy strategy;
  Strategy[] strategies;
  VertexStrategy newStrategy;
  Strategy testStrategyData;
  VertexStrategy testStrategy;
  Strategy[] testStrategies;

  event NewStrategyCreated(VertexCore vertex, VertexPolicy policy);
  event PolicyholderApproved(uint256 id, address indexed policyholder, uint256 weight, string reason);
  event PolicyholderDisapproved(uint256 id, address indexed policyholder, uint256 weight, string reason);

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
  ) public {
    roleHolders.push(RoleHolderData(_role, _policyHolder, 1, type(uint64).max));
    rolePermissions.push(RolePermissionData(_role, _permission, true));

    vm.prank(address(mpCore));

    mpPolicy.setRoleHoldersAndPermissions(roleHolders, rolePermissions);

    strategy = Strategy({
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

    strategies.push(strategy);

    vm.prank(address(mpCore));

    mpCore.createAndAuthorizeStrategies(address(strategyLogic), strategies);

    newStrategy = lens.computeVertexStrategyAddress(address(strategyLogic), strategy, address(mpCore));
  }

  function _deployTestStrategy() internal {
    testStrategyData = Strategy({
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
    testStrategy = lens.computeVertexStrategyAddress(address(strategyLogic), testStrategyData, address(mpCore));
    testStrategies.push(testStrategyData);
    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeStrategies(address(strategyLogic), testStrategies);
  }

  function _deployTestStrategyWithForceApproval() internal {
    uint8[] memory forceRoles = new uint8[](1);
    forceRoles[0] = uint8(Roles.Admin);
    testStrategyData = Strategy({
      approvalPeriod: 1 days,
      queuingPeriod: 2 days,
      expirationPeriod: 8 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 4000,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.TestRole1),
      disapprovalRole: uint8(Roles.TestRole1),
      forceApprovalRoles: forceRoles,
      forceDisapprovalRoles: forceRoles
    });
    testStrategy = lens.computeVertexStrategyAddress(address(strategyLogic), testStrategyData, address(mpCore));
    testStrategies.push(testStrategyData);
    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeStrategies(address(strategyLogic), testStrategies);
  }

  function _createAction() public returns (uint256 actionId) {
    vm.prank(adminAlice);
    actionId = mpCore.createAction(
      uint8(Roles.TestRole1),
      testStrategy,
      address(mockProtocol),
      0, // value
      PAUSE_SELECTOR,
      abi.encode(true)
    );
    vm.warp(block.timestamp + 1);
  }

  function _approveAction(address _policyholder, uint256 _actionId) public {
    // vm.expectEmit(true, true, true, true);
    // emit PolicyholderApproved(_actionId, _policyholder, 1, "");
    vm.prank(_policyholder);
    mpCore.castApproval(_actionId, uint8(Roles.TestRole1));
  }

  function _disapproveAction(address _policyholder, uint256 _actionId) public {
    // vm.expectEmit(true, true, true, true);
    // emit PolicyholderDisapproved(_actionId, _policyholder, 1, "");
    vm.prank(_policyholder);
    mpCore.castDisapproval(_actionId, uint8(Roles.TestRole1));
  }

  function _generateRoleHolder(address user) internal {
    roleHolders.push(RoleHolderData(uint8(Roles.TestRole1), user, 1, type(uint64).max));
    isRoleHolder[user] = true;
  }

  function _tokenId(address user) internal pure returns (uint256) {
    return uint256(uint160(user));
  }
}

contract Constructor is VertexStrategyTest {
  function testFuzz_SetsStrategyStorageQueuingDuration(uint256 _queuingDuration) public {
    deployStrategyAndSetRole(
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
    assertEq(newStrategy.queuingPeriod(), _queuingDuration);
  }

  function testFuzz_SetsStrategyStorageExpirationDelay(uint256 _expirationDelay) public {
    deployStrategyAndSetRole(
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
    assertEq(newStrategy.expirationPeriod(), _expirationDelay);
  }

  function test_SetsStrategyStorageIsFixedLengthApprovalPeriod(bool _isFixedLengthApprovalPeriod) public {
    deployStrategyAndSetRole(
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
    assertEq(newStrategy.isFixedLengthApprovalPeriod(), _isFixedLengthApprovalPeriod);
  }

  function testFuzz_SetsStrategyStorageApprovalPeriod(uint256 _approvalPeriod) public {
    deployStrategyAndSetRole(
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
    assertEq(newStrategy.approvalPeriod(), _approvalPeriod);
  }

  function testFuzz_SetsStrategyStoragePolicy( /*TODO fuzz this test */ ) public {
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
    assertEq(address(newStrategy.policy()), address(mpPolicy));
  }

  function testFuzz_SetsStrategyStorageVertex( /*TODO fuzz this test */ ) public {
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
    assertEq(address(newStrategy.vertex()), address(mpCore));
  }

  function testFuzz_SetsStrategyStorageMinApprovalPct(uint256 _percent) public {
    deployStrategyAndSetRole(
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
    assertEq(newStrategy.minApprovalPct(), _percent);
  }

  function testFuzz_SetsStrategyStorageMinDisapprovalPct(uint256 _percent) public {
    deployStrategyAndSetRole(
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
    assertEq(newStrategy.minDisapprovalPct(), _percent);
  }

  function testFuzz_SetsForceApprovalRoles(uint8[] memory forceApprovalRoles) public {
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
      forceApprovalRoles,
      new uint8[](0)
    );
    for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
      assertEq(newStrategy.forceApprovalRole(forceApprovalRoles[i]), true);
    }
  }

  function testFuzz_SetsForceDisapprovalRoles(uint8[] memory forceDispprovalRoles) public {
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
      forceDispprovalRoles
    );
    for (uint256 i = 0; i < forceDispprovalRoles.length; i++) {
      assertEq(newStrategy.forceDisapprovalRole(forceDispprovalRoles[i]), true);
    }
  }

  function testFuzz_HandlesDuplicateApprovalRoles(uint8 _role) public {
    uint8[] memory forceApprovalRoles = new uint8[](2);
    forceApprovalRoles[0] = _role;
    forceApprovalRoles[1] = _role;
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
      forceApprovalRoles,
      new uint8[](0)
    );
    assertEq(newStrategy.forceApprovalRole(_role), true);
  }

  function testFuzz_HandlesDuplicateDisapprovalRoles(uint8 _role) public {
    uint8[] memory forceDispprovalRoles = new uint8[](2);
    forceDispprovalRoles[0] = _role;
    forceDispprovalRoles[1] = _role;
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
      forceDispprovalRoles
    );
    assertEq(newStrategy.forceDisapprovalRole(_role), true);
  }

  function testFuzz_EmitsNewStrategyCreatedEvent( /*TODO fuzz this test */ ) public {
    vm.expectEmit(true, true, true, true);
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

    _deployTestStrategy();

    for (uint256 i = 1; i < _numberOfPolicies + 1; i++) {
      address _policyHolder = address(uint160(i));
      if (mpPolicy.balanceOf(_policyHolder) == 0 && isRoleHolder[_policyHolder] == false) {
        _generateRoleHolder(_policyHolder);
      }
    }

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolders(roleHolders);

    uint256 actionId = _createAction();

    for (uint256 i = 1; i < _actionApprovals + 1; i++) {
      address _policyHolder = address(uint160(i));
      _approveAction(_policyHolder, actionId);
    }

    bool isActionPassed = testStrategy.isActionPassed(actionId);

    assertEq(isActionPassed, true);
  }

  function testFuzz_ReturnsFalseForFailedActions(uint256 _actionApprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionApprovals = bound(_actionApprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 4000, 10_000) - 1);

    _deployTestStrategy();

    for (uint256 i = 1; i < _numberOfPolicies + 1; i++) {
      address _policyHolder = address(uint160(i));
      if (mpPolicy.balanceOf(_policyHolder) == 0 && isRoleHolder[_policyHolder] == false) {
        _generateRoleHolder(_policyHolder);
      }
    }

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolders(roleHolders);

    uint256 actionId = _createAction();

    for (uint256 i = 1; i < _actionApprovals + 1; i++) {
      address _policyHolder = address(uint160(i));
      _approveAction(_policyHolder, actionId);
    }

    bool isActionPassed = testStrategy.isActionPassed(actionId);

    assertEq(isActionPassed, false);
  }

  function testFuzz_RevertsForNonExistentActionId(uint256 _actionId) public {
    vm.expectRevert(VertexCore.InvalidActionId.selector);
    vm.prank(address(adminAlice));
    mpCore.castApproval(_actionId, uint8(Roles.Admin));
  }
}

contract IsActionCancelationValid is VertexStrategyTest {
  function testFuzz_ReturnsTrueForDisapprovedActions(uint256 _actionDisapprovals, uint256 _numberOfPolicies) public {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals =
      bound(_actionDisapprovals, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000), _numberOfPolicies);

    _deployTestStrategyWithForceApproval();

    for (uint256 i = 1; i < _numberOfPolicies + 1; i++) {
      address _policyHolder = address(uint160(i));
      if (mpPolicy.balanceOf(_policyHolder) == 0 && isRoleHolder[_policyHolder] == false) {
        _generateRoleHolder(_policyHolder);
      }
    }

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolders(roleHolders);

    uint256 actionId = _createAction();

    vm.prank(address(adminAlice));
    mpCore.castApproval(actionId, uint8(Roles.Admin));

    mpCore.queueAction(actionId);

    for (uint256 i = 1; i < _actionDisapprovals + 1; i++) {
      address _policyHolder = address(uint160(i));
      _disapproveAction(_policyHolder, actionId);
    }

    bool isActionCancelled = testStrategy.isActionCancelationValid(actionId);

    assertEq(isActionCancelled, true);
  }

  function testFuzz_ReturnsFalseForActionsNotFullyDisapproved(uint256 _actionDisapprovals, uint256 _numberOfPolicies)
    public
  {
    _numberOfPolicies = bound(_numberOfPolicies, 2, 100);
    _actionDisapprovals = bound(_actionDisapprovals, 0, FixedPointMathLib.mulDivUp(_numberOfPolicies, 2000, 10_000) - 1);

    _deployTestStrategyWithForceApproval();

    for (uint256 i = 1; i < _numberOfPolicies + 1; i++) {
      address _policyHolder = address(uint160(i));
      if (mpPolicy.balanceOf(_policyHolder) == 0 && isRoleHolder[_policyHolder] == false) {
        _generateRoleHolder(_policyHolder);
      }
    }

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolders(roleHolders);

    uint256 actionId = _createAction();

    vm.prank(address(adminAlice));
    mpCore.castApproval(actionId, uint8(Roles.Admin));

    mpCore.queueAction(actionId);

    for (uint256 i = 1; i < _actionDisapprovals + 1; i++) {
      address _policyHolder = address(uint160(i));
      _disapproveAction(_policyHolder, actionId);
    }

    bool isActionCancelled = testStrategy.isActionCancelationValid(actionId);

    assertEq(isActionCancelled, false);
  }

  function testFuzz_RevertsForNonExistentActionId(uint256 _actionId) public {
    vm.expectRevert(VertexCore.InvalidActionId.selector);
    vm.prank(address(adminAlice));
    mpCore.castDisapproval(_actionId, uint8(Roles.Admin));
  }
}

contract GetApprovalWeightAt is VertexStrategyTest {
  function testFuzz_ReturnsZeroWeightPriorToAccountGainingPermission(
    uint256 _timeUntilPermission,
    uint8 _role,
    bytes32 _permission,
    // uint256 _weight,
    address _policyHolder
  ) public {
    vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    vm.warp(_timeUntilPermission);

    deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    assertEq(
      newStrategy.getApprovalWeightAt(_policyHolder, _role, _referenceTime),
      0 // there should be zero weight before permission was granted
    );
  }

  function testFuzz_ReturnsWeightAfterBlockThatAccountGainedPermission(
    uint256 _timeSincePermission, // no assume for this param, we want 0 tested
    bytes32 _permission,
    uint8 _role,
    // uint256 _weight,
    address _policyHolder
  ) public {
    vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );
    vm.warp(_timeSincePermission);
    assertEq(
      newStrategy.getApprovalWeightAt(
        _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
      ),
      1 // the account should still have the weight
    );
  }

  function testFuzz_ReturnsZeroWeightForNonPolicyHolders(uint64 _timestamp, uint8 _role, address _nonPolicyHolder)
    public
  {
    _timestamp = uint64(bound(_timestamp, block.timestamp + 1, type(uint64).max));
    vm.assume(_nonPolicyHolder != address(0));

    // Mock protocol users.
    vm.assume(_nonPolicyHolder != makeAddr("rootVertexAdmin"));
    vm.assume(_nonPolicyHolder != makeAddr("adminAlice"));
    vm.assume(_nonPolicyHolder != makeAddr("actionCreatorAaron"));
    vm.assume(_nonPolicyHolder != makeAddr("approverAdam"));
    vm.assume(_nonPolicyHolder != makeAddr("approverAlicia"));
    vm.assume(_nonPolicyHolder != makeAddr("approverAndy"));
    vm.assume(_nonPolicyHolder != makeAddr("disapproverDave"));
    vm.assume(_nonPolicyHolder != makeAddr("disapproverDiane"));
    vm.assume(_nonPolicyHolder != makeAddr("disapproverDrake"));

    deployStrategyAndSetRole(
      _role, bytes32(0), address(0xdeadbeef), 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getApprovalWeightAt(_nonPolicyHolder, _role, _timestamp - 1),
      0 // the account should not have a weight
    );
  }

  function testFuzz_ReturnsDefaultWeightForPolicyHolderWithoutExplicitWeight(
    uint256 _timestamp,
    bytes32 _permission,
    uint8 _role,
    address _policyHolder
  ) public {
    vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
    vm.assume(_policyHolder != address(0));

    deployStrategyAndSetRole(
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
      newStrategy.getApprovalWeightAt(_policyHolder, _role, _timestamp - 1),
      0 // the account should not have a weight
    );
  }
}

contract GetDisapprovalWeightAt is VertexStrategyTest {
  function testFuzz_ReturnsZeroWeightPriorToAccountGainingPermission(
    uint256 _timeUntilPermission,
    bytes32 _permission,
    uint8 _role,
    // uint256 _weight,
    address _policyHolder
  ) public {
    vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    vm.warp(_timeUntilPermission);

    deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    assertEq(
      newStrategy.getDisapprovalWeightAt(_policyHolder, _role, _referenceTime),
      0 // there should be zero weight before permission was granted
    );
  }

  function testFuzz_ReturnsWeightAfterBlockThatAccountGainedPermission(
    uint256 _timeSincePermission, // no assume for this param, we want 0 tested
    bytes32 _permission,
    uint8 _role,
    // uint256 _weight,
    address _policyHolder
  ) public {
    vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
    vm.assume(_role > 0);
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );
    vm.warp(_timeSincePermission);
    assertEq(
      newStrategy.getDisapprovalWeightAt(
        _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
      ),
      1 // the account should still have the weight
    );
  }

  function testFuzz_ReturnsZeroWeightForNonPolicyHolders(uint256 _timestamp, uint8 _role, address _nonPolicyHolder)
    public
  {
    vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
    vm.assume(_nonPolicyHolder != address(0));

    deployStrategyAndSetRole(
      _role, bytes32(0), address(0xdeadbeef), 1 days, 4 days, 1 days, true, 4000, 2000, new uint8[](0), new uint8[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getDisapprovalWeightAt(_nonPolicyHolder, _role, _timestamp - 1),
      0 // the account should not have a weight
    );
  }

  function testFuzz_ReturnsDefaultWeightForPolicyHolderWithoutExplicitWeight(
    uint256 _timestamp,
    bytes32 _permission,
    uint8 _role,
    address _policyHolder
  ) public {
    vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
    vm.assume(_policyHolder != address(0));

    deployStrategyAndSetRole(
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
      newStrategy.getDisapprovalWeightAt(_policyHolder, _role, _timestamp - 1),
      0 // the account should not have a weight
    );
  }
}

contract GetMinimumAmountNeeded is VertexStrategyTest {
  function testFuzz_calculatesMinimumAmountCorrectly(uint256 supply, uint256 minPct) public {
    minPct = bound(minPct, 0, 10_000);
    deployStrategyAndSetRole(
      uint8(Roles.TestRole1),
      bytes32(0),
      address(0xdeadbeef),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new uint8[](0),
      new uint8[](0)
    );
    vm.assume(minPct == 0 || supply <= type(uint256).max / minPct); // avoid solmate revert statement
    uint256 product = FixedPointMathLib.mulDivUp(supply, minPct, 10_000);
    assertEq(newStrategy.getMinimumAmountNeeded(supply, minPct), product);
  }
}
