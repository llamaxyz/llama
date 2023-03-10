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
  bytes8[] public permissionId;
  bytes8[][] public permissionIds;
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
    permissionId.push(vertexLens.computePermissionId(permission));
    permissionIds.push(permissionId);
    addresses.push(address(this));
    policyRevokeData.push(PolicyRevokeData(uint256(uint160(address(this))), permissionId));
  }

  function setUp() public {
    vertexLens = new VertexLens();
    PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(this));
    vertexPolicyLogic = new VertexPolicy();
    vertexPolicy = VertexPolicy(Clones.cloneDeterministic(address(vertexPolicyLogic), keccak256(abi.encode("TST"))));
    vertexPolicy.initialize("Test", "TST", initialBatchGrantData);
    vertexPolicy.setVertex(address(this));
    ADDRESS_THIS_TOKEN_ID = uint256(uint160(address(this)));
    generateGenericPermissionArray();
    policyIds.push(ADDRESS_THIS_TOKEN_ID);
  }

  function test_initialize_SetsNameAndSymbol() public {
    assertEq(vertexPolicy.name(), "Test");
    assertEq(vertexPolicy.symbol(), "TST");
  }

  function test_initialize_CannotInitializeTwice() public {
    PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(this));
    vm.expectRevert("Initializable: contract is already initialized");
    vertexPolicy.initialize("Test", "TST", initialBatchGrantData);
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
    policyRevokeData[0] = PolicyRevokeData(mockPolicyId, permissionId);
    vm.expectRevert("NOT_MINTED");
    vertexPolicy.batchRevokePolicies(policyRevokeData);
  }

  function test_transferFrom_RevertIfTransferFrom() public {
    vm.expectRevert(VertexPolicy.SoulboundToken.selector);
    vertexPolicy.transferFrom(address(this), address(0xdeadbeef), ADDRESS_THIS_TOKEN_ID);
  }

  function test_holderHasPermissionAt_ReturnsCorrectBool() public {
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionId[0], block.number), true);
    assertEq(vertexPolicy.holderHasPermissionAt(address(0xdeadbeef), permissionId[0], block.number), false);
    addresses[0] = address(0xdeadbeef);
    vm.warp(block.timestamp + 100);

    PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(0xdeadbeef));
    vertexPolicy.batchGrantPolicies(initialBatchGrantData);
    vertexPolicy.batchRevokePolicies(policyRevokeData);

    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionId[0], block.timestamp), false);
    assertEq(vertexPolicy.holderHasPermissionAt(address(0xdeadbeef), permissionId[0], block.timestamp), true);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionId[0], block.timestamp - 99), true);
    assertEq(vertexPolicy.holderHasPermissionAt(address(0xdeadbeef), permissionId[0], block.timestamp - 99), false);
  }

  function test_getSupplyByPermissions_ReturnsCorrectSupply() public {
    assertEq(vertexPolicy.getSupplyByPermissions(permissionId), 1);
    addresses[0] = address(0xdeadbeef);
    PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(0xdeadbeef));
    vertexPolicy.batchGrantPolicies(initialBatchGrantData);
    assertEq(vertexPolicy.getSupplyByPermissions(permissionId), 2);
    vertexPolicy.batchRevokePolicies(policyRevokeData);
    assertEq(vertexPolicy.getSupplyByPermissions(permissionId), 1);
  }

  function test_batchUpdatePermissions_UpdatesPermissionsCorrectly() public {
    bytes8 oldpermissionId = permissionId[0];
    assertEq(vertexPolicy.hasPermission(policyIds[0], oldpermissionId), true);
    permissionsToRevoke = permissionIds;

    permission = PermissionData(
      address(0xdeadbeefdeadbeef), bytes4(0x09090909), VertexStrategy(address(0xdeadbeefdeadbeefdeafbeef))
    );
    permissions[0] = permission;
    permissionsArray[0] = permissions;
    permissionId[0] = vertexLens.computePermissionId(permission);
    permissionIds[0] = permissionId;

    PermissionMetadata[] memory toAdd = new PermissionMetadata[](1);
    PermissionMetadata[] memory toRemove = new PermissionMetadata[](1);

    toAdd[0] = PermissionMetadata(permissionId[0], 0);
    toRemove[0] = PermissionMetadata(oldpermissionId, 0);

    PolicyUpdateData[] memory updateData = new PolicyUpdateData[](1);
    updateData[0] = PolicyUpdateData(policyIds[0], toAdd, toRemove);

    vm.warp(block.timestamp + 100);

    vm.expectEmit(true, true, true, true);
    emit PermissionUpdated(updateData[0]);

    vertexPolicy.batchUpdatePermissions(updateData);

    assertEq(vertexPolicy.hasPermission(policyIds[0], oldpermissionId), false);
    assertEq(vertexPolicy.hasPermission(policyIds[0], permissionId[0]), true);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), oldpermissionId, block.timestamp - 100), true);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), oldpermissionId, block.timestamp), false);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionId[0], block.timestamp - 100), false);
    assertEq(vertexPolicy.holderHasPermissionAt(address(this), permissionId[0], block.timestamp), true);
  }

  function test_batchUpdatePermissions_updatesTimeStamp() public {
    bytes8 _permissionId = vertexLens.computePermissionId(
      PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)))
    ); // same permission as in setup

    PermissionMetadata[] memory permissionsToAdd = new PermissionMetadata[](1);
    permissionsToAdd[0] = PermissionMetadata(_permissionId, block.timestamp + 1 days);

    PolicyUpdateData memory updateData =
      PolicyUpdateData(ADDRESS_THIS_TOKEN_ID, permissionsToAdd, new PermissionMetadata[](0));
    PolicyUpdateData[] memory updateDataArray = new PolicyUpdateData[](1);
    updateDataArray[0] = updateData;
    assertEq(vertexPolicy.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionId[0]), 0);
    vertexPolicy.batchUpdatePermissions(updateDataArray);
    assertEq(
      vertexPolicy.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionId[0]),
      block.timestamp + 1 days
    );
  }

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

  function test_expirationTimestamp_DoesNotHavePermissionIfExpired() public {
    bytes8 _permissionId = vertexLens.computePermissionId(
      PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)))
    ); // same permission as in setup

    assertEq(vertexPolicy.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, _permissionId), 0);
    assertEq(vertexPolicy.hasPermission(ADDRESS_THIS_TOKEN_ID, _permissionId), true);

    uint256 newExpirationTimestamp = block.timestamp + 1 days;

    PermissionMetadata[] memory permissionsToAdd = new PermissionMetadata[](1);
    permissionsToAdd[0] = PermissionMetadata(_permissionId, newExpirationTimestamp);

    PolicyUpdateData memory updateData =
      PolicyUpdateData(ADDRESS_THIS_TOKEN_ID, permissionsToAdd, new PermissionMetadata[](0));
    PolicyUpdateData[] memory updateDataArray = new PolicyUpdateData[](1);
    updateDataArray[0] = updateData;

    vertexPolicy.batchUpdatePermissions(updateDataArray);

    vm.warp(block.timestamp + 2 days);

    assertEq(newExpirationTimestamp < block.timestamp, true);
    assertEq(
      vertexPolicy.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, _permissionId), newExpirationTimestamp
    );
    assertEq(vertexPolicy.hasPermission(ADDRESS_THIS_TOKEN_ID, _permissionId), false);
  }

  function test_grantPermissions_GrantsTokenWithExpiration() public {
    uint256 _newExpirationTimestamp = block.timestamp + 1 days;
    address _newAddress = address(0xdeadbeef);

    PermissionMetadata[] memory _changes = new PermissionMetadata[](1);
    _changes[0] = PermissionMetadata(permissionId[0], _newExpirationTimestamp);

    PolicyGrantData[] memory initialBatchGrantData = new PolicyGrantData[](1);
    initialBatchGrantData[0] = PolicyGrantData(_newAddress, _changes);
    vertexPolicy.batchGrantPolicies(initialBatchGrantData);

    assertEq(
      vertexPolicy.tokenToPermissionExpirationTimestamp(uint256(uint160(_newAddress)), permissionId[0]),
      _newExpirationTimestamp
    );
  }

  function test_expirationTimestamp_RevertIfTimestampIsExpired() public {
    vm.warp(block.timestamp + 1 days);

    bytes8 _permissionId = vertexLens.computePermissionId(
      PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)))
    ); // same permission as in setup

    assertEq(vertexPolicy.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, _permissionId), 0);
    assertEq(vertexPolicy.hasPermission(ADDRESS_THIS_TOKEN_ID, _permissionId), true);

    uint256 newExpirationTimestamp = block.timestamp - 1 days;

    PermissionMetadata[] memory permissionsToAdd = new PermissionMetadata[](1);
    permissionsToAdd[0] = PermissionMetadata(_permissionId, newExpirationTimestamp);

    PolicyUpdateData memory updateData =
      PolicyUpdateData(ADDRESS_THIS_TOKEN_ID, permissionsToAdd, new PermissionMetadata[](0));
    PolicyUpdateData[] memory updateDataArray = new PolicyUpdateData[](1);
    updateDataArray[0] = updateData;

    PolicyGrantData[] memory grantData = new PolicyGrantData[](1);
    grantData[0] = PolicyGrantData(address(0x1), permissionsToAdd);

    vm.expectRevert(VertexPolicy.Expired.selector);
    vertexPolicy.batchGrantPolicies(grantData);
    assertEq(block.timestamp > newExpirationTimestamp, true);
    vm.expectRevert(VertexPolicy.Expired.selector);
    vertexPolicy.batchUpdatePermissions(updateDataArray);
  }

  function test_tokenURI_SVGReturnsCorrectly() public {
    string memory uri = vertexPolicy.tokenURI(ADDRESS_THIS_TOKEN_ID);
    //TODO: test SVG
  }
}
