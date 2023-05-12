// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, stdError, console2} from "forge-std/Test.sol";

import {Base64} from "@openzeppelin/utils/Base64.sol";

import {Clones} from "@openzeppelin/proxy/Clones.sol";

import {Solarray} from "@solarray/Solarray.sol";

import {LibString} from "@solady/utils/LibString.sol";

import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {Checkpoints} from "src/lib/Checkpoints.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaPolicyTest is LlamaTestSetup {
  event RoleAssigned(address indexed policyholder, uint8 indexed role, uint64 expiration, uint128 quantity);
  event RolePermissionAssigned(uint8 indexed role, bytes32 indexed permissionId, bool hasPermission);
  event RoleInitialized(uint8 indexed role, RoleDescription description);
  event Transfer(address indexed from, address indexed to, uint256 indexed id);

  uint8 constant ALL_HOLDERS_ROLE = 0;
  address arbitraryAddress = makeAddr("arbitraryAddress");
  address arbitraryPolicyholder = makeAddr("arbitraryPolicyholder");

  function getRoleDescription(string memory str) internal pure returns (RoleDescription) {
    return RoleDescription.wrap(bytes32(bytes(str)));
  }

  function setUp() public virtual override {
    LlamaTestSetup.setUp();

    // The tests in this file have hardcoded timestamps for simplicity, so if this statement is ever
    // untrue we should update those hardcoded timestamps accordingly.
    require(block.timestamp < 100, "The tests in this file have hardcoded timestamps");
  }
}

// ================================
// ======== Modifier Tests ========
// ================================

contract MockPolicy is LlamaPolicy {
  function exposed_onlyLlama() public onlyLlama {}
  function exposed_nonTransferableToken() public nonTransferableToken {}
}

contract OnlyLlama is LlamaPolicyTest {
  function test_RevertIf_CallerIsNotLlama() public {
    MockPolicy mockPolicy = new MockPolicy();
    vm.expectRevert(LlamaPolicy.OnlyLlama.selector);
    mockPolicy.exposed_onlyLlama();
  }
}

contract NonTransferableToken is LlamaPolicyTest {
  function test_RevertIf_CallerIsNotLlama() public {
    MockPolicy mockPolicy = new MockPolicy();
    vm.expectRevert(LlamaPolicy.NonTransferableToken.selector);
    mockPolicy.exposed_nonTransferableToken();
  }
}

contract Constructor is LlamaPolicyTest {
  function test_RevertIf_InitializeImplementationContract() public {
    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    policyLogic.initialize(
      "Mock Protocol", new RoleDescription[](0), new RoleHolderData[](0), new RolePermissionData[](0)
    );
  }
}

contract Initialize is LlamaPolicyTest {
  uint8 constant INIT_TEST_ROLE = 1;

  function test_RevertIf_NoRolesAssignedAtInitialization() public {
    LlamaPolicy localPolicy = LlamaPolicy(Clones.clone(address(mpPolicy)));
    vm.expectRevert(LlamaPolicy.InvalidRoleHolderInput.selector);
    localPolicy.initialize(
      "Test Policy", new RoleDescription[](0), new RoleHolderData[](0), new RolePermissionData[](0)
    );
  }

  function test_SetsNameAndSymbol() public {
    assertEq(mpPolicy.name(), "Mock Protocol Llama");
    assertEq(mpPolicy.symbol(), "LL-MOCK-PROTOCOL-LLAMA");
  }

  function testFuzz_SetsNumRolesToNumberOfRoleDescriptionsGiven(uint256 numRoles) public {
    numRoles = bound(numRoles, 1, 255); // Reverts if zero roles are given.

    RoleDescription[] memory roleDescriptions = new RoleDescription[](numRoles);
    for (uint8 i = 0; i < numRoles; i++) {
      roleDescriptions[i] = RoleDescription.wrap(bytes32(bytes(string.concat("Role ", vm.toString(i)))));
    }

    LlamaPolicy localPolicy = LlamaPolicy(Clones.clone(address(mpPolicy)));
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
    LlamaPolicy localPolicy = LlamaPolicy(Clones.clone(address(mpPolicy)));

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
    LlamaPolicy localPolicy = LlamaPolicy(Clones.clone(address(mpPolicy)));

    RoleDescription[] memory roleDescriptions = new RoleDescription[](1);
    roleDescriptions[0] = RoleDescription.wrap("Test Role 1");
    RoleHolderData[] memory roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(INIT_TEST_ROLE, address(this), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    RolePermissionData[] memory rolePermissions = new RolePermissionData[](1);
    rolePermissions[0] = RolePermissionData(INIT_TEST_ROLE, pausePermissionId, true);

    uint256 prevSupply = localPolicy.getRoleSupplyAsQuantitySum(INIT_TEST_ROLE);

    vm.expectEmit();
    emit RoleAssigned(address(this), INIT_TEST_ROLE, DEFAULT_ROLE_EXPIRATION, DEFAULT_ROLE_QTY);

    localPolicy.initialize("Test Policy", roleDescriptions, roleHolders, rolePermissions);

    assertEq(localPolicy.getRoleSupplyAsQuantitySum(INIT_TEST_ROLE), prevSupply + DEFAULT_ROLE_QTY);
    assertEq(localPolicy.numRoles(), 1);
  }

  function test_SetsRolePermissions() public {
    LlamaPolicy localPolicy = LlamaPolicy(Clones.clone(address(mpPolicy)));
    assertFalse(localPolicy.canCreateAction(INIT_TEST_ROLE, pausePermissionId));

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

contract SetLlama is LlamaPolicyTest {
  function test_SetsLlamaAddress() public {
    // This test is a no-op because this functionality is already tested in
    // `test_SetsLlamaCoreOnThePolicy`, which also is a stronger test since it tests that
    // method in the context it is used, instead of as a pure unit test.
  }

  function test_RevertIf_LlamaAddressIsSet() public {
    vm.expectRevert(LlamaPolicy.AlreadyInitialized.selector);
    mpPolicy.finalizeInitialization(arbitraryAddress, bytes32(0));
  }
}

// =======================================
// ======== Permission Management ========
// =======================================

contract InitializeRole is LlamaPolicyTest {
  function testFuzz_RevertIf_CallerIsNotLlama(address caller) public {
    vm.assume(caller != address(mpExecutor));
    vm.expectRevert(LlamaPolicy.OnlyLlama.selector);

    vm.prank(caller);
    mpPolicy.initializeRole(RoleDescription.wrap("TestRole1"));
  }

  function test_IncrementsNumRoles() public {
    assertEq(mpPolicy.numRoles(), NUM_INIT_ROLES);
    vm.startPrank(address(mpExecutor));

    mpPolicy.initializeRole(RoleDescription.wrap("TestRole1"));
    assertEq(mpPolicy.numRoles(), NUM_INIT_ROLES + 1);

    mpPolicy.initializeRole(RoleDescription.wrap("TestRole2"));
    assertEq(mpPolicy.numRoles(), NUM_INIT_ROLES + 2);
  }

  function test_RevertIf_OverflowOccurs() public {
    vm.startPrank(address(mpExecutor));
    while (mpPolicy.numRoles() < type(uint8).max) mpPolicy.initializeRole(getRoleDescription("TestRole"));

    // Now the `numRoles` is at the max value, so the next call should revert.
    vm.expectRevert(stdError.arithmeticError);
    mpPolicy.initializeRole(getRoleDescription("TestRole"));
  }

  function test_EmitsRoleInitializedEvent() public {
    vm.expectEmit();
    emit RoleInitialized(NUM_INIT_ROLES + 1, getRoleDescription("TestRole"));
    vm.prank(address(mpExecutor));

    mpPolicy.initializeRole(getRoleDescription("TestRole"));
  }

  function test_DoesNotGuardAgainstSameDescriptionUsedForMultipleRoles() public {
    vm.startPrank(address(mpExecutor));
    mpPolicy.initializeRole(getRoleDescription("TestRole"));
    mpPolicy.initializeRole(getRoleDescription("TestRole"));
    mpPolicy.initializeRole(getRoleDescription("TestRole"));
  }
}

contract SetRoleHolder is LlamaPolicyTest {
  function testFuzz_RevertIf_CallerIsNotLlama(address caller) public {
    vm.assume(caller != address(mpExecutor));
    vm.expectRevert(LlamaPolicy.OnlyLlama.selector);

    vm.prank(caller);
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function test_RevertIf_NonExistentRole(uint8 role) public {
    role = uint8(bound(role, mpPolicy.numRoles() + 1, type(uint8).max));
    vm.startPrank(address(mpExecutor));
    vm.expectRevert(abi.encodeWithSelector(LlamaPolicy.RoleNotInitialized.selector, role));
    mpPolicy.setRoleHolder(role, arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function test_RevertIf_InvalidExpiration(uint64 expiration, uint256 timestamp) public {
    timestamp = bound(timestamp, block.timestamp, type(uint64).max);
    expiration = uint64(bound(expiration, 0, timestamp - 1));
    vm.warp(timestamp);
    vm.expectRevert(LlamaPolicy.AllHoldersRole.selector);
    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, DEFAULT_ROLE_QTY, expiration);
  }

  function test_RevertIf_InvalidQuantity() public {
    vm.startPrank(address(mpExecutor));

    vm.expectRevert(LlamaPolicy.InvalidRoleHolderInput.selector);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryAddress, 0, DEFAULT_ROLE_EXPIRATION);
  }

  function test_RevertIf_AllHoldersRole() public {
    vm.startPrank(address(mpExecutor));

    vm.expectRevert(LlamaPolicy.AllHoldersRole.selector);
    mpPolicy.setRoleHolder(uint8(Roles.AllHolders), arbitraryAddress, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function test_NoOpIfNoChangesAreMade_WhenUserAlreadyHasSameRoleData() public {
    address policyholder = arbitraryPolicyholder;
    vm.startPrank(address(mpExecutor));

    uint256 initRoleHolders = 7;
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders, "0");

    // Assign role to policyholder with quantity of 1.
    vm.expectEmit();
    emit RoleAssigned(policyholder, uint8(Roles.TestRole1), DEFAULT_ROLE_EXPIRATION, DEFAULT_ROLE_QTY);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), true, "10");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.TestRole1)), DEFAULT_ROLE_QTY, "20");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.TestRole1)), DEFAULT_ROLE_EXPIRATION, "30");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 1, "40");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 1, "50");

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.AllHolders)), true, "60");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.AllHolders)), 1, "70");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "80");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 1, "90");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 1, "100");

    // Reassign role to policyholder with quantity of 1, i.e. no changes. All code and assertions
    // should be identical to the above set.
    vm.expectEmit();
    emit RoleAssigned(policyholder, uint8(Roles.TestRole1), DEFAULT_ROLE_EXPIRATION, DEFAULT_ROLE_QTY);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), true, "110");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.TestRole1)), DEFAULT_ROLE_QTY, "120");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.TestRole1)), DEFAULT_ROLE_EXPIRATION, "130");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 1, "140");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 1, "150");

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.AllHolders)), true, "160");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.AllHolders)), 1, "170");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "180");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 1, "190");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 1, "1100");
  }

  function test_NoOpIfNoChangesAreMade_WhenUserDoesNotHaveRole() public {
    address policyholder = arbitraryPolicyholder;
    vm.startPrank(address(mpExecutor));

    uint256 initRoleHolders = 7;
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders, "0");

    // Policyholder has no policy. We assign nothing, and things should not change except for them
    // now holding a policy.
    assertEq(mpPolicy.balanceOf(policyholder), 0, "1");
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, 0, 0);

    assertEq(mpPolicy.balanceOf(policyholder), 1, "2");
    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), false, "10");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.TestRole1)), 0, "20");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.TestRole1)), 0, "30");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 0, "40");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 0, "50");

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.AllHolders)), true, "60");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.AllHolders)), 1, "70");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "80");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 1, "90");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 1, "100");

    // Now we assign them a role and then immediately revoke it, so their balance is still 1 but they
    // hold no roles. Nothing should change.
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    assertEq(mpPolicy.balanceOf(policyholder), 1, "101");
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, 0, 0);

    assertEq(mpPolicy.balanceOf(policyholder), 1, "102");
    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), false, "110");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.TestRole1)), 0, "120");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.TestRole1)), 0, "130");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 0, "140");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 0, "150");

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.AllHolders)), true, "160");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.AllHolders)), 1, "170");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "180");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 1, "190");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 1, "200");

    // We again call `setRoleHolder` and nothing should change.
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, 0, 0);

    assertEq(mpPolicy.balanceOf(policyholder), 1, "202");
    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), false, "210");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.TestRole1)), 0, "220");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.TestRole1)), 0, "230");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 0, "240");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 0, "250");

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.AllHolders)), true, "260");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.AllHolders)), 1, "270");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "280");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 1, "290");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 1, "300");
  }

  function test_SetsRoleHolder(address policyholder) public {
    vm.assume(policyholder != address(0));
    if (mpPolicy.balanceOf(policyholder) > 0) policyholder = makeAddr("policyholderWithoutPolicy");
    vm.startPrank(address(mpExecutor));

    uint256 initRoleHolders = 7;
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders, "0");

    // Assign role to policyholder with quantity of 1.
    vm.expectEmit();
    emit RoleAssigned(policyholder, uint8(Roles.TestRole1), DEFAULT_ROLE_EXPIRATION, DEFAULT_ROLE_QTY);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), true, "10");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.TestRole1)), DEFAULT_ROLE_QTY, "20");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.TestRole1)), DEFAULT_ROLE_EXPIRATION, "30");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 1, "40");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 1, "50");

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.AllHolders)), true, "60");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.AllHolders)), 1, "70");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "80");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 1, "90");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 1, "100");

    // Adjust policyholder's policy to have quantity greater than 1.
    vm.expectEmit();
    emit RoleAssigned(policyholder, uint8(Roles.TestRole1), DEFAULT_ROLE_EXPIRATION - 10, 5);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, 5, DEFAULT_ROLE_EXPIRATION - 10);

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), true, "110");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.TestRole1)), 5, "120");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.TestRole1)), DEFAULT_ROLE_EXPIRATION - 10, "130");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 1, "140");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 5, "150");

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.AllHolders)), true, "160");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.AllHolders)), 1, "170");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "180");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 1, "190");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 1, "200");

    // Add another policyholder with a quantity of 3.
    vm.expectEmit();
    emit RoleAssigned(arbitraryPolicyholder, uint8(Roles.TestRole1), DEFAULT_ROLE_EXPIRATION, 3);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, 3, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasRole(arbitraryPolicyholder, uint8(Roles.TestRole1)), true, "210");
    assertEq(mpPolicy.getQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1)), 3, "220");
    assertEq(mpPolicy.roleExpiration(arbitraryPolicyholder, uint8(Roles.TestRole1)), DEFAULT_ROLE_EXPIRATION, "230");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 2, "240");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 8, "250");

    assertEq(mpPolicy.hasRole(arbitraryPolicyholder, uint8(Roles.AllHolders)), true, "260");
    assertEq(mpPolicy.getQuantity(arbitraryPolicyholder, uint8(Roles.AllHolders)), 1, "270");
    assertEq(mpPolicy.roleExpiration(arbitraryPolicyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "280");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 2, "290");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 2, "300");

    // Decrease the new policyholder's quantity to 2.
    vm.expectEmit();
    emit RoleAssigned(arbitraryPolicyholder, uint8(Roles.TestRole1), DEFAULT_ROLE_EXPIRATION, 2);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, 2, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasRole(arbitraryPolicyholder, uint8(Roles.TestRole1)), true, "301");
    assertEq(mpPolicy.getQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1)), 2, "302");
    assertEq(mpPolicy.roleExpiration(arbitraryPolicyholder, uint8(Roles.TestRole1)), DEFAULT_ROLE_EXPIRATION, "303");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 2, "304");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 7, "305");

    assertEq(mpPolicy.hasRole(arbitraryPolicyholder, uint8(Roles.AllHolders)), true, "306");
    assertEq(mpPolicy.getQuantity(arbitraryPolicyholder, uint8(Roles.AllHolders)), 1, "307");
    assertEq(mpPolicy.roleExpiration(arbitraryPolicyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "308");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 2, "309");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 2, "310");

    // Revoke the original policyholder's role. We did not revoke their policy so they still have the all holders role.
    vm.expectEmit();
    emit RoleAssigned(policyholder, uint8(Roles.TestRole1), 0, 0);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, 0, 0);

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), false, "311");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.TestRole1)), 0, "320");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.TestRole1)), 0, "330");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.TestRole1)), 1, "340");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 2, "350");

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.AllHolders)), true, "360");
    assertEq(mpPolicy.getQuantity(policyholder, uint8(Roles.AllHolders)), 1, "370");
    assertEq(mpPolicy.roleExpiration(policyholder, uint8(Roles.AllHolders)), DEFAULT_ROLE_EXPIRATION, "380");
    assertEq(mpPolicy.getRoleSupplyAsNumberOfHolders(uint8(Roles.AllHolders)), initRoleHolders + 2, "390");
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.AllHolders)), initRoleHolders + 2, "400");
  }
}

contract SetRolePermission is LlamaPolicyTest {
  function testFuzz_RevertIf_CallerIsNotLlama(address caller) public {
    vm.assume(caller != address(mpExecutor));
    vm.expectRevert(LlamaPolicy.OnlyLlama.selector);

    vm.prank(caller);
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), pausePermissionId, true);
  }

  function test_SetsRolePermission(bytes32 permissionId, bool hasPermission) public {
    vm.expectEmit();
    emit RolePermissionAssigned(uint8(Roles.TestRole1), permissionId, hasPermission);
    vm.prank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), permissionId, hasPermission);

    assertEq(mpPolicy.canCreateAction(uint8(Roles.TestRole1), permissionId), hasPermission);
  }
}

contract RevokeExpiredRole is LlamaPolicyTest {
  function test_RevokesExpiredRole(address policyholder, uint64 expiration) public {
    vm.assume(policyholder != address(0));
    expiration = uint64(bound(expiration, block.timestamp + 1, type(uint64).max - 1));

    vm.startPrank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, DEFAULT_ROLE_QTY, expiration);

    vm.warp(expiration + 1);

    vm.expectEmit();
    emit RoleAssigned(policyholder, uint8(Roles.TestRole1), 0, 0);

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), true);

    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), policyholder);

    assertEq(mpPolicy.hasRole(policyholder, uint8(Roles.TestRole1)), false);
  }

  function test_RevertIf_NotExpiredYet(address policyholder, uint64 expiration) public {
    vm.assume(policyholder != address(0));
    expiration = uint64(bound(expiration, block.timestamp + 1, type(uint64).max));

    vm.startPrank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, DEFAULT_ROLE_QTY, expiration);

    vm.expectRevert(LlamaPolicy.InvalidRoleHolderInput.selector);
    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), policyholder);
  }
}

contract RevokePolicy is LlamaPolicyTest {
  function testFuzz_RevertIf_CallerIsNotLlama(address caller) public {
    vm.assume(caller != address(mpExecutor));
    vm.expectRevert(LlamaPolicy.OnlyLlama.selector);

    vm.prank(caller);
    mpPolicy.revokePolicy(makeAddr("policyholder"));
  }

  function test_RevokesPolicy(address policyholder) public {
    vm.assume(policyholder != address(0));
    vm.assume(mpPolicy.balanceOf(policyholder) == 0);

    vm.startPrank(address(mpExecutor));

    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), policyholder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.balanceOf(policyholder), 1);

    vm.expectEmit();
    emit Transfer(policyholder, address(0), uint256(uint160(policyholder)));

    mpPolicy.revokePolicy(policyholder);

    assertEq(mpPolicy.balanceOf(policyholder), 0);
  }

  function test_RevertIf_PolicyDoesNotExist(address policyholder) public {
    vm.assume(policyholder != address(0));
    vm.assume(mpPolicy.balanceOf(policyholder) == 0);
    vm.expectRevert(abi.encodeWithSelector(LlamaPolicy.AddressDoesNotHoldPolicy.selector, policyholder));
    vm.prank(address(mpExecutor));
    mpPolicy.revokePolicy(policyholder);
  }
}

// =================================
// ======== ERC-721 Methods ========
// =================================

contract TransferFrom is LlamaPolicyTest {
  function test_RevertIf_Called() public {
    uint256 tokenId = 0; // Token ID does not actually matter, since that input is never used.
    vm.expectRevert(LlamaPolicy.NonTransferableToken.selector);
    mpPolicy.transferFrom(address(this), arbitraryAddress, tokenId);
  }
}

contract SafeTransferFrom is LlamaPolicyTest {
  function test_RevertIf_Called() public {
    uint256 tokenId = 0; // Token ID does not actually matter, since that input is never used.
    vm.expectRevert(LlamaPolicy.NonTransferableToken.selector);
    mpPolicy.safeTransferFrom(address(this), arbitraryAddress, tokenId);
  }
}

contract SafeTransferFromBytesOverload is LlamaPolicyTest {
  function test_RevertIf_Called() public {
    uint256 tokenId = 0; // Token ID does not actually matter, since that input is never used.
    vm.expectRevert(LlamaPolicy.NonTransferableToken.selector);
    mpPolicy.safeTransferFrom(address(this), arbitraryAddress, tokenId, "");
  }
}

contract Approve is LlamaPolicyTest {
  function test_RevertIf_Called() public {
    uint256 tokenId = 0; // Token ID does not actually matter, since that input is never used.
    vm.expectRevert(LlamaPolicy.NonTransferableToken.selector);
    mpPolicy.approve(arbitraryAddress, tokenId);
  }
}

contract SetApprovalForAll is LlamaPolicyTest {
  function test_RevertIf_Called() public {
    vm.expectRevert(LlamaPolicy.NonTransferableToken.selector);
    mpPolicy.setApprovalForAll(arbitraryAddress, true);
  }
}

// ====================================
// ======== Permission Getters ========
// ====================================
// The actual checkpointing logic is tested in `Checkpoints.t.sol`, so here we just test the logic
// that's added on top of that.

contract GetQuantity is LlamaPolicyTest {
  function test_ReturnsZeroIfPolicyholderDoesNotHoldRole() public {
    assertEq(mpPolicy.getQuantity(arbitraryAddress, uint8(Roles.MadeUpRole)), 0);
  }

  function test_ReturnsOneIfRoleHasExpiredButWasNotRevoked() public {
    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, 100);

    vm.warp(100);
    assertEq(mpPolicy.getQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1)), 1);

    vm.warp(101);
    assertEq(mpPolicy.getQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1)), 1);
  }

  function test_ReturnsOneIfRoleHasNotExpired() public {
    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, 100);

    vm.warp(99);
    assertEq(mpPolicy.getQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1)), 1);
  }
}

contract GetPastQuantity is LlamaPolicyTest {
  function setUp() public override {
    LlamaPolicyTest.setUp();
    vm.startPrank(address(mpExecutor));

    vm.warp(100);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, 105);

    vm.warp(110);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, 200);

    vm.warp(120);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, EMPTY_ROLE_QTY, 0);

    vm.warp(130);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, 200);

    vm.warp(140);
    mpPolicy.revokePolicy(arbitraryPolicyholder);

    vm.warp(150);
    vm.stopPrank();
  }

  function test_ReturnsZeroIfPolicyholderDidNotHaveRoleAndOneIfPolicyholderDidHaveRoleAtTimestamp() public {
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 99), 0, "99");
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 100), 1, "100"); // Role set.
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 101), 1, "101");

    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 104), 1, "104");
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 105), 1, "105"); // Role expires,
      // but not
      // revoked.
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 106), 1, "106");

    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 109), 1, "109");
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 110), 1, "110"); // Role set.
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 111), 1, "111");

    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 119), 1, "119");
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 120), 0, "120"); // Role revoked.
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 121), 0, "121");

    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 129), 0, "129");
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 130), 1, "130"); // Role set.
    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 131), 1, "131"); // Role set.

    assertEq(mpPolicy.getPastQuantity(arbitraryPolicyholder, uint8(Roles.TestRole1), 140), 0, "140"); // Role revoked
  }
}

contract GetSupply is LlamaPolicyTest {
  function setUp() public override {
    LlamaPolicyTest.setUp();
    vm.startPrank(address(mpExecutor));
  }

  function test_IncrementsWhenRolesAreAddedAndDecrementsWhenRolesAreRemoved() public {
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 0);
    uint256 initPolicySupply = mpPolicy.getRoleSupplyAsQuantitySum(ALL_HOLDERS_ROLE);

    // Assigning a role increases supply.
    vm.warp(100);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, 150);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 1);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(ALL_HOLDERS_ROLE), initPolicySupply + 1);

    // Updating the role does not change supply.
    vm.warp(110);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, 160);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 1);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(ALL_HOLDERS_ROLE), initPolicySupply + 1);

    // Assigning the role to a new person increases supply.
    vm.warp(120);
    address newRoleHolder = makeAddr("newRoleHolder");
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), newRoleHolder, DEFAULT_ROLE_QTY, 200);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 2);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(ALL_HOLDERS_ROLE), initPolicySupply + 2);

    // Assigning new role to the same person does not change supply.
    vm.warp(130);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), newRoleHolder, DEFAULT_ROLE_QTY, 300);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 2);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(ALL_HOLDERS_ROLE), initPolicySupply + 2);

    // Revoking all roles from the policyholder should only decrease supply by 1.
    vm.warp(140);
    mpPolicy.revokePolicy(newRoleHolder);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 1);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(ALL_HOLDERS_ROLE), initPolicySupply + 1);

    // Revoking expired roles changes supply of the revoked role, but they still hold a policy, so
    // it doesn't change the total supply.
    vm.warp(200);
    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), arbitraryPolicyholder);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(uint8(Roles.TestRole1)), 0);
    assertEq(mpPolicy.getRoleSupplyAsQuantitySum(ALL_HOLDERS_ROLE), initPolicySupply + 1);
  }
}

contract RoleBalanceCheckpoints is LlamaPolicyTest {
  function test_ReturnsBalanceCheckpoint() public {
    vm.startPrank(address(mpExecutor));

    vm.warp(100);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, 150);

    vm.warp(110);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, 159);

    vm.warp(120);
    address newRoleHolder = makeAddr("newRoleHolder");
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), newRoleHolder, DEFAULT_ROLE_QTY, 200);

    vm.warp(130);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), newRoleHolder, DEFAULT_ROLE_QTY, 300);

    vm.warp(140);
    mpPolicy.revokePolicy(newRoleHolder);

    vm.warp(160);
    mpPolicy.revokeExpiredRole(uint8(Roles.TestRole1), arbitraryPolicyholder);

    vm.warp(161);

    Checkpoints.History memory rbCheckpoint1 =
      mpPolicy.roleBalanceCheckpoints(arbitraryPolicyholder, uint8(Roles.TestRole1));
    Checkpoints.History memory rbCheckpoint2 = mpPolicy.roleBalanceCheckpoints(newRoleHolder, uint8(Roles.TestRole2));

    assertEq(rbCheckpoint1._checkpoints.length, 3);
    assertEq(rbCheckpoint1._checkpoints[0].timestamp, 100);
    assertEq(rbCheckpoint1._checkpoints[0].expiration, 150);
    assertEq(rbCheckpoint1._checkpoints[0].quantity, 1);
    assertEq(rbCheckpoint1._checkpoints[1].timestamp, 110);
    assertEq(rbCheckpoint1._checkpoints[1].expiration, 159);
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

contract HasRole is LlamaPolicyTest {
  function test_ReturnsTrueIfHolderHasRole() public {
    vm.warp(100);
    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasRole(arbitraryPolicyholder, uint8(Roles.TestRole1)), true);
  }

  function test_ReturnsFalseIfHolderDoesNotHaveRole() public {
    assertEq(mpPolicy.hasRole(arbitraryPolicyholder, uint8(Roles.TestRole1)), false);
  }
}

contract HasRoleUint256Overload is LlamaPolicyTest {
  function test_ReturnsTrueIfHolderHasRole() public {
    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.warp(100);

    assertEq(mpPolicy.hasRole(arbitraryPolicyholder, uint8(Roles.TestRole1), block.timestamp - 1), true);
    assertEq(mpPolicy.hasRole(arbitraryPolicyholder, uint8(Roles.TestRole1), 0), false);
  }

  function test_ReturnsFalseIfHolderDoesNotHaveRole() public {
    vm.warp(100);
    assertEq(mpPolicy.hasRole(arbitraryPolicyholder, uint8(Roles.TestRole1), block.timestamp - 1), false);
  }
}

contract HasPermissionId is LlamaPolicyTest {
  function testFuzz_ReturnsTrueIfHolderHasPermission(bytes32 permissionId) public {
    vm.startPrank(address(mpExecutor));

    vm.warp(100);
    mpPolicy.setRolePermission(uint8(Roles.TestRole1), permissionId, true);
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    assertEq(mpPolicy.hasPermissionId(arbitraryPolicyholder, uint8(Roles.TestRole1), permissionId), true);
  }

  function test_ReturnsFalseIfHolderDoesNotHaveQuanitity() public {
    assertEq(mpPolicy.hasPermissionId(arbitraryPolicyholder, uint8(Roles.TestRole1), pausePermissionId), false);
  }

  function testFuzz_ReturnsFalseIfHolderDoesNotHavePermission(bytes32 permissionId) public {
    vm.startPrank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    assertEq(mpPolicy.hasPermissionId(arbitraryPolicyholder, uint8(Roles.TestRole1), permissionId), false);
  }
}

contract TotalSupply is LlamaPolicyTest {
  function testFuzz_getsTotalSupply(uint256 numberOfPolicies) public {
    uint256 initPolicySupply = mpPolicy.getRoleSupplyAsQuantitySum(ALL_HOLDERS_ROLE);
    numberOfPolicies = bound(numberOfPolicies, 1, 10_000);
    for (uint256 i = 0; i < numberOfPolicies; i++) {
      vm.prank(address(mpExecutor));
      mpPolicy.setRoleHolder(
        uint8(Roles.TestRole1), address(uint160(i + 100)), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION
      );
    }

    assertEq(mpPolicy.totalSupply(), initPolicySupply + numberOfPolicies);
  }
}

// =================================
// ======== ERC-721 Getters ========
// =================================

contract PolicyMetadata is LlamaPolicyTest {
  // The token's JSON metadata.
  // The `image` field is the *decoded* SVG image, but in the contract it's base64-encoded.
  struct Metadata {
    string name;
    string description;
    string image; // Decoded SVG.
    string external_url;
  }

  function setTokenURIMetadata() internal {
    string memory color = "#FF0000";
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.startPrank(address(rootExecutor));
    policyMetadataParamRegistry.setColor(mpExecutor, color);
    policyMetadataParamRegistry.setLogo(mpExecutor, logo);
    vm.stopPrank();
  }

  function parseMetadata(string memory uri) internal returns (Metadata memory) {
    string[] memory inputs = new string[](3);
    inputs[0] = "node";
    inputs[1] = "test/lib/metadata.js";
    inputs[2] = uri;
    return abi.decode(vm.ffi(inputs), (Metadata));
  }

  function generateTokenUri(address policyholderAddress) internal view returns (string memory) {
    string memory policyholder = LibString.toHexString(policyholderAddress);
    (string memory color, string memory logo) = policyMetadataParamRegistry.getMetadata(mpExecutor);

    string[21] memory parts;

    parts[0] =
      '<svg xmlns="http://www.w3.org/2000/svg" width="390" height="500" fill="none"><g clip-path="url(#a)"><rect width="390" height="500" fill="#0B101A" rx="13.393" /><mask id="b" width="364" height="305" x="4" y="30" maskUnits="userSpaceOnUse" style="mask-type:alpha"><ellipse cx="186.475" cy="182.744" fill="#8000FF" rx="196.994" ry="131.329" transform="rotate(-31.49 186.475 182.744)" /></mask><g mask="url(#b)"><g filter="url(#c)"><ellipse cx="226.274" cy="247.516" fill="url(#d)" rx="140.048" ry="59.062" transform="rotate(-31.49 226.274 247.516)" /></g><g filter="url(#e)"><ellipse cx="231.368" cy="254.717" fill="url(#f)" rx="102.858" ry="43.378" transform="rotate(-31.49 231.368 254.717)" /></g></g><g filter="url(#g)"><ellipse cx="237.625" cy="248.969" fill="url(#h)" rx="140.048" ry="59.062" transform="rotate(-31.49 237.625 248.969)" /></g><circle cx="109.839" cy="147.893" r="22" fill="url(#i)" /><rect width="150" height="35.071" x="32" y="376.875" fill="';

    parts[1] = color;

    parts[2] =
      '" rx="17.536" /><text xml:space="preserve" fill="#0B101A" font-family="ui-monospace,Cascadia Mono,Menlo,Monaco,Segoe UI Mono,Roboto Mono,Oxygen Mono,Ubuntu Monospace,Source Code Pro,Droid Sans Mono,Fira Mono,Courier,monospace" font-size="16"><tspan x="45.393" y="399.851">';

    parts[3] = string.concat(LibString.slice(policyholder, 0, 6), "...", LibString.slice(policyholder, 38, 42));

    parts[4] =
      '</tspan></text><path fill="#fff" d="M341 127.067a11.433 11.433 0 0 0 8.066-8.067 11.436 11.436 0 0 0 8.067 8.067 11.433 11.433 0 0 0-8.067 8.066 11.43 11.43 0 0 0-8.066-8.066Z" /><path stroke="#fff" stroke-width="1.5" d="M349.036 248.018V140.875" /><circle cx="349.036" cy="259.178" r="4.018" fill="#fff" /><path stroke="#fff" stroke-width="1.5" d="M349.036 292.214v-21.429" /><path fill="#fff" d="M343.364 33.506a1.364 1.364 0 0 0-2.728 0V43.85l-7.314-7.314a1.364 1.364 0 0 0-1.929 1.928l7.315 7.315h-10.344a1.364 1.364 0 0 0 0 2.727h10.344l-7.315 7.315a1.365 1.365 0 0 0 1.929 1.928l7.314-7.314v10.344a1.364 1.364 0 0 0 2.728 0V50.435l7.314 7.314a1.364 1.364 0 0 0 1.929-1.928l-7.315-7.315h10.344a1.364 1.364 0 1 0 0-2.727h-10.344l7.315-7.315a1.365 1.365 0 0 0-1.929-1.928l-7.314 7.314V33.506ZM73.81 44.512h-4.616v1.932h1.777v10.045h-2.29v1.932h6.82V56.49h-1.69V44.512ZM82.469 44.512h-4.617v1.932h1.777v10.045h-2.29v1.932h6.82V56.49h-1.69V44.512ZM88.847 51.534c.097-.995.783-1.526 2.02-1.526 1.236 0 1.854.531 1.854 1.68v.28l-3.4.416c-2.02.251-3.603 1.13-3.603 3.11 0 1.971 1.497 3.101 3.767 3.101 1.903 0 2.743-.724 3.14-1.343h.192v1.17h2.647v-6.337c0-2.763-1.777-4.009-4.54-4.009-2.782 0-4.482 1.246-4.685 3.168v.29h2.608Zm-.338 3.835c0-.763.58-1.13 1.42-1.246l2.792-.367v.435c0 1.632-1.082 2.453-2.57 2.453-1.043 0-1.642-.502-1.642-1.275ZM97.614 58.42h2.608v-6.51c0-1.246.657-1.787 1.575-1.787.821 0 1.226.474 1.226 1.275v7.023h2.609v-6.51c0-1.247.656-1.788 1.564-1.788.831 0 1.227.474 1.227 1.275v7.023h2.618v-7.38c0-1.835-1.159-2.927-2.927-2.927-1.584 0-2.318.686-2.743 1.44h-.194c-.289-.657-1.004-1.44-2.472-1.44-1.44 0-2.067.6-2.415 1.208h-.193v-1.015h-2.483v10.114ZM115.654 51.534c.097-.995.782-1.526 2.019-1.526 1.236 0 1.854.531 1.854 1.68v.28l-3.4.416c-2.019.251-3.603 1.13-3.603 3.11 0 1.971 1.498 3.101 3.767 3.101 1.903 0 2.744-.724 3.14-1.343h.193v1.17h2.647v-6.337c0-2.763-1.778-4.009-4.54-4.009-2.782 0-4.482 1.246-4.685 3.168v.29h2.608Zm-.338 3.835c0-.763.58-1.13 1.42-1.246l2.791-.367v.435c0 1.632-1.081 2.453-2.569 2.453-1.043 0-1.642-.502-1.642-1.275ZM35.314 52.07a.906.906 0 0 1 .88-.895h11.72a4.205 4.205 0 0 0 3.896-2.597 4.22 4.22 0 0 0 .323-1.614V32h-3.316v14.964a.907.907 0 0 1-.88.894H36.205a4.206 4.206 0 0 0-2.972 1.235A4.219 4.219 0 0 0 32 52.07v10.329h3.314v-10.33ZM53.6 34.852h-.147l.141.14v3.086h3.05l1.43 1.446a4.21 4.21 0 0 0-2.418 1.463 4.222 4.222 0 0 0-.95 2.664v18.752h3.3V43.647a.909.909 0 0 1 .894-.895h.508c1.947 0 2.608-1.086 2.803-1.543.196-.456.498-1.7-.88-3.085l-3.23-3.261h-1.006" /><path fill="#fff" d="M44.834 60.77a5.448 5.448 0 0 1 3.89 1.629h4.012a8.8 8.8 0 0 0-3.243-3.608 8.781 8.781 0 0 0-12.562 3.608h4.012a5.459 5.459 0 0 1 3.89-1.629Z" />';

    parts[5] = logo;

    parts[6] =
      '</g><defs><radialGradient id="d" cx="0" cy="0" r="1" gradientTransform="rotate(-90.831 270.037 36.188) scale(115.966 274.979)" gradientUnits="userSpaceOnUse"><stop stop-color="';

    parts[7] = color;

    parts[8] = '" /><stop offset="1" stop-color="';

    parts[9] = color;

    parts[10] =
      '" stop-opacity="0" /></radialGradient><radialGradient id="f" cx="0" cy="0" r="1" gradientTransform="matrix(7.1866 -72.99558 127.41796 12.54463 239.305 292.746)" gradientUnits="userSpaceOnUse"><stop stop-color="';

    parts[11] = color;

    parts[12] = '" /><stop offset="1" stop-color="';

    parts[13] = color;

    parts[14] =
      '" stop-opacity="0" /></radialGradient><radialGradient id="h" cx="0" cy="0" r="1" gradientTransform="rotate(-94.142 264.008 51.235) scale(212.85 177.126)" gradientUnits="userSpaceOnUse"><stop stop-color="';

    parts[15] = color;

    parts[16] = '" /><stop offset="1" stop-color="';

    parts[17] = color;

    parts[18] =
      '" stop-opacity="0" /></radialGradient><radialGradient id="i" cx="0" cy="0" r="1" gradientTransform="matrix(23.59563 32 -33.15047 24.44394 98.506 137.893)" gradientUnits="userSpaceOnUse"><stop stop-color="#0B101A" /><stop offset=".609" stop-color="';

    parts[19] = color;

    parts[20] =
      '" /><stop offset="1" stop-color="#fff" /></radialGradient><filter id="c" width="346.748" height="277.643" x="52.9" y="108.695" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"><feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_260_71" stdDeviation="25" /></filter><filter id="e" width="221.224" height="170.469" x="120.757" y="169.482" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"><feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_260_71" stdDeviation="10" /></filter><filter id="g" width="446.748" height="377.643" x="14.251" y="60.147" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse"><feFlood flood-opacity="0" result="BackgroundImageFix" /><feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape" /><feGaussianBlur result="effect1_foregroundBlur_260_71" stdDeviation="50" /></filter><clipPath id="a"><rect width="390" height="500" fill="#fff" rx="13.393" /></clipPath></defs></svg>';

    string memory svg1 =
      string.concat(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]);
    string memory svg2 =
      string.concat(parts[9], parts[10], parts[11], parts[12], parts[13], parts[14], parts[15], parts[16], parts[17]);
    return string.concat(svg1, svg2, parts[18], parts[19], parts[20]);
  }

  function test_ReturnsCorrectTokenURIWhenAddressHasLeadingZeroes(uint256 tokenIdWithLeadingZeroes) public {
    // Setting this number as the upper limit ensures when this `tokenId` is converted to an address it will be be less
    // than `0x00000000000fffffffffffffffffffffffffffff`. This guarantees that the fuzz output will have at least 11
    // leading zeroes
    tokenIdWithLeadingZeroes = bound(tokenIdWithLeadingZeroes, 0, 5_444_517_870_735_015_415_413_993_718_908_291_383_295);

    setTokenURIMetadata();
    string memory uri = mpPolicy.tokenURI(tokenIdWithLeadingZeroes);
    Metadata memory metadata = parseMetadata(uri);
    assertEq(metadata.image, generateTokenUri(address(uint160(tokenIdWithLeadingZeroes))));
  }

  function test_ReturnsCorrectTokenURI() public {
    setTokenURIMetadata();

    string memory uri = mpPolicy.tokenURI(uint256(uint160(address(this))));
    Metadata memory metadata = parseMetadata(uri);
    string memory name = LibString.concat(mpPolicy.name(), " Member");
    string memory policyholder = LibString.toHexString(address(this));
    string memory description1 =
      LibString.concat("This NFT represents membership in the Llama organization: ", mpPolicy.name());
    string memory description = string.concat(
      description1,
      ". The owner of this NFT can participate in governance according to their roles and permissions. Visit https://app.llama.xyz/profiles/",
      policyholder,
      " to view their profile page."
    );

    assertEq(metadata.description, description);
    assertEq(metadata.name, name);
    assertEq(metadata.image, generateTokenUri(address(this)));
  }
}

contract PolicyMetadataExternalUrl is LlamaPolicyTest {
  // The token's JSON metadata.
  // The `image` field is the *decoded* SVG image, but in the contract it's base64-encoded.
  struct Metadata {
    string name;
    string description;
    string image; // Decoded SVG.
    string external_url;
  }

  function setTokenURIMetadata() internal {
    string memory color = "#FF0000";
    string memory logo =
      '<path fill="#fff" fill-rule="evenodd" d="M344.211 459c7.666-3.026 13.093-10.52 13.093-19.284 0-11.441-9.246-20.716-20.652-20.716S316 428.275 316 439.716a20.711 20.711 0 0 0 9.38 17.36c.401-.714 1.144-1.193 1.993-1.193.188 0 .347-.173.3-.353a14.088 14.088 0 0 1-.457-3.58c0-7.456 5.752-13.501 12.848-13.501.487 0 .917-.324 1.08-.777l.041-.111c.334-.882-.223-2.13-1.153-2.341-4.755-1.082-8.528-4.915-9.714-9.825-.137-.564.506-.939.974-.587l18.747 14.067a.674.674 0 0 1 .254.657 12.485 12.485 0 0 0 .102 4.921.63.63 0 0 1-.247.666 5.913 5.913 0 0 1-6.062.332 1.145 1.145 0 0 0-.794-.116 1.016 1.016 0 0 0-.789.986v8.518a.658.658 0 0 1-.663.653h-1.069a.713.713 0 0 1-.694-.629c-.397-2.96-2.819-5.238-5.749-5.238-.186 0-.37.009-.551.028a.416.416 0 0 0-.372.42c0 .234.187.424.423.457 2.412.329 4.275 2.487 4.275 5.099 0 .344-.033.687-.097 1.025-.072.369.197.741.578.741h.541c.003 0 .007.001.01.004.002.003.004.006.004.01l.001.005.003.005.005.003.005.001h4.183a.17.17 0 0 1 .123.05c.124.118.244.24.362.364.248.266.349.64.39 1.163Zm-19.459-22.154c-.346-.272-.137-.788.306-.788h11.799c.443 0 .652.516.306.788a10.004 10.004 0 0 1-6.205 2.162c-2.329 0-4.478-.804-6.206-2.162Zm22.355 3.712c0 .645-.5 1.168-1.118 1.168-.617 0-1.117-.523-1.117-1.168 0-.646.5-1.168 1.117-1.168.618 0 1.118.523 1.118 1.168Z" clip-rule="evenodd"/>';
    vm.startPrank(address(rootExecutor));
    policyMetadataParamRegistry.setColor(mpExecutor, color);
    policyMetadataParamRegistry.setLogo(mpExecutor, logo);
    vm.stopPrank();
  }

  function parseMetadata(string memory uri) internal returns (Metadata memory) {
    string[] memory inputs = new string[](3);
    inputs[0] = "node";
    inputs[1] = "test/lib/metadata.js";
    inputs[2] = uri;
    return abi.decode(vm.ffi(inputs), (Metadata));
  }

  function test_ReturnsCorrectExternalUrl() public {
    setTokenURIMetadata();

    string memory uri = mpPolicy.tokenURI(uint256(uint160(address(this))));
    Metadata memory metadata = parseMetadata(uri);
    string memory external_url = "https://app.llama.xyz";
    assertEq(metadata.external_url, external_url);
  }
}

contract PolicyMetadataContractURI is LlamaPolicyTest {
  function test_ReturnsCorrectContractURI() external {
    string memory name = "Mock Protocol Llama";
    string[5] memory parts;
    parts[0] = '{ "name": "Llama Policies: ';
    parts[1] = name;
    parts[2] = '", "description": "This collection includes all members of the Llama organization: ';
    parts[3] = name;
    parts[4] =
      '. Visit https://app.llama.xyz to learn more.", "image":"https://llama.xyz/policy-nft/llama-profile.png", "external_link": "https://app.llama.xyz", "banner":"https://llama.xyz/policy-nft/llama-banner.png" }';
    string memory json = Base64.encode(bytes(string.concat(parts[0], parts[1], parts[2], parts[3], parts[4])));
    string memory encodedContractURI = string.concat("data:application/json;base64,", json);
    assertEq(mpPolicy.contractURI(), encodedContractURI);
  }
}

contract IsRoleExpired is LlamaPolicyTest {
  function testFuzz_ReturnsTrueForExpiredRole(uint64 expiration) public {
    expiration = uint64(bound(expiration, block.timestamp + 1, type(uint64).max - 1));

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, expiration);

    vm.warp(expiration + 1);

    assertEq(mpPolicy.isRoleExpired(arbitraryPolicyholder, uint8(Roles.TestRole1)), true);
  }

  function testFuzz_ReturnsFalseForNonExpiredRole(uint64 expiration) public {
    expiration = uint64(bound(expiration, block.timestamp + 1, type(uint64).max));

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole1), arbitraryPolicyholder, DEFAULT_ROLE_QTY, expiration);

    assertEq(mpPolicy.isRoleExpired(arbitraryPolicyholder, uint8(Roles.TestRole1)), false);
  }

  function test_ReturnsFalseIfNoRole() public {
    address randomPolicyholder = makeAddr("randomPolicyholder");
    // Make sure policyholder has no role, in and in that case expired should be false.
    assertEq(mpPolicy.getQuantity(randomPolicyholder, uint8(Roles.TestRole1)), 0);
    assertFalse(mpPolicy.isRoleExpired(randomPolicyholder, uint8(Roles.TestRole1)));
  }
}

contract UpdateRoleDescription is LlamaPolicyTest {
  function test_UpdatesRoleDescription() public {
    vm.prank(address(mpExecutor));
    vm.expectEmit();
    emit RoleInitialized(uint8(Roles.TestRole1), RoleDescription.wrap("New Description"));

    mpPolicy.updateRoleDescription(uint8(Roles.TestRole1), RoleDescription.wrap("New Description"));
  }

  function test_FailsForNonOwner() public {
    vm.expectRevert(LlamaPolicy.OnlyLlama.selector);
    mpPolicy.updateRoleDescription(uint8(Roles.TestRole1), RoleDescription.wrap("New Description"));
  }
}
