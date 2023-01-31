// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "lib/forge-std/src/Test.sol";
import {IVertexCore} from "src/core/IVertexCore.sol";
import {VertexPolicy} from "src/policy/VertexPolicy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {Permission} from "src/utils/Structs.sol";
import {console} from "lib/forge-std/src/console.sol";

contract VertexPolicyNFTTest is Test {
    VertexPolicyNFT public vertexPolicyNFT;

    Permission public permission;
    Permission[] public permissions;
    Permission[][] public permissionsArray;
    bytes8[] public permissionSignature;
    bytes8[][] public permissionSignatures;
    address[] public addresses;
    uint256[] public policyIds;

    address[] public initialPolicies;
    bytes8[][] public initialPermissions;

    uint256 ADDRESS_THIS_TOKEN_ID;
    uint256 constant DEADBEEF_TOKEN_ID = uint256(uint160(address(0xdeadbeef)));

    function generateGenericPermissionArray() internal {
        permission = Permission(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)));
        permissions.push(permission);
        permissionsArray.push(permissions);
        permissionSignature.push(vertexPolicyNFT.hashPermissions(permissions)[0]);
        permissionSignatures.push(permissionSignature);
        addresses.push(address(this));
    }

    function setUp() public {
        vertexPolicyNFT = new VertexPolicyNFT("Test", "TST", address(this), initialPolicies, initialPermissions);
        ADDRESS_THIS_TOKEN_ID = uint256(uint160(address(this)));
        generateGenericPermissionArray();
        vertexPolicyNFT.batchGrantPermissions(addresses, permissionSignatures);
        policyIds.push(ADDRESS_THIS_TOKEN_ID);
    }

    function test_grantPermission() public {
        addresses[0] = address(0xdeadbeef);
        vertexPolicyNFT.batchGrantPermissions(addresses, permissionSignatures);
        assertEq(vertexPolicyNFT.balanceOf(address(0xdeadbeef)), 1);
        assertEq(vertexPolicyNFT.ownerOf(DEADBEEF_TOKEN_ID), address(0xdeadbeef));
    }

    function test_grantPermission_revertIfArraysLengthMismatch() public {
        addresses.push(address(0xdeadbeef));
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchGrantPermissions(addresses, permissionSignatures);
    }

    function test_grantPermission_revertIfPolicyAlreadyGranted() public {
        vm.expectRevert(VertexPolicy.OnlyOnePolicyPerHolder.selector);
        vertexPolicyNFT.batchGrantPermissions(addresses, permissionSignatures);
    }

    function test_grantPermission_revertIfPermissionsArrayEmpty() public {
        addresses[0] = address(0xdeadbeef);
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchGrantPermissions(addresses, new bytes8[][](0));
    }

    function test_revoke() public {
        vertexPolicyNFT.batchRevokePermissions(policyIds);
        assertEq(vertexPolicyNFT.balanceOf(address(this)), 0);
    }

    function test_revoke_revertIfNoPolicySpecified() public {
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchRevokePermissions(new uint256[](0));
    }

    function test_revoke_revertIfPolicyNotGranted() public {
        uint256 mockPolicyId = uint256(uint160(address(0xdeadbeef)));
        policyIds[0] = mockPolicyId;

        vm.expectRevert("NOT_MINTED");
        vertexPolicyNFT.batchRevokePermissions(policyIds);
    }

    function test_cannotTransferTokenOwnership() public {
        vm.expectRevert(VertexPolicy.SoulboundToken.selector);
        vertexPolicyNFT.transferFrom(address(this), address(0xdeadbeef), ADDRESS_THIS_TOKEN_ID);
    }

    function test_holderHasPermissionAt() public {
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.number), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.number), false);
        addresses[0] = address(0xdeadbeef);

        vm.roll(block.number + 100);

        vertexPolicyNFT.batchGrantPermissions(addresses, permissionSignatures);
        vertexPolicyNFT.batchRevokePermissions(policyIds);

        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.number), false);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.number), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.number - 99), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.number - 99), false);
    }

    function test_getSupplyByPermissions() public {
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 1);
        addresses[0] = address(0xdeadbeef);
        vertexPolicyNFT.batchGrantPermissions(addresses, permissionSignatures);
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 2);
        vertexPolicyNFT.batchRevokePermissions(policyIds);
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 1);
    }

    function test_batchUpdatePermissions() public {
        bytes8 oldPermissionSignature = permissionSignature[0];
        assertEq(vertexPolicyNFT.hasPermission(policyIds[0], oldPermissionSignature), true);

        permission = Permission(address(0xdeadbeefdeadbeef), bytes4(0x09090909), VertexStrategy(address(0xdeadbeefdeadbeefdeafbeef)));
        permissions[0] = permission;
        permissionsArray[0] = permissions;
        permissionSignature[0] = vertexPolicyNFT.hashPermissions(permissions)[0];
        permissionSignatures[0] = permissionSignature;

        vm.roll(block.number + 1);

        vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures);

        assertEq(vertexPolicyNFT.hasPermission(policyIds[0], oldPermissionSignature), false);
        assertEq(vertexPolicyNFT.hasPermission(policyIds[0], permissionSignature[0]), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), oldPermissionSignature, block.number - 1), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), oldPermissionSignature, block.number), false);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.number - 1), false);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.number), true);
    }

    function test_batchUpdatePermissions_revertIfArraysLengthMismatch() public {
        policyIds.push(uint256(uint160(address(0xdeadbeef))));
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures);
    }
}
