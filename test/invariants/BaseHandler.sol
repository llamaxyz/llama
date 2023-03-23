// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {Strategy} from "src/lib/Structs.sol";
import {VertexCoreTest} from "test/VertexCore.t.sol";

contract BaseHandler is CommonBase, StdCheats, StdUtils {
  // =========================
  // ======== Storage ========
  // =========================

  // Protocol contracts.
  VertexFactory public immutable vertexFactory;
  VertexCore public immutable vertexCore;
  VertexPolicy public immutable policy;

  // Handler state.
  address[] internal actors;
  uint256[] internal timestamps;
  uint256 currentTimestamp;

  bytes32[] internal permissionIds; // All Permission IDs seen.
  mapping(bytes8 => bool) internal havePermissionId; // Whether a Permission ID has been seen.

  // Metrics.
  mapping(string => uint256) public calls;

  // =============================
  // ======== Constructor ========
  // =============================

  constructor(VertexFactory _vertexFactory, VertexCore _vertexCore) {
    vertexFactory = _vertexFactory;
    vertexCore = _vertexCore;
    policy = vertexCore.policy();
  }

  // =================================================
  // ======== Methods and Modifiers for Users ========
  // =================================================

  // -------- Metrics --------
  // Used to record the number of times each method on a handler contract is called.
  modifier recordCall(string memory name) {
    calls[name]++;
    _;
  }

  // Used to record code paths hit within invariant tests, but for simplicity it uses the same mapping.
  function recordMetric(string memory name) public {
    calls[name]++;
  }

  function callSummary() public view virtual {
    // In the most-derived handler contract, implement your own `callSummary` method that
    // overrides this and calls `super.callSummary()`. Then in the invariant test contract add
    // add a test like this:
    //   function invariant_CallSummary() public view {
    //     handler.callSummary();
    //    }
    console2.log("\n  \u001b[01mCall Summary\u001b[0m");
    console2.log("-----------------------------------------------");
    console2.log("handler_addActor                 ", calls["handler_addActor"]);
    console2.log("handler_increaseTimestampBy      ", calls["handler_increaseTimestampBy"]);
  }

  // -------- Actor Management --------
  modifier useActor(uint256 seed) {
    if (actors.length == 0) handler_addActor();
    vm.startPrank(actors[seed % actors.length]);
    _;
    vm.stopPrank();
  }

  function handler_addActor() public recordCall("handler_addActor") {
    string memory actorName = string(abi.encodePacked("actor", vm.toString(actors.length)));
    actors.push(makeAddr(actorName));
  }

  function getActors() public view returns (address[] memory) {
    return actors;
  }

  // -------- Timestamp Management --------
  modifier useCurrentTimestamp() {
    vm.warp(currentTimestamp);
    _;
  }

  modifier useCurrentTimestampThenIncreaseTimestampBy(uint256 timeToIncrease) {
    vm.warp(currentTimestamp);
    _;
    handler_increaseTimestampBy(timeToIncrease);
  }

  function handler_increaseTimestampBy(uint256 timeToIncrease) public recordCall("handler_increaseTimestampBy") {
    timeToIncrease = bound(timeToIncrease, 0, 8 weeks);
    uint256 newTimestamp = currentTimestamp + timeToIncrease;
    timestamps.push(newTimestamp);
    currentTimestamp = newTimestamp;
  }

  // -------- Generic Helpers --------
  function recordPermissionId(bytes8 permissionId) public {
    if (!havePermissionId[permissionId]) {
      permissionIds.push(permissionId);
      havePermissionId[permissionId] = true;
    }
  }

  function getPermissionIds() public view returns (bytes32[] memory) {
    return permissionIds;
  }

  function getPolicyIds() public view returns (uint256[] memory) {
    uint256[] memory policyIds = new uint256[](actors.length);
    for (uint256 i = 0; i < actors.length; i++) {
      uint256 policyId = uint256(uint160(actors[i]));
      policyIds[i] = policyId;
    }
    return policyIds;
  }
}
