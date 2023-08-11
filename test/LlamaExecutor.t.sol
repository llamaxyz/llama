// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {LlamaExecutor} from "src/LlamaExecutor.sol";

contract LlamaExecutorTestSetup is LlamaTestSetup {}

contract Execute is LlamaExecutorTestSetup {
  function test_RevertsIf_NotCalledByCore(address notCore) public {
    vm.assume(notCore != address(mpCore));
    bytes memory mockData;
    vm.prank(notCore);
    vm.expectRevert(LlamaExecutor.OnlyLlamaCore.selector);
    mpExecutor.execute(address(0xdeadbeef), false, mockData);
  }
}
