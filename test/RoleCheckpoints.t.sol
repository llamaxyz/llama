// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Tests in this contract mirror those in OpenZeppelin's RoleCheckpoints.test.js, which is why
/// the tests are written in a different style than the rest of the tests in this repo (i.e. they
/// do not follow the "one contract per method" pattern).
/// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/d00acef4059807535af0bd0dd0ddf619747a044b/test/utils/RoleCheckpoints.test.js
import {Test, console2} from "forge-std/Test.sol";

import {RoleCheckpoints} from "src/lib/RoleCheckpoints.sol";

/// @dev The RoleCheckpointsMock harness contract has its external functions written according to
/// https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086
/// so that test coverage is captured for the Checkpoints library.
contract RoleCheckpointsMock {
  RoleCheckpoints.History private _totalCheckpoints;

  function printCheckpoints() public view {
    for (uint256 i = 0; i < length(); i++) {
      RoleCheckpoints.Checkpoint memory ckpt = _totalCheckpoints._checkpoints[i];
      console2.log(ckpt.timestamp, ckpt.quantity, ckpt.expiration);
    }
  }

  function latest() external view returns (uint256) {
    uint256 quantity = RoleCheckpoints.latest(_totalCheckpoints);
    return quantity;
  }

  function latestCheckpoint() public view returns (bool, uint256, uint256, uint256) {
    (bool exists, uint256 quantity, uint256 timestamp, uint256 expiration) =
      RoleCheckpoints.latestCheckpoint(_totalCheckpoints);
    return (exists, quantity, timestamp, expiration);
  }

  function length() public view returns (uint256) {
    uint256 numCkpts = RoleCheckpoints.length(_totalCheckpoints);
    return numCkpts;
  }

  function push(uint256 quantity, uint256 expiration) public returns (uint256, uint256) {
    (uint256 prevQty, uint256 newQty) = RoleCheckpoints.push(_totalCheckpoints, quantity, expiration);
    return (prevQty, newQty);
  }

  function getAtProbablyRecentTimestamp(uint256 timestamp) public view returns (uint256) {
    uint256 quantity = RoleCheckpoints.getAtProbablyRecentTimestamp(_totalCheckpoints, timestamp);
    return quantity;
  }
}

contract RoleCheckpointsTest is Test {
  RoleCheckpointsMock checkpoints;
  uint64 DEFAULT_EXPIRATION = type(uint64).max;

  function setUp() public virtual {
    checkpoints = new RoleCheckpointsMock();
  }
}

// ====================================
// ======== OpenZeppelin Tests ========
// ====================================
// All tests within this section mirror the tests in OpenZeppelin's RoleCheckpoints.test.js and
// therefore do not account for checkpoint expiration.

contract WithoutCheckpointsWithoutExpiration is RoleCheckpointsTest {
  function test_ReturnsZeroAsLatestValue() public {
    assertEq(checkpoints.latest(), 0);

    (bool exists, uint256 timestamp,, uint256 quantity) = checkpoints.latestCheckpoint();
    assertEq(exists, false);
    assertEq(timestamp, 0);
    assertEq(quantity, 0);
  }
}

contract WithCheckpointsWithoutExpiration is RoleCheckpointsTest {
  uint256 t0;
  uint256 t1;
  uint256 t2;

  function setUp() public override {
    RoleCheckpointsTest.setUp();

    vm.warp(block.timestamp + 1);
    t0 = block.timestamp;
    checkpoints.push(1, DEFAULT_EXPIRATION);

    vm.warp(block.timestamp + 1);
    t1 = block.timestamp;
    checkpoints.push(2, DEFAULT_EXPIRATION);

    vm.warp(block.timestamp + 2);
    t2 = block.timestamp;
    checkpoints.push(3, DEFAULT_EXPIRATION);

    vm.warp(block.timestamp + 3);
  }

  function test_ReturnsLatestValue() public {
    assertEq(checkpoints.latest(), 3);

    (bool exists, uint256 timestamp,, uint256 quantity) = checkpoints.latestCheckpoint();
    assertEq(exists, true);
    assertEq(timestamp, t2);
    assertEq(quantity, 3);
  }

  function test_Lookup_ProbablyRecentTimestamp_ReturnsPastValues() public {
    assertEq(checkpoints.getAtProbablyRecentTimestamp(t0 - 1), 0);
    assertEq(checkpoints.getAtProbablyRecentTimestamp(t0), 1);
    assertEq(checkpoints.getAtProbablyRecentTimestamp(t1), 2);

    assertEq(checkpoints.getAtProbablyRecentTimestamp(t1 + 1), 2);
    assertEq(checkpoints.getAtProbablyRecentTimestamp(t2), 3);
    assertEq(checkpoints.getAtProbablyRecentTimestamp(t2 + 1), 3);
  }

  function test_Lookup_ProbablyRecentTimestamp_RevertIf_BlockTimestampEqualsCurrentTimestamp() public {
    vm.expectRevert("Checkpoints: timestamp is not in the past");
    checkpoints.getAtProbablyRecentTimestamp(block.timestamp);
  }

  function test_Lookup_ProbablyRecentTimestamp_RevertIf_BlockTimestampGreaterThanCurrentTimestamp() public {
    vm.expectRevert("Checkpoints: timestamp is not in the past");
    checkpoints.getAtProbablyRecentTimestamp(block.timestamp + 1);
  }

  function test_MultipleCheckpointsAtTheSameTimestamp() public {
    uint256 lengthBefore = checkpoints.length();

    checkpoints.push(8, DEFAULT_EXPIRATION);
    checkpoints.push(9, DEFAULT_EXPIRATION);
    checkpoints.push(10, DEFAULT_EXPIRATION);

    vm.warp(block.timestamp + 1);

    assertEq(checkpoints.length(), lengthBefore + 1);
    assertEq(checkpoints.latest(), 10);
  }
}

// ===========================
// ======== Our Tests ========
// ===========================
// Modification of the above tests to account for checkpoint expiration.

contract WithoutCheckpointsWithExpiration is RoleCheckpointsTest {
  function test_ReturnsZeroAsLatestValue() public {
    assertEq(checkpoints.latest(), 0);

    (bool exists, uint256 timestamp, uint256 expiration, uint256 quantity) = checkpoints.latestCheckpoint();
    assertEq(exists, false);
    assertEq(timestamp, 0);
    assertEq(expiration, 0);
    assertEq(quantity, 0);
  }
}

contract WithCheckpointsWithExpiration is RoleCheckpointsTest {
  uint256 t0;
  uint256 t1;
  uint256 t2;

  function setUp() public override {
    RoleCheckpointsTest.setUp();

    vm.warp(block.timestamp + 1);
    t0 = block.timestamp;
    checkpoints.push(1, 10);

    vm.warp(block.timestamp + 1);
    t1 = block.timestamp;
    checkpoints.push(2, 20);

    vm.warp(block.timestamp + 2);
    t2 = block.timestamp;
    checkpoints.push(3, 30);

    vm.warp(block.timestamp + 3);
  }

  function test_ReturnsLatestValue() public {
    assertEq(checkpoints.latest(), 3);

    (bool exists, uint256 timestamp, uint256 expiration, uint256 quantity) = checkpoints.latestCheckpoint();
    assertEq(exists, true);
    assertEq(timestamp, t2);
    assertEq(expiration, 30);
    assertEq(quantity, 3);
  }

  function test_Lookup_ProbablyRecentTimestamp_RevertIf_BlockTimestampEqualsCurrentTimestamp() public {
    vm.expectRevert("Checkpoints: timestamp is not in the past");
    checkpoints.getAtProbablyRecentTimestamp(block.timestamp);
  }

  function test_Lookup_ProbablyRecentTimestamp_RevertIf_BlockTimestampGreaterThanCurrentTimestamp() public {
    vm.expectRevert("Checkpoints: timestamp is not in the past");
    checkpoints.getAtProbablyRecentTimestamp(block.timestamp + 1);
  }

  function test_MultipleCheckpointsAtTheSameTimestamp() public {
    uint256 lengthBefore = checkpoints.length();

    checkpoints.push(8, 80);
    checkpoints.push(9, 90);
    checkpoints.push(10, 100);

    vm.warp(block.timestamp + 1);

    assertEq(checkpoints.length(), lengthBefore + 1);
    assertEq(checkpoints.latest(), 10);

    (bool exists,, uint256 expiration, uint256 quantity) = checkpoints.latestCheckpoint();
    assertEq(exists, true);
    assertEq(expiration, 100);
    assertEq(quantity, 10);
  }
}
