// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@forge-std/Test.sol";
import "src/VertexERC721.sol";
import "@forge-std/console.sol";

contract VertexERC721Test is Test {
    VertexERC721 public vertexERC721;

    event RoleAdded(string role, Permission[] permissions, uint256 permissionSignature);

    function hashPermission(Permission memory permission) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(permission.target, permission.signature, permission.executor)));
    }

    function setUp() public {
        vertexERC721 = new VertexERC721("Test", "TST");
        // console.logAddress(address(vertexERC721)); //0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        // console.logAddress(vertexERC721.owner()); //0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        string[] memory roles = new string[](0);
        vertexERC721.mint(address(this), roles);
    }

    function testMint() public {
        string[] memory roles = new string[](0);
        vertexERC721.mint(address(this), roles);
        assertEq(vertexERC721.balanceOf(address(this)), 2);
        assertEq(vertexERC721.ownerOf(2), address(this));
    }

    function testAddRole() public {
        Permission memory permission = Permission(address(0), bytes4(0), address(0));
        Permission[] memory permissions = new Permission[](1);
        permissions[0] = permission;

        vm.expectEmit(true, true, true, true, address(vertexERC721));
        emit RoleAdded("admin", permissions, hashPermission(permission));

        vertexERC721.addRole("admin", permissions);
        // assertEq(vertexERC721.tokenToRoles(1)[0], "test");
    }
}
