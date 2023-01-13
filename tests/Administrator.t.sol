// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

contract ExampleTest is Test {
    function setUp() public {}

    function testIncrement() public {
        uint256 x = 1;
        assertEq(x, 1);
    }
}
