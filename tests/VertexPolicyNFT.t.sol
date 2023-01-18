// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "lib/forge-std/src/Test.sol";
import "src/policy/VertexPolicyNFT.sol";
import "lib/forge-std/src/console.sol";

contract VertexPolicyNFTTest is Test {
    VertexPolicyNFT public vertexPolicyNFT;

    Permission public permission;
    string[] public roles;
    Permission[] public permissions;
    Permission[][] public permissionsArray;
    bytes8[] public permissionSignature;
    bytes8[][] public permissionSignatures;
    bytes32[] public roleHashes;

    event RolesAdded(bytes32[] roles, string[] roleStrings, Permission[][] permissions, bytes8[][] permissionSignatures);
    event RolesAssigned(uint256 tokenId, bytes32[] roles);
    event RolesRevoked(uint256 tokenId, bytes32[] roles);
    event RolesDeleted(bytes32[] role);
    event PermissionsAdded(bytes32 role, Permission[] permissions, bytes8[] permissionSignatures);
    event PermissionsDeleted(bytes32 role, Permission[] permissions, bytes8[] permissionSignatures);

    error RoleNonExistant(bytes32 role);
    error SoulboundToken();

    function hashPermission(Permission memory permission) internal pure returns (bytes8) {
        return bytes8(keccak256(abi.encodePacked(permission.target, permission.signature, permission.executor)));
    }

    function hashRole(string memory role) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(role));
    }

    function generateGenericPermissionArray() internal {
        permission = Permission(address(0xdeadbeef), bytes4(0x08080808), address(0xdeadbeefdeadbeef));
        permissions.push(permission);
    }

    function addGenericRoleSetup() internal {
        generateGenericPermissionArray();
        permissionsArray.push(permissions);
        permissionSignature.push(hashPermission(permission));
        permissionSignatures.push(permissionSignature);
        roles.push("admin");
        roleHashes.push(hashRole(roles[0]));
        vertexPolicyNFT.addRoles(roles, permissionsArray);
    }

    function setUp() public {
        vertexPolicyNFT = new VertexPolicyNFT("Test", "TST");
        // console.logAddress(address(policyNFT)); //0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        // console.logAddress(policyNFT.owner()); //0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
        bytes32[] memory roles = new bytes32[](0);
        vertexPolicyNFT.mint(address(this), roles);
    }

    function testMint() public {
        bytes32[] memory roles = new bytes32[](0);
        vertexPolicyNFT.mint(address(this), roles);
        assertEq(vertexPolicyNFT.balanceOf(address(this)), 2);
        assertEq(vertexPolicyNFT.ownerOf(1), address(this));
    }

    function testBurn() public {
        vertexPolicyNFT.burn(0);
        assertEq(vertexPolicyNFT.balanceOf(address(this)), 0);
    }

    function testAddRole() public {
        generateGenericPermissionArray();
        permissionsArray.push(permissions);
        permissionSignature.push(hashPermission(permission));
        permissionSignatures.push(permissionSignature);
        roles.push("admin");
        roleHashes.push(hashRole(roles[0]));

        vm.expectEmit(true, true, true, true, address(vertexPolicyNFT));
        emit RolesAdded(roleHashes, roles, permissionsArray, permissionSignatures);
        vertexPolicyNFT.addRoles(roles, permissionsArray);
    }

    function testAssignRole() public {
        addGenericRoleSetup();
        vertexPolicyNFT.assignRoles(1, roleHashes);
        assertEq(vertexPolicyNFT.hasRole(1, roleHashes[0]), true);
        bytes8[] memory tokenPermissions = vertexPolicyNFT.getPermissionSignatures(1);
        assertEq(vertexPolicyNFT.hasPermission(1, hashPermission(permission)), true);
    }

    function testDeleteRole() public {
        addGenericRoleSetup();
        vm.expectEmit(true, false, false, true, address(vertexPolicyNFT));
        emit RolesDeleted(roleHashes);

        vertexPolicyNFT.deleteRoles(roleHashes);
    }

    function testRevokeRole() public {
        addGenericRoleSetup();
        vertexPolicyNFT.assignRoles(1, roleHashes);

        vm.expectEmit(true, true, false, true, address(vertexPolicyNFT));
        emit RolesRevoked(1, roleHashes);

        vertexPolicyNFT.revokeRoles(1, roleHashes);
        assertEq(vertexPolicyNFT.hasRole(1, roleHashes[0]), false);
        bytes32[] memory totalRoles = vertexPolicyNFT.getRoles();
        assertEq(totalRoles.length, 1);
        assertEq(totalRoles[0], roleHashes[0]);
    }

    // function testAddPermission() public {
    //     (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

    //     bytes32 roleHash = vertexPolicyNFT.addRoles(["admin"], [permissions]);

    //     vertexPolicyNFT.assignRoles(1, [roleHash]);

    //     Permission memory newPermission = Permission(address(0xbeef), bytes4(0x09090909), address(0xbeefbeef));
    //     vertexPolicyNFT.addPermissionsToRole(roleHash, [newPermission]);

    //     assertEq(vertexPolicyNFT.hasPermission(1, hashPermission(newPermission)), true);
    // }

    // function testDeletePermission() public {
    //     (Permission[] memory permissions, Permission memory permission) = generateGenericPermissionArray();

    //     vertexPolicyNFT.addRoles(["admin"], [permissions]);
    //     bytes32 roleHash = hashRole("admin");

    //     vertexPolicyNFT.assignRoles(1, [roleHash]);

    //     vertexPolicyNFT.deletePermissionsFromRole(roleHash, storagePermissionsArray);

    //     assertEq(vertexPolicyNFT.hasPermission(1, hashPermission(permission)), false);
    // }

    function testCannotTransferTokenOwnership() public {
        vm.expectRevert(SoulboundToken.selector);
        vertexPolicyNFT.transferFrom(address(this), address(0xdeadbeef), 1);
    }
}
