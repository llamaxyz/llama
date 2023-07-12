// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {MockProtocol} from "test/mock/MockProtocol.sol";
import {MockScript} from "test/mock/MockScript.sol";

import {DeployLlama} from "script/DeployLlama.s.sol";
import {CreateAction} from "script/CreateAction.s.sol";
import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {Action, ActionInfo, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {LlamaAbsolutePeerReview} from "src/strategies/LlamaAbsolutePeerReview.sol";
import {LlamaAbsoluteQuorum} from "src/strategies/LlamaAbsoluteQuorum.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/LlamaAbsoluteStrategyBase.sol";
import {LlamaRelativeQuorum} from "src/strategies/LlamaRelativeQuorum.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
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

contract LlamaTestSetup is DeployLlama, CreateAction, Test {
  using stdJson for string;

  // The actual length of the Roles enum is type(Roles).max *plus* 1 because
  // enums are zero-indexed. However, because we don't actually initialize the
  // "AllHolders" role listed in the enum, this ends up being the correct number
  // of roles.
  uint8 public constant NUM_INIT_ROLES = uint8(type(Roles).max);

  uint8 public constant BOOTSTRAP_ROLE = 1;

  // This is the address that we're using with the CreateAction script to
  // automate action creation to deploy new llamaCore instances. It could be
  // replaced with any address that we hold the private key for.
  address LLAMA_INSTANCE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;

  // Root Llama instance.
  LlamaCore rootCore;
  LlamaExecutor rootExecutor;
  LlamaPolicy rootPolicy;
  ILlamaStrategy rootStrategy1;
  ILlamaStrategy rootStrategy2;
  ILlamaAccount rootAccount1;
  ILlamaAccount rootAccount2;

  // Mock protocol's (mp) llama instance.
  LlamaCore mpCore;
  LlamaExecutor mpExecutor;
  LlamaPolicy mpPolicy;
  ILlamaStrategy mpStrategy1;
  ILlamaStrategy mpStrategy2;
  ILlamaAccount mpAccount1;
  ILlamaAccount mpAccount2;

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
  bytes4 public constant EXECUTE_ACTION_SELECTOR = LlamaCore.executeAction.selector;
  bytes4 public constant AUTHORIZE_SCRIPT_SELECTOR = LlamaCore.setScriptAuthorization.selector;
  bytes4 public constant CREATE_STRATEGY_SELECTOR = 0x0f47de5a; // createStrategies(address,bytes[])
  bytes4 public constant CREATE_ACCOUNT_SELECTOR = 0x90010bb0; // createAccounts(address,bytes[])
  bytes4 public constant EXECUTE_SCRIPT_SELECTOR = 0x2eec6087; // executeScript()
  bytes4 public constant EXECUTE_SCRIPT_WITH_VALUE_SELECTOR = 0xcf62157f; // executeScriptWithValue()

  // Permission IDs for those selectors.
  bytes32 pausePermissionId;
  bytes32 failPermissionId;
  bytes32 receiveEthPermissionId;
  bytes32 executeActionId;
  bytes32 setScriptAuthorizationId;
  bytes32 createStrategyId;
  bytes32 createAccountId;
  bytes32 pausePermissionId2;
  bytes32 executeScriptPermissionId;
  bytes32 executeScriptWithValuePermissionId;

  // Other addresses and constants.
  address payable randomLogicAddress = payable(makeAddr("randomLogicAddress"));
  uint128 DEFAULT_ROLE_QTY = 1;
  uint128 EMPTY_ROLE_QTY = 0;
  uint64 DEFAULT_ROLE_EXPIRATION = type(uint64).max;

  string deployScriptInput;
  string createActionScriptInput;

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

    // We use input from the deploy scripts to bootstrap our test suite.
    deployScriptInput = DeployUtils.readScriptInput("deployLlama.json");
    createActionScriptInput = DeployUtils.readScriptInput("createAction.json");

    DeployLlama.run();

    rootCore = factory.ROOT_LLAMA_CORE();
    rootExecutor = factory.ROOT_LLAMA_EXECUTOR();
    rootPolicy = rootCore.policy();

    // Now we deploy a mock protocol's llama, again with a single action creator role.
    bytes[] memory mpAccounts = accountConfigsLlamaInstance();
    bytes[] memory rootStrategyConfigs = strategyConfigsRootLlama();
    bytes[] memory instanceStrategyConfigs = strategyConfigsLlamaInstance();
    bytes[] memory rootAccounts = accountConfigsRootLlama();

    // First we create an action to deploy a new llamaCore instance.
    CreateAction.run(LLAMA_INSTANCE_DEPLOYER);

    // Advance the clock so that checkpoints take effect.
    vm.roll(block.number + 1);
    vm.warp(block.timestamp + 1);

    // Second, we approve the action.
    vm.prank(LLAMA_INSTANCE_DEPLOYER); // This EOA has force-approval permissions.
    ActionInfo memory deployActionInfo = ActionInfo(
      deployActionId,
      LLAMA_INSTANCE_DEPLOYER, // creator
      uint8(Roles.ActionCreator), // role
      ILlamaStrategy(createActionScriptInput.readAddress(".rootLlamaActionCreationStrategy")),
      address(factory), // target
      0, // value
      createActionCallData
    );
    rootCore.castApproval(uint8(Roles.ActionCreator), deployActionInfo, "");
    rootCore.queueAction(deployActionInfo);

    // Advance the clock to execute the action.
    vm.roll(block.number + 1);
    Action memory action = rootCore.getAction(deployActionId);
    vm.warp(action.minExecutionTime + 1);

    // Execute the action and get a reference to the deployed LlamaCore.
    vm.recordLogs();
    rootCore.executeAction(deployActionInfo);
    Vm.Log[] memory emittedEvents = vm.getRecordedLogs();
    Vm.Log memory _event;
    bytes32 llamaInstanceCreatedSig = keccak256("LlamaInstanceCreated(uint256,string,address,address,address,uint256)");
    for (uint256 i = 0; i < emittedEvents.length; i++) {
      _event = emittedEvents[i];
      if (_event.topics[0] == llamaInstanceCreatedSig) {
        // event LlamaInstanceCreated(
        //   uint256 indexed id,
        //   string indexed name,
        //   address llamaCore,       <--- What we want.
        //   address llamaExecutor,
        //   address llamaPolicy,
        //   uint256 chainId
        // )
        (mpCore,,,) = abi.decode(_event.data, (LlamaCore, LlamaExecutor, address, uint256));
      }
    }
    mpPolicy = mpCore.policy();
    mpExecutor = mpCore.executor();

    // Set llama account addresses.
    rootAccount1 = lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[0], address(rootCore));
    rootAccount2 = lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[1], address(rootCore));
    mpAccount1 = lens.computeLlamaAccountAddress(address(accountLogic), mpAccounts[0], address(mpCore));
    mpAccount2 = lens.computeLlamaAccountAddress(address(accountLogic), mpAccounts[1], address(mpCore));

    // Add approvers and disapprovers to the mock protocol's llama.
    vm.startPrank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.ActionCreator), actionCreatorAaron, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Approver), approverAdam, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Approver), approverAlicia, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Approver), approverAndy, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Disapprover), disapproverDave, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Disapprover), disapproverDiane, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    mpPolicy.setRoleHolder(uint8(Roles.Disapprover), disapproverDrake, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.stopPrank();

    // With the mock protocol's llama instance deployed, we deploy the mock protocol.
    mockProtocol = new MockProtocol(address(mpExecutor));

    // Deploy the mock script
    mockScript = new MockScript();

    // Set strategy and account addresses.
    rootStrategy1 =
      lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), rootStrategyConfigs[1], address(rootCore));
    rootStrategy2 =
      lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), rootStrategyConfigs[2], address(rootCore));
    mpStrategy1 =
      lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), instanceStrategyConfigs[1], address(mpCore));
    mpStrategy2 =
      lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), instanceStrategyConfigs[2], address(mpCore));

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
    setScriptAuthorizationId = keccak256(abi.encode(address(mpCore), AUTHORIZE_SCRIPT_SELECTOR, mpStrategy1));
    createStrategyId = keccak256(abi.encode(address(mpCore), CREATE_STRATEGY_SELECTOR, mpStrategy1));
    createAccountId = keccak256(abi.encode(address(mpCore), CREATE_ACCOUNT_SELECTOR, mpStrategy1));
    pausePermissionId2 = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, mpStrategy2));
    executeScriptPermissionId = keccak256(abi.encode(address(mockScript), EXECUTE_SCRIPT_SELECTOR, mpStrategy1));
    executeScriptWithValuePermissionId =
      keccak256(abi.encode(address(mockScript), EXECUTE_SCRIPT_WITH_VALUE_SELECTOR, mpStrategy1));

    vm.startPrank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), pausePermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), failPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), receiveEthPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), setScriptAuthorizationId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), executeScriptPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), executeScriptWithValuePermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), executeActionId, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), createStrategyId, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), createAccountId, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), pausePermissionId2, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), executeScriptPermissionId, true);
    mpPolicy.setRolePermission(uint8(Roles.TestRole2), executeScriptWithValuePermissionId, true);
    vm.stopPrank();

    // Skip forward 1 second so the most recent checkpoints are in the past.
    vm.warp(block.timestamp + 1);

    // Verify that all storage variables were initialized. Standard assertions are in `setUp` are
    // not well supported by the Forge test runner, so we use require statements instead.
    require(address(0) != address(coreLogic), "coreLogic not set");
    require(address(0) != address(relativeQuorumLogic), "relativeQuorumLogic not set");
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
    require(address(0) != address(mpExecutor), "mpExecutor not set");
    require(address(0) != address(mpPolicy), "mpPolicy not set");
    require(address(0) != address(mpStrategy1), "mpStrategy1 not set");
    require(address(0) != address(mpStrategy2), "mpStrategy2 not set");
    require(address(0) != address(mpAccount1), "mpAccount1 not set");
    require(address(0) != address(mpAccount2), "mpAccount2 not set");

    require(bytes32(0) != pausePermissionId, "pausePermissionId not set");
    require(bytes32(0) != failPermissionId, "failPermissionId not set");
    require(bytes32(0) != receiveEthPermissionId, "receiveEthPermissionId not set");
    require(bytes32(0) != executeActionId, "executeActionId not set");
    require(bytes32(0) != setScriptAuthorizationId, "setScriptAuthorizationId not set");
    require(bytes32(0) != createStrategyId, "createStrategyId not set");
    require(bytes32(0) != createAccountId, "createAccountId not set");
    require(bytes32(0) != executeScriptPermissionId, "executeScriptPermissionId not set");
    require(bytes32(0) != executeScriptWithValuePermissionId, "executeScriptWithValuePermissionId not set");

    require(BOOTSTRAP_ROLE == uint8(Roles.ActionCreator), "test suite bootstrap config mismatch");
  }

  function defaultActionCreatorRoleHolder(address who) internal view returns (RoleHolderData[] memory roleHolders) {
    roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(uint8(Roles.ActionCreator), who, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
  }

  function strategyConfigsRootLlama() internal view returns (bytes[] memory) {
    return DeployUtils.readRelativeStrategies(deployScriptInput);
  }

  function strategyConfigsLlamaInstance() internal view returns (bytes[] memory) {
    return DeployUtils.readRelativeStrategies(createActionScriptInput);
  }

  function accountConfigsRootLlama() internal view returns (bytes[] memory) {
    return DeployUtils.readAccounts(deployScriptInput);
  }

  function accountConfigsLlamaInstance() internal view returns (bytes[] memory) {
    return DeployUtils.readAccounts(createActionScriptInput);
  }

  function rootLlamaRoleDescriptions() internal returns (RoleDescription[] memory) {
    return DeployUtils.readRoleDescriptions(deployScriptInput);
  }

  function toILlamaStrategy(LlamaRelativeQuorum.Config[] memory strategies)
    internal
    pure
    returns (ILlamaStrategy[] memory converted)
  {
    assembly {
      converted := strategies
    }
  }

  function toILlamaStrategy(LlamaRelativeQuorum.Config memory strategy)
    internal
    pure
    returns (ILlamaStrategy[] memory converted)
  {
    assembly {
      converted := strategy
    }
  }

  function toRelativeQuorum(ILlamaStrategy strategy) internal pure returns (LlamaRelativeQuorum converted) {
    assembly {
      converted := strategy
    }
  }

  function toAbsolutePeerReview(ILlamaStrategy strategy) internal pure returns (LlamaAbsolutePeerReview converted) {
    assembly {
      converted := strategy
    }
  }

  function toAbsoluteQuorum(ILlamaStrategy strategy) internal pure returns (LlamaAbsoluteQuorum converted) {
    assembly {
      converted := strategy
    }
  }

  function toAbsoluteStrategyBase(ILlamaStrategy strategy) internal pure returns (LlamaAbsoluteStrategyBase converted) {
    assembly {
      converted := strategy
    }
  }

  function infoHash(ActionInfo memory actionInfo) internal pure returns (bytes32) {
    return infoHash(
      actionInfo.id, actionInfo.creator, actionInfo.strategy, actionInfo.target, actionInfo.value, actionInfo.data
    );
  }

  function infoHash(
    uint256 id,
    address creator,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes memory data
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(id, creator, strategy, target, value, data));
  }

  function toUint128(uint256 n) internal pure returns (uint128) {
    require(n <= type(uint128).max, string.concat("Value cannot fit in a uint128: ", vm.toString(n)));
    return uint128(n);
  }

  function toUint64(uint256 n) internal pure returns (uint64) {
    require(n <= type(uint64).max, string.concat("Value cannot fit in a uint64: ", vm.toString(n)));
    return uint64(n);
  }

  function toUint16(uint256 n) internal pure returns (uint16) {
    require(n <= type(uint16).max, string.concat("Value cannot fit in a uint16: ", vm.toString(n)));
    return uint16(n);
  }

  function deployAbsolutePeerReview(
    uint8 _approvalRole,
    uint8 _disapprovalRole,
    uint64 _queuingDuration,
    uint64 _expirationDelay,
    uint64 _approvalPeriod,
    bool _isFixedLengthApprovalPeriod,
    uint128 _minApprovals,
    uint128 _minDisapprovals,
    uint8[] memory _forceApprovalRoles,
    uint8[] memory _forceDisapprovalRoles
  ) internal returns (ILlamaStrategy newStrategy) {
    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: _approvalPeriod,
      queuingPeriod: _queuingDuration,
      expirationPeriod: _expirationDelay,
      isFixedLengthApprovalPeriod: _isFixedLengthApprovalPeriod,
      minApprovals: _minApprovals,
      minDisapprovals: _minDisapprovals,
      approvalRole: _approvalRole,
      disapprovalRole: _disapprovalRole,
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    mpCore.setStrategyLogicAuthorization(absolutePeerReviewLogic, true);

    vm.prank(address(mpExecutor));

    mpCore.createStrategies(absolutePeerReviewLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

    newStrategy = lens.computeLlamaStrategyAddress(
      address(absolutePeerReviewLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
    );
  }

  function deployAbsoluteQuorum(
    uint8 _approvalRole,
    uint8 _disapprovalRole,
    uint64 _queuingDuration,
    uint64 _expirationDelay,
    uint64 _approvalPeriod,
    bool _isFixedLengthApprovalPeriod,
    uint128 _minApprovals,
    uint128 _minDisapprovals,
    uint8[] memory _forceApprovalRoles,
    uint8[] memory _forceDisapprovalRoles
  ) internal returns (ILlamaStrategy newStrategy) {
    LlamaAbsoluteQuorum absoluteQuorumLogic = new LlamaAbsoluteQuorum();

    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: _approvalPeriod,
      queuingPeriod: _queuingDuration,
      expirationPeriod: _expirationDelay,
      isFixedLengthApprovalPeriod: _isFixedLengthApprovalPeriod,
      minApprovals: _minApprovals,
      minDisapprovals: _minDisapprovals,
      approvalRole: _approvalRole,
      disapprovalRole: _disapprovalRole,
      forceApprovalRoles: _forceApprovalRoles,
      forceDisapprovalRoles: _forceDisapprovalRoles
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(mpExecutor));

    mpCore.setStrategyLogicAuthorization(absoluteQuorumLogic, true);

    vm.prank(address(mpExecutor));

    mpCore.createStrategies(absoluteQuorumLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

    newStrategy = lens.computeLlamaStrategyAddress(
      address(absoluteQuorumLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
    );
  }

  function maxRole(uint8 role, uint8[] memory forceApprovalRoles, uint8[] memory forceDisapprovalRoles)
    internal
    pure
    returns (uint8 largest)
  {
    largest = role;
    for (uint256 i = 0; i < forceApprovalRoles.length; i++) {
      if (forceApprovalRoles[i] > largest) largest = forceApprovalRoles[i];
    }
    for (uint256 i = 0; i < forceDisapprovalRoles.length; i++) {
      if (forceDisapprovalRoles[i] > largest) largest = forceDisapprovalRoles[i];
    }
  }

  function initializeRolesUpTo(uint8 role) internal {
    while (mpPolicy.numRoles() < role) {
      vm.prank(address(mpExecutor));
      mpPolicy.initializeRole(RoleDescription.wrap("Test Role"));
    }
  }

  function createAction(ILlamaStrategy testStrategy) internal returns (ActionInfo memory actionInfo) {
    // Give the action creator the ability to use this strategy.
    bytes32 newPermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, testStrategy));
    vm.prank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), newPermissionId, true);

    // Create the action.
    bytes memory data = abi.encodeCall(MockProtocol.pause, (true));
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), testStrategy, address(mockProtocol), 0, data, "");

    actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), testStrategy, address(mockProtocol), 0, data);

    vm.warp(block.timestamp + 1);
  }

  function approveAction(uint256 numberOfApprovals, ActionInfo memory actionInfo) internal {
    for (uint256 i = 0; i < numberOfApprovals; i++) {
      address _policyholder = address(uint160(i + 100));
      vm.prank(_policyholder);
      mpCore.castApproval(uint8(Roles.TestRole1), actionInfo, "");
    }
  }

  function disapproveAction(uint256 numberOfDisapprovals, ActionInfo memory actionInfo) internal {
    for (uint256 i = 0; i < numberOfDisapprovals; i++) {
      address _policyholder = address(uint160(i + 100));
      vm.prank(_policyholder);
      mpCore.castDisapproval(uint8(Roles.TestRole1), actionInfo, "");
    }
  }

  function generateAndSetRoleHolders(uint256 numberOfHolders) internal {
    for (uint256 i = 0; i < numberOfHolders; i++) {
      address _policyHolder = address(uint160(i + 100));
      if (mpPolicy.balanceOf(_policyHolder) == 0) {
        vm.prank(address(mpExecutor));
        mpPolicy.setRoleHolder(uint8(Roles.TestRole1), _policyHolder, 1, type(uint64).max);
      }
    }
  }
}
