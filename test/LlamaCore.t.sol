// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2, StdStorage, stdStorage} from "forge-std/Test.sol";

import {Solarray} from "@solarray/Solarray.sol";

import {MockAccountLogicContract} from "test/mock/MockAccountLogicContract.sol";
import {MockActionGuard} from "test/mock/MockActionGuard.sol";
import {MockMaliciousExtension} from "test/mock/MockMaliciousExtension.sol";
import {MockPoorlyImplementedAbsolutePeerReview} from "test/mock/MockPoorlyImplementedStrategy.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";
import {SolarrayLlama} from "test/utils/SolarrayLlama.sol";
import {LlamaCoreSigUtils} from "test/utils/LlamaCoreSigUtils.sol";
import {LlamaFactoryWithoutInitialization} from "test/utils/LlamaFactoryWithoutInitialization.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaActionGuard} from "src/interfaces/ILlamaActionGuard.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, ActionInfo, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {LlamaAbsolutePeerReview} from "src/strategies/LlamaAbsolutePeerReview.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/LlamaAbsoluteStrategyBase.sol";
import {LlamaRelativeQuorum} from "src/strategies/LlamaRelativeQuorum.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaCoreTest is LlamaTestSetup, LlamaCoreSigUtils {
  event ActionCreated(
    uint256 id,
    address indexed creator,
    uint8 role,
    ILlamaStrategy indexed strategy,
    address indexed target,
    uint256 value,
    bytes data,
    string description
  );
  event ActionCanceled(uint256 id);
  event ActionQueued(
    uint256 id, address indexed caller, ILlamaStrategy indexed strategy, address indexed creator, uint256 executionTime
  );
  event ActionExecuted(
    uint256 id, address indexed caller, ILlamaStrategy indexed strategy, address indexed creator, bytes result
  );
  event ApprovalCast(uint256 id, address indexed policyholder, uint8 indexed role, uint256 quantity, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint8 indexed role, uint256 quantity, string reason);
  event StrategyCreated(ILlamaStrategy strategy, ILlamaStrategy indexed strategyLogic, bytes initializationData);
  event AccountCreated(ILlamaAccount account, ILlamaAccount indexed accountLogic, bytes initializationData);
  event ScriptAuthorized(address script, bool authorized);

  // We use this to easily generate, save off, and pass around `ActionInfo` structs.
  // mapping (uint256 actionId => ActionInfo) actionInfo;

  function setUp() public virtual override {
    LlamaTestSetup.setUp();

    // Setting Mock Protocol Core's EIP-712 Domain Hash
    setDomainHash(
      LlamaCoreSigUtils.EIP712Domain({
        name: mpCore.name(),
        version: "1",
        chainId: block.chainid,
        verifyingContract: address(mpCore)
      })
    );
  }

  // =========================
  // ======== Helpers ========
  // =========================

  function _createAction() public returns (ActionInfo memory actionInfo) {
    bytes memory data = abi.encodeCall(MockProtocol.pause, (true));
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, "");
    actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data);
    vm.warp(block.timestamp + 1);
  }

  function _approveAction(address _policyholder, ActionInfo memory actionInfo) public {
    vm.expectEmit();
    emit ApprovalCast(actionInfo.id, _policyholder, uint8(Roles.Approver), 1, "");
    vm.prank(_policyholder);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
  }

  function _disapproveAction(address _policyholder, ActionInfo memory actionInfo) public {
    vm.expectEmit();
    emit DisapprovalCast(actionInfo.id, _policyholder, uint8(Roles.Disapprover), 1, "");
    vm.prank(_policyholder);
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");
  }

  function _queueAction(ActionInfo memory actionInfo) public {
    uint256 executionTime = block.timestamp + toRelativeQuorum(mpStrategy1).queuingPeriod();
    vm.expectEmit();
    emit ActionQueued(actionInfo.id, address(this), mpStrategy1, actionCreatorAaron, executionTime);
    mpCore.queueAction(actionInfo);
  }

  function _executeAction(ActionInfo memory actionInfo) public {
    vm.expectEmit();
    emit ActionExecuted(actionInfo.id, address(this), actionInfo.strategy, actionInfo.creator, bytes(""));
    mpCore.executeAction(actionInfo);

    Action memory action = mpCore.getAction(actionInfo.id);
    assertEq(action.executed, true);
  }

  function _executeCompleteActionFlow() internal returns (ActionInfo memory actionInfo) {
    actionInfo = _createAction();

    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionInfo), true);
    _queueAction(actionInfo);

    vm.warp(block.timestamp + 5 days);

    _executeAction(actionInfo);
  }

  function _deployAndAuthorizeAdditionalStrategyLogic() internal returns (ILlamaStrategy) {
    LlamaRelativeQuorum additionalStrategyLogic = new LlamaRelativeQuorum();
    vm.prank(address(rootExecutor));
    factory.authorizeStrategyLogic(additionalStrategyLogic);
    return additionalStrategyLogic;
  }

  function _deployAndAuthorizeAdditionalAccountLogic() internal returns (ILlamaAccount) {
    LlamaAccount additionalAccountLogic = new LlamaAccount();
    vm.prank(address(rootExecutor));
    factory.authorizeAccountLogic(additionalAccountLogic);
    return additionalAccountLogic;
  }

  function _deployAndAuthorizeMockAccountLogic() internal returns (ILlamaAccount) {
    MockAccountLogicContract mockAccountLogic = new MockAccountLogicContract();
    vm.prank(address(rootExecutor));
    factory.authorizeAccountLogic(mockAccountLogic);
    return mockAccountLogic;
  }

  function _createStrategy(uint256 salt, bool isFixedLengthApprovalPeriod)
    internal
    pure
    returns (LlamaRelativeQuorum.Config memory)
  {
    return LlamaRelativeQuorum.Config({
      approvalPeriod: toUint64(salt % 1000 days),
      queuingPeriod: toUint64(salt % 1001 days),
      expirationPeriod: toUint64(salt % 1002 days),
      isFixedLengthApprovalPeriod: isFixedLengthApprovalPeriod,
      minApprovalPct: toUint16(salt % 10_000),
      minDisapprovalPct: toUint16(salt % 10_100),
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });
  }

  function deployMockPoorStrategyAndCreatePermission() internal returns (ILlamaStrategy newStrategy) {
    ILlamaStrategy mockStrategyLogic = new MockPoorlyImplementedAbsolutePeerReview();

    LlamaAbsoluteStrategyBase.Config memory strategyConfig = LlamaAbsoluteStrategyBase.Config({
      approvalPeriod: 1 days,
      queuingPeriod: 1 days,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovals: 2,
      minDisapprovals: 2,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Approver),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    LlamaAbsoluteStrategyBase.Config[] memory strategyConfigs = new LlamaAbsoluteStrategyBase.Config[](1);
    strategyConfigs[0] = strategyConfig;

    vm.prank(address(rootExecutor));

    factory.authorizeStrategyLogic(mockStrategyLogic);

    vm.prank(address(mpExecutor));

    mpCore.createStrategies(mockStrategyLogic, DeployUtils.encodeStrategyConfigs(strategyConfigs));

    newStrategy = lens.computeLlamaStrategyAddress(
      address(mockStrategyLogic), DeployUtils.encodeStrategy(strategyConfig), address(mpCore)
    );

    bytes32 newPermissionId = keccak256(abi.encode(address(mockProtocol), PAUSE_SELECTOR, newStrategy));
    vm.prank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), newPermissionId, true);
  }

  function createActionUsingAbsolutePeerReview(ILlamaStrategy testStrategy)
    internal
    returns (ActionInfo memory actionInfo)
  {
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
}

contract Setup is LlamaCoreTest {
  function test_setUp() public {
    assertEq(address(mpCore.factory()), address(factory));
    assertEq(mpCore.name(), "Mock Protocol Llama");
    assertEq(address(mpCore.policy()), address(mpPolicy));

    assertTrue(mpCore.strategies(mpStrategy1));
    assertTrue(mpCore.strategies(mpStrategy1));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount1.initialize("LlamaAccount0");

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount2.initialize("LlamaAccount1");
  }
}

contract Constructor is LlamaCoreTest {
  function test_RevertIf_InitializeImplementationContract() public {
    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    coreLogic.initialize("NewProject", mpPolicy, relativeQuorumLogic, accountLogic, new bytes[](0), new bytes[](0));
  }
}

contract Initialize is LlamaCoreTest {
  function deployWithoutInitialization()
    internal
    returns (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore llama, LlamaPolicy policy)
  {
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);
    modifiedFactory = new LlamaFactoryWithoutInitialization(
      coreLogic,
      relativeQuorumLogic,
      accountLogic,
      policyLogic,
      policyMetadata,
      "Root Llama",
      strategyConfigs,
      accounts,
      rootLlamaRoleDescriptions(),
      roleHolders,
      new RolePermissionData[](0)
    );

    (llama, policy) = modifiedFactory.deployWithoutInitialization(
      "NewProject", rootLlamaRoleDescriptions(), roleHolders, new RolePermissionData[](0)
    );
  }

  function test_StrategiesAreDeployedAtExpectedAddress() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);
    for (uint256 i = 0; i < strategyConfigs.length; i++) {
      strategyAddresses[i] =
        lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), strategyConfigs[i], address(uninitializedLlama));
    }

    assertEq(address(strategyAddresses[0]).code.length, 0);
    assertEq(address(strategyAddresses[1]).code.length, 0);

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeQuorumLogic, accountLogic, strategyConfigs, accounts
    );

    assertGt(address(strategyAddresses[0]).code.length, 0);
    assertGt(address(strategyAddresses[1]).code.length, 0);
  }

  function test_EmitsStrategyAuthorizedEventForEachStrategy() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);
    for (uint256 i = 0; i < strategyConfigs.length; i++) {
      strategyAddresses[i] =
        lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), strategyConfigs[i], address(uninitializedLlama));
    }

    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[0], relativeQuorumLogic, strategyConfigs[0]);
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[1], relativeQuorumLogic, strategyConfigs[1]);

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeQuorumLogic, accountLogic, strategyConfigs, accounts
    );
  }

  function test_StrategiesHaveLlamaCoreAddressInStorage() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);
    for (uint256 i = 0; i < strategyConfigs.length; i++) {
      strategyAddresses[i] =
        lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), strategyConfigs[i], address(uninitializedLlama));
    }

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeQuorumLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(address(strategyAddresses[0].llamaCore()), address(uninitializedLlama));
    assertEq(address(strategyAddresses[1].llamaCore()), address(uninitializedLlama));
  }

  function test_StrategiesHavePolicyAddressInStorage() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);
    for (uint256 i = 0; i < strategyConfigs.length; i++) {
      strategyAddresses[i] =
        lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), strategyConfigs[i], address(uninitializedLlama));
    }

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeQuorumLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(address(strategyAddresses[0].policy()), address(policy));
    assertEq(address(strategyAddresses[1].policy()), address(policy));
  }

  function test_StrategiesAreAuthorizedByLlamaCore() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);
    for (uint256 i = 0; i < strategyConfigs.length; i++) {
      strategyAddresses[i] =
        lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), strategyConfigs[i], address(uninitializedLlama));
    }

    assertEq(uninitializedLlama.strategies(strategyAddresses[0]), false);
    assertEq(uninitializedLlama.strategies(strategyAddresses[1]), false);

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeQuorumLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(uninitializedLlama.strategies(strategyAddresses[0]), true);
    assertEq(uninitializedLlama.strategies(strategyAddresses[1]), true);
  }

  function testFuzz_RevertIf_StrategyLogicIsNotAuthorized(address notStrategyLogic) public {
    vm.assume(notStrategyLogic != address(relativeQuorumLogic));
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();

    vm.expectRevert(LlamaCore.UnauthorizedStrategyLogic.selector);
    modifiedFactory.initialize(
      uninitializedLlama,
      policy,
      "NewProject",
      ILlamaStrategy(notStrategyLogic),
      ILlamaAccount(accountLogic),
      strategyConfigs,
      accounts
    );
  }

  function test_AccountsAreDeployedAtExpectedAddress() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    ILlamaAccount[] memory accountAddresses = new ILlamaAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeLlamaAccountAddress(address(accountLogic), accounts[i], address(uninitializedLlama));
    }

    assertEq(address(accountAddresses[0]).code.length, 0);
    assertEq(address(accountAddresses[1]).code.length, 0);

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeQuorumLogic, accountLogic, strategyConfigs, accounts
    );

    assertGt(address(accountAddresses[0]).code.length, 0);
    assertGt(address(accountAddresses[1]).code.length, 0);
  }

  function test_EmitsAccountCreatedEventForEachAccount() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    ILlamaAccount[] memory accountAddresses = new ILlamaAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeLlamaAccountAddress(address(accountLogic), accounts[i], address(uninitializedLlama));
    }

    vm.expectEmit();
    emit AccountCreated(accountAddresses[0], accountLogic, accounts[0]);
    vm.expectEmit();
    emit AccountCreated(accountAddresses[1], accountLogic, accounts[1]);
    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeQuorumLogic, accountLogic, strategyConfigs, accounts
    );
  }

  function test_AccountsHaveLlamaExecutorAddressInStorage() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    ILlamaAccount[] memory accountAddresses = new ILlamaAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeLlamaAccountAddress(address(accountLogic), accounts[i], address(uninitializedLlama));
    }

    LlamaExecutor executor = modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeQuorumLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(address(accountAddresses[0].llamaExecutor()), address(executor));
    assertEq(address(accountAddresses[1].llamaExecutor()), address(executor));
  }

  function test_AccountsHaveNameInStorage() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();
    ILlamaAccount[] memory accountAddresses = new ILlamaAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeLlamaAccountAddress(address(accountLogic), accounts[i], address(uninitializedLlama));
    }

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeQuorumLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(LlamaAccount(payable(address(accountAddresses[0]))).name(), "Llama Treasury");
    assertEq(LlamaAccount(payable(address(accountAddresses[1]))).name(), "Llama Grants");
  }

  function testFuzz_RevertIf_AccountLogicIsNotAuthorized(address notAccountLogic) public {
    vm.assume(notAccountLogic != address(accountLogic));
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    bytes[] memory accounts = accountConfigsRootLlama();

    vm.expectRevert(LlamaCore.UnauthorizedAccountLogic.selector);
    modifiedFactory.initialize(
      uninitializedLlama,
      policy,
      "NewProject",
      relativeQuorumLogic,
      ILlamaAccount(notAccountLogic),
      strategyConfigs,
      accounts
    );
  }
}

contract CreateAction is LlamaCoreTest {
  bytes data = abi.encodeCall(MockProtocol.pause, (true));

  function test_CreatesAnAction() public {
    vm.expectEmit();
    emit ActionCreated(
      0, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, ""
    );
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, "");

    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data);
    Action memory action = mpCore.getAction(actionInfo.id);
    uint256 approvalPeriodEnd = toRelativeQuorum(actionInfo.strategy).approvalEndTime(actionInfo);

    assertEq(actionInfo.id, 0);
    assertEq(mpCore.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(approvalPeriodEnd, block.timestamp + 2 days);
    assertEq(toRelativeQuorum(actionInfo.strategy).actionApprovalSupply(actionInfo.id), 3);
    assertEq(toRelativeQuorum(actionInfo.strategy).actionDisapprovalSupply(actionInfo.id), 3);
  }

  function test_CreatesAnActionWithDescription() public {
    string memory description =
      "# Transfer USDC to service provider \n This action transfers 10,000 USDC to our trusted provider.";
    vm.expectEmit();
    emit ActionCreated(
      0, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, description
    );
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, description);

    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data);
    Action memory action = mpCore.getAction(actionInfo.id);
    uint256 approvalPeriodEnd = toRelativeQuorum(actionInfo.strategy).approvalEndTime(actionInfo);

    assertEq(actionInfo.id, 0);
    assertEq(mpCore.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(approvalPeriodEnd, block.timestamp + 2 days);
    assertEq(toRelativeQuorum(actionInfo.strategy).actionApprovalSupply(actionInfo.id), 3);
    assertEq(toRelativeQuorum(actionInfo.strategy).actionDisapprovalSupply(actionInfo.id), 3);
  }

  function testFuzz_RevertIf_PolicyholderDoesNotHavePermission(address _target, uint256 _value) public {
    vm.assume(_target != address(mockProtocol) && _target != address(mpExecutor));

    bytes memory dataTrue = abi.encodeCall(MockProtocol.pause, (true));
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    vm.prank(actionCreatorAaron);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(_target), _value, dataTrue, "");
  }

  function test_RevertIf_ActionGuardProhibitsAction() public {
    ILlamaActionGuard guard = ILlamaActionGuard(new MockActionGuard(false, true, true, "no action creation"));

    vm.prank(address(mpExecutor));
    mpCore.setGuard(address(mockProtocol), PAUSE_SELECTOR, guard);

    vm.prank(actionCreatorAaron);
    vm.expectRevert("no action creation");
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, "");
  }

  function test_RevertIf_StrategyUnauthorized() public {
    ILlamaStrategy unauthorizedStrategy = ILlamaStrategy(makeAddr("unauthorized strategy"));
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.InvalidStrategy.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), unauthorizedStrategy, address(mockProtocol), 0, data, "");
  }

  function test_RevertIf_StrategyIsFromAnotherLlama() public {
    ILlamaStrategy unauthorizedStrategy = rootStrategy1;
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.InvalidStrategy.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), unauthorizedStrategy, address(mockProtocol), 0, data, "");
  }

  function testFuzz_RevertIf_PolicyholderNotMinted(address policyholder) public {
    if (policyholder == address(0)) policyholder = address(100); // Faster than vm.assume, since 0 comes up a lot.
    vm.assume(mpPolicy.balanceOf(policyholder) == 0);
    vm.prank(policyholder);
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, "");
  }

  function test_RevertIf_NoPermissionForStrategy() public {
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy2, address(mockProtocol), 0, data, "");
  }

  function testFuzz_RevertIf_NoPermissionForTarget(address _incorrectTarget) public {
    vm.assume(_incorrectTarget != address(mockProtocol) && _incorrectTarget != address(mpExecutor));
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, _incorrectTarget, 0, data, "");
  }

  function testFuzz_RevertIf_BadPermissionForSelector(bytes4 _badSelector) public {
    vm.assume(_badSelector != PAUSE_SELECTOR && _badSelector != FAIL_SELECTOR && _badSelector != RECEIVE_ETH_SELECTOR);
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, abi.encodeWithSelector(_badSelector), ""
    );
  }

  function testFuzz_RevertIf_PermissionExpired(uint64 _expirationTimestamp) public {
    vm.assume(_expirationTimestamp > block.timestamp + 1 && _expirationTimestamp < type(uint64).max - 1);
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    vm.startPrank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.ActionCreator), actionCreatorAustin, DEFAULT_ROLE_QTY, _expirationTimestamp);
    vm.stopPrank();

    vm.prank(address(actionCreatorAustin));
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, "");

    vm.warp(_expirationTimestamp + 1);
    mpPolicy.revokeExpiredRole(uint8(Roles.ActionCreator), actionCreatorAustin);

    vm.startPrank(address(actionCreatorAustin));
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, "");
  }

  function testFuzz_CreatesAnActionWithScriptAsTarget(address scriptAddress) public {
    vm.assume(
      scriptAddress != address(mpExecutor) && scriptAddress != address(mpCore) && scriptAddress != address(mpPolicy)
    );

    PermissionData memory permissionData = PermissionData(scriptAddress, bytes4(data), mpStrategy1);

    vm.prank(address(mpExecutor));
    mpCore.authorizeScript(scriptAddress, true);

    vm.prank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), keccak256(abi.encode(permissionData)), true);

    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(scriptAddress), 0, data, "");
    Action memory action = mpCore.getAction(actionId);

    assertEq(action.isScript, true);
  }

  function testFuzz_CreatesAnActionWithNonScriptAsTarget(address nonScriptAddress) public {
    vm.assume(nonScriptAddress != address(mpExecutor));

    PermissionData memory permissionData = PermissionData(nonScriptAddress, bytes4(data), mpStrategy1);

    vm.prank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), keccak256(abi.encode(permissionData)), true);

    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(nonScriptAddress), 0, data, "");
    Action memory action = mpCore.getAction(actionId);

    assertEq(action.isScript, false);
  }

  function test_RevertIf_ActionTargetIsExecutor() public {
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.CannotSetExecutorAsTarget.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mpExecutor), 0, abi.encodeWithSelector(""), "");
  }
}

contract CreateActionBySig is LlamaCoreTest {
  function createOffchainSignature(uint256 privateKey) internal view returns (uint8 v, bytes32 r, bytes32 s) {
    (v, r, s) = createOffchainSignatureWithDescription(privateKey, "");
  }

  function createOffchainSignatureWithDescription(uint256 privateKey, string memory description)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    LlamaCoreSigUtils.CreateAction memory createAction = LlamaCoreSigUtils.CreateAction({
      role: uint8(Roles.ActionCreator),
      strategy: address(mpStrategy1),
      target: address(mockProtocol),
      value: 0,
      data: abi.encodeCall(MockProtocol.pause, (true)),
      description: description,
      policyholder: actionCreatorAaron,
      nonce: 0
    });
    bytes32 digest = getCreateActionTypedDataHash(createAction);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function createActionBySig(uint8 v, bytes32 r, bytes32 s) internal returns (uint256 actionId) {
    actionId = mpCore.createActionBySig(
      actionCreatorAaron,
      uint8(Roles.ActionCreator),
      mpStrategy1,
      address(mockProtocol),
      0,
      abi.encodeCall(MockProtocol.pause, (true)),
      "",
      v,
      r,
      s
    );
  }

  function test_CreatesActionBySig() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionCreatorAaronPrivateKey);
    bytes memory data = abi.encodeCall(MockProtocol.pause, (true));

    vm.expectEmit();
    emit ActionCreated(
      0, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, ""
    );

    uint256 actionId = createActionBySig(v, r, s);
    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data);
    Action memory action = mpCore.getAction(actionId);

    uint256 approvalPeriodEnd = toRelativeQuorum(actionInfo.strategy).approvalEndTime(actionInfo);

    assertEq(actionId, 0);
    assertEq(mpCore.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(approvalPeriodEnd, block.timestamp + 2 days);
    assertEq(toRelativeQuorum(actionInfo.strategy).actionApprovalSupply(actionId), 3);
    assertEq(toRelativeQuorum(actionInfo.strategy).actionDisapprovalSupply(actionId), 3);
  }

  function test_CreatesActionBySigWithDescription() public {
    (uint8 v, bytes32 r, bytes32 s) =
      createOffchainSignatureWithDescription(actionCreatorAaronPrivateKey, "# Action 0 \n This is my action.");
    bytes memory data = abi.encodeCall(MockProtocol.pause, (true));

    vm.expectEmit();
    emit ActionCreated(
      0,
      actionCreatorAaron,
      uint8(Roles.ActionCreator),
      mpStrategy1,
      address(mockProtocol),
      0,
      data,
      "# Action 0 \n This is my action."
    );

    uint256 actionId = mpCore.createActionBySig(
      actionCreatorAaron,
      uint8(Roles.ActionCreator),
      mpStrategy1,
      address(mockProtocol),
      0,
      abi.encodeCall(MockProtocol.pause, (true)),
      "# Action 0 \n This is my action.",
      v,
      r,
      s
    );
    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data);
    Action memory action = mpCore.getAction(actionId);

    uint256 approvalPeriodEnd = toRelativeQuorum(actionInfo.strategy).approvalEndTime(actionInfo);

    assertEq(actionId, 0);
    assertEq(mpCore.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(approvalPeriodEnd, block.timestamp + 2 days);
    assertEq(toRelativeQuorum(actionInfo.strategy).actionApprovalSupply(actionId), 3);
    assertEq(toRelativeQuorum(actionInfo.strategy).actionDisapprovalSupply(actionId), 3);
  }

  function test_CheckNonceIncrements() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionCreatorAaronPrivateKey);
    assertEq(mpCore.nonces(actionCreatorAaron, LlamaCore.createActionBySig.selector), 0);
    createActionBySig(v, r, s);
    assertEq(mpCore.nonces(actionCreatorAaron, LlamaCore.createActionBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionCreatorAaronPrivateKey);
    createActionBySig(v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    createActionBySig(v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address is not the same as the policyholder passed in as
    // parameter.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    createActionBySig(v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionCreatorAaronPrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    createActionBySig((v + 1), r, s);
  }

  function test_RevertIf_PolicyholderIncrementsNonce() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionCreatorAaronPrivateKey);

    vm.prank(actionCreatorAaron);
    mpCore.incrementNonce(LlamaCore.createActionBySig.selector);

    // Invalid Signature error since the recovered signer address during the call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    createActionBySig(v, r, s);
  }
}

contract CancelAction is LlamaCoreTest {
  ActionInfo actionInfo;

  function setUp() public override {
    LlamaCoreTest.setUp();
    actionInfo = _createAction();
  }

  function test_CreatorCancelFlow() public {
    vm.prank(actionCreatorAaron);
    vm.expectEmit();
    emit ActionCanceled(actionInfo.id);
    mpCore.cancelAction(actionInfo);

    uint256 state = uint256(mpCore.getActionState(actionInfo));
    uint256 canceled = uint256(ActionState.Canceled);
    assertEq(state, canceled);
  }

  function testFuzz_RevertIf_NotCreator(address _randomCaller) public {
    vm.assume(_randomCaller != actionCreatorAaron);
    vm.prank(_randomCaller);
    vm.expectRevert(LlamaRelativeQuorum.OnlyActionCreator.selector);
    mpCore.cancelAction(actionInfo);
  }

  function testFuzz_RevertIf_InvalidActionId(ActionInfo calldata _actionInfo) public {
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
    mpCore.cancelAction(_actionInfo);
  }

  function test_RevertIf_AlreadyCanceled() public {
    vm.startPrank(actionCreatorAaron);
    mpCore.cancelAction(actionInfo);
    vm.expectRevert(abi.encodeWithSelector(LlamaRelativeQuorum.CannotCancelInState.selector, ActionState.Canceled));
    mpCore.cancelAction(actionInfo);
  }

  function test_RevertIf_ActionExecuted() public {
    ActionInfo memory _actionInfo = _executeCompleteActionFlow();

    vm.prank(actionCreatorAaron);
    vm.expectRevert(abi.encodeWithSelector(LlamaRelativeQuorum.CannotCancelInState.selector, ActionState.Executed));
    mpCore.cancelAction(_actionInfo);
  }

  function test_RevertIf_ActionExpired() public {
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionInfo), true);
    _queueAction(actionInfo);

    _disapproveAction(disapproverDave, actionInfo);

    vm.warp(block.timestamp + 15 days);

    vm.prank(actionCreatorAaron);
    vm.expectRevert(abi.encodeWithSelector(LlamaRelativeQuorum.CannotCancelInState.selector, ActionState.Expired));
    mpCore.cancelAction(actionInfo);
  }

  function test_RevertIf_ActionFailed() public {
    _approveAction(approverAdam, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionInfo), false);

    vm.expectRevert(abi.encodeWithSelector(LlamaRelativeQuorum.CannotCancelInState.selector, ActionState.Failed));
    mpCore.cancelAction(actionInfo);
  }

  function test_RevertIf_DisapprovalDoesNotReachQuorum() public {
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionInfo), true);
    _queueAction(actionInfo);

    vm.expectRevert(LlamaRelativeQuorum.OnlyActionCreator.selector);
    mpCore.cancelAction(actionInfo);
  }
}

contract QueueAction is LlamaCoreTest {
  function test_RevertIf_NotApproved() public {
    ActionInfo memory actionInfo = _createAction();
    _approveAction(approverAdam, actionInfo);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(abi.encodePacked(LlamaCore.InvalidActionState.selector, uint256(ActionState.Failed)));
    mpCore.queueAction(actionInfo);
  }

  function testFuzz_RevertIf_InvalidActionId(ActionInfo calldata actionInfo) public {
    vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
    mpCore.queueAction(actionInfo);
  }

  function testFuzz_RevertIf_MinExecutionTimeIsInThePast(uint64 blockTimestamp, uint64 minExecutionTime) public {
    blockTimestamp = toUint64(bound(blockTimestamp, block.timestamp, type(uint64).max / 2)); // Arbitrary bound that
      // won't revert.
    minExecutionTime = toUint64(bound(minExecutionTime, 0, blockTimestamp));
    vm.warp(blockTimestamp);

    // Approve an action.
    ActionInfo memory actionInfo = _createAction();
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);
    vm.warp(block.timestamp + 6 days);
    assertEq(mpStrategy1.isActionApproved(actionInfo), true);

    // Queue reverts because minExecutionTime is in the past.
    assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Approved));
    vm.mockCall(
      address(actionInfo.strategy),
      abi.encodeWithSelector(ILlamaStrategy.minExecutionTime.selector),
      abi.encode(minExecutionTime)
    );
    vm.expectRevert(LlamaCore.MinExecutionTimeCannotBeInThePast.selector);
    mpCore.queueAction(actionInfo);
  }

  function testFuzz_SuccessfullyQueuesAction(uint64 blockTimestamp, uint64 minExecutionTime) public {
    blockTimestamp = toUint64(bound(blockTimestamp, block.timestamp, type(uint64).max / 2)); // Arbitrary bound that
      // won't revert.
    minExecutionTime = toUint64(bound(minExecutionTime, 0, blockTimestamp));
    vm.warp(blockTimestamp);

    // Approve an action.
    ActionInfo memory actionInfo = _createAction();
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);
    vm.warp(block.timestamp + 6 days);
    assertEq(mpStrategy1.isActionApproved(actionInfo), true);

    // Queue it.
    assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Approved));
    mpCore.queueAction(actionInfo);
    assertEq(uint8(mpCore.getActionState(actionInfo)), uint8(ActionState.Queued));
  }
}

contract ExecuteAction is LlamaCoreTest {
  ActionInfo actionInfo;

  function _executeScriptAuthorizationActionFlow(bool authorize) internal {
    bytes memory data = abi.encodeCall(mpCore.authorizeScript, (address(mockScript), authorize));
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mpCore), 0, data, "");
    actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mpCore), 0, data);
    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionInfo), true);
    _queueAction(actionInfo);

    vm.warp(block.timestamp + 5 days);

    _executeAction(actionInfo);
  }

  function setUp() public override {
    LlamaCoreTest.setUp();

    actionInfo = _createAction();
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionInfo), true);
  }

  function test_ActionExecution() public {
    mpCore.queueAction(actionInfo);
    vm.warp(block.timestamp + 6 days);

    vm.expectEmit();
    emit ActionExecuted(0, address(this), mpStrategy1, actionCreatorAaron, bytes(""));
    mpCore.executeAction(actionInfo);
  }

  function test_ScriptsAlwaysUseDelegatecall() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    vm.prank(address(mpExecutor));
    mpCore.authorizeScript(address(mockScript), true);

    bytes memory data = abi.encodeWithSelector(EXECUTE_SCRIPT_SELECTOR);
    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(uint8(Roles.TestRole2), mpStrategy1, address(mockScript), 0, data, "");
    ActionInfo memory _actionInfo =
      ActionInfo(actionId, actionCreatorAustin, uint8(Roles.TestRole2), mpStrategy1, address(mockScript), 0, data);

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, _actionInfo);
    _approveAction(approverAlicia, _actionInfo);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(_actionInfo);

    vm.warp(block.timestamp + 5 days);

    vm.expectEmit();
    // Checking that the result is a delegatecall because msg.sender is this mpCore and not mpExecutor
    emit ActionExecuted(_actionInfo.id, address(this), mpStrategy1, actionCreatorAustin, abi.encode(address(mpCore)));
    mpCore.executeAction(_actionInfo);
  }

  function test_RevertIf_NotQueued() public {
    vm.expectRevert(abi.encodePacked(LlamaCore.InvalidActionState.selector, uint256(ActionState.Approved)));
    mpCore.executeAction(actionInfo);

    // Check that it's in the Approved state
    assertEq(uint256(mpCore.getActionState(actionInfo)), uint256(3));
  }

  function test_RevertIf_ActionGuardProhibitsActionPreExecution() public {
    ILlamaActionGuard guard = ILlamaActionGuard(new MockActionGuard(true, false, true, "no action pre-execution"));

    vm.prank(address(mpExecutor));
    mpCore.setGuard(address(mockProtocol), PAUSE_SELECTOR, guard);

    mpCore.queueAction(actionInfo);
    vm.warp(block.timestamp + 6 days);

    vm.expectRevert("no action pre-execution");
    mpCore.executeAction(actionInfo);
  }

  function test_RevertIf_ActionGuardProhibitsActionPostExecution() public {
    ILlamaActionGuard guard = ILlamaActionGuard(new MockActionGuard(true, true, false, "no action post-execution"));

    vm.prank(address(mpExecutor));
    mpCore.setGuard(address(mockProtocol), PAUSE_SELECTOR, guard);

    mpCore.queueAction(actionInfo);
    vm.warp(block.timestamp + 6 days);

    vm.expectRevert("no action post-execution");
    mpCore.executeAction(actionInfo);
  }

  function testFuzz_RevertIf_InvalidAction(ActionInfo calldata _actionInfo) public {
    vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
    mpCore.executeAction(_actionInfo);
  }

  function testFuzz_RevertIf_MinExecutionTimeNotReached(uint256 timeElapsed) public {
    // Using a reasonable upper limit for elapsedTime
    vm.assume(timeElapsed < 10_000 days);
    mpCore.queueAction(actionInfo);
    uint256 executionTime = mpCore.getAction(actionInfo.id).minExecutionTime;

    vm.warp(block.timestamp + timeElapsed);

    if (executionTime > block.timestamp) {
      vm.expectRevert(LlamaCore.MinExecutionTimeNotReached.selector);
      mpCore.executeAction(actionInfo);
    }
  }

  function testFuzz_RevertIf_IncorrectMsgValue(uint256 value) public {
    vm.assume(value != 1 ether);
    bytes memory data = abi.encodeCall(MockProtocol.receiveEth, ());
    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 1 ether, data, "");
    ActionInfo memory _actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 1 ether, data
    );

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, _actionInfo);
    _approveAction(approverAlicia, _actionInfo);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(_actionInfo);

    vm.warp(block.timestamp + 5 days);

    vm.deal(actionCreatorAaron, value);

    vm.prank(actionCreatorAaron);
    (bool status, bytes memory _data) =
      address(mpCore).call{value: value}((abi.encodeCall(mpCore.executeAction, (_actionInfo))));
    assertFalse(status, "expectRevert: call did not revert");
    assertEq(_data, bytes.concat(LlamaCore.IncorrectMsgValue.selector));
  }

  function test_RevertIf_FailedActionExecution() public {
    bytes memory data = abi.encodeCall(MockProtocol.fail, ());
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data, "");
    ActionInfo memory _actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, data);

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, _actionInfo);
    _approveAction(approverAlicia, _actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(_actionInfo), true);

    mpCore.queueAction(_actionInfo);

    vm.warp(block.timestamp + 5 days);

    bytes memory expectedErr = abi.encodeWithSelector(
      LlamaCore.FailedActionExecution.selector, abi.encodeWithSelector(MockProtocol.Failed.selector)
    );
    vm.expectRevert(expectedErr);
    mpCore.executeAction(_actionInfo);
  }

  function test_HandlesReentrancy() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");
    bytes memory expectedErr = abi.encodeWithSelector(
      LlamaCore.FailedActionExecution.selector,
      abi.encodeWithSelector(LlamaCore.InvalidActionState.selector, (ActionState.Approved))
    );

    vm.startPrank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.stopPrank();

    bytes memory data = abi.encodeCall(LlamaCore.executeAction, (actionInfo));
    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(uint8(Roles.TestRole2), mpStrategy1, address(mpCore), 0, data, "");
    ActionInfo memory _actionInfo =
      ActionInfo(actionId, actionCreatorAustin, uint8(Roles.TestRole2), mpStrategy1, address(mpCore), 0, data);

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, _actionInfo);
    _approveAction(approverAlicia, _actionInfo);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(_actionInfo);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(expectedErr);
    mpCore.executeAction(_actionInfo);
  }

  function test_ScriptAuthorizationDoesNotAffectExecution() external {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");
    vm.prank(address(mpExecutor));
    mpCore.authorizeScript(address(mockScript), false);

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    bytes memory data = abi.encodeWithSelector(EXECUTE_SCRIPT_SELECTOR);
    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(uint8(Roles.TestRole2), mpStrategy1, address(mockScript), 0, data, "");
    ActionInfo memory _actionInfo =
      ActionInfo(actionId, actionCreatorAustin, uint8(Roles.TestRole2), mpStrategy1, address(mockScript), 0, data);

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, _actionInfo);
    _approveAction(approverAlicia, _actionInfo);

    vm.warp(block.timestamp + 6 days);

    vm.prank(address(mpExecutor));
    mpCore.authorizeScript(address(mockScript), true);

    mpCore.queueAction(_actionInfo);

    vm.warp(block.timestamp + 5 days);

    vm.expectEmit();
    // Checking that the result is a call because msg.sender is mpExecutor
    emit ActionExecuted(
      _actionInfo.id, address(this), mpStrategy1, actionCreatorAustin, abi.encode(address(mpExecutor))
    );
    mpCore.executeAction(_actionInfo);
  }

  function test_ScriptUnauthorizationDoesNotAffectExecution() external {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");
    vm.prank(address(mpExecutor));
    mpCore.authorizeScript(address(mockScript), true);

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    bytes memory data = abi.encodeWithSelector(EXECUTE_SCRIPT_SELECTOR);
    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(uint8(Roles.TestRole2), mpStrategy1, address(mockScript), 0, data, "");
    ActionInfo memory _actionInfo =
      ActionInfo(actionId, actionCreatorAustin, uint8(Roles.TestRole2), mpStrategy1, address(mockScript), 0, data);

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, _actionInfo);
    _approveAction(approverAlicia, _actionInfo);

    vm.warp(block.timestamp + 6 days);

    vm.prank(address(mpExecutor));
    mpCore.authorizeScript(address(mockScript), false);

    mpCore.queueAction(_actionInfo);

    vm.warp(block.timestamp + 5 days);

    vm.expectEmit();
    // Checking that the result is a delegatecall because msg.sender is mpCore not mpExecutor
    emit ActionExecuted(_actionInfo.id, address(this), mpStrategy1, actionCreatorAustin, abi.encode(address(mpCore)));
    mpCore.executeAction(_actionInfo);
  }

  function test_ScriptAuthorizationFromActionDoesNotAffectExecution() external {
    _executeScriptAuthorizationActionFlow(false);

    bytes memory data = abi.encodeWithSelector(EXECUTE_SCRIPT_SELECTOR);
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockScript), 0, data, "");

    ActionInfo memory _actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockScript), 0, data);

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, _actionInfo);
    _approveAction(approverAlicia, _actionInfo);

    _executeScriptAuthorizationActionFlow(true);

    mpCore.queueAction(_actionInfo);

    vm.warp(block.timestamp + 5 days);

    vm.expectEmit();
    // Checking that the result is a call because msg.sender is mpExecutor
    emit ActionExecuted(_actionInfo.id, address(this), mpStrategy1, actionCreatorAaron, abi.encode(address(mpExecutor)));
    mpCore.executeAction(_actionInfo);
  }

  function test_ScriptUnauthorizationFromActionDoesNotAffectExecution() external {
    _executeScriptAuthorizationActionFlow(true);

    bytes memory data = abi.encodeWithSelector(EXECUTE_SCRIPT_SELECTOR);
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mockScript), 0, data, "");

    ActionInfo memory _actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mockScript), 0, data);

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, _actionInfo);
    _approveAction(approverAlicia, _actionInfo);

    _executeScriptAuthorizationActionFlow(false);

    mpCore.queueAction(_actionInfo);

    vm.warp(block.timestamp + 5 days);

    vm.expectEmit();
    // Checking that the result is a delegatecall because msg.sender is mpCore and not mpExecutor
    emit ActionExecuted(_actionInfo.id, address(this), mpStrategy1, actionCreatorAaron, abi.encode(address(mpCore)));
    mpCore.executeAction(_actionInfo);
  }
}

contract CastApproval is LlamaCoreTest {
  ActionInfo actionInfo;

  function setUp() public override {
    LlamaCoreTest.setUp();
    actionInfo = _createAction();
  }

  function test_SuccessfulApproval() public {
    _approveAction(approverAdam, actionInfo);
    assertEq(mpCore.getAction(0).totalApprovals, 1);
    assertEq(mpCore.approvals(0, approverAdam), true);
  }

  function test_SuccessfulApprovalWithReason(string calldata reason) public {
    vm.expectEmit();
    emit ApprovalCast(actionInfo.id, approverAdam, uint8(Roles.Approver), 1, reason);
    vm.prank(approverAdam);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, reason);
  }

  function test_RevertIf_ActionNotActive() public {
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionInfo);

    vm.expectRevert(abi.encodePacked(LlamaCore.InvalidActionState.selector, uint256(ActionState.Queued)));
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
  }

  function test_RevertIf_DuplicateApproval() public {
    _approveAction(approverAdam, actionInfo);

    vm.expectRevert(LlamaCore.DuplicateCast.selector);
    vm.prank(approverAdam);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
  }

  function test_RevertIf_InvalidPolicyholder() public {
    address notPolicyholder = 0x9D3de545F58C696946b4Cf2c884fcF4f7914cB53;
    vm.prank(notPolicyholder);

    vm.expectRevert(LlamaCore.InvalidPolicyholder.selector);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");

    vm.prank(approverAdam);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
  }

  function test_RevertIf_NoQuantity() public {
    ILlamaStrategy newStrategy = deployMockPoorStrategyAndCreatePermission();

    bytes memory data = abi.encodeCall(MockProtocol.pause, (true));
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), newStrategy, address(mockProtocol), 0, data, "");
    actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), newStrategy, address(mockProtocol), 0, data);
    vm.warp(block.timestamp + 1);

    vm.prank(actionCreatorAaron);
    vm.expectRevert(
      abi.encodeWithSelector(
        LlamaCore.CannotCastWithZeroQuantity.selector, actionCreatorAaron, uint8(Roles.ActionCreator)
      )
    );
    mpCore.castApproval(uint8(Roles.ActionCreator), actionInfo, "");
  }
}

contract CastApprovalBySig is LlamaCoreTest {
  function createOffchainSignature(ActionInfo memory actionInfo, uint256 privateKey)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    LlamaCoreSigUtils.CastApproval memory castApproval = LlamaCoreSigUtils.CastApproval({
      actionInfo: actionInfo,
      role: uint8(Roles.Approver),
      reason: "",
      policyholder: approverAdam,
      nonce: 0
    });
    bytes32 digest = getCastApprovalTypedDataHash(castApproval);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function castApprovalBySig(ActionInfo memory actionInfo, uint8 v, bytes32 r, bytes32 s) internal {
    mpCore.castApprovalBySig(approverAdam, uint8(Roles.Approver), actionInfo, "", v, r, s);
  }

  function test_CastsApprovalBySig() public {
    ActionInfo memory actionInfo = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, approverAdamPrivateKey);

    vm.expectEmit();
    emit ApprovalCast(actionInfo.id, approverAdam, uint8(Roles.Approver), 1, "");

    castApprovalBySig(actionInfo, v, r, s);

    assertEq(mpCore.getAction(0).totalApprovals, 1);
    assertEq(mpCore.approvals(0, approverAdam), true);
  }

  function test_CheckNonceIncrements() public {
    ActionInfo memory actionInfo = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, approverAdamPrivateKey);

    assertEq(mpCore.nonces(approverAdam, LlamaCore.castApprovalBySig.selector), 0);
    castApprovalBySig(actionInfo, v, r, s);
    assertEq(mpCore.nonces(approverAdam, LlamaCore.castApprovalBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    ActionInfo memory actionInfo = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, approverAdamPrivateKey);
    castApprovalBySig(actionInfo, v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castApprovalBySig(actionInfo, v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    ActionInfo memory actionInfo = _createAction();

    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address is not the same as the policyholder passed in as
    // parameter.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castApprovalBySig(actionInfo, v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    ActionInfo memory actionInfo = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, approverAdamPrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castApprovalBySig(actionInfo, (v + 1), r, s);
  }

  function test_RevertIf_PolicyholderIncrementsNonce() public {
    ActionInfo memory actionInfo = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, approverAdamPrivateKey);

    vm.prank(approverAdam);
    mpCore.incrementNonce(LlamaCore.castApprovalBySig.selector);

    // Invalid Signature error since the recovered signer address during the call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castApprovalBySig(actionInfo, v, r, s);
  }

  function test_ActionCreatorCanRelayMessage() public {
    // Testing that ActionCreatorCannotCast() error is not hit
    ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      1,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createActionUsingAbsolutePeerReview(absolutePeerReview);

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, approverAdamPrivateKey);
    vm.prank(actionCreatorAaron);
    castApprovalBySig(actionInfo, v, r, s);
  }
}

contract CastDisapproval is LlamaCoreTest {
  function _createApproveAndQueueAction() internal returns (ActionInfo memory actionInfo) {
    actionInfo = _createAction();
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionInfo), true);
    _queueAction(actionInfo);
  }

  function test_SuccessfulDisapproval() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    vm.prank(disapproverDrake);
    vm.expectEmit();
    emit DisapprovalCast(actionInfo.id, disapproverDrake, uint8(Roles.Disapprover), 1, "");

    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");

    assertEq(mpCore.getAction(0).totalDisapprovals, 1);
    assertEq(mpCore.disapprovals(0, disapproverDrake), true);
  }

  function test_SuccessfulDisapprovalWithReason(string calldata reason) public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();
    vm.expectEmit();
    emit DisapprovalCast(actionInfo.id, disapproverDrake, uint8(Roles.Disapprover), 1, reason);
    vm.prank(disapproverDrake);
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, reason);
  }

  function test_RevertIf_ActionNotQueued() public {
    ActionInfo memory actionInfo = _createAction();

    vm.expectRevert(abi.encodePacked(LlamaCore.InvalidActionState.selector, uint256(ActionState.Active)));
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");
  }

  function test_RevertIf_DuplicateDisapproval() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    _disapproveAction(disapproverDrake, actionInfo);

    vm.expectRevert(LlamaCore.DuplicateCast.selector);
    vm.prank(disapproverDrake);
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");
  }

  function test_RevertIf_InvalidPolicyholder() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();
    address notPolicyholder = 0x9D3de545F58C696946b4Cf2c884fcF4f7914cB53;
    vm.prank(notPolicyholder);

    vm.expectRevert(LlamaCore.InvalidPolicyholder.selector);
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");

    vm.prank(disapproverDrake);
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");
  }

  function test_FailsIfDisapproved() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    vm.prank(disapproverDave);
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");
    vm.prank(disapproverDrake);
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");

    ActionState state = mpCore.getActionState(actionInfo);
    assertEq(uint8(state), uint8(ActionState.Failed));

    vm.expectRevert(abi.encodeWithSelector(LlamaCore.InvalidActionState.selector, ActionState.Failed));
    mpCore.executeAction(actionInfo);
  }

  function test_RevertIf_NoQuantity() public {
    ILlamaStrategy newStrategy = deployMockPoorStrategyAndCreatePermission();

    bytes memory data = abi.encodeCall(MockProtocol.pause, (true));
    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), newStrategy, address(mockProtocol), 0, data, "");
    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), newStrategy, address(mockProtocol), 0, data);
    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    uint256 executionTime = block.timestamp + toAbsolutePeerReview(newStrategy).queuingPeriod();
    vm.expectEmit();
    emit ActionQueued(actionInfo.id, address(this), newStrategy, actionCreatorAaron, executionTime);
    mpCore.queueAction(actionInfo);

    vm.expectRevert(
      abi.encodeWithSelector(
        LlamaCore.CannotCastWithZeroQuantity.selector, actionCreatorAaron, uint8(Roles.ActionCreator)
      )
    );
    vm.prank(actionCreatorAaron);
    mpCore.castDisapproval(uint8(Roles.ActionCreator), actionInfo, "");
  }
}

contract CastDisapprovalBySig is LlamaCoreTest {
  function createOffchainSignature(ActionInfo memory actionInfo, uint256 privateKey)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    LlamaCoreSigUtils.CastDisapproval memory castDisapproval = LlamaCoreSigUtils.CastDisapproval({
      actionInfo: actionInfo,
      role: uint8(Roles.Disapprover),
      reason: "",
      policyholder: disapproverDrake,
      nonce: 0
    });
    bytes32 digest = getCastDisapprovalTypedDataHash(castDisapproval);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function castDisapprovalBySig(ActionInfo memory actionInfo, uint8 v, bytes32 r, bytes32 s) internal {
    mpCore.castDisapprovalBySig(disapproverDrake, uint8(Roles.Disapprover), actionInfo, "", v, r, s);
  }

  function _createApproveAndQueueAction() internal returns (ActionInfo memory actionInfo) {
    actionInfo = _createAction();
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(actionInfo.strategy.isActionApproved(actionInfo), true);
    _queueAction(actionInfo);
  }

  function test_CastsDisapprovalBySig() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, disapproverDrakePrivateKey);

    vm.expectEmit();
    emit DisapprovalCast(actionInfo.id, disapproverDrake, uint8(Roles.Disapprover), 1, "");

    castDisapprovalBySig(actionInfo, v, r, s);

    assertEq(mpCore.getAction(0).totalDisapprovals, 1);
    assertEq(mpCore.disapprovals(0, disapproverDrake), true);
  }

  function test_CheckNonceIncrements() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, disapproverDrakePrivateKey);

    assertEq(mpCore.nonces(disapproverDrake, LlamaCore.castDisapprovalBySig.selector), 0);
    castDisapprovalBySig(actionInfo, v, r, s);
    assertEq(mpCore.nonces(disapproverDrake, LlamaCore.castDisapprovalBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, disapproverDrakePrivateKey);
    castDisapprovalBySig(actionInfo, v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castDisapprovalBySig(actionInfo, v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castDisapprovalBySig(actionInfo, v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, disapproverDrakePrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castDisapprovalBySig(actionInfo, (v + 1), r, s);
  }

  function test_RevertIf_PolicyholderIncrementsNonce() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, disapproverDrakePrivateKey);

    vm.prank(disapproverDrake);
    mpCore.incrementNonce(LlamaCore.castDisapprovalBySig.selector);

    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castDisapprovalBySig(actionInfo, v, r, s);
  }

  function test_FailsIfDisapproved() public {
    ActionInfo memory actionInfo = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, disapproverDrakePrivateKey);

    // First disapproval.
    vm.expectEmit();
    emit DisapprovalCast(actionInfo.id, disapproverDrake, uint8(Roles.Disapprover), 1, "");
    castDisapprovalBySig(actionInfo, v, r, s);
    assertEq(mpCore.getAction(actionInfo.id).totalDisapprovals, 1);

    // Second disapproval.
    vm.prank(disapproverDave);
    mpCore.castDisapproval(uint8(Roles.Disapprover), actionInfo, "");

    // Assertions.
    ActionState state = mpCore.getActionState(actionInfo);
    assertEq(uint8(state), uint8(ActionState.Failed));

    vm.expectRevert(abi.encodeWithSelector(LlamaCore.InvalidActionState.selector, ActionState.Failed));
    mpCore.executeAction(actionInfo);
  }

  function test_ActionCreatorCanRelayMessage() public {
    // Testing that ActionCreatorCannotCast() error is not hit
    ILlamaStrategy absolutePeerReview = deployAbsolutePeerReview(
      uint8(Roles.Approver),
      uint8(Roles.Disapprover),
      1 days,
      4 days,
      1 days,
      true,
      2,
      1,
      new uint8[](0),
      new uint8[](0)
    );
    ActionInfo memory actionInfo = createActionUsingAbsolutePeerReview(absolutePeerReview);

    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 1 days);

    mpCore.queueAction(actionInfo);

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionInfo, disapproverDrakePrivateKey);
    vm.prank(actionCreatorAaron);
    castDisapprovalBySig(actionInfo, v, r, s);
  }
}

contract CreateStrategies is LlamaCoreTest {
  function testFuzz_RevertIf_CallerIsNotLlama(address caller) public {
    vm.assume(caller != address(mpExecutor));
    vm.expectRevert(LlamaCore.OnlyLlama.selector);
    LlamaRelativeQuorum.Config[] memory newStrategies = new LlamaRelativeQuorum.Config[](3);

    vm.prank(caller);
    mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(newStrategies));
  }

  function test_CreateNewStrategies(uint256 salt1, uint256 salt2, uint256 salt3, bool isFixedLengthApprovalPeriod)
    public
  {
    LlamaRelativeQuorum.Config[] memory newStrategies = new LlamaRelativeQuorum.Config[](3);
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);
    vm.assume(salt1 != salt2);
    vm.assume(salt1 != salt3);
    vm.assume(salt2 != salt3);

    newStrategies[0] = _createStrategy(salt1, isFixedLengthApprovalPeriod);
    newStrategies[1] = _createStrategy(salt2, isFixedLengthApprovalPeriod);
    newStrategies[2] = _createStrategy(salt3, isFixedLengthApprovalPeriod);

    for (uint256 i = 0; i < newStrategies.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeQuorumLogic), DeployUtils.encodeStrategy(newStrategies[i]), address(mpCore)
      );
    }

    vm.startPrank(address(mpExecutor));

    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[0], relativeQuorumLogic, DeployUtils.encodeStrategy(newStrategies[0]));
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[1], relativeQuorumLogic, DeployUtils.encodeStrategy(newStrategies[1]));
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[2], relativeQuorumLogic, DeployUtils.encodeStrategy(newStrategies[2]));

    mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(newStrategies));

    assertEq(mpCore.strategies(strategyAddresses[0]), true);
    assertEq(mpCore.strategies(strategyAddresses[1]), true);
    assertEq(mpCore.strategies(strategyAddresses[2]), true);
  }

  function test_CreateNewStrategiesWithAdditionalStrategyLogic() public {
    ILlamaStrategy additionalStrategyLogic = _deployAndAuthorizeAdditionalStrategyLogic();

    LlamaRelativeQuorum.Config[] memory newStrategies = new LlamaRelativeQuorum.Config[](3);
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);

    newStrategies[0] = LlamaRelativeQuorum.Config({
      approvalPeriod: 4 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    newStrategies[1] = LlamaRelativeQuorum.Config({
      approvalPeriod: 5 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    newStrategies[2] = LlamaRelativeQuorum.Config({
      approvalPeriod: 6 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    for (uint256 i = 0; i < newStrategies.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(additionalStrategyLogic), DeployUtils.encodeStrategy(newStrategies[i]), address(mpCore)
      );
    }

    vm.startPrank(address(mpExecutor));

    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[0], additionalStrategyLogic, DeployUtils.encodeStrategy(newStrategies[0]));
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[1], additionalStrategyLogic, DeployUtils.encodeStrategy(newStrategies[1]));
    vm.expectEmit();
    emit StrategyCreated(strategyAddresses[2], additionalStrategyLogic, DeployUtils.encodeStrategy(newStrategies[2]));

    mpCore.createStrategies(additionalStrategyLogic, DeployUtils.encodeStrategyConfigs(newStrategies));

    assertEq(mpCore.strategies(strategyAddresses[0]), true);
    assertEq(mpCore.strategies(strategyAddresses[1]), true);
    assertEq(mpCore.strategies(strategyAddresses[2]), true);
  }

  function test_RevertIf_StrategyLogicNotAuthorized() public {
    LlamaRelativeQuorum.Config[] memory newStrategies = new LlamaRelativeQuorum.Config[](1);

    newStrategies[0] = LlamaRelativeQuorum.Config({
      approvalPeriod: 4 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    vm.startPrank(address(mpExecutor));

    vm.expectRevert(LlamaCore.UnauthorizedStrategyLogic.selector);
    mpCore.createStrategies(ILlamaStrategy(randomLogicAddress), DeployUtils.encodeStrategyConfigs(newStrategies));
  }

  function test_RevertIf_StrategiesAreIdentical() public {
    LlamaRelativeQuorum.Config[] memory newStrategies = new LlamaRelativeQuorum.Config[](2);

    LlamaRelativeQuorum.Config memory duplicateStrategy = LlamaRelativeQuorum.Config({
      approvalPeriod: 4 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    newStrategies[0] = duplicateStrategy;
    newStrategies[1] = duplicateStrategy;

    vm.startPrank(address(mpExecutor));

    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(newStrategies));
  }

  function test_RevertIf_IdenticalStrategyIsAlreadyDeployed() public {
    LlamaRelativeQuorum.Config[] memory newStrategies1 = new LlamaRelativeQuorum.Config[](1);
    LlamaRelativeQuorum.Config[] memory newStrategies2 = new LlamaRelativeQuorum.Config[](1);

    LlamaRelativeQuorum.Config memory duplicateStrategy = LlamaRelativeQuorum.Config({
      approvalPeriod: 4 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    newStrategies1[0] = duplicateStrategy;
    newStrategies2[0] = duplicateStrategy;

    vm.startPrank(address(mpExecutor));
    mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(newStrategies1));

    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createStrategies(relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(newStrategies2));
  }

  function test_CanBeCalledByASuccessfulAction() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    LlamaRelativeQuorum.Config[] memory newStrategies = new LlamaRelativeQuorum.Config[](1);

    newStrategies[0] = LlamaRelativeQuorum.Config({
      approvalPeriod: 4 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });

    ILlamaStrategy strategyAddress = lens.computeLlamaStrategyAddress(
      address(relativeQuorumLogic), DeployUtils.encodeStrategy(newStrategies[0]), address(mpCore)
    );

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    bytes memory data = abi.encodeCall(
      LlamaCore.createStrategies, (relativeQuorumLogic, DeployUtils.encodeStrategyConfigs(newStrategies))
    );
    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(uint8(Roles.TestRole2), mpStrategy1, address(mpCore), 0, data, "");
    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAustin, uint8(Roles.TestRole2), mpStrategy1, address(mpCore), 0, data);

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionInfo);

    vm.warp(block.timestamp + 5 days);

    mpCore.executeAction(actionInfo);

    assertEq(mpCore.strategies(strategyAddress), true);
  }
}

contract CreateAccounts is LlamaCoreTest {
  function encodeMockAccount(MockAccountLogicContract.Config memory account)
    internal
    pure
    returns (bytes memory encoded)
  {
    encoded = abi.encode(account);
  }

  function encodeMockAccountConfigs(MockAccountLogicContract.Config[] memory accounts)
    internal
    pure
    returns (bytes[] memory encoded)
  {
    encoded = new bytes[](accounts.length);
    for (uint256 i = 0; i < accounts.length; i++) {
      encoded[i] = encodeMockAccount(accounts[i]);
    }
  }

  function testFuzz_RevertIf_CallerIsNotLlama(address caller) public {
    vm.assume(caller != address(mpExecutor));
    vm.expectRevert(LlamaCore.OnlyLlama.selector);

    LlamaAccount.Config[] memory newAccounts = new LlamaAccount.Config[](3);
    newAccounts[0] = LlamaAccount.Config({name: "LlamaAccount2"});
    newAccounts[1] = LlamaAccount.Config({name: "LlamaAccount3"});
    newAccounts[2] = LlamaAccount.Config({name: "LlamaAccount4"});

    vm.prank(caller);
    mpCore.createAccounts(accountLogic, DeployUtils.encodeAccountConfigs(newAccounts));
  }

  function test_CreateNewAccounts() public {
    LlamaAccount.Config[] memory newAccounts = new LlamaAccount.Config[](3);
    newAccounts[0] = LlamaAccount.Config({name: "LlamaAccount2"});
    newAccounts[1] = LlamaAccount.Config({name: "LlamaAccount3"});
    newAccounts[2] = LlamaAccount.Config({name: "LlamaAccount4"});

    ILlamaAccount[] memory accountAddresses = new ILlamaAccount[](3);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeLlamaAccountAddress(
        address(accountLogic), DeployUtils.encodeAccount(newAccounts[i]), address(mpCore)
      );
    }

    vm.expectEmit();
    emit AccountCreated(accountAddresses[0], accountLogic, DeployUtils.encodeAccount(newAccounts[0]));
    vm.expectEmit();
    emit AccountCreated(accountAddresses[1], accountLogic, DeployUtils.encodeAccount(newAccounts[1]));
    vm.expectEmit();
    emit AccountCreated(accountAddresses[2], accountLogic, DeployUtils.encodeAccount(newAccounts[2]));

    vm.prank(address(mpExecutor));
    mpCore.createAccounts(accountLogic, DeployUtils.encodeAccountConfigs(newAccounts));
  }

  function test_CreateNewAccountsWithAdditionalAccountLogic() public {
    ILlamaAccount additionalAccountLogic = _deployAndAuthorizeAdditionalAccountLogic();

    LlamaAccount.Config[] memory newAccounts = new LlamaAccount.Config[](3);
    newAccounts[0] = LlamaAccount.Config({name: "LlamaAccount2"});
    newAccounts[1] = LlamaAccount.Config({name: "LlamaAccount3"});
    newAccounts[2] = LlamaAccount.Config({name: "LlamaAccount4"});

    ILlamaAccount[] memory accountAddresses = new ILlamaAccount[](3);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeLlamaAccountAddress(
        address(additionalAccountLogic), DeployUtils.encodeAccount(newAccounts[i]), address(mpCore)
      );
    }

    vm.expectEmit();
    emit AccountCreated(accountAddresses[0], additionalAccountLogic, DeployUtils.encodeAccount(newAccounts[0]));
    vm.expectEmit();
    emit AccountCreated(accountAddresses[1], additionalAccountLogic, DeployUtils.encodeAccount(newAccounts[1]));
    vm.expectEmit();
    emit AccountCreated(accountAddresses[2], additionalAccountLogic, DeployUtils.encodeAccount(newAccounts[2]));

    vm.prank(address(mpExecutor));
    mpCore.createAccounts(additionalAccountLogic, DeployUtils.encodeAccountConfigs(newAccounts));
  }

  function test_CreateNewAccountsWithMockAccountLogic() public {
    ILlamaAccount mockAccountLogic = _deployAndAuthorizeMockAccountLogic();

    MockAccountLogicContract.Config[] memory newAccounts = new MockAccountLogicContract.Config[](1);
    newAccounts[0] = MockAccountLogicContract.Config({creationTime: block.timestamp});

    ILlamaAccount[] memory accountAddresses = new ILlamaAccount[](1);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] =
        lens.computeLlamaAccountAddress(address(mockAccountLogic), encodeMockAccount(newAccounts[i]), address(mpCore));
    }

    vm.expectEmit();
    emit AccountCreated(accountAddresses[0], mockAccountLogic, encodeMockAccount(newAccounts[0]));

    vm.prank(address(mpExecutor));
    mpCore.createAccounts(mockAccountLogic, encodeMockAccountConfigs(newAccounts));

    assertEq(MockAccountLogicContract(address(accountAddresses[0])).creationTime(), block.timestamp);
  }

  function test_RevertIf_AccountLogicNotAuthorized() public {
    LlamaAccount.Config[] memory newAccounts = new LlamaAccount.Config[](3);
    newAccounts[0] = LlamaAccount.Config({name: "LlamaAccount2"});
    newAccounts[1] = LlamaAccount.Config({name: "LlamaAccount3"});
    newAccounts[2] = LlamaAccount.Config({name: "LlamaAccount4"});

    vm.expectRevert(LlamaCore.UnauthorizedAccountLogic.selector);
    vm.prank(address(mpExecutor));
    mpCore.createAccounts(ILlamaAccount(randomLogicAddress), DeployUtils.encodeAccountConfigs(newAccounts));
  }

  function test_RevertIf_Reinitialized() public {
    LlamaAccount.Config[] memory newAccounts = new LlamaAccount.Config[](3);
    newAccounts[0] = LlamaAccount.Config({name: "LlamaAccount2"});
    newAccounts[1] = LlamaAccount.Config({name: "LlamaAccount3"});
    newAccounts[2] = LlamaAccount.Config({name: "LlamaAccount4"});

    ILlamaAccount[] memory accountAddresses = new ILlamaAccount[](3);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeLlamaAccountAddress(
        address(accountLogic), DeployUtils.encodeAccount(newAccounts[i]), address(mpCore)
      );
    }

    vm.startPrank(address(mpExecutor));
    mpCore.createAccounts(accountLogic, DeployUtils.encodeAccountConfigs(newAccounts));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[0].initialize(DeployUtils.encodeAccount(newAccounts[0]));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[1].initialize(DeployUtils.encodeAccount(newAccounts[1]));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[2].initialize(DeployUtils.encodeAccount(newAccounts[2]));
  }

  function test_RevertIf_AccountsAreIdentical() public {
    LlamaAccount.Config[] memory newAccounts = new LlamaAccount.Config[](2);
    newAccounts[0] = LlamaAccount.Config({name: "LlamaAccount1"});
    newAccounts[1] = LlamaAccount.Config({name: "LlamaAccount1"});

    vm.prank(address(mpExecutor));
    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createAccounts(accountLogic, DeployUtils.encodeAccountConfigs(newAccounts));
  }

  function test_RevertIf_IdenticalAccountIsAlreadyDeployed() public {
    LlamaAccount.Config[] memory newAccounts1 = new LlamaAccount.Config[](1);
    newAccounts1[0] = LlamaAccount.Config({name: "LlamaAccount1"});
    LlamaAccount.Config[] memory newAccounts2 = new LlamaAccount.Config[](1);
    newAccounts2[0] = LlamaAccount.Config({name: "LlamaAccount1"});

    vm.startPrank(address(mpExecutor));
    mpCore.createAccounts(accountLogic, DeployUtils.encodeAccountConfigs(newAccounts1));

    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createAccounts(accountLogic, DeployUtils.encodeAccountConfigs(newAccounts2));
  }

  function test_CanBeCalledByASuccessfulAction() public {
    LlamaAccount.Config[] memory newAccounts = new LlamaAccount.Config[](1);
    newAccounts[0] = LlamaAccount.Config({name: "LlamaAccount1"});
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    vm.prank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    ILlamaAccount accountAddress =
      lens.computeLlamaAccountAddress(address(accountLogic), DeployUtils.encodeAccount(newAccounts[0]), address(mpCore));

    bytes memory data =
      abi.encodeCall(LlamaCore.createAccounts, (accountLogic, DeployUtils.encodeAccountConfigs(newAccounts)));
    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(uint8(Roles.TestRole2), mpStrategy1, address(mpCore), 0, data, "");
    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAustin, uint8(Roles.TestRole2), mpStrategy1, address(mpCore), 0, data);

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionInfo);

    vm.warp(block.timestamp + 5 days);

    vm.expectEmit();
    emit AccountCreated(accountAddress, accountLogic, DeployUtils.encodeAccount(newAccounts[0]));
    mpCore.executeAction(actionInfo);
  }
}

contract SetGuard is LlamaCoreTest {
  event ActionGuardSet(address indexed target, bytes4 indexed selector, ILlamaActionGuard actionGuard);

  function testFuzz_RevertIf_CallerIsNotLlama(address caller, address target, bytes4 selector, ILlamaActionGuard guard)
    public
  {
    vm.assume(caller != address(mpExecutor));
    vm.expectRevert(LlamaCore.OnlyLlama.selector);
    vm.prank(caller);
    mpCore.setGuard(target, selector, guard);
  }

  function testFuzz_UpdatesGuardAndEmitsActionGuardSetEvent(address target, bytes4 selector, ILlamaActionGuard guard)
    public
  {
    vm.assume(target != address(mpCore) && target != address(mpPolicy));
    vm.prank(address(mpExecutor));
    vm.expectEmit();
    emit ActionGuardSet(target, selector, guard);
    mpCore.setGuard(target, selector, guard);
    assertEq(address(mpCore.actionGuard(target, selector)), address(guard));
  }

  function testFuzz_RevertIf_TargetIsCore(bytes4 selector, ILlamaActionGuard guard) public {
    vm.prank(address(mpExecutor));
    vm.expectRevert(LlamaCore.RestrictedAddress.selector);
    mpCore.setGuard(address(mpCore), selector, guard);
  }

  function testFuzz_RevertIf_TargetIsPolicy(bytes4 selector, ILlamaActionGuard guard) public {
    vm.prank(address(mpExecutor));
    vm.expectRevert(LlamaCore.RestrictedAddress.selector);
    mpCore.setGuard(address(mpPolicy), selector, guard);
  }
}

contract AuthorizeScript is LlamaCoreTest {
  function testFuzz_RevertIf_CallerIsNotLlama(address caller, address script, bool authorized) public {
    vm.assume(caller != address(mpExecutor));
    vm.expectRevert(LlamaCore.OnlyLlama.selector);
    vm.prank(caller);
    mpCore.authorizeScript(script, authorized);
  }

  function testFuzz_UpdatesScriptMappingAndEmitsScriptAuthorizedEvent(address script, bool authorized) public {
    vm.assume(script != address(mpCore) && script != address(mpPolicy) && script != address(mpExecutor));
    vm.prank(address(mpExecutor));
    vm.expectEmit();
    emit ScriptAuthorized(script, authorized);
    mpCore.authorizeScript(script, authorized);
    assertEq(mpCore.authorizedScripts(script), authorized);
  }

  function testFuzz_RevertIf_ScriptIsCore(bool authorized) public {
    vm.prank(address(mpExecutor));
    vm.expectRevert(LlamaCore.RestrictedAddress.selector);
    mpCore.authorizeScript(address(mpCore), authorized);
  }

  function testFuzz_RevertIf_ScriptIsPolicy(bool authorized) public {
    vm.prank(address(mpExecutor));
    vm.expectRevert(LlamaCore.RestrictedAddress.selector);
    mpCore.authorizeScript(address(mpPolicy), authorized);
  }
}

contract IncrementNonce is LlamaCoreTest {
  using stdStorage for StdStorage;

  function testFuzz_IncrementsNonceForAllCallersAndSelectors(address caller, bytes4 selector, uint256 initialNonce)
    public
  {
    initialNonce = bound(initialNonce, 0, type(uint256).max - 1);
    stdstore.target(address(mpCore)).sig(mpCore.nonces.selector).with_key(caller).with_key(selector).checked_write(
      initialNonce
    );

    assertEq(mpCore.nonces(caller, selector), initialNonce);
    vm.prank(caller);
    mpCore.incrementNonce(selector);
    assertEq(mpCore.nonces(caller, selector), initialNonce + 1);
  }
}

contract GetLastActionTimestamp is LlamaCoreTest {
  function test_ReturnsCorrectTimestamp() public {
    // Current block timestamp is 4, but no actions have been created yet, so we expect `t0 == 0`.
    uint256 t0 = mpCore.getLastActionTimestamp();
    assertEq(t0, 0);
    assertEq(block.timestamp, 4);

    // Now an action is created. It's created when the block timestamp is 4, so we expect `t1 == 4`.
    // The `_createAction()` helper method advances the timestamp by 1 second.
    _createAction();
    uint256 t1 = mpCore.getLastActionTimestamp();
    assertEq(t1, 4);
    assertEq(block.timestamp, 5);
  }
}

contract GetActionState is LlamaCoreTest {
  function testFuzz_RevertsOnInvalidAction(ActionInfo calldata actionInfo) public {
    vm.expectRevert(LlamaCore.InfoHashMismatch.selector);
    mpCore.getActionState(actionInfo);
  }

  function test_CanceledActionsHaveStateCanceled() public {
    ActionInfo memory actionInfo = _createAction();
    vm.prank(actionCreatorAaron);
    mpCore.cancelAction(actionInfo);

    uint256 currentState = uint256(mpCore.getActionState(actionInfo));
    uint256 canceledState = uint256(ActionState.Canceled);
    assertEq(currentState, canceledState);
  }

  function test_UnpassedActionsPriorToApprovalPeriodEndHaveStateActive() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    vm.startPrank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.stopPrank();

    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole2), mpStrategy2, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );

    ActionInfo memory actionInfo = ActionInfo(
      actionId,
      actionCreatorAustin,
      uint8(Roles.TestRole2),
      mpStrategy2,
      address(mockProtocol),
      0,
      abi.encodeCall(MockProtocol.pause, (true))
    );

    uint256 currentState = uint256(mpCore.getActionState(actionInfo));
    uint256 activeState = uint256(ActionState.Active);
    assertEq(currentState, activeState);
  }

  function test_ApprovedActionsWithFixedLengthHaveStateActive() public {
    ActionInfo memory actionInfo = _createAction();
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 1 days);

    uint256 currentState = uint256(mpCore.getActionState(actionInfo));
    uint256 activeState = uint256(ActionState.Active);
    assertEq(currentState, activeState);
  }

  function test_PassedActionsPriorToApprovalPeriodEndHaveStateApproved() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    vm.startPrank(address(mpExecutor));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.stopPrank();

    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole2), mpStrategy2, address(mockProtocol), 0, abi.encodeCall(MockProtocol.pause, (true)), ""
    );
    vm.warp(block.timestamp + 1);

    ActionInfo memory actionInfo = ActionInfo(
      actionId,
      actionCreatorAustin,
      uint8(Roles.TestRole2),
      mpStrategy2,
      address(mockProtocol),
      0,
      abi.encodeCall(MockProtocol.pause, (true))
    );

    uint256 currentState = uint256(mpCore.getActionState(actionInfo));
    uint256 activeState = uint256(ActionState.Active);
    assertEq(currentState, activeState);

    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);
    _approveAction(approverAndy, actionInfo);

    currentState = uint256(mpCore.getActionState(actionInfo));
    uint256 approvedState = uint256(ActionState.Approved);
    assertEq(currentState, approvedState);
  }

  function testFuzz_ApprovedActionsHaveStateApproved(uint256 _timeSinceCreation) public {
    ActionInfo memory actionInfo = _createAction();
    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    uint256 approvalEndTime = toRelativeQuorum(actionInfo.strategy).approvalEndTime(actionInfo);
    vm.assume(_timeSinceCreation < toRelativeQuorum(mpStrategy1).approvalPeriod() * 2);
    vm.warp(block.timestamp + _timeSinceCreation);

    uint256 currentState = uint256(mpCore.getActionState(actionInfo));
    uint256 expectedState = uint256(block.timestamp < approvalEndTime ? ActionState.Active : ActionState.Approved);
    assertEq(currentState, expectedState);
  }

  function test_QueuedActionsHaveStateQueued() public {
    ActionInfo memory actionInfo = _createAction();

    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionInfo), true);
    _queueAction(actionInfo);

    uint256 currentState = uint256(mpCore.getActionState(actionInfo));
    uint256 queuedState = uint256(ActionState.Queued);
    assertEq(currentState, queuedState);
  }

  function test_ExecutedActionsHaveStateExecuted() public {
    ActionInfo memory actionInfo = _createAction();

    _approveAction(approverAdam, actionInfo);
    _approveAction(approverAlicia, actionInfo);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionInfo), true);
    _queueAction(actionInfo);

    _disapproveAction(disapproverDave, actionInfo);

    vm.warp(block.timestamp + 5 days);

    _executeAction(actionInfo);

    uint256 currentState = uint256(mpCore.getActionState(actionInfo));
    uint256 executedState = uint256(ActionState.Executed);
    assertEq(currentState, executedState);
  }

  function test_RejectedActionsHaveStateFailed() public {
    ActionInfo memory actionInfo = _createAction();
    vm.warp(block.timestamp + 12 days);

    uint256 currentState = uint256(mpCore.getActionState(actionInfo));
    uint256 failedState = uint256(ActionState.Failed);
    assertEq(currentState, failedState);
  }
}

contract LlamaCoreHarness is LlamaCore {
  function infoHash_exposed(ActionInfo calldata actionInfo) external pure returns (bytes32) {
    return _infoHash(actionInfo);
  }

  function infoHash_exposed(
    uint256 id,
    address creator,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data
  ) external pure returns (bytes32) {
    return _infoHash(id, creator, role, strategy, target, value, data);
  }
}

contract InfoHash is LlamaCoreTest {
  LlamaCoreHarness llamaCoreHarness;

  function setUp() public override {
    llamaCoreHarness = new LlamaCoreHarness();
  }

  function testFuzz_InfoHashMethodsAreEquivalent(ActionInfo calldata actionInfo) public {
    bytes32 infoHash1 = llamaCoreHarness.infoHash_exposed(actionInfo);
    bytes32 infoHash2 = llamaCoreHarness.infoHash_exposed(
      actionInfo.id,
      actionInfo.creator,
      actionInfo.creatorRole,
      actionInfo.strategy,
      actionInfo.target,
      actionInfo.value,
      actionInfo.data
    );
    assertEq(infoHash1, infoHash2);
  }
}
