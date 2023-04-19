// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {stdJson} from "forge-std/Script.sol";
import {Solarray} from "@solarray/Solarray.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";
import {MockScript} from "test/mock/MockScript.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {Action, RelativeStrategyConfig, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployVertexProtocol} from "script/DeployVertexProtocol.s.sol";
import {SolarrayVertex} from "test/utils/SolarrayVertex.sol";

// Used for readability of tests, so they can be accessed with e.g. `uint8(Roles.ActionCreator)`.
enum Roles {
  AllHolders,
  ActionCreator,
  Approver,
  Disapprover,
  ForceApprover,
  ForceDisapprover,
  TestRole1,
  TestRole2,
  MadeUpRole
}

contract VertexTestSetup is DeployVertexProtocol, Test {
  using stdJson for string;

  // The actual length of the Roles enum is type(Roles).max *plus* 1 because
  // enums are zero-indexed. However, because we don't actually initialize the
  // "AllHolders" role listed in the enum, this ends up being the correct number
  // of roles.
  uint8 public constant NUM_INIT_ROLES = uint8(type(Roles).max);

  // Root Vertex instance.
  VertexCore rootCore;
  VertexPolicy rootPolicy;
  IVertexStrategy rootStrategy1;
  IVertexStrategy rootStrategy2;
  VertexAccount rootAccount1;
  VertexAccount rootAccount2;

  // Mock protocol's (mp) vertex instance.
  VertexCore mpCore;
  VertexPolicy mpPolicy;
  IVertexStrategy mpStrategy1;
  IVertexStrategy mpStrategy2;
  VertexAccount mpAccount1;
  VertexAccount mpAccount2;

  // Mock protocol for action targets.
  MockProtocol public mockProtocol;

  // Mock script for action targets.
  MockScript public mockScript;

  // Root vertex action creator.
  address rootVertexActionCreator;
  uint256 rootVertexActionCreatorPrivateKey;

  // Mock protocol users.
  address actionCreatorAaron;
  uint256 actionCreatorAaronPrivateKey;

  address approverAdam;
  uint256 approverAdamPrivateKey;
  address approverAlicia;
  uint256 approverAliciaPrivateKey;
  address approverAndy;
  uint256 approverAndyPrivateKey;

  address disapproverDave;
  uint256 disapproverDavePrivateKey;
  address disapproverDiane;
  uint256 disapproverDianePrivateKey;
  address disapproverDrake;
  uint256 disapproverDrakePrivateKey;

  // Constants.
  uint256 SELF_TOKEN_ID = uint256(uint160(address(this)));

  // Function selectors used in tests.
  bytes4 public constant PAUSE_SELECTOR = 0x02329a29; // pause(bool)
  bytes4 public constant FAIL_SELECTOR = 0xa9cc4718; // fail()
  bytes4 public constant RECEIVE_ETH_SELECTOR = 0x4185f8eb; // receiveEth()
  bytes4 public constant EXECUTE_ACTION_SELECTOR = 0xc0c1cf55; // executeAction(uint256)
  bytes4 public constant CREATE_STRATEGY_SELECTOR = 0xbd112734; // createAndAuthorizeStrategies(address,bytes[])
  bytes4 public constant CREATE_ACCOUNT_SELECTOR = 0x9c8b12f1; // createAccounts(string[])
  bytes4 public constant EXECUTE_SCRIPT_SELECTOR = 0x2eec6087; // executeScript()

  // Permission IDs for those selectors.
  bytes32 pausePermissionId;
  bytes32 failPermissionId;
  bytes32 receiveEthPermissionId;
  bytes32 executeActionId;
  bytes32 createStrategyId;
  bytes32 createAccountId;
  bytes32 pausePermissionId2;
  bytes32 executeScriptPermissionId;

  // Other addresses and constants.
  address payable randomLogicAddress = payable(makeAddr("randomLogicAddress"));
  uint128 DEFAULT_ROLE_QTY = 1;
  uint128 EMPTY_ROLE_QTY = 0;
  uint64 DEFAULT_ROLE_EXPIRATION = type(uint64).max;

  string scriptInput;

  function setUp() public virtual {
    // Setting up user addresses and private keys.
    (rootVertexActionCreator, rootVertexActionCreatorPrivateKey) = makeAddrAndKey("rootVertexActionCreator");
    (actionCreatorAaron, actionCreatorAaronPrivateKey) = makeAddrAndKey("actionCreatorAaron");
    (approverAdam, approverAdamPrivateKey) = makeAddrAndKey("approverAdam");
    (approverAlicia, approverAliciaPrivateKey) = makeAddrAndKey("approverAlicia");
    (approverAndy, approverAndyPrivateKey) = makeAddrAndKey("approverAndy");
    (disapproverDave, disapproverDavePrivateKey) = makeAddrAndKey("disapproverDave");
    (disapproverDiane, disapproverDianePrivateKey) = makeAddrAndKey("disapproverDiane");
    (disapproverDrake, disapproverDrakePrivateKey) = makeAddrAndKey("disapproverDrake");

    DeployVertexProtocol.run();

    rootCore = factory.ROOT_VERTEX();
    rootPolicy = rootCore.policy();

    // We use input from the deploy script to bootstrap our test suite.
    scriptInput = readScriptInput();

    // Now we deploy a mock protocol's vertex, again with a single action creator role.
    string[] memory mpAccounts = Solarray.strings("MP Treasury", "MP Grants");
    RoleHolderData[] memory mpRoleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    RoleDescription[] memory roleDescriptionStrings = readRoleDescriptions(scriptInput);
    string[] memory rootAccounts = scriptInput.readStringArray(".initialAccountNames");

    vm.prank(address(rootCore));
    mpCore = factory.deploy(
      "Mock Protocol Vertex",
      relativeStrategyLogic,
      strategyConfigs,
      mpAccounts,
      roleDescriptionStrings,
      mpRoleHolders,
      new RolePermissionData[](0)
    );
    mpPolicy = mpCore.policy();

    // Set strategy addresses.
    rootStrategy1 =
      lens.computeVertexStrategyAddress(address(relativeStrategyLogic), strategyConfigs[0], address(rootCore));
    rootStrategy2 =
      lens.computeVertexStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(rootCore));
    mpStrategy1 = lens.computeVertexStrategyAddress(address(relativeStrategyLogic), strategyConfigs[0], address(mpCore));
    mpStrategy2 = lens.computeVertexStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(mpCore));

    // Set vertex account addresses.
    rootAccount1 = lens.computeVertexAccountAddress(address(accountLogic), rootAccounts[0], address(rootCore));
    rootAccount2 = lens.computeVertexAccountAddress(address(accountLogic), rootAccounts[1], address(rootCore));
    mpAccount1 = lens.computeVertexAccountAddress(address(accountLogic), mpAccounts[0], address(mpCore));
    mpAccount2 = lens.computeVertexAccountAddress(address(accountLogic), mpAccounts[1], address(mpCore));

    // Add approvers and disapprovers to the mock protocol's vertex.
    // forgefmt: disable-start
    bytes[] memory roleAssignmentCalls = new bytes[](7);
    roleAssignmentCalls[0] = abi.encodeCall(VertexPolicy.setRoleHolder, (uint8(Roles.ActionCreator), actionCreatorAaron, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION));
    roleAssignmentCalls[1] = abi.encodeCall(VertexPolicy.setRoleHolder, (uint8(Roles.Approver), approverAdam, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION));
    roleAssignmentCalls[2] = abi.encodeCall(VertexPolicy.setRoleHolder, (uint8(Roles.Approver), approverAlicia, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION));
    roleAssignmentCalls[3] = abi.encodeCall(VertexPolicy.setRoleHolder, (uint8(Roles.Approver), approverAndy, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION));
    roleAssignmentCalls[4] = abi.encodeCall(VertexPolicy.setRoleHolder, (uint8(Roles.Disapprover), disapproverDave, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION));
    roleAssignmentCalls[5] = abi.encodeCall(VertexPolicy.setRoleHolder, (uint8(Roles.Disapprover), disapproverDiane, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION));
    roleAssignmentCalls[6] = abi.encodeCall(VertexPolicy.setRoleHolder, (uint8(Roles.Disapprover), disapproverDrake, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION));
    // forgefmt: disable-end

    vm.prank(address(mpCore));
    mpPolicy.aggregate(roleAssignmentCalls);

    // With the mock protocol's vertex instance deployed, we deploy the mock protocol.
    mockProtocol = new MockProtocol(address(mpCore));

    // Deploy the mock script
    mockScript = new MockScript();

    // Set strategy and account addresses.
    rootStrategy1 =
      lens.computeVertexStrategyAddress(address(relativeStrategyLogic), strategyConfigs[0], address(rootCore));
    rootStrategy2 =
      lens.computeVertexStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(rootCore));
    mpStrategy1 = lens.computeVertexStrategyAddress(address(relativeStrategyLogic), strategyConfigs[0], address(mpCore));
    mpStrategy2 = lens.computeVertexStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(mpCore));

    // Set vertex account addresses.
    rootAccount1 = lens.computeVertexAccountAddress(address(accountLogic), rootAccounts[0], address(rootCore));
    rootAccount2 = lens.computeVertexAccountAddress(address(accountLogic), rootAccounts[1], address(rootCore));
    mpAccount1 = lens.computeVertexAccountAddress(address(accountLogic), mpAccounts[0], address(mpCore));
    mpAccount2 = lens.computeVertexAccountAddress(address(accountLogic), mpAccounts[1], address(mpCore));

    // With the protocol deployed, we can set special permissions.
    pausePermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, mpStrategy1));
    failPermissionId = keccak256(abi.encode(address(mockProtocol), FAIL_SELECTOR, mpStrategy1));
    receiveEthPermissionId = keccak256(abi.encode(address(mockProtocol), RECEIVE_ETH_SELECTOR, mpStrategy1));
    executeActionId = keccak256(abi.encode(address(mpCore), EXECUTE_ACTION_SELECTOR, mpStrategy1));
    createStrategyId = keccak256(abi.encode(address(mpCore), CREATE_STRATEGY_SELECTOR, mpStrategy1));
    createAccountId = keccak256(abi.encode(address(mpCore), CREATE_ACCOUNT_SELECTOR, mpStrategy1));
    pausePermissionId2 = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, mpStrategy2));
    executeScriptPermissionId = keccak256(abi.encode(address(mockScript), EXECUTE_SCRIPT_SELECTOR, mpStrategy1));

    bytes[] memory permissionsToSet = new bytes[](8);
    permissionsToSet[0] =
      abi.encodeCall(VertexPolicy.setRolePermission, (uint8(Roles.ActionCreator), pausePermissionId, true));
    permissionsToSet[1] =
      abi.encodeCall(VertexPolicy.setRolePermission, (uint8(Roles.ActionCreator), failPermissionId, true));
    permissionsToSet[2] =
      abi.encodeCall(VertexPolicy.setRolePermission, (uint8(Roles.ActionCreator), receiveEthPermissionId, true));
    permissionsToSet[3] =
      abi.encodeCall(VertexPolicy.setRolePermission, (uint8(Roles.TestRole2), executeActionId, true));
    permissionsToSet[4] =
      abi.encodeCall(VertexPolicy.setRolePermission, (uint8(Roles.TestRole2), createStrategyId, true));
    permissionsToSet[5] =
      abi.encodeCall(VertexPolicy.setRolePermission, (uint8(Roles.TestRole2), createAccountId, true));
    permissionsToSet[6] =
      abi.encodeCall(VertexPolicy.setRolePermission, (uint8(Roles.TestRole2), pausePermissionId2, true));
    permissionsToSet[7] =
      abi.encodeCall(VertexPolicy.setRolePermission, (uint8(Roles.TestRole2), executeScriptPermissionId, true));

    vm.prank(address(mpCore));
    mpPolicy.aggregate(permissionsToSet);

    // Skip forward 1 second so the most recent checkpoints are in the past.
    vm.warp(block.timestamp + 1);

    // Verify that all storage variables were initialized. Standard assertions are in `setUp` are
    // not well supported by the Forge test runner, so we use require statements instead.
    require(address(0) != address(coreLogic), "coreLogic not set");
    require(address(0) != address(relativeStrategyLogic), "relativeStrategyLogic not set");
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
    require(bytes32(0) != executeActionId, "executeActionId not set");
    require(bytes32(0) != createStrategyId, "createStrategyId not set");
    require(bytes32(0) != createAccountId, "createAccountId not set");
    require(bytes32(0) != executeScriptPermissionId, "executeScriptPermissionId not set");
  }

  function defaultActionCreatorRoleHolder(address who) internal view returns (RoleHolderData[] memory roleHolders) {
    roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(uint8(Roles.ActionCreator), who, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function relativeStrategyConfigs() internal view returns (bytes[] memory strategyConfigs) {
    strategyConfigs = encodeStrategyConfigs(readStrategies(scriptInput));
  }

  function toIVertexStrategy(RelativeStrategyConfig[] memory strategies)
    internal
    pure
    returns (IVertexStrategy[] memory converted)
  {
    assembly {
      converted := strategies
    }
  }

  function toIVertexStrategy(RelativeStrategyConfig memory strategy)
    internal
    pure
    returns (IVertexStrategy[] memory converted)
  {
    assembly {
      converted := strategy
    }
  }
}
