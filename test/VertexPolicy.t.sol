// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/forge-std/src/console.sol";
import {Test, stdError, console2} from "lib/forge-std/src/Test.sol";
import {DefaultStrategy} from "src/strategies/DefaultStrategy.sol";
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
  uint8 constant INIT_TEST_ROLE = 1;

  function test_RevertIf_NoRolesAssignedAtInitialization() public {
    VertexPolicy localPolicy = VertexPolicy(Clones.clone(address(mpPolicy)));
    localPolicy.setVertex(address(this));
    vm.expectRevert(VertexPolicy.InvalidRoleHolderInput.selector);
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

  function test_RevertIf_InitializeIsCalledTwice() public {
    vm.expectRevert("Initializable: contract is already initialized");
    mpPolicy.initialize("Test", new RoleDescription[](0), new RoleHolderData[](0), new RolePermissionData[](0));
  }

  function test_SetsRoleDescriptions() public {
    VertexPolicy localPolicy = VertexPolicy(Clones.clone(address(mpPolicy)));
    localPolicy.setVertex(address(this));
    RoleDescription[] memory roleDescriptions = new RoleDescription[](1);
    roleDescriptions[0] = RoleDescription.wrap("Test Policy");
    RoleHolderData[] memory roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(INIT_TEST_ROLE, address(this), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    RolePermissionData[] memory rolePermissions = new RolePermissionData[](1);
    rolePermissions[0] = RolePermissionData(INIT_TEST_ROLE, pausePermissionId, true);

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
    roleHolders[0] = RoleHolderData(INIT_TEST_ROLE, address(this), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    RolePermissionData[] memory rolePermissions = new RolePermissionData[](1);
    rolePermissions[0] = RolePermissionData(INIT_TEST_ROLE, pausePermissionId, true);

    uint256 prevSupply = localPolicy.getSupply(INIT_TEST_ROLE);

    vm.expectEmit();
    emit RoleAssigned(address(this), INIT_TEST_ROLE, DEFAULT_ROLE_EXPIRATION, DEFAULT_ROLE_QTY);

    localPolicy.initialize("Test Policy", roleDescriptions, roleHolders, rolePermissions);

    assertEq(localPolicy.getSupply(INIT_TEST_ROLE), prevSupply + DEFAULT_ROLE_QTY);
    assertEq(localPolicy.numRoles(), 1);
  }

  function test_SetsRolePermissions() public {
    VertexPolicy localPolicy = VertexPolicy(Clones.clone(address(mpPolicy)));
    assertFalse(localPolicy.canCreateAction(INIT_TEST_ROLE, pausePermissionId));
    localPolicy.setVertex(makeAddr("the factory"));

    RoleDescription[] memory roleDescriptions = new RoleDescription[](1);
    roleDescriptions[0] = RoleDescription.wrap("Test Role 1");
    RoleHolderData[] memory roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(INIT_TEST_ROLE, address(this), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    RolePermissionData[] memory rolePermissions = new RolePermissionData[](1);
    rolePermissions[0] = RolePermissionData(INIT_TEST_ROLE, pausePermissionId, true);

    vm.expectEmit();
    emit RolePermissionAssigned(INIT_TEST_ROLE, pausePermissionId, true);

    localPolicy.initialize("Test Policy", roleDescriptions, roleHolders, rolePermissions);
    assertTrue(localPolicy.canCreateAction(INIT_TEST_ROLE, pausePermissionId));
  }
}

contract SetVertex is VertexPolicyTest {
  function test_SetsVertexAddress() public {
    // This test is a no-op because this functionality is already tested in
    // `test_SetsVertexCoreOnThePolicy`, which also is a stronger test since it tests that
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
  function testFuzz_RevertIf_CallerIsNotVertex(address caller) public {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);

    vm.prank(caller);
    mpPolicy.initializeRole(RoleDescription.wrap("TestRole1"));
  }

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
  function testFuzz_RevertIf_CallerIsNotVertex(address caller) public {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);

    vm.prank(caller);
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function test_RevertIf_NonExistentRole(uint8 role) public {
    role = uint8(bound(role, mpPolicy.numRoles() + 1, type(uint8).max));
    vm.startPrank(address(mpCore));
    vm.expectRevert(abi.encodeWithSelector(VertexPolicy.RoleNotInitialized.selector, role));
    mpPolicy.setRoleHolder(role, arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function test_RevertIf_InvalidExpiration(uint64 expiration, uint256 timestamp) public {
    timestamp = bound(timestamp, block.timestamp, type(uint64).max);
    expiration = uint64(bound(expiration, 0, timestamp - 1));
    vm.warp(timestamp);
    vm.expectRevert(VertexPolicy.AllHoldersRole.selector);
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, DEFAULT_ROLE_QTY, expiration);
  }

  function test_RevertIf_InvalidQuantity() public {
    vm.startPrank(address(mpCore));

    vm.expectRevert(VertexPolicy.InvalidRoleHolderInput.selector);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryAddress, 0, DEFAULT_ROLE_EXPIRATION);
  }

  function test_RevertIf_AllHoldersRole() public {
    vm.startPrank(address(mpCore));

    vm.expectRevert(VertexPolicy.AllHoldersRole.selector);
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
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
  function testFuzz_RevertIf_CallerIsNotVertex(address caller) public {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);

    vm.prank(caller);
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), pausePermissionId, true);
  }

  function test_SetsRolePermission(bytes32 permissionId, bool hasPermission) public {
    vm.expectEmit();
    emit RolePermissionAssigned(uint8(Roles.TestRole1), permissionId, hasPermission);
    vm.prank(address(mpCore));
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), permissionId, hasPermission);

    assertEq(mpPolicy.canCreateAction(uint8(Roles.TestRole1), permissionId), hasPermission);
  }
}

contract RevokeExpiredRole is VertexPolicyTest {
  function test_RevokesExpiredRole(address user, uint64 expiration) public {
    vm.assume(user != address(0));
    expiration = uint64(bound(expiration, block.timestamp + 1, type(uint64).max));

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), user, DEFAULT_ROLE_QTY, expiration);

    vm.warp(expiration);

    vm.expectEmit();
    emit RoleAssigned(user, uint8(Roles.TestRole1), 0, 0);

    assertEq(mpPolicy.hasRole(user, uint8(Roles.TestRole1)), true);

    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), user);

    assertEq(mpPolicy.hasRole(user, uint8(Roles.TestRole1)), false);
  }

  function test_RevertIf_NotExpiredYet(address user, uint64 expiration) public {
    vm.assume(user != address(0));
    expiration = uint64(bound(expiration, block.timestamp + 1, type(uint64).max));

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), user, DEFAULT_ROLE_QTY, expiration);

    vm.expectRevert(VertexPolicy.InvalidRoleHolderInput.selector);
    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), user);
  }
}

contract RevokePolicy is VertexPolicyTest {
  function testFuzz_RevertIf_CallerIsNotVertex(address caller) public {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);

    vm.prank(caller);
    mpPolicy.revokePolicy(makeAddr("user"));
  }

  function test_RevokesPolicy(address user) public {
    vm.assume(user != address(0));
    vm.assume(mpPolicy.balanceOf(user) == 0);

    vm.startPrank(address(mpCore));

    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), user, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.balanceOf(user), 1);

    vm.expectEmit();
    emit Transfer(user, address(0), uint256(uint160(user)));

    mpPolicy.revokePolicy(user);

    assertEq(mpPolicy.balanceOf(user), 0);
  }

  function test_RevertIf_PolicyDoesNotExist(address user) public {
    vm.assume(user != address(0));
    vm.assume(mpPolicy.balanceOf(user) == 0);
    vm.expectRevert(abi.encodeWithSelector(VertexPolicy.UserDoesNotHoldPolicy.selector, user));
    vm.prank(address(mpCore));
    mpPolicy.revokePolicy(user);
  }
}

contract RevokePolicyRolesOverload is VertexPolicyTest {
  function setUpLocalPolicy() internal returns (VertexPolicy localPolicy) {
    localPolicy = VertexPolicy(Clones.clone(address(mpPolicy)));
    RoleDescription[] memory roleDescriptions = new RoleDescription[](1);
    roleDescriptions[0] = RoleDescription.wrap(bytes32(bytes(string.concat("Role ", vm.toString(uint256(1))))));
    RoleHolderData[] memory roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(uint8(1), arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    localPolicy.setVertex(address(this));
    localPolicy.initialize("Test Policy", roleDescriptions, roleHolders, new RolePermissionData[](0));

    vm.startPrank(address(this));
  }

  function testFuzz_RevertIf_CallerIsNotVertex(address caller) public {
    vm.assume(caller != address(mpCore) && caller != address(this));
    VertexPolicy localPolicy = setUpLocalPolicy();
    uint8[] memory roles = new uint8[](254);
    vm.stopPrank();

    vm.expectRevert(VertexPolicy.OnlyVertex.selector);
    vm.prank(caller);
    localPolicy.revokePolicy(arbitraryAddress, roles);
  }

  function test_Revokes255RolesWithEnumeration() public {
    VertexPolicy localPolicy = setUpLocalPolicy();

    for (uint8 i = 2; i < 255; i++) {
      localPolicy.initializeRole(RoleDescription.wrap(bytes32(uint256(i))));
      vm.expectEmit();
      emit RoleAssigned(arbitraryAddress, i, DEFAULT_ROLE_EXPIRATION, DEFAULT_ROLE_QTY);
      localPolicy.setRoleHolder(i, arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    }

    for (uint8 i; i < 254; i++) {
      uint256 roleSupply = localPolicy.getSupply(i + 1);
      vm.expectEmit();
      emit RoleAssigned(arbitraryAddress, i + 1, 0, roleSupply - 1);
    }

    localPolicy.revokePolicy(arbitraryAddress);

    assertEq(localPolicy.balanceOf(arbitraryAddress), 0);
    assertEq(localPolicy.hasRole(arbitraryAddress, uint8(type(Roles).max) + 1), false);
  }

  function test_Revokes255RolesWithoutEnumeration() public {
    VertexPolicy localPolicy = setUpLocalPolicy();
    for (uint8 i = 2; i < 255; i++) {
      localPolicy.initializeRole(RoleDescription.wrap(bytes32(uint256(i))));
      vm.expectEmit();
      emit RoleAssigned(arbitraryAddress, i, DEFAULT_ROLE_EXPIRATION, DEFAULT_ROLE_QTY);
      localPolicy.setRoleHolder(i, arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    }

    uint8[] memory roles = new uint8[](254); // 254 instead of 255 since we don't want to include the all holders role
    for (uint8 i; i < 254; i++) {
      roles[i] = i + 1; // setting i to i + 1 so it doesn't try to remove the all holders role
      uint256 roleSupply = localPolicy.getSupply(i + 1);
      vm.expectEmit();
      emit RoleAssigned(arbitraryAddress, i + 1, 0, roleSupply - 1);
    }

    vm.expectEmit();
    emit Transfer(arbitraryAddress, address(0), uint256(uint160(arbitraryAddress)));

    localPolicy.revokePolicy(arbitraryAddress, roles);

    assertEq(localPolicy.balanceOf(arbitraryAddress), 0);
    assertEq(localPolicy.hasRole(arbitraryAddress, uint8(0)), false);
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

contract GetQuantity is VertexPolicyTest {
  function test_ReturnsZeroIfUserDoesNotHoldRole() public {
    assertEq(mpPolicy.getQuantity(arbitraryAddress, uint8(Roles.MadeUpRole)), 0);
  }

  function test_ReturnsOneIfRoleHasExpiredButWasNotRevoked() public {
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 100);

    vm.warp(100);
    assertEq(mpPolicy.getQuantity(arbitraryUser, uint8(Roles.TestRole1)), 1);

    vm.warp(101);
    assertEq(mpPolicy.getQuantity(arbitraryUser, uint8(Roles.TestRole1)), 1);
  }

  function test_ReturnsOneIfRoleHasNotExpired() public {
    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 100);

    vm.warp(99);
    assertEq(mpPolicy.getQuantity(arbitraryUser, uint8(Roles.TestRole1)), 1);
  }
}

contract GetPastQuantity is VertexPolicyTest {
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
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 99), 0, "99");
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 100), 1, "100"); // Role set.
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 101), 1, "101");

    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 104), 1, "104");
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 105), 1, "105"); // Role expires, but not
      // revoked.
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 106), 1, "106");

    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 109), 1, "109");
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 110), 1, "110"); // Role set.
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 111), 1, "111");

    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 119), 1, "119");
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 120), 0, "120"); // Role revoked.
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 121), 0, "121");

    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 129), 0, "129");
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 130), 1, "130"); // Role set.
    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 131), 1, "131"); // Role set.

    assertEq(mpPolicy.getPastQuantity(arbitraryUser, uint8(Roles.TestRole1), 140), 0, "140"); // Role revoked
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
    vm.startPrank(address(mpCore));

    vm.warp(100);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 150);

    vm.warp(110);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, 160);

    vm.warp(120);
    address newRoleHolder = makeAddr("newRoleHolder");
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), newRoleHolder, DEFAULT_ROLE_QTY, 200);

    vm.warp(130);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), newRoleHolder, DEFAULT_ROLE_QTY, 300);

    vm.warp(140);
    mpPolicy.revokePolicy(newRoleHolder);

    vm.warp(160);
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
    supply = uint8(bound(supply, 0, type(uint8).max - 100));

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
}

contract HasPermissionId is VertexPolicyTest {
  function test_ReturnsTrueIfHolderHasPermission(bytes32 permissionId) public {
    vm.startPrank(address(mpCore));

    vm.warp(100);
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), permissionId, true);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasPermissionId(arbitraryUser, uint8(Roles.TestRole1), permissionId), true);
  }

  function test_ReturnsFalseIfHolderDoesNotHaveQuanitity() public {
    assertEq(mpPolicy.hasPermissionId(arbitraryUser, uint8(Roles.TestRole1), pausePermissionId), false);
  }

  function test_ReturnsFalseIfHolderDoesNotHavePermission(bytes32 permissionId) public {
    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    assertEq(mpPolicy.hasPermissionId(arbitraryUser, uint8(Roles.TestRole1), permissionId), false);
  }
}

contract TotalSupply is VertexPolicyTest {
  function test_getsTotalSupply(uint256 numberOfPolicies) public {
    uint256 initPolicySupply = mpPolicy.getSupply(ALL_HOLDERS_ROLE);
    numberOfPolicies = bound(numberOfPolicies, 1, 10_000);
    for (uint256 i = 0; i < numberOfPolicies; i++) {
      vm.prank(address(mpCore));
      mpPolicy.setRoleHolder(
        uint8(Roles.TestRole1), address(uint160(i + 100)), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION
      );
    }

    assertEq(mpPolicy.totalSupply(), initPolicySupply + numberOfPolicies);
  }
}

contract Aggregate is VertexPolicyTest {
  function testFuzz_RevertIf_CallerIsNotVertex(address caller) public {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);
    bytes[] memory calls = new bytes[](3);

    vm.prank(caller);
    mpPolicy.aggregate(calls);
  }

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

  function test_RevertIf_CalldataIsIncorrect() public {
    uint8 uninitializedRole = NUM_INIT_ROLES + 1;
    bytes memory call1 = abi.encodeCall(
      VertexPolicy.setRoleHolder, (uninitializedRole, arbitraryUser, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION)
    );
    bytes[] memory calls = new bytes[](1);
    calls[0] = call1;

    bytes memory failedResponse = abi.encodeWithSelector(VertexPolicy.RoleNotInitialized.selector, uninitializedRole);

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

  function setTokenURIMetadata() internal {
    string memory color = "#FF0000";
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.startPrank(address(rootCore));
    policyTokenURIParamRegistry.setColor(mpCore, color);
    policyTokenURIParamRegistry.setLogo(mpCore, logo);
    vm.stopPrank();
  }

  function parseMetadata(string memory uri) internal returns (Metadata memory) {
    string[] memory inputs = new string[](3);
    inputs[0] = "node";
    inputs[1] = "test/lib/metadata.js";
    inputs[2] = uri;
    return abi.decode(vm.ffi(inputs), (Metadata));
  }

  function test_ReturnsCorrectTokenURI() public {
    setTokenURIMetadata();

    string memory uri = mpPolicy.tokenURI(uint256(uint160(address(this))));
    Metadata memory metadata = parseMetadata(uri);
    string memory policyholder = LibString.toHexString(uint256(uint160(address(this))));
    string memory name1 = LibString.concat("Vertex Policy ID: ", LibString.toString(uint256(uint160(address(this)))));
    string memory name2 = LibString.concat(" - ", mpPolicy.symbol());
    string memory name = LibString.concat(name1, name2);
    assertEq(metadata.name, name);
    assertEq(metadata.description, "Vertex is a framework for onchain organizations.");
    (string memory color, string memory logo) = policyTokenURIParamRegistry.getMetadata(mpCore);
    string[17] memory parts;

    parts[0] =
      '<svg xmlns="http://www.w3.org/2000/svg" width="390" height="500" fill="none"><g clip-path="url(#a)"><rect width="390" height="500" fill="#0B101A" rx="13.393" /><mask id="b" width="364" height="305" x="4" y="30" maskUnits="userSpaceOnUse" style="mask-type:alpha"><ellipse cx="186.475" cy="182.744" fill="#8000FF" rx="196.994" ry="131.329" transform="rotate(-31.49 186.475 182.744)" /></mask><g mask="url(#b)"><g filter="url(#c)"><ellipse cx="237.625" cy="248.968" fill="#6A45EC" rx="140.048" ry="59.062" transform="rotate(-31.49 237.625 248.968)" /></g><g filter="url(#d)"><ellipse cx="286.654" cy="297.122" fill="';

    parts[1] = color;

    parts[2] =
      '" rx="140.048" ry="59.062" transform="rotate(-31.49 286.654 297.122)" /></g> </g> <g filter="url(#e)"> <ellipse cx="237.625" cy="248.968" fill="';

    parts[3] = color;

    parts[4] =
      '" rx="140.048" ry="59.062" transform="rotate(-31.49 237.625 248.968)" /></g><circle cx="109.839" cy="147.893" r="22" fill="url(#f)" /><path fill="#fff" d="M342.455 33.597a1.455 1.455 0 0 0-2.91 0v11.034l-7.802-7.802a1.454 1.454 0 1 0-2.057 2.057l7.802 7.802h-11.033a1.454 1.454 0 1 0 0 2.91h11.033l-7.802 7.802a1.455 1.455 0 0 0 2.057 2.057l7.802-7.803v11.034a1.455 1.455 0 0 0 2.91 0V51.654l7.802 7.803a1.455 1.455 0 0 0 2.057-2.057l-7.802-7.803h11.033a1.454 1.454 0 1 0 0-2.909h-11.033l7.802-7.802a1.455 1.455 0 0 0-2.057-2.057l-7.802 7.802V33.597Z"/><text fill="#fff" font-family="\'Courier New\', monospace" font-size="38"><tspan x="32" y="459.581">';

    parts[5] = mpPolicy.name();

    parts[6] = "</tspan></text>";

    parts[7] = logo;

    parts[8] = '<rect width="150" height="35.071" x="32" y="376.875" fill="';

    parts[9] = color;

    parts[10] =
      '" rx="17.536"/><text fill="#0B101A" font-family="\'Courier New\', monospace" font-size="16"><tspan x="45.393" y="399.851">';

    parts[11] =
      string(abi.encodePacked(LibString.slice(policyholder, 0, 6), "...", LibString.slice(policyholder, 38, 42)));

    parts[12] = '</tspan></text><path fill="';

    parts[13] = color;

    parts[14] =
      '" d="M36.08 53.84h1.696l3.52-10.88h-1.632l-2.704 9.087h-.064l-2.704-9.088H32.56l3.52 10.88Zm7.891 0h7.216v-1.36h-5.696v-3.505h4.96v-1.36h-4.96V44.32h5.696v-1.36h-7.216v10.88Zm13.609-4.593 2.544 4.592h1.744L59.18 49.2c.848-.096 1.392-.4 1.808-.816.56-.56.784-1.344.784-2.304 0-1.008-.24-1.808-.816-2.336-.576-.528-1.472-.784-2.592-.784h-4.096v10.88h1.52v-4.592h1.792Zm-1.792-1.296V44.32h3.136c.768 0 1.248.448 1.248 1.184v1.2c0 .672-.448 1.248-1.248 1.248h-3.136Zm7.78-3.632h3.249v9.52h1.52v-9.52h3.248v-1.36h-8.016v1.36Zm10.464 9.52h7.216v-1.36h-5.696v-3.504h4.96v-1.36h-4.96V44.32h5.696v-1.36h-7.216v10.88Zm9.192 0h1.68l2.592-4.256 2.56 4.256h1.696l-3.44-5.584 3.312-5.296H89.96l-2.464 4.016-2.416-4.016h-1.664l3.28 5.296-3.472 5.584Z"/><path fill="#fff" d="M341 127.067a11.433 11.433 0 0 0 8.066-8.067 11.436 11.436 0 0 0 8.067 8.067 11.433 11.433 0 0 0-8.067 8.066 11.43 11.43 0 0 0-8.066-8.066Z" /><path stroke="#fff" stroke-width="1.5" d="M349.036 248.018V140.875" /><circle cx="349.036" cy="259.178" r="4.018" fill="#fff" /><path stroke="#fff" stroke-width="1.5" d="M349.036 292.214v-21.429" /></g><filter id="c" width="514.606" height="445.5" x="-19.678" y="26.218" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"> <feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_123_5" stdDeviation="66.964" /></filter><filter id="d" width="514.606" height="445.5" x="29.352" y="74.373" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"> <feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_123_5" stdDeviation="66.964" /></filter><filter id="e" width="514.606" height="445.5" x="-19.678" y="26.219" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"> <feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_123_5" stdDeviation="66.964" /></filter><radialGradient id="f" cx="0" cy="0" r="1" gradientTransform="matrix(23.59563 32 -33.15047 24.44394 98.506 137.893)" gradientUnits="userSpaceOnUse"> <stop stop-color="#0B101A" /><stop offset=".609" stop-color="';

    parts[15] = color;

    parts[16] =
      '" /><stop offset="1" stop-color="#fff" /></radialGradient><clipPath id="a"><rect width="390" height="500" fill="#fff" rx="13.393" /></clipPath></svg>';

    string memory svg1 =
      string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));
    string memory svg2 =
      string(abi.encodePacked(parts[9], parts[10], parts[11], parts[12], parts[13], parts[14], parts[15], parts[16]));

    string memory svg = LibString.concat(svg1, svg2);

    assertEq(metadata.image, svg);
  }
}

contract IsRoleExpired is VertexPolicyTest {
  function test_ReturnsTrueForExpiredRole(uint64 expiration) public {
    expiration = uint64(bound(expiration, block.timestamp + 1, type(uint64).max - 1));

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, expiration);

    vm.warp(expiration + 1);

    assertEq(mpPolicy.isRoleExpired(arbitraryUser, uint8(Roles.TestRole1)), true);
  }

  function test_ReturnsFalseForNonExpiredRole(uint64 expiration) public {
    expiration = uint64(bound(expiration, block.timestamp + 1, type(uint64).max));

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryUser, DEFAULT_ROLE_QTY, expiration);

    assertEq(mpPolicy.isRoleExpired(arbitraryUser, uint8(Roles.TestRole1)), false);
  }
}

contract UpdateRoleDescription is VertexPolicyTest {
  function test_UpdatesRoleDescription() public {
    vm.prank(address(mpCore));
    vm.expectEmit();
    emit RoleInitialized(uint8(Roles.TestRole1), RoleDescription.wrap("New Description"));

    mpPolicy.updateRoleDescription(uint8(Roles.TestRole1), RoleDescription.wrap("New Description"));
  }

  function test_FailsForNonOwner() public {
    vm.expectRevert(VertexPolicy.OnlyVertex.selector);
    mpPolicy.updateRoleDescription(uint8(Roles.TestRole1), RoleDescription.wrap("New Description"));
  }
}
