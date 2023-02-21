// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "lib/forge-std/src/Test.sol";
import {IVertexCore} from "src/core/IVertexCore.sol";
import {VertexPolicy} from "src/policy/VertexPolicy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {PermissionData} from "src/utils/Structs.sol";
import {console} from "lib/forge-std/src/console.sol";

contract VertexPolicyNFTTest is Test {
    event PoliciesAdded(address[] users, bytes8[][] permissionSignatures, uint256[][] expirationTimestamps);
    event PermissionsUpdated(uint256[] policyIds, bytes8[][] permissionSignatures, bytes8[][] permissionsRemoved, uint256[][] expirationTimestamps);
    event PoliciesRevoked(uint256[] policyIds, bytes8[][] permissionSignatures);

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
    uint256 ADDRESS_THIS_TOKEN_ID = uint256(uint160(address(this)));
    uint256 constant DEADBEEF_TOKEN_ID = uint256(uint160(address(0xdeadbeef)));

    function setUp() public {
        vertexPolicyNFT = new VertexPolicyNFT("Test", "TST", initialPolicies, initialPermissions, initialExpirationTimestamps);
        vertexPolicyNFT.setVertex(address(this));
        generateGenericPermissionArray();
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
        policyIds.push(ADDRESS_THIS_TOKEN_ID);
    }

    function generateGenericPermissionArray() internal {
        permission = PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)));
        permissions.push(permission);
        permissionsArray.push(permissions);
        permissionSignature.push(vertexPolicyNFT.hashPermissions(permissions)[0]);
        permissionSignatures.push(permissionSignature);
        addresses.push(address(this));
    }
}

contract Constructor is VertexPolicyNFTTest {
  function testFuzz_SetsName(string memory _name) public {} // TODO
  function testFuzz_SetsSymbol(string memory _symbol) public {} // TODO
  function testFuzz_GrantsInitialPermissions(/*random array args*/) public {} // TODO
  function testFuzz_RevertIfInvalidInput(/*random array lengths*/) public {} // TODO
}

contract SetVertex is VertexPolicyNFTTest {
  // TODO
}

contract BatchGrantPermissions is VertexPolicyNFTTest {
    function test_grantPermission_CorrectlyGrantsPermission() public {
        addresses[0] = address(0xdeadbeef);
        vm.expectEmit(true, true, true, true);
        emit PoliciesAdded(addresses, permissionSignatures, initialExpirationTimestamps);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
        assertEq(vertexPolicyNFT.balanceOf(address(0xdeadbeef)), 1);
        assertEq(vertexPolicyNFT.ownerOf(DEADBEEF_TOKEN_ID), address(0xdeadbeef));
    }

    function test_grantPermission_RevertIfArraysLengthMismatch() public {
        addresses.push(address(0xdeadbeef));
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
    }

    function test_grantPermission_RevertIfPolicyAlreadyGranted() public {
        vm.expectRevert(VertexPolicy.OnlyOnePolicyPerHolder.selector);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
    }

    function test_grantPermission_RevertIfPermissionsArrayEmpty() public {
        addresses[0] = address(0xdeadbeef);
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchGrantPolicies(addresses, new bytes8[][](0), initialExpirationTimestamps);
    }

    function test_grantPermissions_GrantsTokenWithExpiration() public {
        uint256[] memory newExpirationTimestamp = new uint256[](1);
        newExpirationTimestamp[0] = block.timestamp + 1 days;
        expirationTimestamps.push(newExpirationTimestamp);
        address[] memory newAddresses = new address[](1);
        newAddresses[0] = address(0xdeadbeef);
        addresses = newAddresses;
        vertexPolicyNFT.batchGrantPermissions(addresses, permissionSignatures, expirationTimestamps);
        assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(uint256(uint160(address(0xdeadbeef))), permissionSignature[0]), newExpirationTimestamp[0]);
    }
}

contract RevokePermissions is VertexPolicyNFTTest {
  // TODO
}

contract BatchRevokePermissions is VertexPolicyNFTTest {
    function test_Revoke_CorrectlyRevokesPolicy() public {
        vm.expectEmit(true, true, true, true);
        emit PoliciesRevoked(policyIds, permissionSignatures);

        vertexPolicyNFT.batchRevokePolicies(policyIds, permissionSignatures);
        assertEq(vertexPolicyNFT.balanceOf(address(this)), 0);
    }

    function test_revoke_RevertIfNoPolicySpecified() public {
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchRevokePolicies(new uint256[](0), permissionSignatures);
    }

    function test_revoke_RevertIfPolicyNotGranted() public {
        uint256 mockPolicyId = uint256(uint160(address(0xdeadbeef)));
        policyIds[0] = mockPolicyId;

        vm.expectRevert("NOT_MINTED");
        vertexPolicyNFT.batchRevokePolicies(policyIds, permissionSignatures);
    }
}

contract HashPermission is VertexPolicyNFTTest {
  // TODO
}

contract HashPermissions is VertexPolicyNFTTest {
  // TODO
}

contract HasPermission is VertexPolicyNFTTest {
  // TODO
}

contract UpdatePermissions is VertexPolicyNFTTest {
  // TODO
}

contract GrantPermissions is VertexPolicyNFTTest {
  // TODO
}

contract SortedPermissionInsert is VertexPolicyNFTTest {
  // TODO
}

contract SortedPermissionRemove is VertexPolicyNFTTest {
  // TODO
}

contract PermissionIsInPermissionsArray is VertexPolicyNFTTest {
}

contract PermissionIsInPermissionsArrayCalldata is VertexPolicyNFTTest {
}

contract CheckExpiration is VertexPolicyNFTTest {
}

contract TransferFrom is VertexPolicyNFTTest {
    function test_transferFrom_RevertIfTransferFrom() public {
        vm.expectRevert(VertexPolicy.SoulboundToken.selector);
        vertexPolicyNFT.transferFrom(address(this), address(0xdeadbeef), ADDRESS_THIS_TOKEN_ID);
    }
}

contract HolderHasPermissionAt is VertexPolicyNFTTest {
    function test_holderHasPermissionAt_ReturnsCorrectBool() public {
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.number), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.number), false);
        addresses[0] = address(0xdeadbeef);

        vm.warp(block.timestamp + 100);

        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
        vertexPolicyNFT.batchRevokePolicies(policyIds, permissionSignatures);

        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp), false);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.timestamp), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp - 99), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.timestamp - 99), false);
    }
}

contract GetSupplyByPermissions is VertexPolicyNFTTest {
    function test_getSupplyByPermissions_ReturnsCorrectSupply() public {
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 1);
        addresses[0] = address(0xdeadbeef);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 2);
        vertexPolicyNFT.batchRevokePolicies(policyIds, permissionSignatures);
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 1);
    }
}

contract BatchUpdatePermissions is VertexPolicyNFTTest {
    function test_batchUpdatePermissions_UpdatesPermissionsCorrectly() public {
        bytes8 oldPermissionSignature = permissionSignature[0];
        assertEq(vertexPolicyNFT.hasPermission(policyIds[0], oldPermissionSignature), true);
        permissionsToRevoke = permissionSignatures;

        permission = PermissionData(address(0xdeadbeefdeadbeef), bytes4(0x09090909), VertexStrategy(address(0xdeadbeefdeadbeefdeafbeef)));
        permissions[0] = permission;
        permissionsArray[0] = permissions;
        permissionSignature[0] = vertexPolicyNFT.hashPermissions(permissions)[0];
        permissionSignatures[0] = permissionSignature;

        vm.warp(block.timestamp + 100);

        vm.expectEmit(true, true, true, true);
        emit PermissionsUpdated(policyIds, permissionSignatures, permissionsToRevoke, initialExpirationTimestamps);

        vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, initialExpirationTimestamps);

        assertEq(vertexPolicyNFT.hasPermission(policyIds[0], oldPermissionSignature), false);
        assertEq(vertexPolicyNFT.hasPermission(policyIds[0], permissionSignature[0]), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), oldPermissionSignature, block.timestamp - 100), true);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), oldPermissionSignature, block.timestamp), false);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp - 100), false);
        assertEq(vertexPolicyNFT.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp), true);
    }

    function test_batchUpdatePermissions_RevertIfArraysLengthMismatch() public {
        policyIds.push(uint256(uint160(address(0xdeadbeef))));
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, initialExpirationTimestamps);
    }

    function test_batchUpdatePermissions_updatesTimeStamp() public {
        uint256[] memory newExpirationTimestamp = new uint256[](1);
        newExpirationTimestamp[0] = block.timestamp + 1 days;
        expirationTimestamps.push(newExpirationTimestamp);
        assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), 0);
        vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, expirationTimestamps);
        assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), newExpirationTimestamp[0]);
    }

    function test_expirationTimestamp_RevertIfTimestampIsExpired() public {
        uint256[] memory newExpirationTimestamp = new uint256[](1);
        newExpirationTimestamp[0] = block.timestamp;
        expirationTimestamps.push(newExpirationTimestamp);
        address[] memory newAddresses = new address[](1);
        newAddresses[0] = address(0xdeadbeef);
        addresses = newAddresses;

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(VertexPolicy.Expired.selector);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, expirationTimestamps);
        newExpirationTimestamp[0] = block.timestamp - 1 seconds;
        expirationTimestamps[0] = newExpirationTimestamp;
        assertEq(block.timestamp > newExpirationTimestamp[0], true);
        vm.expectRevert(VertexPolicy.Expired.selector);
        vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, expirationTimestamps);
    }

    function test_expirationTimestamp_DoesNotHavePermissionIfExpired() public {
        assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), 0);
        assertEq(vertexPolicyNFT.hasPermission(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), true);

        uint256[] memory newExpirationTimestamp = new uint256[](1);
        newExpirationTimestamp[0] = block.timestamp + 1 days;
        expirationTimestamps.push(newExpirationTimestamp);
        vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, expirationTimestamps);

        vm.warp(block.timestamp + 2 days);

        assertEq(newExpirationTimestamp[0] < block.timestamp, true);
        assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), newExpirationTimestamp[0]);
        assertEq(vertexPolicyNFT.hasPermission(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), false);
    }
}

contract TokenURI is VertexPolicyNFTTest {
    function test_tokenURI_ReturnsCorrectURI() public {
        string memory baseURI = "https://vertex.link/policy/";
        vertexPolicyNFT.setBaseURI(baseURI);
        assertEq(vertexPolicyNFT.tokenURI(ADDRESS_THIS_TOKEN_ID), string.concat(baseURI, vm.toString(ADDRESS_THIS_TOKEN_ID)));
    }
}

contract TotalSupply is VertexPolicyNFTTest {
    function test_totalSupply_ReturnsCorrectSupply() public {
        assertEq(vertexPolicyNFT.totalSupply(), 1);
        addresses[0] = address(0xdeadbeef);
        vertexPolicyNFT.batchGrantPermissions(addresses, permissionSignatures, initialExpirationTimestamps);
        assertEq(vertexPolicyNFT.totalSupply(), 2);
        vertexPolicyNFT.batchRevokePermissions(policyIds, permissionSignatures);
        assertEq(vertexPolicyNFT.totalSupply(), 1);
    }
}

contract OnlyVertex is VertexPolicyNFTTest {
    function test_onlyVertex_RevertIfNotVertex() public {
        string memory baseURI = "https://vertex.link/policy/";
        vm.prank(address(0xdeadbeef));
        vm.expectRevert(VertexPolicy.OnlyVertex.selector);
        vertexPolicyNFT.setBaseURI(baseURI);
    }
}
