// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployVertex} from "../script/DeployVertex.s.sol";
import {Test, console2} from "forge-std/Test.sol";

contract DeployVertexTest is Test {
  function setUp() public {}

  function test_David() public {
    console2.log("david", block.chainid);
    console2.log("david root creator", makeAddr("rootVertexActionCreator"));
    assertTrue(true);
  }

  // Once root vertex is deployed, deploy a new vertex with the factory
}
