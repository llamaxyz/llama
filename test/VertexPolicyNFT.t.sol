// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "lib/forge-std/src/console.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {IVertexCore} from "src/interfaces/IVertexCore.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {
  PermissionData, PolicyUpdateData, PermissionMetadata, PolicyGrantData, PolicyRevokeData
} from "src/lib/Structs.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {console} from "lib/forge-std/src/console.sol";

contract VertexPolicyTest is Test {
  event PolicyAdded(PolicyGrantData grantData);
  event PermissionUpdated(PolicyUpdateData updateData);
  event PolicyRevoked(PolicyRevokeData revokeData);

  VertexPolicy public vertexPolicyLogic;
  VertexPolicy public vertexPolicy;
  VertexLens public vertexLens;
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
  PolicyRevokeData[] public policyRevokeData;
  uint256 ADDRESS_THIS_TOKEN_ID;
  uint256 constant DEADBEEF_TOKEN_ID = uint256(uint160(address(0xdeadbeef)));

  function _buildPermissionMetadata() internal pure returns (PermissionMetadata[] memory permissionMetadata) {
    PermissionData memory _permission = PermissionData(
      // TODO These values should be function inputs so they can fuzzed over.
      address(0xdeadbeef),
      bytes4(0x08080808),
      VertexStrategy(address(0xdeadbeefdeadbeef))
    );
    permissionMetadata = new PermissionMetadata[](1);
    permissionMetadata[0] =
      PermissionMetadata({permissionId: bytes8(keccak256(abi.encode(_permission))), expirationTimestamp: 0});
  }

  function _buildBatchGrantData(address _user) internal pure returns (PolicyGrantData[] memory _batchGrantData) {
    _batchGrantData = new PolicyGrantData[](1);
    _batchGrantData[0] = PolicyGrantData(_user, _buildPermissionMetadata());
  }

  function generateGenericPermissionArray() internal {
    permission = PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)));
    permissions.push(permission);
    permissionsArray.push(permissions);
    permissionSignature.push(vertexLens.hashPermission(permission));
    permissionSignatures.push(permissionSignature);
    addresses.push(address(this));
    policyRevokeData.push(PolicyRevokeData(uint256(uint160(address(this))), permissionSignature));
  }

  function setUp() public {
    vertexLens = new VertexLens();
    PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(this));
    vertexPolicyLogic = new VertexPolicy();
    vertexPolicy = VertexPolicy(Clones.cloneDeterministic(address(vertexPolicyLogic), keccak256(abi.encode("TST")))); //Clones.cloneDeterministic(address(vertexAccountImplementation),
    vertexPolicy.initialize("Test", "TST", initialBatchGrantData);
    vertexPolicy.setVertex(address(this));
    ADDRESS_THIS_TOKEN_ID = uint256(uint160(address(this)));
    generateGenericPermissionArray();
    policyIds.push(ADDRESS_THIS_TOKEN_ID);
  }

  function test_grantPermission_CorrectlyGrantsPermission() public {
    addresses[0] = address(0xdeadbeef);
    PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(addresses[0]);
    vm.expectEmit(true, true, true, true);
    emit PolicyAdded(initialBatchGrantData[0]);
    vertexPolicy.batchGrantPolicies(initialBatchGrantData);
    assertEq(vertexPolicy.balanceOf(address(0xdeadbeef)), 1);
    assertEq(vertexPolicy.ownerOf(DEADBEEF_TOKEN_ID), address(0xdeadbeef));
  }

  function test_grantPermission_RevertIfPolicyAlreadyGranted() public {
    vm.expectRevert(VertexPolicy.OnlyOnePolicyPerHolder.selector);
    PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(this));
    vertexPolicy.batchGrantPolicies(initialBatchGrantData);
  }

  function test_Revoke_CorrectlyRevokesPolicy() public {
    vm.expectEmit(true, true, true, true);
    emit PolicyRevoked(policyRevokeData[0]);

    vertexPolicy.batchRevokePolicies(policyRevokeData);
    assertEq(vertexPolicy.balanceOf(address(this)), 0);
  }

  function test_revoke_RevertIfPolicyNotGranted() public {
    uint256 mockPolicyId = uint256(uint160(address(0xdeadbeef)));
    policyIds[0] = mockPolicyId;
    policyRevokeData[0] = PolicyRevokeData(mockPolicyId, permissionSignature);
    vm.expectRevert("NOT_MINTED");
    vertexPolicy.batchRevokePolicies(policyRevokeData);
  }

  function test_transferFrom_RevertIfTransferFrom() public {
    vm.expectRevert(VertexPolicy.SoulboundToken.selector);
    vertexPolicy.transferFrom(address(this), address(0xdeadbeef), ADDRESS_THIS_TOKEN_ID);
  }

  function test_holderHasPermissionAt_ReturnsCorrectBool() public {
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionSignature[0], block.number), true);
    assertEq(vertexPolicy.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.number), false);
    addresses[0] = address(0xdeadbeef);
    vm.warp(block.timestamp + 100);

    PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(0xdeadbeef));
    vertexPolicy.batchGrantPolicies(initialBatchGrantData);
    vertexPolicy.batchRevokePolicies(policyRevokeData);

    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp), false);
    assertEq(vertexPolicy.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.timestamp), true);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp - 99), true);
    assertEq(
      vertexPolicy.holderHasPermissionAt(address(0xdeadbeef), permissionSignature[0], block.timestamp - 99), false
    );
  }

  function test_getSupplyByPermissions_ReturnsCorrectSupply() public {
    assertEq(vertexPolicy.getSupplyByPermissions(permissionSignature), 1);
    addresses[0] = address(0xdeadbeef);
    PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(0xdeadbeef));
    vertexPolicy.batchGrantPolicies(initialBatchGrantData);
    assertEq(vertexPolicy.getSupplyByPermissions(permissionSignature), 2);
    vertexPolicy.batchRevokePolicies(policyRevokeData);
    assertEq(vertexPolicy.getSupplyByPermissions(permissionSignature), 1);
  }

  function test_batchUpdatePermissions_UpdatesPermissionsCorrectly() public {
    bytes8 oldPermissionSignature = permissionSignature[0];
    assertEq(vertexPolicy.hasPermission(policyIds[0], oldPermissionSignature), true);
    permissionsToRevoke = permissionSignatures;

    permission = PermissionData(
      address(0xdeadbeefdeadbeef), bytes4(0x09090909), VertexStrategy(address(0xdeadbeefdeadbeefdeafbeef))
    );
    permissions[0] = permission;
    permissionsArray[0] = permissions;
    permissionSignature[0] = vertexLens.hashPermission(permission);
    permissionSignatures[0] = permissionSignature;

    PermissionMetadata[] memory toAdd = new PermissionMetadata[](1);
    PermissionMetadata[] memory toRemove = new PermissionMetadata[](1);

    toAdd[0] = PermissionMetadata(permissionSignature[0], 0);
    toRemove[0] = PermissionMetadata(oldPermissionSignature, 0);

    PolicyUpdateData[] memory updateData = new PolicyUpdateData[](1);
    updateData[0] = PolicyUpdateData(policyIds[0], toAdd, toRemove);

    vm.warp(block.timestamp + 100);

    vm.expectEmit(true, true, true, true);
    emit PermissionUpdated(updateData[0]);

    vertexPolicy.batchUpdatePermissions(updateData);

    assertEq(vertexPolicy.hasPermission(policyIds[0], oldPermissionSignature), false);
    assertEq(vertexPolicy.hasPermission(policyIds[0], permissionSignature[0]), true);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), oldPermissionSignature, block.timestamp - 100), true);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), oldPermissionSignature, block.timestamp), false);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp - 100), false);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionSignature[0], block.timestamp), true);
  }

  // function test_batchUpdatePermissions_RevertIfArraysLengthMismatch() public {
  //     policyIds.push(uint256(uint160(address(0xdeadbeef))));
  //     vm.expectRevert(VertexPolicy.InvalidInput.selector);
  //     vertexPolicy.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke,
  // initialExpirationTimestamps);
  // }

  // function test_batchUpdatePermissions_updatesTimeStamp() public {
  //     uint256[] memory newExpirationTimestamp = new uint256[](1);
  //     newExpirationTimestamp[0] = block.timestamp + 1 days;
  //     expirationTimestamps.push(newExpirationTimestamp);
  //     assertEq(vertexPolicy.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]),
  // 0);
  //     vertexPolicy.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke,
  // expirationTimestamps);
  //     assertEq(vertexPolicy.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]),
  // newExpirationTimestamp[0]);
  // }

  function test_tokenURI_ReturnsCorrectURI() public {
    string memory baseURI = "https://vertex.link/policy/";
    vertexPolicy.setBaseURI(baseURI);
    assertEq(vertexPolicy.tokenURI(ADDRESS_THIS_TOKEN_ID), string.concat(baseURI, vm.toString(ADDRESS_THIS_TOKEN_ID)));
  }

  function test_totalSupply_ReturnsCorrectSupply() public {
    assertEq(vertexPolicy.totalSupply(), 1);
    addresses[0] = address(0xdeadbeef);
    vertexPolicy.batchGrantPolicies(_buildBatchGrantData(addresses[0]));
    assertEq(vertexPolicy.totalSupply(), 2);
    vertexPolicy.batchRevokePolicies(policyRevokeData);
    assertEq(vertexPolicy.totalSupply(), 1);
  }

  function test_onlyVertex_RevertIfNotVertex() public {
    string memory baseURI = "https://vertex.link/policy/";
    vm.prank(address(0xdeadbeef));
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);
    vertexPolicy.setBaseURI(baseURI);
  }

  // function test_expirationTimestamp_DoesNotHavePermissionIfExpired() public {
  //     assertEq(vertexPolicy.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]),
  // 0);
  //     assertEq(vertexPolicy.hasPermission(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), true);

  //     uint256[] memory newExpirationTimestamp = new uint256[](1);
  //     newExpirationTimestamp[0] = block.timestamp + 1 days;
  //     expirationTimestamps.push(newExpirationTimestamp);
  //     vertexPolicy.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke,
  // expirationTimestamps);

  //     vm.warp(block.timestamp + 2 days);

  //     assertEq(newExpirationTimestamp[0] < block.timestamp, true);
  //     assertEq(vertexPolicy.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]),
  // newExpirationTimestamp[0]);
  //     assertEq(vertexPolicy.hasPermission(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), false);
  // }

  function test_grantPermissions_GrantsTokenWithExpiration() public {
    uint256 _newExpirationTimestamp = block.timestamp + 1 days;
    address _newAddress = address(0xdeadbeef);

    PermissionMetadata[] memory _changes = new PermissionMetadata[](1);
    _changes[0] = PermissionMetadata(permissionSignature[0], _newExpirationTimestamp);

    PolicyGrantData[] memory initialBatchGrantData = new PolicyGrantData[](1);
    initialBatchGrantData[0] = PolicyGrantData(_newAddress, _changes);
    vertexPolicy.batchGrantPolicies(initialBatchGrantData);

    assertEq(
      vertexPolicy.tokenToPermissionExpirationTimestamp(uint256(uint160(_newAddress)), permissionSignature[0]),
      _newExpirationTimestamp
    );
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
  //     vertexPolicy.batchGrantPolicies(addresses, permissionSignatures, expirationTimestamps);
  //     newExpirationTimestamp[0] = block.timestamp - 1 seconds;
  //     expirationTimestamps[0] = newExpirationTimestamp;
  //     assertEq(block.timestamp > newExpirationTimestamp[0], true);
  //     vm.expectRevert(VertexPolicy.Expired.selector);
  //     vertexPolicy.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke,
  // expirationTimestamps);
  // }
}
