// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployVertexFactory} from '../script/DeployVertexFactory.s.sol';
import {Test, console2} from "forge-std/Test.sol";

contract DeployVertexFactoryTest is Test {
  function setUp() public {
  }

  function test_David() public {
    console2.log("david", block.chainid);
    assertTrue(true);
  }
}
