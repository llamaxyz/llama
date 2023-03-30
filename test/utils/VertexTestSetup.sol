// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Solarray} from "solarray/Solarray.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {ProtocolXYZ} from "test/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicyMetadata} from "src/VertexPolicyMetadata.sol";
import {Action, Strategy, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";

// Used for readability of tests, so they can be accessed with e.g. `Roles.Admin`.
enum Roles {
  AllHolders,
  Admin,
  ActionCreator,
  Approver,
  Disapprover,
  ForceApprover,
  ForceDisapprover,
  TestRole1,
  TestRole2,
  MadeUpRole
}

contract VertexTestSetup is Test {
  // Logic contracts.
  VertexCore coreLogic;
  VertexStrategy strategyLogic;
  VertexAccount accountLogic;
  VertexPolicy policyLogic;

  // Core Protocol.
  VertexFactory factory;
  VertexPolicyMetadata policyMetadata;
  VertexLens lens;

  // Root Vertex instance.
  VertexCore rootCore;
  VertexPolicy rootPolicy;
  VertexStrategy rootStrategy1;
  VertexStrategy rootStrategy2;
  VertexAccount rootAccount1;
  VertexAccount rootAccount2;

  // Mock protocol's (mp) vertex instance.
  VertexCore mpCore;
  VertexPolicy mpPolicy;
  VertexStrategy mpStrategy1;
  VertexStrategy mpStrategy2;
  VertexAccount mpAccount1;
  VertexAccount mpAccount2;

  // Mock protocol for action targets.
  ProtocolXYZ public mockProtocol;

  // Root vertex admin.
  address rootVertexAdmin = makeAddr("rootVertexAdmin");

  // Mock protocol users.
  address adminAlice = makeAddr("adminAlice");
  address actionCreatorAaron = makeAddr("actionCreatorAaron");

  address approverAdam = makeAddr("approverAdam");
  address approverAlicia = makeAddr("approverAlicia");
  address approverAndy = makeAddr("approverAndy");

  address disapproverDave = makeAddr("disapproverDave");
  address disapproverDiane = makeAddr("disapproverDiane");
  address disapproverDrake = makeAddr("disapproverDrake");

  // Constants.
  uint256 SELF_TOKEN_ID = uint256(uint160(address(this)));

  // Function selectors used in tests.
  bytes4 public constant PAUSE_SELECTOR = 0x02329a29; // pause(bool)
  bytes4 public constant FAIL_SELECTOR = 0xa9cc4718; // fail()
  bytes4 public constant RECEIVE_ETH_SELECTOR = 0x4185f8eb; // receiveEth()

  // Permission IDs for those selectors.
  bytes32 pausePermissionId;
  bytes32 failPermissionId;
  bytes32 receiveEthPermissionId;

  // Other addresses and constants.
  address randomLogicAddress = makeAddr("randomLogicAddress");
  uint128 DEFAULT_ROLE_QTY = 1;
  uint64 DEFAULT_ROLE_EXPIRATION = type(uint64).max;

  function setUp() public virtual {
    // Deploy logic contracts.
    coreLogic = new VertexCore();
    strategyLogic = new VertexStrategy();
    accountLogic = new VertexAccount();
    policyLogic = new VertexPolicy();
    policyMetadata = new VertexPolicyMetadata();

    // Deploy lens.
    lens = new VertexLens();

    // Deploy the Root vertex instance. We only instantiate it with a single admin role.
    Strategy[] memory strategies = defaultStrategies();
    string[] memory roleDescriptions =
      Solarray.strings("AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole");
    string[] memory rootAccounts = Solarray.strings("Llama Treasury", "Llama Grants");
    RoleHolderData[] memory rootRoleHolders = defaultAdminRoleHolder(rootVertexAdmin);

    factory = new VertexFactory(
      coreLogic,
      address(strategyLogic),
      address(accountLogic),
      policyLogic,
      policyMetadata,
      "Root Vertex",
      strategies,
      rootAccounts,
      roleDescriptions,
      rootRoleHolders,
      new RolePermissionData[](0)
    );
    rootCore = factory.ROOT_VERTEX();
    rootPolicy = rootCore.policy();

    // Now we deploy a mock protocol's vertex, again with a single admin role.
    string[] memory mpAccounts = Solarray.strings("MP Treasury", "MP Grants");
    RoleHolderData[] memory mpRoleHolders = defaultAdminRoleHolder(adminAlice);

    vm.prank(address(rootCore));
    mpCore = factory.deploy(
      "Mock Protocol Vertex",
      address(strategyLogic),
      address(accountLogic),
      strategies,
      mpAccounts,
      roleDescriptions,
      mpRoleHolders,
      new RolePermissionData[](0)
    );
    mpPolicy = mpCore.policy();

    // Add approvers and disapprovers to the mock protocol's vertex.
    // forgefmt: disable-start
    RoleHolderData[] memory mpRoleHoldersNew = new RoleHolderData[](7);
    mpRoleHoldersNew[0] = RoleHolderData(uint8(Roles.ActionCreator), actionCreatorAaron, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpRoleHoldersNew[1] = RoleHolderData(uint8(Roles.Approver), approverAdam, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpRoleHoldersNew[2] = RoleHolderData(uint8(Roles.Approver), approverAlicia, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpRoleHoldersNew[3] = RoleHolderData(uint8(Roles.Approver), approverAndy, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpRoleHoldersNew[4] = RoleHolderData(uint8(Roles.Disapprover), disapproverDave, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpRoleHoldersNew[5] = RoleHolderData(uint8(Roles.Disapprover), disapproverDiane, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpRoleHoldersNew[6] = RoleHolderData(uint8(Roles.Disapprover), disapproverDrake, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    // forgefmt: disable-end

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolders(mpRoleHoldersNew);

    // With the mock protocol's vertex instance deployed, we deploy the mock protocol.
    mockProtocol = new ProtocolXYZ(address(mpCore));

    // With the protocol deployed, we can set special permissions.
    pausePermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, mpStrategy1));
    failPermissionId = keccak256(abi.encode(address(mockProtocol), FAIL_SELECTOR, mpStrategy1));
    receiveEthPermissionId = keccak256(abi.encode(address(mockProtocol), RECEIVE_ETH_SELECTOR, mpStrategy1));

    RolePermissionData[] memory rolePermissions = new RolePermissionData[](3);
    rolePermissions[0] = RolePermissionData(uint8(Roles.ActionCreator), pausePermissionId, true);
    rolePermissions[1] = RolePermissionData(uint8(Roles.ActionCreator), failPermissionId, true);
    rolePermissions[2] = RolePermissionData(uint8(Roles.ActionCreator), receiveEthPermissionId, true);

    // Set strategy and account addresses.
    rootStrategy1 = lens.computeVertexStrategyAddress(address(strategyLogic), strategies[0], address(rootCore));
    rootStrategy2 = lens.computeVertexStrategyAddress(address(strategyLogic), strategies[1], address(rootCore));
    mpStrategy1 = lens.computeVertexStrategyAddress(address(strategyLogic), strategies[0], address(mpCore));
    mpStrategy2 = lens.computeVertexStrategyAddress(address(strategyLogic), strategies[1], address(mpCore));

    // Set vertex account addresses.
    rootAccount1 = lens.computeVertexAccountAddress(address(accountLogic), rootAccounts[0], address(rootCore));
    rootAccount2 = lens.computeVertexAccountAddress(address(accountLogic), rootAccounts[1], address(rootCore));
    mpAccount1 = lens.computeVertexAccountAddress(address(accountLogic), mpAccounts[0], address(mpCore));
    mpAccount2 = lens.computeVertexAccountAddress(address(accountLogic), mpAccounts[1], address(mpCore));

    // Skip forward 1 second so the most recent checkpoints are in the past.
    vm.warp(block.timestamp + 1);

    // Verify that all storage variables were initialized. Standard assertions are in `setUp` are
    // not well supported by the Forge test runner, so we use require statements instead.
    require(address(0) != address(coreLogic), "coreLogic not set");
    require(address(0) != address(strategyLogic), "strategyLogic not set");
    require(address(0) != address(accountLogic), "accountLogic not set");
    require(address(0) != address(policyLogic), "policyLogic not set");

    require(address(0) != address(factory), "factory not set");
    require(address(0) != address(lens), "lens not set");

    require(address(0) != address(rootCore), "rootCore not set");
    require(address(0) != address(rootPolicy), "rootPolicy not set");
    require(address(0) != address(rootStrategy1), "rootStrategy1 not set");
    require(address(0) != address(rootStrategy2), "rootStrategy2 not set");
    require(address(0) != address(rootAccount1), "rootAccount1 not set");
    require(address(0) != address(rootAccount2), "rootAccount2 not set");

    require(address(0) != address(mockProtocol), "mockProtocol not set");
    require(address(0) != address(mpCore), "mpCore not set");
    require(address(0) != address(mpPolicy), "mpPolicy not set");
    require(address(0) != address(mpStrategy1), "mpStrategy1 not set");
    require(address(0) != address(mpStrategy2), "mpStrategy2 not set");
    require(address(0) != address(mpAccount1), "mpAccount1 not set");
    require(address(0) != address(mpAccount2), "mpAccount2 not set");

    require(bytes32(0) != pausePermissionId, "pausePermissionId not set");
    require(bytes32(0) != failPermissionId, "failPermissionId not set");
    require(bytes32(0) != receiveEthPermissionId, "receiveEthPermissionId not set");
  }

  function defaultAdminRoleHolder(address who) internal view returns (RoleHolderData[] memory roleHolders) {
    roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(uint8(Roles.Admin), who, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function defaultStrategies() internal pure returns (Strategy[] memory strategies) {
    Strategy memory strategy1Config = Strategy({
      approvalPeriod: 2 days,
      queuingPeriod: 4 days,
      expirationPeriod: 8 days,
      isFixedLengthApprovalPeriod: true,
      minApprovalPct: 4000,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    Strategy memory strategy2Config = Strategy({
      approvalPeriod: 2 days,
      queuingPeriod: 0,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 8000,
      minDisapprovalPct: 10_001,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: Solarray.uint8s(uint8(Roles.Admin)),
      forceDisapprovalRoles: Solarray.uint8s(uint8(Roles.Admin))
    });

    strategies = new Strategy[](2);
    strategies[0] = strategy1Config;
    strategies[1] = strategy2Config;
  }
}
