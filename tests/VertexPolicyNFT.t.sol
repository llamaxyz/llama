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

    function test_burn() public {
        vertexPolicyNFT.batchRevokePermissions(policyIds);
        assertEq(vertexPolicyNFT.balanceOf(address(this)), 0);
    }

    function testCannotTransferTokenOwnership() public {
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
}
