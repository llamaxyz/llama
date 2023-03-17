// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
import {Action, Strategy, PermissionData, SetRoleHolder, SetRolePermission} from "src/lib/Structs.sol";

// Namespacing roles used for testing for readability, so they can be accessed with e.g. `Roles.Admin`.
library Roles {
  bytes32 public constant Admin = "admin";
  bytes32 public constant ActionCreator = "action creator";
  bytes32 public constant Approver = "approver";
  bytes32 public constant Disapprover = "disapprover";
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

  // Mock protocol roles.
  address adminAlice = makeAddr("adminAlice");

  // Constants.
  uint256 SELF_TOKEN_ID = uint256(uint160(address(this)));

  // Function selectors used in tests.
  bytes4 public constant PAUSE_SELECTOR = 0x02329a29; // pause(bool)
  bytes4 public constant FAIL_SELECTOR = 0xa9cc4718; // fail()
  bytes4 public constant RECEIVE_ETH_SELECTOR = 0x4185f8eb; // receiveEth()

  // Permission IDs for those selectors.
  // bytes32 pausePermissionId;
  // bytes32 failPermissionId;
  // bytes32 receiveEthPermissionId;

  address randomLogicAddress = makeAddr("randomLogicAddress");

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
    string[] memory rootAccounts = Solarray.strings("Llama Treasury", "Llama Grants");
    SetRoleHolder[] memory rootRoleHolders = defaultAdminRoleHolder(rootVertexAdmin);

    factory = new VertexFactory(
      coreLogic,
      address(strategyLogic),
      address(accountLogic),
      policyLogic,
      "Root Vertex",
      strategies,
      rootAccounts,
      rootRoleHolders,
      new SetRolePermission[](0)
    );
    rootCore = factory.rootVertex();
    rootPolicy = rootCore.policy();

    // Now we deploy a mock protocol's vertex, again with a single admin role.
    string[] memory mpAccounts = Solarray.strings("MP Treasury", "MP Grants");
    SetRoleHolder[] memory mpRoleHolders = defaultAdminRoleHolder(adminAlice);

    factory = new VertexFactory(
      coreLogic,
      address(strategyLogic),
      address(accountLogic),
      policyLogic,
      "Mock Protocol Vertex",
      strategies,
      mpAccounts,
      mpRoleHolders,
      new SetRolePermission[](0)
    );
    mpCore = factory.rootVertex();
    mpPolicy = rootCore.policy();

    // With the mock protocol's vertex instance deployed, we deploy the mock protocol.
    mockProtocol = new ProtocolXYZ(address(mpCore));

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

    // require(bytes32(0) != pausePermissionId, "pausePermissionId not set");
    // require(bytes32(0) != failPermissionId, "failPermissionId not set");
    // require(bytes32(0) != receiveEthPermissionId, "receiveEthPermissionId not set");
  }

  function defaultAdminRoleHolder(address who) internal pure returns (SetRoleHolder[] memory roleHolders) {
    roleHolders = new SetRoleHolder[](1);
    roleHolders[0] = SetRoleHolder(Roles.Admin, who, type(uint64).max);
  }

  function defaultStrategies() internal pure returns (Strategy[] memory strategies) {
    Strategy memory strategy1Config = Strategy({
      approvalPeriod: 2 days,
      queuingPeriod: 4 days,
      expirationPeriod: 8 days,
      isFixedLengthApprovalPeriod: true,
      minApprovalPct: 4000,
      minDisapprovalPct: 2000,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });

    Strategy memory strategy2Config = Strategy({
      approvalPeriod: 2 days,
      queuingPeriod: 0,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 8000,
      minDisapprovalPct: 10_001,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: Solarray.bytes32s("admin"),
      forceDisapprovalRoles: Solarray.bytes32s("admin")
    });

    strategies = new Strategy[](2);
    strategies[0] = strategy1Config;
    strategies[1] = strategy2Config;
  }
}
