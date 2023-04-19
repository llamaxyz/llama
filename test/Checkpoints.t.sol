// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Tests in this contract mirror those in OpenZeppelin's Checkpoints.test.js, which is why
/// the tests are written in a different style than the rest of the tests in this repo (i.e. they
/// do not follow the "one contract per method" pattern).
/// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/d00acef4059807535af0bd0dd0ddf619747a044b/test/utils/Checkpoints.test.js
import {Test, console2} from "forge-std/Test.sol";

import {Checkpoints} from "src/lib/Checkpoints.sol";

/// @dev The CheckpointsMock harness contract has its external functions written according to
/// https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086
/// so that test coverage is captured for the Checkpoints library.
contract CheckpointsMock {
  Checkpoints.History private _totalCheckpoints;

  function print() public view {
    for (uint256 i = 0; i < length(); i++) {
      Checkpoints.Checkpoint memory ckpt = _totalCheckpoints._checkpoints[i];
      console2.log(ckpt.timestamp, ckpt.quantity, ckpt.expiration);
    }
  }

  function latest() external view returns (uint256) {
    uint256 quantity = Checkpoints.latest(_totalCheckpoints);
    return quantity;
  }

  function latestCheckpoint() public view returns (bool, uint256, uint256, uint256) {
    (bool exists, uint256 quantity, uint256 timestamp, uint256 expiration) =
      Checkpoints.latestCheckpoint(_totalCheckpoints);
    return (exists, quantity, timestamp, expiration);
  }

  function length() public view returns (uint256) {
    uint256 numCkpts = Checkpoints.length(_totalCheckpoints);
    return numCkpts;
  }

  function push(uint256 quantity) public returns (uint256, uint256) {
    (uint256 prevQty, uint256 newQty) = Checkpoints.push(_totalCheckpoints, quantity);
    return (prevQty, newQty);
  }

  function push(uint256 quantity, uint256 expiration) public returns (uint256, uint256) {
    (uint256 prevQty, uint256 newQty) = Checkpoints.push(_totalCheckpoints, quantity, expiration);
    return (prevQty, newQty);
  }

  function getAtTimestamp(uint256 timestamp) public view returns (uint256) {
    uint256 quantity = Checkpoints.getAtTimestamp(_totalCheckpoints, timestamp);
    return quantity;
  }

  function getAtProbablyRecentTimestamp(uint256 timestamp) public view returns (uint256) {
    uint256 quantity = Checkpoints.getAtProbablyRecentTimestamp(_totalCheckpoints, timestamp);
    return quantity;
  }

  function getCheckpointAtTimestamp(uint256 timestamp) public view returns (uint256, uint256) {
    (uint256 quantity, uint256 expiration) = Checkpoints.getCheckpointAtTimestamp(_totalCheckpoints, timestamp);
    return (quantity, expiration);
  }

  function getCheckpointAtProbablyRecentTimestamp(uint256 timestamp) public view returns (uint256, uint256) {
    (uint256 quantity, uint256 expiration) =
      Checkpoints.getCheckpointAtProbablyRecentTimestamp(_totalCheckpoints, timestamp);
    return (quantity, expiration);
  }
}

contract CheckpointsTest is Test {
  CheckpointsMock checkpoints;

  function setUp() public virtual {
    checkpoints = new CheckpointsMock();
  }
}

// ====================================
// ======== OpenZeppelin Tests ========
// ====================================
// All tests within this section mirror the tests in OpenZeppelin's Checkpoints.test.js and
// therefore do not account for checkpoint expiration.

contract WithoutCheckpointsWithoutExpiration is CheckpointsTest {
  function test_ReturnsZeroAsLatestValue() public {
    assertEq(checkpoints.latest(), 0);

    (bool exists, uint256 timestamp,, uint256 quantity) = checkpoints.latestCheckpoint();
    assertEq(exists, false);
    assertEq(timestamp, 0);
    assertEq(quantity, 0);
  }

  function test_ReturnsZeroAsPastValue() public {
    vm.warp(block.timestamp + 1);

    uint256 quantity = checkpoints.getAtTimestamp(block.timestamp - 1);
    assertEq(quantity, 0);
    quantity = checkpoints.getAtProbablyRecentTimestamp(block.timestamp - 1);
    assertEq(quantity, 0);
  }
}

contract WithCheckpointsWithoutExpiration is CheckpointsTest {
  uint256 t0;
  uint256 t1;
  uint256 t2;

  function setUp() public override {
    CheckpointsTest.setUp();

    vm.warp(block.timestamp + 1);
    t0 = block.timestamp;
    checkpoints.push(1);

    vm.warp(block.timestamp + 1);
    t1 = block.timestamp;
    checkpoints.push(2);

    vm.warp(block.timestamp + 2);
    t2 = block.timestamp;
    checkpoints.push(3);

    vm.warp(block.timestamp + 3);
  }

  function test_ReturnsLatestValue() public {
    assertEq(checkpoints.latest(), 3);

    (bool exists, uint256 timestamp,, uint256 quantity) = checkpoints.latestCheckpoint();
    assertEq(exists, true);
    assertEq(timestamp, t2);
    assertEq(quantity, 3);
  }

  function test_Lookup_GetAtTimestamp_ReturnsPastValues() public {
    assertEq(checkpoints.getAtTimestamp(t0 - 1), 0);
    assertEq(checkpoints.getAtTimestamp(t0), 1);
    assertEq(checkpoints.getAtTimestamp(t1), 2);

    assertEq(checkpoints.getAtTimestamp(t1 + 1), 2);
    assertEq(checkpoints.getAtTimestamp(t2), 3);
    assertEq(checkpoints.getAtTimestamp(t2 + 1), 3);
  }

  function test_Lookup_GetAtTimestamp_RevertIf_BlockTimestampEqualsCurrentTimestamp() public {
    vm.expectRevert("Checkpoints: timestamp is not in the past");
    checkpoints.getAtTimestamp(block.timestamp);
  }

  function test_Lookup_GetAtTimestamp_RevertIf_BlockTimestampGreaterThanCurrentTimestamp() public {
    vm.expectRevert("Checkpoints: timestamp is not in the past");
    checkpoints.getAtTimestamp(block.timestamp + 1);
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

    checkpoints.push(8);
    checkpoints.push(9);
    checkpoints.push(10);

    vm.warp(block.timestamp + 1);

    assertEq(checkpoints.length(), lengthBefore + 1);
    assertEq(checkpoints.latest(), 10);
  }

  function test_MoreThan5Checkpoints() public {
    checkpoints.push(4);
    vm.warp(block.timestamp + 1);
    checkpoints.push(5);
    vm.warp(block.timestamp + 1);
    checkpoints.push(6);

    assertEq(checkpoints.length(), 6);

    assertEq(checkpoints.getAtTimestamp(block.timestamp - 1), 5);
    assertEq(checkpoints.getAtTimestamp(block.timestamp - 9), 0);

    assertEq(checkpoints.getAtProbablyRecentTimestamp(block.timestamp - 1), 5);
    assertEq(checkpoints.getAtProbablyRecentTimestamp(block.timestamp - 9), 0);
  }
}

// ===========================
// ======== Our Tests ========
// ===========================
// Modification of the above tests to account for checkpoint expiration.

contract WithoutCheckpointsWithExpiration is CheckpointsTest {
  function test_ReturnsZeroAsLatestValue() public {
    assertEq(checkpoints.latest(), 0);

    (bool exists, uint256 timestamp, uint256 expiration, uint256 quantity) = checkpoints.latestCheckpoint();
    assertEq(exists, false);
    assertEq(timestamp, 0);
    assertEq(expiration, 0);
    assertEq(quantity, 0);
  }

  function test_ReturnsZeroAsPastValue() public {
    vm.warp(block.timestamp + 1);

    (uint256 quantity, uint256 expiration) = checkpoints.getCheckpointAtTimestamp(block.timestamp - 1);
    assertEq(quantity, 0);
    assertEq(expiration, 0);
    (quantity, expiration) = checkpoints.getCheckpointAtProbablyRecentTimestamp(block.timestamp - 1);
    assertEq(quantity, 0);
    assertEq(expiration, 0);
  }
}

contract WithCheckpointsWithExpiration is CheckpointsTest {
  uint256 t0;
  uint256 t1;
  uint256 t2;

  function setUp() public override {
    CheckpointsTest.setUp();

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

  function test_Lookup_GetAtTimestamp_ReturnsPastValues() public {
    (uint256 quantity, uint256 expiration) = checkpoints.getCheckpointAtTimestamp(t0 - 1);
    assertEq(quantity, 0);
    assertEq(expiration, 0);

    (quantity, expiration) = checkpoints.getCheckpointAtTimestamp(t0);
    assertEq(quantity, 1);
    assertEq(expiration, 10);

    (quantity, expiration) = checkpoints.getCheckpointAtTimestamp(t1);
    assertEq(quantity, 2);
    assertEq(expiration, 20);

    (quantity, expiration) = checkpoints.getCheckpointAtTimestamp(t1 + 1);
    assertEq(quantity, 2);
    assertEq(expiration, 20);

    (quantity, expiration) = checkpoints.getCheckpointAtTimestamp(t2);
    assertEq(quantity, 3);
    assertEq(expiration, 30);

    (quantity, expiration) = checkpoints.getCheckpointAtTimestamp(t2 + 1);
    assertEq(quantity, 3);
    assertEq(expiration, 30);
  }

  function test_Lookup_GetAtTimestamp_RevertIf_BlockTimestampEqualsCurrentTimestamp() public {
    vm.expectRevert("Checkpoints: timestamp is not in the past");
    checkpoints.getAtTimestamp(block.timestamp);
  }

  function test_Lookup_GetAtTimestamp_RevertIf_BlockTimestampGreaterThanCurrentTimestamp() public {
    vm.expectRevert("Checkpoints: timestamp is not in the past");
    checkpoints.getAtTimestamp(block.timestamp + 1);
  }

  function test_Lookup_ProbablyRecentTimestamp_ReturnsPastValues() public {
    (uint256 quantity, uint256 expiration) = checkpoints.getCheckpointAtProbablyRecentTimestamp(t0 - 1);
    assertEq(quantity, 0);
    assertEq(expiration, 0);

    (quantity, expiration) = checkpoints.getCheckpointAtProbablyRecentTimestamp(t0);
    assertEq(quantity, 1);
    assertEq(expiration, 10);

    (quantity, expiration) = checkpoints.getCheckpointAtProbablyRecentTimestamp(t1);
    assertEq(quantity, 2);
    assertEq(expiration, 20);

    (quantity, expiration) = checkpoints.getCheckpointAtProbablyRecentTimestamp(t1 + 1);
    assertEq(quantity, 2);
    assertEq(expiration, 20);

    (quantity, expiration) = checkpoints.getCheckpointAtProbablyRecentTimestamp(t2);
    assertEq(quantity, 3);
    assertEq(expiration, 30);

    (quantity, expiration) = checkpoints.getCheckpointAtProbablyRecentTimestamp(t2 + 1);
    assertEq(quantity, 3);
    assertEq(expiration, 30);
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

  function test_MoreThan5Checkpoints() public {
    checkpoints.push(4, 40);
    vm.warp(block.timestamp + 1);
    checkpoints.push(5, 50);
    vm.warp(block.timestamp + 1);
    checkpoints.push(6, 60);

    assertEq(checkpoints.length(), 6);

    (uint256 quantity, uint256 expiration) = checkpoints.getCheckpointAtTimestamp(block.timestamp - 1);
    assertEq(quantity, 5);
    assertEq(expiration, 50);

    (quantity, expiration) = checkpoints.getCheckpointAtTimestamp(block.timestamp - 9);
    assertEq(quantity, 0);
    assertEq(expiration, 0);

    (quantity, expiration) = checkpoints.getCheckpointAtProbablyRecentTimestamp(block.timestamp - 1);
    assertEq(quantity, 5);
    assertEq(expiration, 50);

    (quantity, expiration) = checkpoints.getCheckpointAtProbablyRecentTimestamp(block.timestamp - 9);
    assertEq(quantity, 0);
    assertEq(expiration, 0);
  }
}
