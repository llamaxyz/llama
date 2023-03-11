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
import {VertexTestSetup} from "test/utils/VertexTestSetup.sol";

// TODO Need to uncomment and update tests.
contract VertexPolicyTest is VertexTestSetup {
  event PolicyAdded(PolicyGrantData grantData);
  event PermissionUpdated(PolicyUpdateData updateData);
  event PolicyRevoked(PolicyRevokeData revokeData);

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
}

contract Initialize is VertexPolicyTest {
  function test_SetsNameAndSymbol() public {
    assertEq(policy.name(), "Root Vertex");
    assertEq(policy.symbol(), "V_Roo_0");
  }

  function test_RevertsIf_InitializeIsCalledTwice() public {
    PolicyGrantData[] memory policies = getDefaultPolicies();
    vm.expectRevert("Initializable: contract is already initialized");
    policy.initialize("Test", 1, policies);
  }
}

contract HolderWeightAt is VertexPolicyTest {
  function test_ReturnsCorrectValue() public {
    // TODO
    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.number), 1);
    // assertEq(policy.holderWeightAt(policyHolderPam, permissionId1, block.number), 0);

    // vm.warp(block.timestamp + 100);

    // PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(address(0xdeadbeef));
    // policy.batchGrantPolicies(initialBatchGrantData);
    // policy.batchRevokePolicies(policyRevokeData);

    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.timestamp), 0);
    // assertEq(policy.holderWeightAt(address(0xdeadbeef), permissionId1, block.timestamp), 1);
    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.timestamp - 99), 1);
    // assertEq(policy.holderWeightAt(address(0xdeadbeef), permissionId1, block.timestamp - 99), 0);
  }
}

contract TotalSupplyAt is VertexPolicyTest {
// TODO Add tests.
}

contract BatchGrantPolicies is VertexPolicyTest {
  function test_CorrectlyGrantsPermission() public {
    // PolicyGrantData[] memory initialBatchGrantData = _buildBatchGrantData(policyHolderPam);
    // vm.expectEmit(true, true, true, true);
    // emit PolicyAdded(initialBatchGrantData[0]);
    // policy.batchGrantPolicies(initialBatchGrantData);
    // assertEq(policy.balanceOf(address(0xdeadbeef)), 1);
    // assertEq(policy.ownerOf(DEADBEEF_TOKEN_ID), address(0xdeadbeef));
  }

  function test_RevertIfPolicyAlreadyGranted() public {
    // PolicyGrantData[] memory policies;
    // vm.expectRevert(VertexPolicy.OnlyOnePolicyPerHolder.selector);
    // policy.batchGrantPolicies(policies);
  }
}

contract BatchUpdatePermissions is VertexPolicyTest {
  function test_UpdatesPermissionsCorrectly() public {
    // bytes32 oldPermissionSignature = permissionId1;
    // assertEq(policy.hasPermission(policyIds[0], oldPermissionSignature), true);
    // permissionsToRevoke = permissionIds;

    // permission = PermissionData(
    //   address(0xdeadbeefdeadbeef), bytes4(0x09090909), VertexStrategy(address(0xdeadbeefdeadbeefdeafbeef))
    // );
    // permissions[0] = permission;
    // permissionsArray[0] = permissions;
    // permissionId1 = lens.computePermissionId(permission);
    // permissionIds[0] = permissionId;

    // PermissionMetadata[] memory toAdd = new PermissionMetadata[](1);
    // PermissionMetadata[] memory toRemove = new PermissionMetadata[](1);

    // toAdd[0] = PermissionMetadata(permissionId1, 0);
    // toRemove[0] = PermissionMetadata(permissionId2, 0);

    // PolicyUpdateData[] memory updateData = new PolicyUpdateData[](1);
    // updateData[0] = PolicyUpdateData(policyIds[0], toAdd, toRemove);

    // vm.warp(block.timestamp + 100);

    // vm.expectEmit(true, true, true, true);
    // emit PermissionUpdated(updateData[0]);

    // policy.batchUpdatePermissions(updateData);

    // assertEq(policy.hasPermission(policyIds[0], oldPermissionSignature), false);
    // assertEq(policy.hasPermission(policyIds[0], permissionId1), true);
    // assertEq(policy.holderWeightAt(address(this), oldPermissionSignature, block.timestamp - 100), 1);
    // assertEq(policy.holderWeightAt(address(this), oldPermissionSignature, block.timestamp), 0);
    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.timestamp - 100), 0);
    // assertEq(policy.holderWeightAt(address(this), permissionId1, block.timestamp), 1);
  }

  function test_updatesTimeStamp() public {
    // bytes32 _permissionId = lens.computePermissionId(
    //   PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)))
    // ); // same permission as in setup

    // PermissionMetadata[] memory permissionsToAdd = new PermissionMetadata[](1);
    // permissionsToAdd[0] = PermissionMetadata(_permissionId, block.timestamp + 1 days);

    // PolicyUpdateData memory updateData = PolicyUpdateData(SELF_TOKEN_ID, permissionsToAdd, new
    // PermissionMetadata[](0));
    // PolicyUpdateData[] memory updateDataArray = new PolicyUpdateData[](1);
    // updateDataArray[0] = updateData;
    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, permissionId1), 0);
    // policy.batchUpdatePermissions(updateDataArray);
    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, permissionId1), block.timestamp + 1 days);
  }
}

contract BatchRevokePolicies is VertexPolicyTest {
  function test_CorrectlyRevokesPolicy() public {
    // vm.expectEmit(true, true, true, true);
    // emit PolicyRevoked(policyRevokeData[0]);
    // policy.batchRevokePolicies(policyRevokeData);
    // assertEq(policy.balanceOf(address(this)), 0);
  }

  function test_RevertIf_PolicyNotGranted() public {
    // uint256 mockPolicyId = uint256(uint160(address(0xdeadbeef)));
    // policyIds[0] = mockPolicyId;
    // policyRevokeData[0] = PolicyRevokeData(mockPolicyId, permissionId);
    // vm.expectRevert("NOT_MINTED");
    // policy.batchRevokePolicies(policyRevokeData);
  }
}

contract HasPermission is VertexPolicyTest {
// TODO Add tests.
}

contract RevokeExpiredPermission is VertexPolicyTest {
// TODO Add tests.
}

contract TransferFrom is VertexPolicyTest {
  function test_transferFrom_RevertIfTransferFrom() public {
    vm.expectRevert(VertexPolicy.SoulboundToken.selector);
    policy.transferFrom(address(this), address(0xdeadbeef), SELF_TOKEN_ID);
  }
}

contract TokenURI is VertexPolicyTest {
  function test_ReturnsCorrectTokenURI() public {
    assertEq(policy.tokenURI(SELF_TOKEN_ID), string.concat(policy.baseURI(), vm.toString(SELF_TOKEN_ID)));
  }
}

contract TotalSupply is VertexPolicyTest {
  function test_ReturnsCorrectTotalSupply() public {
    // assertEq(policy.totalSupply(), 1);
    // addresses[0] = address(0xdeadbeef);
    // policy.batchGrantPolicies(_buildBatchGrantData(addresses[0]));
    // assertEq(policy.totalSupply(), 2);
    // policy.batchRevokePolicies(policyRevokeData);
    // assertEq(policy.totalSupply(), 1);
  }
}

contract SetBaseURI is VertexPolicyTest {
  function test_RevertIf_CallerIsNotVertex() public {
    string memory baseURI = "https://vertex.link/policy/";
    vm.prank(address(0xdeadbeef));
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);
    policy.setBaseURI(baseURI);
  }

  function test_SetsBaseURIInStorage() public {
    string memory baseURI = "https://vertex.link/policy/";
    vm.prank(address(core));
    policy.setBaseURI(baseURI);
    assertEq(policy.baseURI(), baseURI);
  }
}

contract ExpirationTests is VertexPolicyTest {
  // TODO Refactor these so they are in the correct method contracts
  function test_expirationTimestamp_DoesNotHavePermissionIfExpired() public {
    // bytes32 _permissionId = lens.computePermissionId(
    //   PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)))
    // ); // same permission as in setup

    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, _permissionId), 0);
    // assertEq(policy.hasPermission(SELF_TOKEN_ID, _permissionId), true);

    // uint256 newExpirationTimestamp = block.timestamp + 1 days;

    // PermissionMetadata[] memory permissionsToAdd = new PermissionMetadata[](1);
    // permissionsToAdd[0] = PermissionMetadata(_permissionId, newExpirationTimestamp);

    // PolicyUpdateData memory updateData = PolicyUpdateData(SELF_TOKEN_ID, permissionsToAdd, new
    // PermissionMetadata[](0));
    // PolicyUpdateData[] memory updateDataArray = new PolicyUpdateData[](1);
    // updateDataArray[0] = updateData;

    // policy.batchUpdatePermissions(updateDataArray);

    // vm.warp(block.timestamp + 2 days);

    // assertEq(newExpirationTimestamp < block.timestamp, true);
    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, _permissionId), newExpirationTimestamp);
    // assertEq(policy.hasPermission(SELF_TOKEN_ID, _permissionId), false);
  }

  function test_grantPermissions_GrantsTokenWithExpiration() public {
    // uint256 _newExpirationTimestamp = block.timestamp + 1 days;
    // address _newAddress = address(0xdeadbeef);

    // PermissionMetadata[] memory _changes = new PermissionMetadata[](1);
    // _changes[0] = PermissionMetadata(permissionId1, _newExpirationTimestamp);

    // PolicyGrantData[] memory initialBatchGrantData = new PolicyGrantData[](1);
    // initialBatchGrantData[0] = PolicyGrantData(_newAddress, _changes);
    // policy.batchGrantPolicies(initialBatchGrantData);

    // assertEq(
    //   policy.tokenToPermissionExpirationTimestamp(uint256(uint160(_newAddress)), permissionId1),
    // _newExpirationTimestamp
    // );
  }

  function test_expirationTimestamp_RevertIfTimestampIsExpired() public {
    // vm.warp(block.timestamp + 1 days);

    // bytes32 _permissionId = lens.computePermissionId(
    //   PermissionData(address(0xdeadbeef), bytes4(0x08080808), VertexStrategy(address(0xdeadbeefdeadbeef)))
    // ); // same permission as in setup

    // assertEq(policy.tokenToPermissionExpirationTimestamp(SELF_TOKEN_ID, _permissionId), 0);
    // assertEq(policy.hasPermission(SELF_TOKEN_ID, _permissionId), true);

    // uint256 newExpirationTimestamp = block.timestamp - 1 days;

    // PermissionMetadata[] memory permissionsToAdd = new PermissionMetadata[](1);
    // permissionsToAdd[0] = PermissionMetadata(_permissionId, newExpirationTimestamp);

    // PolicyUpdateData memory updateData = PolicyUpdateData(SELF_TOKEN_ID, permissionsToAdd, new
    // PermissionMetadata[](0));
    // PolicyUpdateData[] memory updateDataArray = new PolicyUpdateData[](1);
    // updateDataArray[0] = updateData;

    // PolicyGrantData[] memory grantData = new PolicyGrantData[](1);
    // grantData[0] = PolicyGrantData(address(0x1), permissionsToAdd);

    // vm.expectRevert(VertexPolicy.Expired.selector);
    // policy.batchGrantPolicies(grantData);
    // assertEq(block.timestamp > newExpirationTimestamp, true);
    // vm.expectRevert(VertexPolicy.Expired.selector);
    // policy.batchUpdatePermissions(updateDataArray);
  }
}
