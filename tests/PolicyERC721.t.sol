// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "lib/forge-std/src/Test.sol";
import "src/policy/PolicyERC721.sol";
import "lib/forge-std/src/console.sol";

contract PolicyERC721Test is Test {
    PolicyERC721 public policyERC721;

    event RoleAdded(string role, Permission[] permissions, uint256[] permissionSignatures);
    event RoleRevoked(uint256 tokenId, string role);
    event RoleDeleted(string role);

    function hashPermission(Permission memory permission) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(permission.target, permission.signature, permission.executor)));
    }

    function generateGenericPermissionArray() internal pure returns (Permission[] memory, Permission memory) {
        Permission memory permission = Permission(address(0xdeadbeef), bytes4(0x08080808), address(0xdeadbeefdeadbeef));
        Permission[] memory permissions = new Permission[](1);
        permissions[0] = permission;
        return (permissions, permission);
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
        assertEq(policyERC721.ownerOf(1), address(this));
    }

    function testBurn() public {
        policyERC721.burn(0);
        assertEq(policyERC721.balanceOf(address(this)), 0);
    }

    function testAddRole() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();
        uint256[] memory permissionSignaturesArray = new uint256[](1);
        permissionSignaturesArray[0] = hashPermission(permission);

        vm.expectEmit(true, true, true, true, address(policyERC721));
        emit RoleAdded("admin", permissions, permissionSignaturesArray);

        policyERC721.addRole("admin", permissions);
    }

    function testAssignRole() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

        policyERC721.addRole("admin", permissions);

        policyERC721.assignRole(1, "admin");
        assertEq(policyERC721.hasRole(1, "admin"), true);
        uint256[] memory tokenPermissions = policyERC721.getPermissionSignatures(1);
        assertEq(policyERC721.hasPermission(1, hashPermission(permission)), true);
    }

    function testDeleteRole() public {
        (Permission[] memory permissions, ) = generateGenericPermissionArray();

        policyERC721.addRole("admin", permissions);

        vm.expectEmit(true, false, false, true, address(policyERC721));
        emit RoleDeleted("admin");

        policyERC721.deleteRole("admin");
    }

    function testRevokeRole() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

        policyERC721.addRole("admin", permissions);
        policyERC721.assignRole(1, "admin");

        vm.expectEmit(true, true, false, true, address(policyERC721));
        emit RoleRevoked(1, "admin");

        policyERC721.revokeRole(1, "admin");
    }

    function testAddPermission() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

        policyERC721.addRole("admin", permissions);

        policyERC721.assignRole(1, "admin");

        Permission memory newPermission = Permission(address(0xbeef), bytes4(0x09090909), address(0xbeefbeef));
        policyERC721.addPermissionToRole("admin", newPermission);

        assertEq(policyERC721.hasPermission(1, hashPermission(newPermission)), true);
    }

    function testDeletePermission() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

        policyERC721.addRole("admin", permissions);

        policyERC721.assignRole(1, "admin");

        policyERC721.deletePermissionFromRole("admin", permission);

        assertEq(policyERC721.hasPermission(1, hashPermission(permission)), false);
    }

    function testCannotTransferTokenOwnership() public {
        vm.expectRevert("PolicyERC721: transferFrom is disabled");
        policyERC721.transferFrom(address(this), address(0xdeadbeef), 1);
    }
}
