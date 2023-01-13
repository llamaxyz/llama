// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "lib/forge-std/src/Test.sol";
import "src/core/VertexPolicyNFT.sol";
import "lib/forge-std/src/console.sol";

contract VertexPolicyNFTTest is Test {
    VertexPolicyNFT public vertexPolicyNFT;

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
        vertexPolicyNFT = new VertexPolicyNFT("Test", "TST");
        // console.logAddress(address(policyNFT)); //0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        // console.logAddress(policyNFT.owner()); //0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        string[] memory roles = new string[](0);
        vertexPolicyNFT.mint(address(this), roles);
    }

    function testMint() public {
        string[] memory roles = new string[](0);
        vertexPolicyNFT.mint(address(this), roles);
        assertEq(vertexPolicyNFT.balanceOf(address(this)), 2);
        assertEq(vertexPolicyNFT.ownerOf(1), address(this));
    }

    function testBurn() public {
        vertexPolicyNFT.burn(0);
        assertEq(vertexPolicyNFT.balanceOf(address(this)), 0);
    }

    function testAddRole() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();
        uint256[] memory permissionSignaturesArray = new uint256[](1);
        permissionSignaturesArray[0] = hashPermission(permission);

        vm.expectEmit(true, true, true, true, address(vertexPolicyNFT));
        emit RoleAdded("admin", permissions, permissionSignaturesArray);

        vertexPolicyNFT.addRole("admin", permissions);
    }

    function testAssignRole() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

        vertexPolicyNFT.addRole("admin", permissions);

        vertexPolicyNFT.assignRole(1, "admin");
        assertEq(vertexPolicyNFT.hasRole(1, "admin"), true);
        uint256[] memory tokenPermissions = vertexPolicyNFT.getPermissionSignatures(1);
        assertEq(vertexPolicyNFT.hasPermission(1, hashPermission(permission)), true);
    }

    function testDeleteRole() public {
        (Permission[] memory permissions, ) = generateGenericPermissionArray();

        vertexPolicyNFT.addRole("admin", permissions);

        vm.expectEmit(true, false, false, true, address(vertexPolicyNFT));
        emit RoleDeleted("admin");

        vertexPolicyNFT.deleteRole("admin");
    }

    function testRevokeRole() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

        vertexPolicyNFT.addRole("admin", permissions);
        vertexPolicyNFT.assignRole(1, "admin");

        vm.expectEmit(true, true, false, true, address(vertexPolicyNFT));
        emit RoleRevoked(1, "admin");

        vertexPolicyNFT.revokeRole(1, "admin");
        assertEq(vertexPolicyNFT.hasRole(1, "admin"), false);
        string[] memory roles = vertexPolicyNFT.getRoles();
        assertEq(roles.length, 1);
        assertEq(roles[0], "admin");
    }

    function testAddPermission() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

        vertexPolicyNFT.addRole("admin", permissions);

        vertexPolicyNFT.assignRole(1, "admin");

        Permission memory newPermission = Permission(address(0xbeef), bytes4(0x09090909), address(0xbeefbeef));
        vertexPolicyNFT.addPermissionToRole("admin", newPermission);

        assertEq(vertexPolicyNFT.hasPermission(1, hashPermission(newPermission)), true);
    }

    function testDeletePermission() public {
        (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

        vertexPolicyNFT.addRole("admin", permissions);

        vertexPolicyNFT.assignRole(1, "admin");

        vertexPolicyNFT.deletePermissionFromRole("admin", permission);

        assertEq(vertexPolicyNFT.hasPermission(1, hashPermission(permission)), false);
    }

    function testCannotTransferTokenOwnership() public {
        vm.expectRevert("VertexPolicyNFT: transferFrom is disabled");
        vertexPolicyNFT.transferFrom(address(this), address(0xdeadbeef), 1);
    }
}
