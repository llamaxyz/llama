// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "lib/forge-std/src/console.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {IVertexCore} from "src/core/IVertexCore.sol";
import {VertexPolicy} from "src/policy/VertexPolicy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {PermissionData, BatchUpdateData, PermissionChangeData, BatchGrantData, BatchRevokeData, PermissionChangeData} from "src/utils/Structs.sol";
import {console} from "lib/forge-std/src/console.sol";

contract VertexPolicyNFTTest is Test {
    event PoliciesAdded(BatchGrantData[] grantData);
    event PermissionsUpdated(BatchUpdateData[] updateData);
    event PoliciesRevoked(BatchRevokeData[] revokeData);

    VertexPolicyNFT public vertexPolicyNFT;
    PermissionData public permission;
    PermissionData[] public permissions;
    PermissionData[][] public permissionsArray;
    bytes8[] public permissionSignature;
    bytes8[][] public permissionSignatures;
    bytes8[][] public permissionsToRevoke;
    uint256[][] public expirationTimestamps;
    address[] public addresses;
    uint256[] public policyIds;
    address[] public initialPolicies;
    bytes8[][] public initialPermissions;
    uint256[][] public initialExpirationTimestamps;
    BatchRevokeData[] public batchRevokeData;
    uint256 ADDRESS_THIS_TOKEN_ID;
    uint256 constant DEADBEEF_TOKEN_ID = uint256(uint160(address(0xdeadbeef)));

    function _buildPermissionChangeData() internal returns (PermissionChangeData[] memory permissionChangeData) {
        PermissionData memory _permission = PermissionData(
            // TODO These values should be function inputs so they can fuzzed over.
            address(0xdeadbeef),
            bytes4(0x08080808),
            VertexStrategy(address(0xdeadbeefdeadbeef))
        );
        permissionChangeData = new PermissionChangeData[](1);
        // we cant call vertexPolicyNFT.hashPermission(_permission) because we have not yet deployed the contract
        permissionChangeData[0] = PermissionChangeData({permissionId: bytes8(keccak256(abi.encode(_permission))), expirationTimestamp: 0});
    }

    function _buildBatchGrantData(address _user) internal returns (BatchGrantData[] memory _batchGrantData) {
        _batchGrantData = new BatchGrantData[](1);
        _batchGrantData[0] = BatchGrantData(_user, _buildPermissionChangeData());
    }

    function generateGenericPermissionArray() internal {
        permission = PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)));
        permissions.push(permission);
        permissionsArray.push(permissions);
        permissionSignature.push(vertexPolicyNFT.hashPermissions(permissions)[0]);
        permissionSignatures.push(permissionSignature);
        addresses.push(address(this));
        batchRevokeData.push(BatchRevokeData(uint256(uint160(address(this))), permissionSignature));
    }

    function setUp() public {
        BatchGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(this));
        vertexPolicyNFT = new VertexPolicyNFT("Test", "TST", initialBatchGrantData);
        vertexPolicyNFT.setVertex(address(this));
        ADDRESS_THIS_TOKEN_ID = uint256(uint160(address(this)));
        generateGenericPermissionArray();
        policyIds.push(ADDRESS_THIS_TOKEN_ID);
    }

    function test_grantPermission_CorrectlyGrantsPermission() public {
        addresses[0] = address(0xdeadbeef);
        BatchGrantData[] memory initialBatchGrantData = _buildBatchGrantData(addresses[0]);
        vm.expectEmit(true, true, true, true);
        emit PoliciesAdded(initialBatchGrantData);
        vertexPolicyNFT.batchGrantPolicies(initialBatchGrantData);
        assertEq(vertexPolicyNFT.balanceOf(address(0xdeadbeef)), 1);
        assertEq(vertexPolicyNFT.ownerOf(DEADBEEF_TOKEN_ID), address(0xdeadbeef));
    }

    function test_grantPermission_RevertIfPolicyAlreadyGranted() public {
        vm.expectRevert(VertexPolicy.OnlyOnePolicyPerHolder.selector);
        BatchGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(this));
        vertexPolicyNFT.batchGrantPolicies(initialBatchGrantData);
    }

    function test_Revoke_CorrectlyRevokesPolicy() public {
        vm.expectEmit(true, true, true, true);
        emit PoliciesRevoked(batchRevokeData);

        vertexPolicyNFT.batchRevokePolicies(batchRevokeData);
        assertEq(vertexPolicyNFT.balanceOf(address(this)), 0);
    }

    function test_revoke_RevertIfPolicyNotGranted() public {
        uint256 mockPolicyId = uint256(uint160(address(0xdeadbeef)));
        policyIds[0] = mockPolicyId;
        batchRevokeData[0] = BatchRevokeData(mockPolicyId, permissionSignature);
        vm.expectRevert("NOT_MINTED");
        vertexPolicyNFT.batchRevokePolicies(batchRevokeData);
    }

    function test_transferFrom_RevertIfTransferFrom() public {
        vm.expectRevert(VertexPolicy.SoulboundToken.selector);
        vertexPolicyNFT.transferFrom(address(this), address(0xdeadbeef), ADDRESS_THIS_TOKEN_ID);
    }

    function test_holderHasPermissionAt_ReturnsCorrectBool() public {
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.number), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.number), false);
        addresses[0] = address(0xdeadbeef);
        vm.warp(block.timestamp + 100);

        BatchGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(0xdeadbeef));
        vertexPolicyNFT.batchGrantPolicies(initialBatchGrantData);
        vertexPolicyNFT.batchRevokePolicies(batchRevokeData);

        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp), false);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.timestamp), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp - 99), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.timestamp - 99), false);
    }

    function test_getSupplyByPermissions_ReturnsCorrectSupply() public {
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 1);
        addresses[0] = address(0xdeadbeef);
        BatchGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(0xdeadbeef));
        vertexPolicyNFT.batchGrantPolicies(initialBatchGrantData);
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 2);
        vertexPolicyNFT.batchRevokePolicies(batchRevokeData);
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 1);
    }

    function test_batchUpdatePermissions_UpdatesPermissionsCorrectly() public {
        bytes8 oldPermissionSignature = permissionSignature[0];
        assertEq(vertexPolicyNFT.hasPermission(policyIds[0], oldPermissionSignature), true);
        permissionsToRevoke = permissionSignatures;

        permission = PermissionData(address(0xdeadbeefdeadbeef), bytes4(0x09090909), VertexStrategy(address(0xdeadbeefdeadbeefdeafbeef)));
        permissions[0] = permission;
        permissionsArray[0] = permissions;
        permissionSignature[0] = vertexPolicyNFT.hashPermissions(permissions)[0];
        permissionSignatures[0] = permissionSignature;

        PermissionChangeData[] memory toAdd = new PermissionChangeData[](1);
        PermissionChangeData[] memory toRemove = new PermissionChangeData[](1);

        toAdd[0] = PermissionChangeData(permissionSignature[0], 0);
        toRemove[0] = PermissionChangeData(oldPermissionSignature, 0);

        BatchUpdateData[] memory updateData = new BatchUpdateData[](1);
        updateData[0] = BatchUpdateData(policyIds[0], toAdd, toRemove);

        vm.warp(block.timestamp + 100);

        vm.expectEmit(true, true, true, true);
        emit PermissionsUpdated(updateData);

        vertexPolicyNFT.batchUpdatePermissions(updateData);

        assertEq(vertexPolicyNFT.hasPermission(policyIds[0], oldPermissionSignature), false);
        assertEq(vertexPolicyNFT.hasPermission(policyIds[0], permissionSignature[0]), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), oldPermissionSignature, block.timestamp - 100), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), oldPermissionSignature, block.timestamp), false);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp - 100), false);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp), true);
    }

    // function test_batchUpdatePermissions_RevertIfArraysLengthMismatch() public {
    //     policyIds.push(uint256(uint160(address(0xdeadbeef))));
    //     vm.expectRevert(VertexPolicy.InvalidInput.selector);
    //     vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, initialExpirationTimestamps);
    // }

    // function test_batchUpdatePermissions_updatesTimeStamp() public {
    //     uint256[] memory newExpirationTimestamp = new uint256[](1);
    //     newExpirationTimestamp[0] = block.timestamp + 1 days;
    //     expirationTimestamps.push(newExpirationTimestamp);
    //     assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), 0);
    //     vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, expirationTimestamps);
    //     assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), newExpirationTimestamp[0]);
    // }

    function test_tokenURI_ReturnsCorrectURI() public {
        string memory baseURI = "https://vertex.link/policy/";
        vertexPolicyNFT.setBaseURI(baseURI);
        assertEq(vertexPolicyNFT.tokenURI(ADDRESS_THIS_TOKEN_ID), string.concat(baseURI, vm.toString(ADDRESS_THIS_TOKEN_ID)));
    }

    function test_totalSupply_ReturnsCorrectSupply() public {
        assertEq(vertexPolicyNFT.totalSupply(), 1);
        addresses[0] = address(0xdeadbeef);
        vertexPolicyNFT.batchGrantPolicies(_buildBatchGrantData(addresses[0]));
        assertEq(vertexPolicyNFT.totalSupply(), 2);
        vertexPolicyNFT.batchRevokePolicies(batchRevokeData);
        assertEq(vertexPolicyNFT.totalSupply(), 1);
    }

    function test_onlyVertex_RevertIfNotVertex() public {
        string memory baseURI = "https://vertex.link/policy/";
        vm.prank(address(0xdeadbeef));
        vm.expectRevert(VertexPolicy.OnlyVertex.selector);
        vertexPolicyNFT.setBaseURI(baseURI);
    }

    // function test_expirationTimestamp_DoesNotHavePermissionIfExpired() public {
    //     assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), 0);
    //     assertEq(vertexPolicyNFT.hasPermission(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), true);

    //     uint256[] memory newExpirationTimestamp = new uint256[](1);
    //     newExpirationTimestamp[0] = block.timestamp + 1 days;
    //     expirationTimestamps.push(newExpirationTimestamp);
    //     vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, expirationTimestamps);

    //     vm.warp(block.timestamp + 2 days);

    //     assertEq(newExpirationTimestamp[0] < block.timestamp, true);
    //     assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), newExpirationTimestamp[0]);
    //     assertEq(vertexPolicyNFT.hasPermission(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), false);
    // }

    function test_grantPermissions_GrantsTokenWithExpiration() public {
        uint256 _newExpirationTimestamp = block.timestamp + 1 days;
        address _newAddress = address(0xdeadbeef);

        PermissionChangeData[] memory _changes = new PermissionChangeData[](1);
        _changes[0] = PermissionChangeData(permissionSignature[0], _newExpirationTimestamp);

        BatchGrantData[] memory initialBatchGrantData = new BatchGrantData[](1);
        initialBatchGrantData[0] = BatchGrantData(_newAddress, _changes);
        vertexPolicyNFT.batchGrantPolicies(initialBatchGrantData);

        assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(uint256(uint160(_newAddress)), permissionSignature[0]), _newExpirationTimestamp);
    }

    // function test_expirationTimestamp_RevertIfTimestampIsExpired() public {
    //     uint256[] memory newExpirationTimestamp = new uint256[](1);
    //     newExpirationTimestamp[0] = block.timestamp;
    //     expirationTimestamps.push(newExpirationTimestamp);
    //     address[] memory newAddresses = new address[](1);
    //     newAddresses[0] = address(0xdeadbeef);
    //     addresses = newAddresses;

    //     vm.warp(block.timestamp + 1 days);

    //     vm.expectRevert(VertexPolicy.Expired.selector);
    //     vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, expirationTimestamps);
    //     newExpirationTimestamp[0] = block.timestamp - 1 seconds;
    //     expirationTimestamps[0] = newExpirationTimestamp;
    //     assertEq(block.timestamp > newExpirationTimestamp[0], true);
    //     vm.expectRevert(VertexPolicy.Expired.selector);
    //     vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, expirationTimestamps);
    // }
}
