// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@forge-std/Test.sol";
import "src/PolicyERC721.sol";
import "@forge-std/console.sol";

contract PolicyERC721Test is Test {
    PolicyERC721 public policyERC721;

    event RoleAdded(string role, Permission[] permissions, uint256 permissionSignature);
    event RoleDeleted(string role);

    function hashPermission(Permission memory permission) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(permission.target, permission.signature, permission.executor)));
    }

    function setUp() public {
        policyERC721 = new PolicyERC721("Test", "TST");
        // console.logAddress(address(policyERC721)); //0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        // console.logAddress(policyERC721.owner()); //0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        string[] memory roles = new string[](0);
        policyERC721.mint(address(this), roles);
    }

    function testMint() public {
        string[] memory roles = new string[](0);
        policyERC721.mint(address(this), roles);
        assertEq(policyERC721.balanceOf(address(this)), 2);
        assertEq(policyERC721.ownerOf(2), address(this));
    }

    function testBurn() public {
        policyERC721.burn(1);
        assertEq(policyERC721.balanceOf(address(this)), 0);
    }

    function testAddRole() public {
        Permission memory permission = Permission(address(0), bytes4(0), address(0));
        Permission[] memory permissions = new Permission[](1);
        permissions[0] = permission;

        vm.expectEmit(true, true, true, true, address(policyERC721));
        emit RoleAdded("admin", permissions, hashPermission(permission));

        policyERC721.addRole("admin", permissions);
    }

    function testAssignRole() public {
        Permission memory permission = Permission(address(0), bytes4(0), address(0));
        Permission[] memory permissions = new Permission[](1);
        permissions[0] = permission;

        policyERC721.addRole("admin", permissions);

        policyERC721.assignRole(1, "admin");
        assertEq(policyERC721.hasRole(1, "admin"), true);
        uint256[] memory tokenPermissions = policyERC721.getPermissionSignatures(1);
        assertEq(policyERC721.hasPermission(1, hashPermission(permission)), true);
    }

    function testDeleteRole() public {
        Permission[] memory permissions = new Permission[](0);
        policyERC721.addRole("admin", permissions);

        vm.expectEmit(true, false, false, true, address(policyERC721));
        emit RoleDeleted("admin");

        policyERC721.deleteRole("admin");
    }

    function testRevokeRole() public {}
}
