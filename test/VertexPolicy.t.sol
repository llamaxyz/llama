// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/forge-std/src/console.sol";
import {Test, stdError, console2} from "lib/forge-std/src/Test.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {Base64} from "@solady/utils/Base64.sol";
import {console} from "lib/forge-std/src/console.sol";
import {Roles, VertexTestSetup} from "test/utils/VertexTestSetup.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {Checkpoints} from "src/lib/Checkpoints.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {Solarray} from "solarray/Solarray.sol";

contract VertexPolicyTest is VertexTestSetup {
  event RoleAssigned(address indexed user, uint8 indexed role, uint256 expiration, uint256 roleSupply);
  event RolePermissionAssigned(uint8 indexed role, bytes32 indexed permissionId, bool hasPermission);
  event RoleInitialized(uint8 indexed role, RoleDescription description);
  event Transfer(address indexed from, address indexed to, uint256 indexed id);

  uint8 constant ALL_HOLDERS_ROLE = 0;
  address arbitraryAddress = makeAddr("arbitraryAddress");
  address arbitraryUser = makeAddr("arbitraryUser");

  function getRoleDescription(string memory str) internal pure returns (RoleDescription) {
    return RoleDescription.wrap(bytes32(bytes(str)));
  }

  function setUp() public virtual override {
    VertexTestSetup.setUp();

    // The tests in this file have hardcoded timestamps for simplicity, so if this statement is ever
    // untrue we should update those hardcoded timestamps accordingly.
    require(block.timestamp < 100, "The tests in this file have hardcoded timestamps");
  }
}

// ================================
// ======== Modifier Tests ========
// ================================

contract MockPolicy is VertexPolicy {
  function exposed_onlyVertex() public onlyVertex {}
  function exposed_nonTransferableToken() public nonTransferableToken {}
}

contract OnlyVertex is VertexPolicyTest {
  function test_RevertIf_CallerIsNotVertex() public {
    MockPolicy mockPolicy = new MockPolicy();
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);
    mockPolicy.exposed_onlyVertex();
  }
}

contract NonTransferableToken is VertexPolicyTest {
  function test_RevertIf_CallerIsNotVertex() public {
    MockPolicy mockPolicy = new MockPolicy();
    vm.expectRevert(VertexPolicy.NonTransferableToken.selector);
    mockPolicy.exposed_nonTransferableToken();
  }
}

contract Initialize is VertexPolicyTest {
  uint8 constant TEST_ROLE = 1;

  function test_RevertIf_NoRolesAssignedAtInitialization() public {
    VertexPolicy localPolicy = VertexPolicy(Clones.clone(address(mpPolicy)));
    localPolicy.setVertex(address(this));
    vm.expectRevert(VertexPolicy.InvalidInput.selector);
    localPolicy.initialize(
      "Test Policy", new RoleDescription[](0), new RoleHolderData[](0), new RolePermissionData[](0)
    );
  }

  function test_SetsNameAndSymbol() public {
    assertEq(mpPolicy.name(), "Mock Protocol Vertex");
    assertEq(mpPolicy.symbol(), "V_Moc");
  }

  function testFuzz_SetsNumRolesToNumberOfRoleDescriptionsGiven(uint256 numRoles) public {
    numRoles = bound(numRoles, 1, 255); // Reverts if zero roles are given.

    RoleDescription[] memory roleDescriptions = new RoleDescription[](numRoles);
    for (uint8 i = 0; i < numRoles; i++) {
      roleDescriptions[i] = RoleDescription.wrap(bytes32(bytes(string.concat("Role ", vm.toString(i)))));
    }

    VertexPolicy localPolicy = VertexPolicy(Clones.clone(address(mpPolicy)));
    localPolicy.setVertex(address(this));
    localPolicy.initialize(
      "Test Policy", roleDescriptions, defaultActionCreatorRoleHolder(actionCreatorAaron), new RolePermissionData[](0)
    );
    assertEq(localPolicy.numRoles(), numRoles);
  }

  function test_RevertsIf_InitializeIsCalledTwice() public {
    vm.expectRevert("Initializable: contract is already initialized");
    mpPolicy.initialize("Test", new RoleDescription[](0), new RoleHolderData[](0), new RolePermissionData[](0));
  }

  function test_SetsRoleDescriptions() public {
    VertexPolicy localPolicy = VertexPolicy(Clones.clone(address(mpPolicy)));
    localPolicy.setVertex(address(this));
    RoleDescription[] memory roleDescriptions = new RoleDescription[](1);
    roleDescriptions[0] = RoleDescription.wrap("Test Policy");
    RoleHolderData[] memory roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(TEST_ROLE, address(this), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    RolePermissionData[] memory rolePermissions = new RolePermissionData[](1);
    rolePermissions[0] = RolePermissionData(TEST_ROLE, pausePermissionId, true);

    vm.expectEmit();
    emit RoleInitialized(1, RoleDescription.wrap("Test Policy"));

    localPolicy.initialize("local policy", roleDescriptions, roleHolders, rolePermissions);
  }

  function test_SetsRoleHolders() public {
    VertexPolicy localPolicy = VertexPolicy(Clones.clone(address(mpPolicy)));
    localPolicy.setVertex(address(this));
    RoleDescription[] memory roleDescriptions = new RoleDescription[](1);
    roleDescriptions[0] = RoleDescription.wrap("Test Role 1");
    RoleHolderData[] memory roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(TEST_ROLE, address(this), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    RolePermissionData[] memory rolePermissions = new RolePermissionData[](1);
    rolePermissions[0] = RolePermissionData(TEST_ROLE, pausePermissionId, true);

    uint256 prevSupply = localPolicy.getSupply(TEST_ROLE);

    vm.expectEmit();
    emit RoleAssigned(address(this), TEST_ROLE, DEFAULT_ROLE_EXPIRATION, DEFAULT_ROLE_QTY);

    localPolicy.initialize("Test Policy", roleDescriptions, roleHolders, rolePermissions);

    assertEq(localPolicy.getSupply(TEST_ROLE), prevSupply + DEFAULT_ROLE_QTY);
    assertEq(localPolicy.numRoles(), 1);
  }

  function test_SetsRolePermissions() public {
    VertexPolicy localPolicy = VertexPolicy(Clones.clone(address(mpPolicy)));
    assertFalse(localPolicy.canCreateAction(TEST_ROLE, pausePermissionId));
    localPolicy.setVertex(makeAddr("the factory"));

    RoleDescription[] memory roleDescriptions = new RoleDescription[](1);
    roleDescriptions[0] = RoleDescription.wrap("Test Role 1");
    RoleHolderData[] memory roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(TEST_ROLE, address(this), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    RolePermissionData[] memory rolePermissions = new RolePermissionData[](1);
    rolePermissions[0] = RolePermissionData(TEST_ROLE, pausePermissionId, true);

    localPolicy.initialize("Test Policy", roleDescriptions, roleHolders, rolePermissions);
    assertTrue(localPolicy.canCreateAction(TEST_ROLE, pausePermissionId));
  }
}

contract SetVertex is VertexPolicyTest {
  function test_SetsVertexAddress() public {
    // This test is a no-op because this functionality is already tested in
    // `test_SetsVertexCoreAddressOnThePolicy`, which also is a stronger test since it tests that
    // method in the context it is used, instead of as a pure unit test.
  }

  function test_RevertIf_VertexAddressIsSet() public {
    vm.expectRevert(VertexPolicy.AlreadyInitialized.selector);
    mpPolicy.setVertex(arbitraryAddress);
  }
}

// =======================================
// ======== Permission Management ========
// =======================================

contract InitializeRole is VertexPolicyTest {
  uint8 constant NUM_INIT_ROLES = 7; // VertexTestSetup initializes 7 roles.

  function test_IncrementsNumRoles() public {
    assertEq(mpPolicy.numRoles(), NUM_INIT_ROLES);
    vm.startPrank(address(mpCore));

    mpPolicy.initializeRole(RoleDescription.wrap("TestRole1"));
    assertEq(mpPolicy.numRoles(), NUM_INIT_ROLES + 1);

    mpPolicy.initializeRole(RoleDescription.wrap("TestRole2"));
    assertEq(mpPolicy.numRoles(), NUM_INIT_ROLES + 2);
  }

  function test_RevertIf_OverflowOccurs() public {
    vm.startPrank(address(mpCore));
    while (mpPolicy.numRoles() < type(uint8).max) mpPolicy.initializeRole(getRoleDescription("TestRole"));

    // Now the `numRoles` is at the max value, so the next call should revert.
    vm.expectRevert(stdError.arithmeticError);
    mpPolicy.initializeRole(getRoleDescription("TestRole"));
  }

  function test_EmitsRoleInitializedEvent() public {
    vm.expectEmit();
    emit RoleInitialized(NUM_INIT_ROLES + 1, getRoleDescription("TestRole"));
    vm.prank(address(mpCore));
    mpPolicy.initializeRole(getRoleDescription("TestRole"));
  }

  function test_DoesNotGuardAgainstSameDescriptionUsedForMultipleRoles() public {
    vm.startPrank(address(mpCore));
    mpPolicy.initializeRole(getRoleDescription("TestRole"));
    mpPolicy.initializeRole(getRoleDescription("TestRole"));
    mpPolicy.initializeRole(getRoleDescription("TestRole"));
  }
}

contract SetRoleHolder is VertexPolicyTest {
  function test_RevertIf_CalledByNonVertex() public {
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function test_RevertIf_NonExistantRole(uint8 role) public {
    vm.assume(role > mpPolicy.numRoles());
    vm.startPrank(address(mpCore));
    vm.expectRevert(abi.encodeWithSelector(VertexPolicy.RoleNotInitialized.selector, role));
    mpPolicy.setRoleHolder(role, arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function test_RevertIf_InvalidExpiration(uint64 expiration, uint256 timestamp) public {
    vm.assume(expiration < timestamp);
    vm.warp(timestamp);
    vm.expectRevert(VertexPolicy.InvalidInput.selector);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, DEFAULT_ROLE_QTY, expiration);
  }

  function test_RevertIf_InvalidQuantity() public {
    vm.expectRevert(VertexPolicy.InvalidInput.selector);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, 0, 1);

    vm.expectRevert(VertexPolicy.InvalidInput.selector);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, DEFAULT_ROLE_QTY, 0);
  }

  function test_SetsRoleHolder(address user) public {
    vm.assume(user != address(0));
    vm.expectEmit();
    emit RoleAssigned(user, uint8(Roles.TestRole1), DEFAULT_ROLE_EXPIRATION, DEFAULT_ROLE_QTY);

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), user, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasRole(user, uint8(Roles.TestRole1)), true);
  }
}

contract SetRolePermission is VertexPolicyTest {
  function test_SetsRolePermission(bytes32 permissionId, bool hasPermission) public {
    vm.expectEmit();
    emit RolePermissionAssigned(uint8(Roles.TestRole1), permissionId, hasPermission);
    vm.prank(address(mpCore));
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), permissionId, hasPermission);

    assertEq(mpPolicy.canCreateAction(uint8(Roles.TestRole1), permissionId), hasPermission);
  }

  function test_RevertIf_CalledByNonVertex() public {
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), pausePermissionId, true);
  }
}

contract RevokeExpiredRole is VertexPolicyTest {
  function test_RevokesExpiredRole(address user, uint64 expiration) public {
    vm.assume(user != address(0));
    vm.assume(expiration > block.timestamp);

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), user, DEFAULT_ROLE_QTY, expiration);

    vm.warp(expiration);

    vm.expectEmit();
    emit RoleAssigned(user, uint8(Roles.TestRole1), 0, 0);

    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), user);

    assertEq(mpPolicy.hasRole(user, uint8(Roles.TestRole1)), false);
  }

  function test_RevertIf_NotExpiredYet(address user, uint64 expiration) public {
    vm.assume(user != address(0));
    vm.assume(expiration > block.timestamp);

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), user, DEFAULT_ROLE_QTY, expiration);

    vm.expectRevert(VertexPolicy.InvalidInput.selector);
    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), user);
  }
}

contract RevokePolicy is VertexPolicyTest {
  function test_RevokesPolicy(address user) public {
    vm.assume(user != address(0));
    vm.assume(mpPolicy.balanceOf(user) == 0);

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), user, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.balanceOf(user), 1);

    vm.expectEmit();
    emit Transfer(user, address(0), uint256(uint160(user)));

    vm.prank(address(mpCore));
    mpPolicy.revokePolicy(user);

    assertEq(mpPolicy.balanceOf(user), 0);
  }

  function test_RevertsIf_PolicyDoesNotExist(address user) public {
    vm.assume(user != address(0));
    vm.assume(mpPolicy.balanceOf(user) == 0);
    vm.expectRevert(VertexPolicy.InvalidInput.selector);
    vm.prank(address(mpCore));
    mpPolicy.revokePolicy(user);
  }
}

contract RevokePolicyRolesOverload is VertexPolicyTest {
  function test_Revokes255RolesWithEnumeration() public {
    for (uint8 i = 7; i < 255; i++) {
      vm.prank(address(mpCore));
      mpPolicy.initializeRole(RoleDescription.wrap(bytes32(uint256(i))));
      vm.prank(address(mpCore));
      mpPolicy.setRoleHolder(i, arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    }

    vm.prank(address(mpCore));
    mpPolicy.revokePolicy(arbitraryAddress);
  }

  function test_Revokes255RolesWithoutEnumeration() public {
    for (uint8 i = 7; i < 255; i++) {
      vm.prank(address(mpCore));
      mpPolicy.initializeRole(RoleDescription.wrap(bytes32(uint256(i))));
      vm.prank(address(mpCore));
      mpPolicy.setRoleHolder(i, arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    }

    uint8[] memory roles = new uint8[](255);
    for (uint8 i; i < 255; i++) {
      roles[i] = i;
    }

    vm.prank(address(mpCore));
    mpPolicy.revokePolicy(arbitraryAddress, roles);
  }
}

// =================================
// ======== ERC-721 Methods ========
// =================================

contract TransferFrom is VertexPolicyTest {
  function test_RevertIf_Called() public {
    uint256 tokenId = 0; // Token ID does not actually matter, since that input is never used.
    vm.expectRevert(VertexPolicy.NonTransferableToken.selector);
    mpPolicy.transferFrom(address(this), arbitraryAddress, tokenId);
  }
}

contract SafeTransferFrom is VertexPolicyTest {
  function test_RevertIf_Called() public {
    uint256 tokenId = 0; // Token ID does not actually matter, since that input is never used.
    vm.expectRevert(VertexPolicy.NonTransferableToken.selector);
    mpPolicy.safeTransferFrom(address(this), arbitraryAddress, tokenId);
  }
}

contract SafeTransferFromBytesOverload is VertexPolicyTest {
  function test_RevertIf_Called() public {
    uint256 tokenId = 0; // Token ID does not actually matter, since that input is never used.
    vm.expectRevert(VertexPolicy.NonTransferableToken.selector);
    mpPolicy.safeTransferFrom(address(this), arbitraryAddress, tokenId, "");
  }
}

contract Approve is VertexPolicyTest {
  function test_RevertIf_Called() public {
    uint256 tokenId = 0; // Token ID does not actually matter, since that input is never used.
    vm.expectRevert(VertexPolicy.NonTransferableToken.selector);
    mpPolicy.approve(arbitraryAddress, tokenId);
  }
}

contract SetApprovalForAll is VertexPolicyTest {
  function test_RevertIf_Called() public {
    vm.expectRevert(VertexPolicy.NonTransferableToken.selector);
    mpPolicy.setApprovalForAll(arbitraryAddress, true);
  }
}

// ====================================
// ======== Permission Getters ========
// ====================================
// The actual checkpointing logic is tested in `Checkpoints.t.sol`, so here we just test the logic
// that's added on top of that.

// TODO Once the `expiration` timestamp is hit, the role is expired. Confirm that this is the
// desired behavior, i.e. should roles become expired at `expiration` or at `expiration + 1`?
// Ensure this inclusive vs. exclusive behavior is consistent across all timestamp usage.

contract GetWeight is VertexPolicyTest {
  function test_ReturnsZeroIfUserDoesNotHoldRole() public {
    assertEq(mpPolicy.getWeight(arbitraryAddress, uint8(Roles.MadeUpRole)), 0);
  }

  function test_ReturnsOneIfRoleHasExpiredButWasNotRevoked() public {
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 100);

    vm.warp(100);
    assertEq(mpPolicy.getWeight(arbitraryUser, uint8(Roles.TestRole1)), 1);

    vm.warp(101);
    assertEq(mpPolicy.getWeight(arbitraryUser, uint8(Roles.TestRole1)), 1);
  }

  function test_ReturnsOneIfRoleHasNotExpired() public {
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 100);

    vm.warp(99);
    assertEq(mpPolicy.getWeight(arbitraryUser, uint8(Roles.TestRole1)), 1);
  }
}

contract GetPastWeight is VertexPolicyTest {
  function setUp() public override {
    VertexPolicyTest.setUp();
    vm.startPrank(address(mpCore));

    vm.warp(100);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 105);

    vm.warp(110);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 200);

    vm.warp(120);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, EMPTY_ROLE_QTY, 0);

    vm.warp(130);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 200);

    vm.warp(140);
    mpPolicy.revokePolicy(arbitraryUser, Solarray.uint8s(uint8(Roles.TestRole1)));

    vm.warp(150);
    vm.stopPrank();
  }

  function test_ReturnsZeroIfUserDidNotHaveRoleAndOneIfUserDidHaveRoleAtTimestamp() public {
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 99), 0, "99");
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 100), 1, "100"); // Role set.
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 101), 1, "101");

    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 104), 1, "104");
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 105), 1, "105"); // Role expires, but not
      // revoked.
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 106), 1, "106");

    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 109), 1, "109");
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 110), 1, "110"); // Role set.
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 111), 1, "111");

    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 119), 1, "119");
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 120), 0, "120"); // Role revoked.
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 121), 0, "121");

    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 129), 0, "129");
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 130), 1, "130"); // Role set.
    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 131), 1, "131"); // Role set.

    assertEq(mpPolicy.getPastWeight(arbitraryUser, uint8(Roles.TestRole1), 140), 0, "140"); // Role revoked
  }
}

contract GetSupply is VertexPolicyTest {
  function setUp() public override {
    VertexPolicyTest.setUp();
    vm.startPrank(address(mpCore));
  }

  function test_IncrementsWhenRolesAreAddedAndDecrementsWhenRolesAreRemoved() public {
    assertEq(mpPolicy.getSupply(uint8(Roles.TestRole1)), 0);
    uint256 initPolicySupply = mpPolicy.getSupply(ALL_HOLDERS_ROLE);

    // Assigning a role increases supply.
    vm.warp(100);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 150);
    assertEq(mpPolicy.getSupply(uint8(Roles.TestRole1)), 1);
    assertEq(mpPolicy.getSupply(ALL_HOLDERS_ROLE), initPolicySupply + 1);

    // Updating the role does not change supply.
    vm.warp(110);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 160);
    assertEq(mpPolicy.getSupply(uint8(Roles.TestRole1)), 1);
    assertEq(mpPolicy.getSupply(ALL_HOLDERS_ROLE), initPolicySupply + 1);

    // Assigning the role to a new person increases supply.
    vm.warp(120);
    address newRoleHolder = makeAddr("newRoleHolder");
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), newRoleHolder, DEFAULT_ROLE_QTY, 200);
    assertEq(mpPolicy.getSupply(uint8(Roles.TestRole1)), 2);
    assertEq(mpPolicy.getSupply(ALL_HOLDERS_ROLE), initPolicySupply + 2);

    // Assigning new role to the same person does not change supply.
    vm.warp(130);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), newRoleHolder, DEFAULT_ROLE_QTY, 300);
    assertEq(mpPolicy.getSupply(uint8(Roles.TestRole1)), 2);
    assertEq(mpPolicy.getSupply(ALL_HOLDERS_ROLE), initPolicySupply + 2);

    // Revoking all roles from the user should only decrease supply by 1.
    vm.warp(140);
    mpPolicy.revokePolicy(newRoleHolder, Solarray.uint8s(uint8(Roles.TestRole1), uint8(Roles.TestRole2)));
    assertEq(mpPolicy.getSupply(uint8(Roles.TestRole1)), 1);
    assertEq(mpPolicy.getSupply(ALL_HOLDERS_ROLE), initPolicySupply + 1);

    // Revoking expired roles changes supply of the revoked role, but they still hold a policy, so
    // it doesn't change the total supply.
    vm.warp(200);
    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), arbitraryUser);
    assertEq(mpPolicy.getSupply(uint8(Roles.TestRole1)), 0);
    assertEq(mpPolicy.getSupply(ALL_HOLDERS_ROLE), initPolicySupply + 1);
  }
}

contract GetPastSupply is VertexPolicyTest {
  function setUp() public override {
    VertexPolicyTest.setUp();
    vm.startPrank(address(mpCore));
  }

  function test_IncrementsWhenRolesAreAddedAndDecrementsWhenRolesAreRemoved() public {
    // This is similar to the `getSupply` test, but with all warps/role setting first, then
    // assertions after using `getPastSupply`
    assertEq(mpPolicy.getSupply(uint8(Roles.TestRole1)), 0);
    uint256 initPolicySupply = mpPolicy.getSupply(ALL_HOLDERS_ROLE);

    // Assigning a role increases supply.
    vm.warp(100);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 150);

    // Updating the role does not change supply.
    vm.warp(110);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 160);

    // Assigning the role to a new person increases supply.
    vm.warp(120);
    address newRoleHolder = makeAddr("newRoleHolder");
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), newRoleHolder, DEFAULT_ROLE_QTY, 200);

    // Assigning new role to the same person does not change supply.
    vm.warp(130);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), newRoleHolder, DEFAULT_ROLE_QTY, 300);

    // Revoking all roles from the user should only decrease supply by 1.
    vm.warp(140);
    mpPolicy.revokePolicy(newRoleHolder, Solarray.uint8s(uint8(Roles.TestRole1), uint8(Roles.TestRole2)));

    // Revoking expired roles changes supply of the revoked role, but they still hold a policy, so
    // it doesn't change the total supply.
    vm.warp(200);
    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), arbitraryUser);

    vm.warp(201);

    // Now we assert the past supply.
    assertEq(mpPolicy.getPastSupply(uint8(Roles.TestRole1), 100), 1);
    assertEq(mpPolicy.getPastSupply(ALL_HOLDERS_ROLE, 100), initPolicySupply + 1);

    assertEq(mpPolicy.getPastSupply(uint8(Roles.TestRole1), 110), 1);
    assertEq(mpPolicy.getPastSupply(ALL_HOLDERS_ROLE, 110), initPolicySupply + 1);

    assertEq(mpPolicy.getPastSupply(uint8(Roles.TestRole1), 120), 2);
    assertEq(mpPolicy.getPastSupply(ALL_HOLDERS_ROLE, 120), initPolicySupply + 2);

    assertEq(mpPolicy.getPastSupply(uint8(Roles.TestRole1), 130), 2);
    assertEq(mpPolicy.getPastSupply(ALL_HOLDERS_ROLE, 130), initPolicySupply + 2);

    assertEq(mpPolicy.getPastSupply(uint8(Roles.TestRole1), 140), 1);
    assertEq(mpPolicy.getPastSupply(ALL_HOLDERS_ROLE, 140), initPolicySupply + 1);

    assertEq(mpPolicy.getPastSupply(uint8(Roles.TestRole1), 200), 0);
    assertEq(mpPolicy.getPastSupply(ALL_HOLDERS_ROLE, 200), initPolicySupply + 1);
  }
}

contract RoleBalanceCheckpoints is VertexPolicyTest {
  function test_ReturnsBalanceCheckpoint() public {
    vm.warp(100);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 150);

    vm.warp(110);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 160);

    vm.warp(120);
    address newRoleHolder = makeAddr("newRoleHolder");
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), newRoleHolder, DEFAULT_ROLE_QTY, 200);

    vm.warp(130);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), newRoleHolder, DEFAULT_ROLE_QTY, 300);

    vm.warp(140);
    vm.prank(address(mpCore));
    mpPolicy.revokePolicy(newRoleHolder);

    vm.warp(160);
    vm.prank(address(mpCore));
    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), arbitraryUser);

    vm.warp(161);

    Checkpoints.History memory rbCheckpoint1 = mpPolicy.roleBalanceCheckpoints(arbitraryUser, uint8(Roles.TestRole1));
    Checkpoints.History memory rbCheckpoint2 = mpPolicy.roleBalanceCheckpoints(newRoleHolder, uint8(Roles.TestRole2));

    assertEq(rbCheckpoint1._checkpoints.length, 3);
    assertEq(rbCheckpoint1._checkpoints[0].timestamp, 100);
    assertEq(rbCheckpoint1._checkpoints[0].expiration, 150);
    assertEq(rbCheckpoint1._checkpoints[0].quantity, 1);
    assertEq(rbCheckpoint1._checkpoints[1].timestamp, 110);
    assertEq(rbCheckpoint1._checkpoints[1].expiration, 160);
    assertEq(rbCheckpoint1._checkpoints[1].quantity, 1);
    assertEq(rbCheckpoint1._checkpoints[2].timestamp, 160);
    assertEq(rbCheckpoint1._checkpoints[2].expiration, 0);
    assertEq(rbCheckpoint1._checkpoints[2].quantity, 0);

    assertEq(rbCheckpoint2._checkpoints.length, 3);
    assertEq(rbCheckpoint2._checkpoints[0].timestamp, 120);
    assertEq(rbCheckpoint2._checkpoints[0].expiration, 200);
    assertEq(rbCheckpoint2._checkpoints[0].quantity, 1);
    assertEq(rbCheckpoint2._checkpoints[1].timestamp, 130);
    assertEq(rbCheckpoint2._checkpoints[1].expiration, 300);
    assertEq(rbCheckpoint2._checkpoints[1].quantity, 1);
    assertEq(rbCheckpoint2._checkpoints[2].timestamp, 140);
    assertEq(rbCheckpoint2._checkpoints[2].expiration, 0);
    assertEq(rbCheckpoint2._checkpoints[2].quantity, 0);
  }
}

contract RoleSupplyCheckpoints is VertexPolicyTest {
  function test_ReturnsSupplyCheckpoint(uint8 supply, uint8 quantity) public {
    vm.assume(quantity > 0);
    vm.assume(supply < type(uint8).max - 100);

    uint256 initialTimestamp = block.timestamp;

    for (uint8 i = 100; i < supply + 100; i++) {
      vm.warp(block.timestamp + 1);
      vm.prank(address(mpCore));
      mpPolicy.setRoleHolder(uint8(Roles.TestRole1), address(uint160(i)), quantity, DEFAULT_ROLE_EXPIRATION);
    }

    vm.warp(block.timestamp + 1);

    uint256 roleSupply = mpPolicy.getSupply(uint8(Roles.TestRole1));
    assertEq(roleSupply, uint256(supply) * uint256(quantity));

    Checkpoints.History memory rsCheckpoint = mpPolicy.roleSupplyCheckpoints(uint8(Roles.TestRole1));
    assertEq(rsCheckpoint._checkpoints.length, supply);
    if (supply > 0) {
      assertEq(rsCheckpoint._checkpoints[0].timestamp, initialTimestamp + 1);
      assertEq(rsCheckpoint._checkpoints[0].quantity, quantity);
      assertEq(rsCheckpoint._checkpoints[rsCheckpoint._checkpoints.length - 1].timestamp, block.timestamp - 1);
      assertEq(
        rsCheckpoint._checkpoints[rsCheckpoint._checkpoints.length - 1].quantity, uint256(supply) * uint256(quantity)
      );
    }
  }
}

contract HasRole is VertexPolicyTest {
  function test_ReturnsTrueIfHolderHasRole() public {
    vm.warp(100);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole1)), true);
  }

  function test_ReturnsFalseIfHolderDoesNotHaveRole() public {
    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole1)), false);
  }

  function test_ReturnsFalseIfHolderHasExpiredRole() public {
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 100);

    vm.warp(101);

    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole1)), false);
  }
}

contract HasRoleUint256Overload is VertexPolicyTest {
  function test_ReturnsTrueIfHolderHasRole() public {
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.warp(100);

    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole1), block.timestamp - 1), true);
    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole1), 0), false);
  }

  function test_ReturnsFalseIfHolderDoesNotHaveRole() public {
    vm.warp(100);
    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole1), block.timestamp - 1), false);
  }

  function test_ReturnsFalseIfHolderHasExpiredRole() public {
    vm.warp(100);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.warp(101);

    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole1), 99), false);
    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole1), 100), true);
  }
}

contract HasPermissionId is VertexPolicyTest {
  function test_ReturnsTrueIfHolderHasPermission(bytes32 permisisonId) public {
    vm.warp(100);
    vm.prank(address(mpCore));
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), permisisonId, true);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasPermissionId(arbitraryUser, uint8(Roles.TestRole1), permisisonId), true);
  }

  function test_ReturnsFalseIfHolderDoesNotHavePermission(bytes32 permissionId) public {
    assertEq(mpPolicy.hasPermissionId(arbitraryUser, uint8(Roles.TestRole1), permissionId), false);
  }
}

contract TotalSupply is VertexPolicyTest {
  function test_getsTotalSupply(uint256 numberOfPolicies) public {
    uint256 initPolicySupply = mpPolicy.getSupply(ALL_HOLDERS_ROLE);
    vm.assume(numberOfPolicies < 10_000);
    for (uint256 i = 0; i < numberOfPolicies; i++) {
      vm.prank(address(mpCore));
      mpPolicy.setRoleHolder(
        uint8(Roles.TestRole1), address(uint160(i + 100)), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION
      );
    }

    // vm.warp(block.timestamp + 1);

    assertEq(mpPolicy.totalSupply(), initPolicySupply + numberOfPolicies);
  }
}

contract Aggregate is VertexPolicyTest {
  function test_AggregatesSetRoleHolderCalls() public {
    address newRoleHolder = makeAddr("newRoleHolder");

    bytes memory call1 = abi.encodeCall(
      VertexPolicy.setRoleHolder, (uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION)
    );
    bytes memory call2 = abi.encodeCall(
      VertexPolicy.setRoleHolder, (uint8(Roles.TestRole2), arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION)
    );
    bytes memory call3 = abi.encodeCall(
      VertexPolicy.setRoleHolder, (uint8(Roles.TestRole1), newRoleHolder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION)
    );

    bytes[] memory calls = new bytes[](3);
    calls[0] = call1;
    calls[1] = call2;
    calls[2] = call3;

    vm.prank(address(mpCore));
    mpPolicy.aggregate(calls);

    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole1)), true);
    assertEq(mpPolicy.hasRole(arbitraryUser, uint8(Roles.TestRole2)), true);
    assertEq(mpPolicy.hasRole(newRoleHolder, uint8(Roles.TestRole1)), true);
  }

  function test_RevertsIf_CalldataIsIncorrect() public {
    bytes memory call1 = abi.encodeCall(
      VertexPolicy.setRoleHolder,
      ( /* uninitialized role */ 8, arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION)
    );
    bytes[] memory calls = new bytes[](1);
    calls[0] = call1;

    bytes memory failedResponse = hex"e5b1d7a00000000000000000000000000000000000000000000000000000000000000008";

    vm.expectRevert(abi.encodeWithSelector(VertexPolicy.CallReverted.selector, 0, failedResponse));
    vm.prank(address(mpCore));
    mpPolicy.aggregate(calls);
  }
}

// =================================
// ======== ERC-721 Getters ========
// =================================

contract TokenURI is VertexPolicyTest {
  // The token's JSON metadata.
  // The `image` field is the *decoded* SVG image, but in the contract it's base64-encoded.
  struct Metadata {
    string name;
    string description;
    string image; // Decoded SVG.
  }

  function parseMetadata(string memory uri) internal returns (Metadata memory) {
    string[] memory inputs = new string[](3);
    inputs[0] = "node";
    inputs[1] = "test/lib/metadata.js";
    inputs[2] = uri;
    return abi.decode(vm.ffi(inputs), (Metadata));
  }

  function test_ReturnsCorrectTokenURI() public {
    string memory uri = mpPolicy.tokenURI(uint256(uint160(address(this))));
    Metadata memory metadata = parseMetadata(uri);
    assertEq(metadata.name, LibString.concat("Vertex Policy ID: ", LibString.toString(uint256(uint160(address(this))))));
    assertEq(metadata.description, "Vertex is a identity access system for privledged smart contract functions");

    string[9] memory parts;
    parts[0] =
      '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" />';
    parts[1] =
      '<path transform="translate(10,10)" d="M3.0543 18.4836C3.05685 18.2679 3.14276 18.0616 3.29402 17.908C3.44526 17.7544 3.65009 17.6653 3.86553 17.6596H14.6671C15.177 17.6606 15.682 17.5611 16.1534 17.3667C16.6248 17.1724 17.0533 16.8869 17.4143 16.5267C17.7754 16.1665 18.062 15.7386 18.2577 15.2674C18.4534 14.7963 18.5545 14.2912 18.555 13.781V0H15.4987V13.781C15.4961 13.9967 15.4102 14.2029 15.2589 14.3566C15.1077 14.5102 14.9029 14.5993 14.6874 14.605H3.87567C2.84811 14.6061 1.86294 15.0151 1.13634 15.7422C0.409745 16.4694 0.00107373 17.4553 0 18.4836V27.9963H3.0543V18.4836Z" fill="url(#paint0_linear_2141_86430)"/><path transform="translate(10,10)" d="M19.9061 2.62599H19.7701L19.8999 2.7559V5.59734H22.7109L24.0292 6.92876C23.1533 7.10776 22.3661 7.58374 21.8004 8.27633C21.2346 8.96892 20.9252 9.83566 20.924 10.7302V28H23.9662V10.7261C23.9694 10.5086 24.0571 10.3008 24.2108 10.1469C24.3646 9.99309 24.5723 9.90526 24.7896 9.90211H25.2581C27.0529 9.90211 27.6615 8.90152 27.8419 8.4814C28.0224 8.06126 28.3003 6.91455 27.0308 5.63994L24.0534 2.63615H23.1265" fill="url(#paint1_linear_2141_86430)"/><path transform="translate(10,10)" d="M11.828 26.4971C12.4952 26.4965 13.1559 26.6289 13.7715 26.8864C14.3871 27.1439 14.9453 27.5214 15.4137 27.9969H19.1109C18.4455 26.6309 17.4099 25.4796 16.1222 24.6742C14.8345 23.8688 13.3465 23.4418 11.828 23.4418C10.3095 23.4418 8.82159 23.8688 7.53388 24.6742C6.2462 25.4796 5.21058 26.6309 4.54515 27.9969H8.24237C8.71076 27.5214 9.269 27.1439 9.88461 26.8864C10.5002 26.6289 11.1608 26.4965 11.828 26.4971Z" fill="url(#paint2_linear_2141_86430)"/><path transform="translate(10,10)" d="M36.616 11.494V11.824L41.17 23H44.756L49.288 11.824V11.494H45.878L43.062 19.678H42.842L40.026 11.494H36.616ZM49.53 17.236C49.53 21.152 52.214 23.264 55.712 23.264C59.166 23.264 60.816 21.196 61.3 19.59V19.26H58.286C58.066 19.986 57.428 21.02 55.712 21.02C53.908 21.02 52.874 19.656 52.83 18.006H61.498V17.06C61.498 13.32 59.078 11.23 55.624 11.23C52.214 11.23 49.53 13.32 49.53 17.236ZM52.852 16.048C52.962 14.618 53.908 13.474 55.668 13.474C57.406 13.474 58.33 14.618 58.396 16.048H52.852ZM63.6437 11.494V23H66.8777V17.324C66.8777 14.97 67.9337 13.914 70.0237 13.914H72.1357V11.45H70.1117C68.3077 11.45 67.4057 12.22 66.9657 13.254H66.7457V11.494H63.6437ZM73.3455 11.494V13.65H76.7115V19.854C76.7115 21.9 77.9875 23 80.0775 23H83.9055V20.734H80.1215L79.9455 20.558V13.65H83.6855V11.494H79.9455V7.6H79.6155L76.7115 8.964V11.494H73.3455ZM85.2181 17.236C85.2181 21.152 87.9021 23.264 91.4001 23.264C94.8541 23.264 96.5041 21.196 96.9881 19.59V19.26H93.9741C93.7541 19.986 93.1161 21.02 91.4001 21.02C89.5961 21.02 88.5621 19.656 88.5181 18.006H97.1861V17.06C97.1861 13.32 94.7661 11.23 91.3121 11.23C87.9021 11.23 85.2181 13.32 85.2181 17.236ZM88.5401 16.048C88.6501 14.618 89.5961 13.474 91.3561 13.474C93.0941 13.474 94.0181 14.618 94.0841 16.048H88.5401ZM98.0558 11.494V11.824L101.994 17.082L97.5498 22.67V23H101.048L103.952 19.172H104.172L106.944 23H110.354V22.67L106.306 17.302L110.64 11.824V11.494H107.186L104.348 15.212H104.128L101.466 11.494H98.0558Z" fill="white"/><defs><linearGradient id="paint0_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient><linearGradient id="paint1_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient><linearGradient id="paint2_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient></defs>';
    parts[2] = '<text x="10" y="60" class="base">';
    parts[3] = string.concat("Policy Id: ", LibString.toString(uint256(uint160(address(this)))));
    parts[4] = '</text><text x="10" y="80" class="base">';
    parts[5] = mpPolicy.name();
    parts[6] = '</text><text x="10" y="100" class="base">';
    parts[7] = mpPolicy.symbol();
    parts[8] = "</text></svg>";

    string memory svg =
      string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));

    assertEq(metadata.image, svg);
  }
}
