// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {PermissionData} from "src/lib/Structs.sol";

contract LlamaExecutorTestSetup is LlamaTestSetup {}

contract Execute is LlamaExecutorTestSetup {
    function test_RevertsIf_NotCalledByCore(address notCore) public {
        vm.assume(notCore != address(mpCore));
        bytes memory mockData;
        vm.prank(notCore);
        mpExecutor.execute(address(0xdeadbeef), false, mockData);
    }
}