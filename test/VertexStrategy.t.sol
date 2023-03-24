// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexTestSetup} from "test/utils/VertexTestSetup.sol";
import {RoleHolderData, RolePermissionData, Strategy} from "src/lib/Structs.sol";

contract VertexStrategyTest is VertexTestSetup {
  RoleHolderData[] roleHolders;
  RolePermissionData[] rolePermissions;
  Strategy strategy;
  Strategy[] strategies;
  VertexStrategy newStrategy;

  function deployStrategyAndSetRole(
    bytes32 _role,
    bytes32 _permission,
    address _policyHolder,
    uint256 _queuingDuration,
    uint256 _expirationDelay,
    uint256 _approvalPeriod,
    bool _isFixedLengthApprovalPeriod,
    uint256 _minApprovalPct,
    uint256 _minDisapprovalPct,
    bytes32[] memory _forceApprovalRoles,
    bytes32[] memory _forceDisapprovalRoles
  ) public {
    roleHolders.push(RoleHolderData(_role, _policyHolder, type(uint64).max));
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

  // function setUp() public virtual override {
  //   // TODO shared setup
  // }

  // TODO shared helpers
}

contract Constructor is VertexStrategyTest {
  function testFuzz_SetsStrategyStorageQueuingDuration(uint256 _queuingDuration) public {
    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      address(this),
      _queuingDuration,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
    );
    assertEq(newStrategy.queuingPeriod(), _queuingDuration);
  }

  function testFuzz_SetsStrategyStorageExpirationDelay(uint256 _expirationDelay) public {
    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      address(this),
      1 days,
      _expirationDelay,
      1 days,
      true,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
    );
    assertEq(newStrategy.expirationPeriod(), _expirationDelay);
  }

  function test_SetsStrategyStorageIsFixedLengthApprovalPeriod(bool _isFixedLengthApprovalPeriod) public {
    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      _isFixedLengthApprovalPeriod,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
    );
    assertEq(newStrategy.isFixedLengthApprovalPeriod(), _isFixedLengthApprovalPeriod);
  }

  function testFuzz_SetsStrategyStorageApprovalPeriod(uint256 _approvalPeriod) public {
    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      _approvalPeriod,
      true,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
    );
    assertEq(newStrategy.approvalPeriod(), _approvalPeriod);
  }

  function testFuzz_SetsStrategyStoragePolicy() public {
    //TODO actually use fuzzing in this test
    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
    );
    assertEq(address(newStrategy.policy()), address(mpPolicy));
  }

  function testFuzz_SetsStrategyStorageVertex(address _vertex) public {
    //TODO actually use fuzzing in this test
    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
    );
    assertEq(address(newStrategy.vertex()), address(mpCore));
  }

  function testFuzz_SetsStrategyStorageMinApprovalPct(uint256 _percent) public {
    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      _percent,
      2000,
      new bytes32[](0),
      new bytes32[](0)
    );
    assertEq(newStrategy.minApprovalPct(), _percent);
  }

  function testFuzz_SetsStrategyStorageMinDisapprovalPct(uint256 _percent) public {
    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      address(this),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      _percent,
      new bytes32[](0),
      new bytes32[](0)
    );
    assertEq(newStrategy.minDisapprovalPct(), _percent);
  }

  function test_SetsStrategyStorageDefaultOperatorWeights() public {
    // TODO
    // assert approvalWeightByPermission[DEFAULT_OPERATOR] = 1;
    // assert disapprovalWeightByPermission[DEFAULT_OPERATOR] = 1;
  }

  function testFuzz_CanOverrideDefaultOperatorWeights(uint256 _approvalWeight, uint256 _disapprovalWeight) public {
    // TODO
    // assert that the default weights can be overridden with the fuzz weights
    // assert approvalWeightByPermission[DEFAULT_OPERATOR] = _approvalWeight;
    // assert disapprovalWeightByPermission[DEFAULT_OPERATOR] = _disapprovalWeight;
  }

  function testFuzz_SetsApprovalPermissions( /*TODO decide on fuzz params*/ ) public {
    // TODO
    // deploy with strategyConfig.approvalWeightByPermission.length > 1
    // assert approvalWeightByPermission is stored accordingly
  }

  function testFuzz_HandlesDuplicateApprovalPermissions( /*TODO decide on fuzz params*/ ) public {
    // TODO
    // deploy with strategyConfig.approvalWeightByPermission.length > 1.
    // The strategyConfig.approvalWeightByPermission array should include duplicate
    // permissions with different weights.
    // Assert that only the final weight in the array is saved.
  }

  function testFuzz_SetsDisapprovalPermissions( /*TODO decide on fuzz params*/ ) public {
    // TODO
    // deploy with strategyConfig.approvalWeightByPermission.length > 1
    // assert disapprovalWeightByPermission is stored accordingly
  }

  function testFuzz_HandlesDuplicateDisapprovalPermissions( /*TODO decide on fuzz params*/ ) public {
    // TODO
    // deploy with strategyConfig.approvalWeightByPermission.length > 1.
    // The strategyConfig.disapprovalWeightByPermission array should include duplicate
    // permissions with different weights.
    // Assert that only the final weight in the array is saved.
  }

  function testFuzz_EmitsNewStrategyCreatedEvent(address _vertex, address _policy) public {
    // TODO
    // assert emits NewStrategyCreated event
  }
}

contract IsActionPassed is VertexStrategyTest {
  function testFuzz_ReturnsTrueForPassedActions(uint256 _actionApprovals) public {
    // TODO
    // call isActionPassed on an action that has sufficient (random) num of votes
    // assert response is true
  }

  function testFuzz_ReturnsFalseForFailedActions(uint256 _actionApprovals) public {
    // TODO
    // call isActionPassed on an action that has insufficient (random) num of votes
    // assert response is false
  }

  function testFuzz_RevertsForNonExistentActionId(uint256 _actionId) public {
    // TODO
    // what if nonexistent actionId is passed in? I think this will return true
    // currently but it should probably revert
  }

  function testFuzz_RoundsCorrectly(uint256 _actionAppovals) public {
    // TODO
    // what happens if the minAppovalPct rounds the action.approvalPolicySupply
    // the wrong way?
  }
}

contract IsActionCancelationValid is VertexStrategyTest {
  function testFuzz_ReturnsTrueForDisapprovedActions(uint256 _actionDisapprovals) public {
    // TODO
    // call isActionCancelationValid on an action that has sufficient (random)
    // num of disapprovals. assert response is true
  }

  function testFuzz_ReturnsFalseForActionsNotFullyDisapproved(uint256 _actionApprovals) public {
    // TODO
    // call isActionPassed on an action that has insufficient (random) num of
    // disapprovals. assert response is false
  }

  function testFuzz_RevertsForNonExistentActionId(uint256 _actionId) public {
    // TODO
    // what if nonexistent actionId is passed in? I think this will return true
    // currently but it should probably revert
  }

  function testFuzz_RoundsCorrectly(uint256 _actionAppovals) public {
    // TODO
    // what happens if the minDisapprovalPct rounds the
    // action.disapprovalPolicySupply the wrong way?
  }
}

contract GetApprovalWeightAt is VertexStrategyTest {
  function testFuzz_ReturnsZeroWeightPriorToAccountGainingPermission(
    uint256 _timeUntilPermission,
    bytes32 _role,
    bytes32 _permission,
    // uint256 _weight,
    address _policyHolder
  ) public {
    // TODO
    vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
    vm.assume(_role > bytes32(0));
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    vm.warp(_timeUntilPermission);

    deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new bytes32[](0), new bytes32[](0)
    );

    assertEq(
      newStrategy.getApprovalWeightAt(_policyHolder, _role, _referenceTime),
      0 // there should be zero weight before permission was granted
    );
  }

  function testFuzz_ReturnsWeightAfterBlockThatAccountGainedPermission(
    uint256 _timeSincePermission, // no assume for this param, we want 0 tested
    bytes32 _permission,
    bytes32 _role,
    // uint256 _weight,
    address _policyHolder
  ) public {
    vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
    vm.assume(_role > bytes32(0));
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new bytes32[](0), new bytes32[](0)
    );
    vm.warp(_timeSincePermission);
    assertEq(
      newStrategy.getApprovalWeightAt(
        _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
      ),
      1 // the account should still have the weight
    );
  }

  function testFuzz_ReturnsZeroWeightForNonPolicyHolders(uint64 _timestamp, bytes32 _role, address _nonPolicyHolder)
    public
  {
    vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
    vm.assume(_nonPolicyHolder != address(0));

    deployStrategyAndSetRole(
      _role,
      bytes32(0),
      address(0xdeadbeef),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
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
    bytes32 _role,
    address _policyHolder
  ) public {
    vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
    vm.assume(_policyHolder != address(0));

    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      _policyHolder,
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
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
    bytes32 _role,
    // uint256 _weight,
    address _policyHolder
  ) public {
    vm.assume(_timeUntilPermission > block.timestamp && _timeUntilPermission < type(uint64).max);
    vm.assume(_role > bytes32(0));
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    vm.warp(_timeUntilPermission);

    deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new bytes32[](0), new bytes32[](0)
    );

    assertEq(
      newStrategy.getDisapprovalWeightAt(_policyHolder, _role, _referenceTime),
      0 // there should be zero weight before permission was granted
    );
  }

  function testFuzz_ReturnsWeightAfterBlockThatAccountGainedPermission(
    uint256 _timeSincePermission, // no assume for this param, we want 0 tested
    bytes32 _permission,
    bytes32 _role,
    // uint256 _weight,
    address _policyHolder
  ) public {
    vm.assume(_timeSincePermission > block.timestamp && _timeSincePermission < type(uint64).max);
    vm.assume(_role > bytes32(0));
    vm.assume(_permission > bytes32(0));
    vm.assume(_policyHolder != address(0));
    uint256 _referenceTime = block.timestamp;
    deployStrategyAndSetRole(
      _role, _permission, _policyHolder, 1 days, 4 days, 1 days, true, 4000, 2000, new bytes32[](0), new bytes32[](0)
    );
    vm.warp(_timeSincePermission);
    assertEq(
      newStrategy.getDisapprovalWeightAt(
        _policyHolder, _role, _timeSincePermission > 0 ? _timeSincePermission - 1 : _timeSincePermission
      ),
      1 // the account should still have the weight
    );
  }

  function testFuzz_ReturnsZeroWeightForNonPolicyHolders(uint256 _timestamp, bytes32 _role, address _nonPolicyHolder)
    public
  {
    vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
    vm.assume(_nonPolicyHolder != address(0));

    deployStrategyAndSetRole(
      _role,
      bytes32(0),
      address(0xdeadbeef),
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
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
    bytes32 _role,
    address _policyHolder
  ) public {
    vm.assume(_timestamp > block.timestamp && _timestamp < type(uint64).max);
    vm.assume(_policyHolder != address(0));

    deployStrategyAndSetRole(
      bytes32(0),
      bytes32(0),
      _policyHolder,
      1 days,
      4 days,
      1 days,
      true,
      4000,
      2000,
      new bytes32[](0),
      new bytes32[](0)
    );

    vm.warp(_timestamp);

    assertEq(
      newStrategy.getDisapprovalWeightAt(_policyHolder, _role, _timestamp - 1),
      0 // the account should not have a weight
    );
  }
}
