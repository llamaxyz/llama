// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {stdJson} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {Solarray} from "@solarray/Solarray.sol";

import {MockProtocol} from "test/mock/MockProtocol.sol";
import {MockScript} from "test/mock/MockScript.sol";

import {DeployLlama} from "script/DeployLlama.s.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {Action, RelativeStrategyConfig, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

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

contract LlamaTestSetup is DeployLlama, Test {
  using stdJson for string;

  // The actual length of the Roles enum is type(Roles).max *plus* 1 because
  // enums are zero-indexed. However, because we don't actually initialize the
  // "AllHolders" role listed in the enum, this ends up being the correct number
  // of roles.
  uint8 public constant NUM_INIT_ROLES = uint8(type(Roles).max);

  // Root Llama instance.
  LlamaCore rootCore;
  LlamaPolicy rootPolicy;
  ILlamaStrategy rootStrategy1;
  ILlamaStrategy rootStrategy2;
  LlamaAccount rootAccount1;
  LlamaAccount rootAccount2;

  // Mock protocol's (mp) llama instance.
  LlamaCore mpCore;
  LlamaPolicy mpPolicy;
  ILlamaStrategy mpStrategy1;
  ILlamaStrategy mpStrategy2;
  LlamaAccount mpAccount1;
  LlamaAccount mpAccount2;

  // Mock protocol for action targets.
  MockProtocol public mockProtocol;

  // Mock script for action targets.
  MockScript public mockScript;

  // Root llama action creator.
  address rootLlamaActionCreator;
  uint256 rootLlamaActionCreatorPrivateKey;

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
    (rootLlamaActionCreator, rootLlamaActionCreatorPrivateKey) = makeAddrAndKey("rootLlamaActionCreator");
    (actionCreatorAaron, actionCreatorAaronPrivateKey) = makeAddrAndKey("actionCreatorAaron");
    (approverAdam, approverAdamPrivateKey) = makeAddrAndKey("approverAdam");
    (approverAlicia, approverAliciaPrivateKey) = makeAddrAndKey("approverAlicia");
    (approverAndy, approverAndyPrivateKey) = makeAddrAndKey("approverAndy");
    (disapproverDave, disapproverDavePrivateKey) = makeAddrAndKey("disapproverDave");
    (disapproverDiane, disapproverDianePrivateKey) = makeAddrAndKey("disapproverDiane");
    (disapproverDrake, disapproverDrakePrivateKey) = makeAddrAndKey("disapproverDrake");

    DeployLlama.run();

    rootCore = factory.ROOT_LLAMA();
    rootPolicy = rootCore.policy();

    // We use input from the deploy script to bootstrap our test suite.
    scriptInput = readScriptInput();

    // Now we deploy a mock protocol's llama, again with a single action creator role.
    string[] memory mpAccounts = Solarray.strings("MP Treasury", "MP Grants");
    RoleHolderData[] memory mpRoleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    RoleDescription[] memory roleDescriptionStrings = readRoleDescriptions(scriptInput);
    string[] memory rootAccounts = scriptInput.readStringArray(".initialAccountNames");

    vm.prank(address(rootCore));
    mpCore = factory.deploy(
      "Mock Protocol Llama",
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
      lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[0], address(rootCore));
    rootStrategy2 =
      lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(rootCore));
    mpStrategy1 = lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[0], address(mpCore));
    mpStrategy2 = lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(mpCore));

    // Set llama account addresses.
    rootAccount1 = lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[0], address(rootCore));
    rootAccount2 = lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[1], address(rootCore));
    mpAccount1 = lens.computeLlamaAccountAddress(address(accountLogic), mpAccounts[0], address(mpCore));
    mpAccount2 = lens.computeLlamaAccountAddress(address(accountLogic), mpAccounts[1], address(mpCore));

    // Add approvers and disapprovers to the mock protocol's llama.
    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.ActionCreator), actionCreatorAaron, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Approver), approverAdam, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Approver), approverAlicia, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Approver), approverAndy, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Disapprover), disapproverDave, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Disapprover), disapproverDiane, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Disapprover), disapproverDrake, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.stopPrank();

    // With the mock protocol's llama instance deployed, we deploy the mock protocol.
    mockProtocol = new MockProtocol(address(mpCore));

    // Deploy the mock script
    mockScript = new MockScript();

    // Set strategy and account addresses.
    rootStrategy1 =
      lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[0], address(rootCore));
    rootStrategy2 =
      lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(rootCore));
    mpStrategy1 = lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[0], address(mpCore));
    mpStrategy2 = lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(mpCore));

    // Set llama account addresses.
    rootAccount1 = lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[0], address(rootCore));
    rootAccount2 = lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[1], address(rootCore));
    mpAccount1 = lens.computeLlamaAccountAddress(address(accountLogic), mpAccounts[0], address(mpCore));
    mpAccount2 = lens.computeLlamaAccountAddress(address(accountLogic), mpAccounts[1], address(mpCore));

    // With the protocol deployed, we can set special permissions.
    pausePermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, mpStrategy1));
    failPermissionId = keccak256(abi.encode(address(mockProtocol), FAIL_SELECTOR, mpStrategy1));
    receiveEthPermissionId = keccak256(abi.encode(address(mockProtocol), RECEIVE_ETH_SELECTOR, mpStrategy1));
    executeActionId = keccak256(abi.encode(address(mpCore), EXECUTE_ACTION_SELECTOR, mpStrategy1));
    createStrategyId = keccak256(abi.encode(address(mpCore), CREATE_STRATEGY_SELECTOR, mpStrategy1));
    createAccountId = keccak256(abi.encode(address(mpCore), CREATE_ACCOUNT_SELECTOR, mpStrategy1));
    pausePermissionId2 = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, mpStrategy2));
    executeScriptPermissionId = keccak256(abi.encode(address(mockScript), EXECUTE_SCRIPT_SELECTOR, mpStrategy1));

    vm.startPrank(address(mpCore));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), pausePermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), failPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), receiveEthPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), executeActionId, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), createStrategyId, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), createAccountId, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), pausePermissionId2, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), executeScriptPermissionId, true);
    vm.stopPrank();

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

  function toILlamaStrategy(RelativeStrategyConfig[] memory strategies)
    internal
    pure
    returns (ILlamaStrategy[] memory converted)
  {
    assembly {
      converted := strategies
    }
  }

  function toILlamaStrategy(RelativeStrategyConfig memory strategy)
    internal
    pure
    returns (ILlamaStrategy[] memory converted)
  {
    assembly {
      converted := strategy
    }
  }
}
