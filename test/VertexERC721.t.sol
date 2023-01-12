// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@forge-std/Test.sol";
import "src/VertexERC721.sol";
import "@forge-std/console.sol";

contract VertexERC721Test is Test {
    VertexERC721 public vertexERC721;

    function setUp() public {
        vertexERC721 = new VertexERC721("Test", "TST");
        // console.logAddress(address(vertexERC721)); //0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        // console.logAddress(vertexERC721.owner()); //0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        string[] memory roles = new string[](1);
        vertexERC721.mint(address(this), roles);
    }

    // TODO: finish tests
    function testMint() public {
        string[] memory roles = new string[](1);
        vertexERC721.mint(address(this), roles);
        assertEq(vertexERC721.balanceOf(address(this)), 2);
        assertEq(vertexERC721.ownerOf(1), address(this));
    }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
