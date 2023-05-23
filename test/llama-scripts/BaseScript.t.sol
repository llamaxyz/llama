// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";
import {BaseScript} from "src/llama-scripts/BaseScript.sol";
import {MockBaseScript} from "test/mock/MockBaseScript.sol";

contract BaseScriptTest is LlamaTestSetup {
  MockBaseScript baseScript;

  function setUp() public virtual override {
    LlamaTestSetup.setUp();
    baseScript = new MockBaseScript();
  }

  function test_canDelegateCallBaseScript() public {
    vm.startPrank(address(mpExecutor));
    mpCore.authorizeScript(address(baseScript), true);
    assertEq(baseScript.counter(), 0);
    baseScript.run();
    assertEq(baseScript.counter(), 1);
    vm.stopPrank();
  }

  function test_revertIf_notDelegateCalled() public {
    vm.prank(address(mpExecutor));
    vm.expectRevert(BaseScript.OnlyDelegateCall.selector);
    baseScript.run();
  }
}
