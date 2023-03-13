// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @dev Tests in this contract mirror those in OpenZeppelin's Checkpoints.test.js, which is why
/// the tests are written in a different style than the rest of the tests in this repo (i.e. they
/// do not follow the "one contract per method" pattern).
/// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/d00acef4059807535af0bd0dd0ddf619747a044b/test/utils/Checkpoints.test.js
import {Test, console2} from "forge-std/Test.sol";
import {Checkpoints} from "src/lib/Checkpoints.sol";

contract CheckpointsMock {
  using Checkpoints for Checkpoints.History;

  Checkpoints.History private _totalCheckpoints;

  function latest() public view returns (uint256 quantity) {
    return _totalCheckpoints.latest();
  }

  function latestCheckpoint() public view returns (bool exists, uint256 timestamp, uint256 quantity) {
    return _totalCheckpoints.latestCheckpoint();
  }

  function length() public view returns (uint256 numCkpts) {
    return _totalCheckpoints.length();
  }

  function push(uint256 value) public returns (uint256 prevQty, uint256 newQty) {
    return _totalCheckpoints.push(value);
  }

  function getAtTimestamp(uint256 blockNumber) public view returns (uint256 quantity) {
    return _totalCheckpoints.getAtTimestamp(blockNumber);
  }

  function getAtProbablyRecentTimestamp(uint256 blockNumber) public view returns (uint256 quantity) {
    return _totalCheckpoints.getAtProbablyRecentTimestamp(blockNumber);
  }
}

contract CheckpointsTest is Test {
  CheckpointsMock checkpoints;

  function setUp() public virtual {
    checkpoints = new CheckpointsMock();
  }
}

contract WithoutCheckpoints is CheckpointsTest {
  function test_ReturnsZeroAsLatestValue() public {
    assertEq(checkpoints.latest(), 0);

    (bool exists, uint256 timestamp, uint256 quantity) = checkpoints.latestCheckpoint();
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

contract WithCheckpoints is CheckpointsTest {
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

    (bool exists, uint256 timestamp, uint256 quantity) = checkpoints.latestCheckpoint();
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
