// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract VertexStrategyTest is Test {
  function setUp() virtual {
    // TODO shared setup
  }

  // TODO shared helpers
}

contract Constructor is VertexStrategyTest {
  function testFuzz_SetsStrategyStorageVars() public {
    // TODO
    // fuzz over all of the following:
    //   assert queuingDuration
    //   assert expirationDelay
    //   assert isFixedLengthApprovalPeriod
    //   assert approvalPeriod
    //   assert policy
    //   assert vertex
    //   assert minApprovalPct
    //   assert minDisapprovalPct
    //
    //   assert default operator weights
    //
    //   assert emits NewStrategyCreated event
  }

  function test_SetsApprovalPermissionWeight() public {
    // TODO
    // assert permissions have expected approval weights
  }

  function test_SetsDisapprovalPermissionWeight() public {
    // TODO
    // assert permissions have expected disapproval weights
  }

  function test_DuplicatePermissionsGetLastWeight() public {
    // TODO
    // assert that if there are duplicate permissions in
    // strategyConfig.approvalWeightByPermission array, then the weight that
    // gets set is the last weight for that permission in the array.
    // Likewise for strategyConfig.disapprovalWeightByPermission.
  }
}

contract IsActionPassed is VertexStrategyTest {
}

contract IsCancelationValid is VertexStrategyTest {
}

contract GetApprovalWeightAt is VertexStrategyTest {
}

contract GetDisapprovalWeightAt is VertexStrategyTest {
}

contract IsApprovalQuorumValid is VertexStrategyTest {
}

contract IsDisapprovalQuorumValid is VertexStrategyTest {
}
