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
    uint256 immutable ADDRESS_THIS_TOKEN_ID = uint256(uint160(address(this)));
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
    function testFuzz_GrantsInitialPermissions( /*random array args*/ ) public {} // TODO
    function testFuzz_RevertIf_InvalidInput( /*random array lengths*/ ) public {} // TODO
}

contract SetVertex is VertexPolicyNFTTest {
    function testFuzz_SetsVertexInStorage(address _newVertex) public {
        // TODO
        // expect address to be present in storage
    }
    function testFuzz_RevertIf_AlreadyInitialized(address _newVertex) public {
        // TODO
        // expect revert if vertexPolicyNFT.setVertex(_newVertex) is called
    }
}

contract BatchGrantPolicies is VertexPolicyNFTTest {
    // TODO fuzz over addresses, permissionSignatures, expirationTimestamps
    function test_CorrectlyGrantsPermission() public {
        addresses[0] = address(0xdeadbeef);
        vm.expectEmit(true, true, true, true);
        emit PoliciesAdded(addresses, permissionSignatures, initialExpirationTimestamps);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
        assertEq(vertexPolicyNFT.balanceOf(address(0xdeadbeef)), 1);
        assertEq(vertexPolicyNFT.ownerOf(DEADBEEF_TOKEN_ID), address(0xdeadbeef));
    }

    // TODO fuzz over input array lengths
    function test_RevertIf_ArraysLengthsDoNotMatch() public {
        addresses.push(address(0xdeadbeef));
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
    }

    function test_RevertIf_PolicyAlreadyGranted() public {
        vm.expectRevert(VertexPolicy.OnlyOnePolicyPerHolder.selector);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
    }

    // TODO fuzz over addresses and initialExpirationTimestamps
    function test_RevertIf_PermissionsArrayIsEmpty() public {
        addresses[0] = address(0xdeadbeef);
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchGrantPolicies(addresses, new bytes8[][](0), initialExpirationTimestamps);
    }

    // TODO fuzz over address and expiration timestamp
    function test_GrantsTokenWithExpiration() public {
        uint256[] memory newExpirationTimestamp = new uint256[](1);
        newExpirationTimestamp[0] = block.timestamp + 1 days;
        expirationTimestamps.push(newExpirationTimestamp);
        address[] memory newAddresses = new address[](1);
        newAddresses[0] = address(0xdeadbeef);
        addresses = newAddresses;
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, expirationTimestamps);
        assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(uint256(uint160(address(0xdeadbeef))), permissionSignature[0]), newExpirationTimestamp[0]);
    }

    function testFuzz_RevertIf_ExpirationTimestampIsInPast(address _newAddress, uint256 _timedelta, bytes8 _permission) public {
        // TODO
        // uint256[] memory newExpirationTimestamp = new uint256[](1);
        // newExpirationTimestamp[0] = block.timestamp - _timedelta;
        // expirationTimestamps.push(newExpirationTimestamp);
        // address[] memory newAddresses = new address[](1);
        // newAddresses[0] = _newAddress;
        // addresses = newAddresses;
        // vm.expectRevert(Expired);
        // vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, expirationTimestamps);
    }

    function testFuzz_CheckpointsTokenPermissions(address _newAddress, uint256 _timedelta, bytes8 _permission) public {
        // TODO
        // batchGrantPolicies and confirm that tokenPermissionCheckpoints get added
    }

    function testFuzz_CheckpointsPermissionsSupply(address _newAddress, uint256 _timedelta, bytes8 _permission) public {
        // TODO
        // batchGrantPolicies and confirm that permissionSupplyCheckpoints get added
    }

    function testFuzz_RevertIf_CalledByAccountThatIsNotVertex(address _caller) public {
        // TODO
        // vm.assume(_caller != address(this));
        // vm.prank(_caller);
        // vm.expectRevert(OnlyVertex());
        // batchGrantPolicies(...);
    }
}

contract BatchRevokePolicies is VertexPolicyNFTTest {
    function test_RevokesSinglePolicy() public {
        vm.expectEmit(true, true, true, true);
        emit PoliciesRevoked(policyIds, permissionSignatures);

        vertexPolicyNFT.batchRevokePolicies(policyIds, permissionSignatures);
        assertEq(vertexPolicyNFT.balanceOf(address(this)), 0);
    }

    function test_RevokesMultiplePolicies() public {
        // TODO test that multiple policies can be revoked with a single call
    }

    function testFuzz_RevertIf_InputArraysAreMismatched(uint8 _policyIdsLength, uint8 _permissionsLength) public {
        // TODO
        // if (_policyIdsLength == _permissionsLength) _policyIdsLength++;
        // Instantiate random input args that differ in length.
        // vm.expectRevert(InvalidInput);
        // Call batchRevokePolicies with the mismatched inputs.
    }

    function test_RevertIf_NoPolicySpecified() public {
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchRevokePolicies(new uint256[](0), permissionSignatures);
    }

    function test_RevertIf_PolicyNotGranted() public {
        uint256 mockPolicyId = uint256(uint160(address(0xdeadbeef)));
        policyIds[0] = mockPolicyId;

        vm.expectRevert("NOT_MINTED");
        vertexPolicyNFT.batchRevokePolicies(policyIds, permissionSignatures);
    }

    function testFuzz_RevertIf_CalledByAccountThatIsNotVertex(address _caller) public {
        // TODO
        // vm.assume(_caller != address(this));
        // vm.prank(_caller);
        // vm.expectRevert(OnlyVertex());
        // call function(...);
    }
}

contract RevokePolicy is VertexPolicyNFTTest {
    // This can be called via batchRevokePolicies or by exposing the function
    // through a MockVertexPolicyNFT contract and using that in the tests, e.g.
    // function exposed_revokePolicy(...same args) public {
    //   revokePolicy(...args);
    // }
    function testFuzz_RevertIf_CallerIsNotOwner(address _caller) public {} // TODO
    function testFuzz_ZerosTokenPermissionCheckpoints(address _caller) public {} // TODO
    function testFuzz_DecrementsPermissionSuppylCheckpoints(address _caller) public {} // TODO
    function testFuzz_DecrementsTotalSupply(address _caller) public {} // TODO
    function testFuzz_BurnsTheNFT(address _caller) public {} // TODO
}

contract HashPermission is VertexPolicyNFTTest {
    function test_hashesPermissions() public {
        // TODO just a manual comparison of hashPermission
    }
}

contract HashPermissions is VertexPolicyNFTTest {
    function test_hashesPermissions() public {
        // TODO just a manual comparison of multiple permission hashes
    }
}

contract HasPermission is VertexPolicyNFTTest {
    function testFuzz_returnsTrueWhenPolicyHasPermission(address _owner, bytes8 _permission) public {
        // TODO
        // This is just a simple happy path test.
        // Grant the permission to a policy, confirm that hasPermission == true
    }

    function testFuzz_returnsFalseWhenPolicyNeverHadPermission(address _owner, bytes8 _permission) public {
        // TODO
        // Assert that hasPermission(uint(uint160(_owner)), _permission) == false
    }

    function testFuzz_returnsFalseWhenPolicyNoLongerHasPermission(address _owner, bytes8 _permission) public {
        // TODO
        // Grant the _permission to _owner.
        // vm.roll ahead.
        // Revoke the _permission.
        // vm.roll ahead.
        // Assert that hasPermission(uint(uint160(_owner)), _permission) == false
    }

    function testFuzz_returnsFalseWhenPolicyIsExpired(address _owner, bytes8 _permission) public {
        // TODO
        // Grant the _permission to _owner.
        // vm.warp past expiration.
        // Assert that hasPermission(uint(uint160(_owner)), _permission) == false
    }

    function testFuzz_returnsFalseWhenPolicyIdIsFake(address _owner, bytes8 _permission) public {
        // TODO
        // We just want to use a policy ID that hasn't been seen before.
        // Assert that hasPermission(uint(uint160(_owner)), _permission) == false
    }
}

contract TransferFrom is VertexPolicyNFTTest {
    // TODO convert to fuzz test, fuzzing over caller, from, and recipient
    function test_RevertIf_TransferFromIsCalled() public {
        vm.expectRevert(VertexPolicy.SoulboundToken.selector);
        vertexPolicyNFT.transferFrom(address(this), address(0xdeadbeef), ADDRESS_THIS_TOKEN_ID);
    }
}

contract RevokeExpiredPermission is VertexPolicyNFTTest {
    // TODO We'll need to expose tokenPermissionCheckpoints and
    // permissionSupplyCheckpoints for these tests. This is another reason to make a
    // MockVertexPolicyNFT contract.
    function testFuzz_UpdatesTokenPermissionCheckpoints(address _owner, bytes8 _permission, uint256 _timeUntilExpiration) public {
        // TODO
        // grant _permission to _owner that expires at block.time + _timeUntilExpiration.
        // assert that latest tokenPermissionCheckpoints[uint(_owner)][_permission] > 0
        // vm.warp past expiration time.
        // revokeExpiredPermission should return true
        // assert that latest tokenPermissionCheckpoints[uint(_owner)][_permission] == 0
    }

    function testFuzz_UpdatesPermissionSupplyCheckpoints(address _owner, bytes8 _permission, uint256 _timeUntilExpiration) public {
        // TODO
        // grant _permission to _owner that expires at block.time + _timeUntilExpiration.
        // get latest permissionSupplyCheckpoints[_permission]
        // vm.warp past expiration time.
        // revokeExpiredPermission should return true
        // assert that latest permissionSupplyCheckpoints[_permission] has been
        // decremented relative to the value we just got.
    }

    function testFuzz_NonExpiredPolicyIdReturnsFalse(address _owner, bytes8 _permission, uint256 _timeUntilExpiration) public {
        // TODO
        // grant _permission to _owner that expires at block.time + _timeUntilExpiration.
        // get latest permissionSupplyCheckpoints[_permission]
        // assert revokeExpiredPermission(uint(_owner), _permission) == false
        // assert permissionSupplyCheckpoints[_permission] hasn't changed
        // assert that latest tokenPermissionCheckpoints[uint(_owner)][_permission] == 1
    }

    function testFuzz_NonExistentPolicyIdReturnsFalse(address _owner, bytes8 _permission) public {
        // TODO
        // vm.assume _owner was never granted any permission (i.e. never had a policy).
        // get latest permissionSupplyCheckpoints[_permission]
        // assert revokeExpiredPermission(uint(_owner), _permission) == false
        // assert permissionSupplyCheckpoints[_permission] hasn't changed
    }
}

contract HolderHasPermissionAt is VertexPolicyNFTTest {
    function testFuzz_UnexpiredPolicyIsHandled(address _owner, bytes8 _permission, uint256 _timeUntilGrant, uint256 _timeUntilExpiration, uint256 _queryTime)
        public
    {
        // TODO
        // vm.warp(_timeUntilGrant);
        // grant _permission to _owner's policy with _timeUntilExpiration
        //   It's important that _timeUntilExpiration be allowed to be 0 so that we
        //   test permissions that don't expire as well as those that do.
        // if _timeUntilExpiration == 0, vm.warp(10 years or something)
        // else vm.warp(_timeUntilExpiration);
        // if _queryTime < _timeUntilGrant
        //   assert holderHasPermissionAt(_queryTime) == false
        // if _queryTime < _timeAfterExpiration
        //   assert holderHasPermissionAt(_queryTime) == true
        // if _queryTime >= _timeAfterExpiration
        //   assert holderHasPermissionAt(_queryTime) == false
    }

    function testFuzz_UnexpiredRevokedPolicyIsHandled(
        address _owner,
        bytes8 _permission,
        uint256 _timeUntilRevoke,
        uint256 _timeAfterRevoke,
        uint256 _queryTime
    ) public {
        // TODO
        // vm.assume(_queryTime <= _timeAfterRevoke);
        // grant _permission to _owner's policy without an expiration
        // vm.warp(_timeUntilRevoke);
        // revoke the policy
        // vm.warp(_timeAfterRevoke);
        // if _queryTime < _timeUntilRevoke
        //   assert that holderHasPermissionAt(_queryTime) == true
        // else
        //   assert that holderHasPermissionAt(_queryTime) == false
    }

    function testFuzz_ExpiredPolicyReturnsFalse(
        address _owner,
        bytes8 _permission,
        uint256 _timeUntilExpiration,
        bool _revokePermission,
        uint256 _timeAfterExpiration,
        uint256 _queryTime
    ) public {
        // TODO
        // The basic idea here is to vary:
        //   (a) when the policy expires
        //   (b) whether to revoke it
        //   (c) the timestamp provided to holderHasPermissionAt
        //   to confirm that no matter the combination, the function still returns false.
        // grant _permission to _owner's policy with _timeUntilExpiration
        // vm.warp(_timeUntilExpiration)
        // if _revokePermission, revoke the permission
        // vm.warp(_timeAfterExpiration)
        // if _queryTime < _timeUntilExpiration
        //   assert that holderHasPermissionAt(_queryTime) == true
        // else
        //   assert that holderHasPermissionAt(_queryTime) == false
    }

    function testFuzz_PolicyNeverHasPermissionReturnsFalse(address _owner, bytes8 _permissionToGrant, bytes8 _permissionToTest, uint256 _queryTime) public {
        // TODO
        // vm.assume(_queryTime < 10 years from now)
        // grant _permissionToGrant to _owner with no expiration
        // vm.warp(10 years from now);
        // assert holderHasPermissionAt(_owner, _permissionToTest, _queryTime) == false
    }

    function testFuzz_AddressWithoutPolicyReturnsFalse(address _owner, bytes8 _permission, uint256 _queryTime) public {
        // TODO
        // vm.assume(_queryTime < 10 years from now)
        // grant _permission to _owner with no expiration
        // vm.warp(10 years from now);
        // assert holderHasPermissionAt(_owner, _permission, _queryTime) == false
    }
}

contract GetSupplyByPermissions is VertexPolicyNFTTest {
    function test_ReturnsCorrectSupply() public {
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 1);
        addresses[0] = address(0xdeadbeef);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 2);
        vertexPolicyNFT.batchRevokePolicies(policyIds, permissionSignatures);
        assertEq(vertexPolicyNFT.getSupplyByPermissions(permissionSignature), 1);
    }

    function testFuzz_ReturnsCorrectSupply(uint8 _permissionCount) public {
        // TODO
        // assert getSupplyByPermissions(permissions) == 0
        // construct array of random addresses of length=_permissionCount
        // construct array of random byte8's of length=_permissionCount
        // vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, new uint[][](_permissionCount));
        // assert getSupplyByPermissions(permissions) == _permissionCount
    }
}

contract BatchUpdatePermissions is VertexPolicyNFTTest {
    function test_UpdatesPermissionsCorrectly() public {
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

    // TODO This should go away if/when we switch to passing in arrays of structs instead of nested arrays.
    function test_RevertIf_ArraysLengthsDoNotMatch() public {
        policyIds.push(uint256(uint160(address(0xdeadbeef))));
        vm.expectRevert(VertexPolicy.InvalidInput.selector);
        vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, initialExpirationTimestamps);
    }

    function test_updatesTimeStamp() public {
        uint256[] memory newExpirationTimestamp = new uint256[](1);
        newExpirationTimestamp[0] = block.timestamp + 1 days;
        expirationTimestamps.push(newExpirationTimestamp);
        assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), 0);
        vertexPolicyNFT.batchUpdatePermissions(policyIds, permissionSignatures, permissionsToRevoke, expirationTimestamps);
        assertEq(vertexPolicyNFT.tokenToPermissionExpirationTimestamp(ADDRESS_THIS_TOKEN_ID, permissionSignature[0]), newExpirationTimestamp[0]);
    }

    function test_RevertIf_TimestampIsExpired() public {
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

    function test_PermissionRemovalUpdatesTokenPermissionCheckpoints() public {
        // TODO
    }

    function test_PermissionRemovalUpdatesPermissionSupplyCheckpoints() public {
        // TODO
    }

    function test_PermissionAdditionUpdatesTokenPermissionCheckpoints() public {
        // TODO
    }

    function test_PermissionAdditionUpdatesPermissionSupplyCheckpoints() public {
        // TODO
    }

    function testFuzz_RevertIf_CalledByAccountThatIsNotVertex(address _caller) public {
        // TODO
        // vm.assume(_caller != address(this));
        // vm.prank(_caller);
        // vm.expectRevert(OnlyVertex());
        // call function(...);
    }
}

contract TokenURI is VertexPolicyNFTTest {
    function testFuzz_ReturnsCorrectURI(string memory _newURI) public {
        vertexPolicyNFT.setBaseURI(_newURI);
        assertEq(vertexPolicyNFT.tokenURI(ADDRESS_THIS_TOKEN_ID), string.concat(_newURI, vm.toString(ADDRESS_THIS_TOKEN_ID)));
    }

    function testFuzz_RevertIf_CalledByAccountThatIsNotVertex(address _caller, string memory _newURI) public {
        // TODO
        // vm.assume(_caller != address(this));
        // vm.expectRevert(OnlyVertex());
        // vm.prank(_caller);
        // vertexPolicyNFT.setBaseURI(_newURI);
    }
}

contract TotalSupply is VertexPolicyNFTTest {
    function test_totalSupply_ReturnsCorrectSupply() public {
        assertEq(vertexPolicyNFT.totalSupply(), 1);
        addresses[0] = address(0xdeadbeef);
        vertexPolicyNFT.batchGrantPolicies(addresses, permissionSignatures, initialExpirationTimestamps);
        assertEq(vertexPolicyNFT.totalSupply(), 2);
        vertexPolicyNFT.batchRevokePolicies(policyIds, permissionSignatures);
        assertEq(vertexPolicyNFT.totalSupply(), 1);
    }
}
