// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {Solarray} from "@solarray/Solarray.sol";

import {MockActionGuard} from "test/mock/MockActionGuard.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";
import {SolarrayLlama} from "test/utils/SolarrayLlama.sol";
import {LlamaCoreSigUtils} from "test/utils/LlamaCoreSigUtils.sol";
import {LlamaFactoryWithoutInitialization} from "test/utils/LlamaFactoryWithoutInitialization.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {IActionGuard} from "src/interfaces/IActionGuard.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, RelativeStrategyConfig, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RelativeStrategy} from "src/strategies/RelativeStrategy.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract LlamaCoreTest is LlamaTestSetup, LlamaCoreSigUtils {
  event ActionCreated(
    uint256 id,
    address indexed creator,
    ILlamaStrategy indexed strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes data
  );
  event ActionCanceled(uint256 id);
  event ActionQueued(
    uint256 id, address indexed caller, ILlamaStrategy indexed strategy, address indexed creator, uint256 executionTime
  );
  event ActionExecuted(
    uint256 id, address indexed caller, ILlamaStrategy indexed strategy, address indexed creator, bytes result
  );
  event ApprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event StrategyAuthorized(ILlamaStrategy indexed strategy, address indexed strategyLogic, bytes initializationData);
  event StrategyUnauthorized(ILlamaStrategy indexed strategy);
  event AccountCreated(LlamaAccount indexed account, string name);

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

  function _createAction() public returns (uint256 actionId) {
    vm.prank(actionCreatorAaron);
    actionId = mpCore.createAction(
      uint8(Roles.ActionCreator),
      mpStrategy1,
      address(mockProtocol),
      0, // value
      PAUSE_SELECTOR,
      abi.encode(true)
    );
    vm.warp(block.timestamp + 1);
  }

  function _approveAction(address _policyholder, uint256 _actionId) public {
    vm.expectEmit();
    emit ApprovalCast(_actionId, _policyholder, 1, "");
    vm.prank(_policyholder);
    mpCore.castApproval(_actionId, uint8(Roles.Approver));
  }

  function _approveAction(address _policyholder) public {
    uint256 _assumedActionId = 0;
    _approveAction(_policyholder, _assumedActionId);
  }

  function _disapproveAction(address _policyholder, uint256 _actionId) public {
    vm.expectEmit();
    emit DisapprovalCast(_actionId, _policyholder, 1, "");
    vm.prank(_policyholder);
    mpCore.castDisapproval(_actionId, uint8(Roles.Disapprover));
  }

  function _disapproveAction(address _policyholder) public {
    uint256 _assumedActionId = 0;
    _disapproveAction(_policyholder, _assumedActionId);
  }

  function _queueAction(uint256 _actionId) public {
    uint256 executionTime = block.timestamp + toRelativeStrategy(mpStrategy1).queuingPeriod();
    vm.expectEmit();
    emit ActionQueued(_actionId, address(this), mpStrategy1, actionCreatorAaron, executionTime);
    mpCore.queueAction(_actionId);
  }

  function _queueAction() public {
    uint256 _assumedActionId = 0;
    _queueAction(_assumedActionId);
  }

  function _executeAction() public {
    vm.expectEmit();
    emit ActionExecuted(0, address(this), mpStrategy1, actionCreatorAaron, bytes(""));
    mpCore.executeAction(0);

    Action memory action = mpCore.getAction(0);
    assertEq(action.executed, true);
  }

  function _executeCompleteActionFlow() internal {
    _createAction();

    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(0), true);
    _queueAction();

    vm.warp(block.timestamp + 5 days);

    _executeAction();
  }

  function _deployAndAuthorizeAdditionalStrategyLogic() internal returns (address) {
    RelativeStrategy additionalStrategyLogic = new RelativeStrategy();
    vm.prank(address(rootCore));
    factory.authorizeStrategyLogic(additionalStrategyLogic);
    return address(additionalStrategyLogic);
  }

  function _createStrategy(uint256 salt, bool isFixedLengthApprovalPeriod)
    internal
    pure
    returns (RelativeStrategyConfig memory)
  {
    return RelativeStrategyConfig({
      approvalPeriod: salt % 1000 days,
      queuingPeriod: salt % 1001 days,
      expirationPeriod: salt % 1002 days,
      isFixedLengthApprovalPeriod: isFixedLengthApprovalPeriod,
      minApprovalPct: salt % 10_000,
      minDisapprovalPct: salt % 10_100,
      approvalRole: uint8(Roles.Approver),
      disapprovalRole: uint8(Roles.Disapprover),
      forceApprovalRoles: new uint8[](0),
      forceDisapprovalRoles: new uint8[](0)
    });
  }
}

contract Setup is LlamaCoreTest {
  function test_setUp() public {
    assertEq(address(mpCore.factory()), address(factory));
    assertEq(mpCore.name(), "Mock Protocol Llama");
    assertEq(address(mpCore.policy()), address(mpPolicy));
    assertEq(address(mpCore.llamaAccountLogic()), address(accountLogic));

    assertTrue(mpCore.authorizedStrategies(mpStrategy1));
    assertTrue(mpCore.authorizedStrategies(mpStrategy1));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount1.initialize("LlamaAccount0");

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount2.initialize("LlamaAccount1");
  }
}

contract Initialize is LlamaCoreTest {
  function deployWithoutInitialization()
    internal
    returns (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore llama, LlamaPolicy policy)
  {
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account 1", "Account 2", "Account 3");
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);
    modifiedFactory = new LlamaFactoryWithoutInitialization(
      coreLogic,
      relativeStrategyLogic,
      accountLogic,
      policyLogic,
      policyTokenURI,
      "Root Llama",
      strategyConfigs,
      accounts,
      SolarrayLlama.roleDescription("AllHolders","ActionCreator","Approver","Disapprover","TestRole1","TestRole2","MadeUpRole"),
      roleHolders,
      new RolePermissionData[](0)
    );

    (llama, policy) = modifiedFactory.deployWithoutInitialization(
      "NewProject",
      SolarrayLlama.roleDescription(
        "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
      ),
      roleHolders,
      new RolePermissionData[](0)
    );
  }

  function test_StrategiesAreDeployedAtExpectedAddress() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](2);
    for (uint256 i; i < strategyConfigs.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeStrategyLogic), strategyConfigs[i], address(uninitializedLlama)
      );
    }

    assertEq(address(strategyAddresses[0]).code.length, 0);
    assertEq(address(strategyAddresses[1]).code.length, 0);

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeStrategyLogic, accountLogic, strategyConfigs, accounts
    );

    assertGt(address(strategyAddresses[0]).code.length, 0);
    assertGt(address(strategyAddresses[1]).code.length, 0);
  }

  function test_EmitsStrategyAuthorizedEventForEachStrategy() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](2);
    for (uint256 i; i < strategyConfigs.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeStrategyLogic), strategyConfigs[i], address(uninitializedLlama)
      );
    }

    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[0], address(relativeStrategyLogic), strategyConfigs[0]);
    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[1], address(relativeStrategyLogic), strategyConfigs[1]);

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeStrategyLogic, accountLogic, strategyConfigs, accounts
    );
  }

  function test_StrategiesHaveLlamaCoreAddressInStorage() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](2);
    for (uint256 i; i < strategyConfigs.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeStrategyLogic), strategyConfigs[i], address(uninitializedLlama)
      );
    }

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeStrategyLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(address(strategyAddresses[0].llamaCore()), address(uninitializedLlama));
    assertEq(address(strategyAddresses[1].llamaCore()), address(uninitializedLlama));
  }

  function test_StrategiesHavePolicyAddressInStorage() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](2);
    for (uint256 i; i < strategyConfigs.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeStrategyLogic), strategyConfigs[i], address(uninitializedLlama)
      );
    }

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeStrategyLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(address(strategyAddresses[0].policy()), address(policy));
    assertEq(address(strategyAddresses[1].policy()), address(policy));
  }

  function test_StrategiesAreAuthorizedByLlamaCore() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](2);
    for (uint256 i; i < strategyConfigs.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeStrategyLogic), strategyConfigs[i], address(uninitializedLlama)
      );
    }

    assertEq(uninitializedLlama.authorizedStrategies(strategyAddresses[0]), false);
    assertEq(uninitializedLlama.authorizedStrategies(strategyAddresses[1]), false);

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeStrategyLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(uninitializedLlama.authorizedStrategies(strategyAddresses[0]), true);
    assertEq(uninitializedLlama.authorizedStrategies(strategyAddresses[1]), true);
  }

  function testFuzz_RevertIf_StrategyLogicIsNotAuthorized(address notStrategyLogic) public {
    vm.assume(notStrategyLogic != address(relativeStrategyLogic));
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");

    vm.expectRevert(LlamaCore.UnauthorizedStrategyLogic.selector);
    modifiedFactory.initialize(
      uninitializedLlama,
      policy,
      "NewProject",
      ILlamaStrategy(notStrategyLogic),
      LlamaAccount(accountLogic),
      strategyConfigs,
      accounts
    );
  }

  function test_AccountsAreDeployedAtExpectedAddress() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    LlamaAccount[] memory accountAddresses = new LlamaAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeLlamaAccountAddress(address(accountLogic), accounts[i], address(uninitializedLlama));
    }

    assertEq(address(accountAddresses[0]).code.length, 0);
    assertEq(address(accountAddresses[1]).code.length, 0);

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeStrategyLogic, accountLogic, strategyConfigs, accounts
    );

    assertGt(address(accountAddresses[0]).code.length, 0);
    assertGt(address(accountAddresses[1]).code.length, 0);
  }

  function test_EmitsAccountCreatedEventForEachAccount() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    LlamaAccount[] memory accountAddresses = new LlamaAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeLlamaAccountAddress(address(accountLogic), accounts[i], address(uninitializedLlama));
    }

    vm.expectEmit();
    emit AccountCreated(accountAddresses[0], accounts[0]);
    vm.expectEmit();
    emit AccountCreated(accountAddresses[1], accounts[1]);
    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeStrategyLogic, accountLogic, strategyConfigs, accounts
    );
  }

  function test_AccountsHaveLlamaCoreAddressInStorage() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    LlamaAccount[] memory accountAddresses = new LlamaAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeLlamaAccountAddress(address(accountLogic), accounts[i], address(uninitializedLlama));
    }

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeStrategyLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(address(accountAddresses[0].llamaCore()), address(uninitializedLlama));
    assertEq(address(accountAddresses[1].llamaCore()), address(uninitializedLlama));
  }

  function test_AccountsHaveNameInStorage() public {
    (LlamaFactoryWithoutInitialization modifiedFactory, LlamaCore uninitializedLlama, LlamaPolicy policy) =
      deployWithoutInitialization();
    bytes[] memory strategyConfigs = relativeStrategyConfigs();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    LlamaAccount[] memory accountAddresses = new LlamaAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeLlamaAccountAddress(address(accountLogic), accounts[i], address(uninitializedLlama));
    }

    modifiedFactory.initialize(
      uninitializedLlama, policy, "NewProject", relativeStrategyLogic, accountLogic, strategyConfigs, accounts
    );

    assertEq(accountAddresses[0].name(), "Account1");
    assertEq(accountAddresses[1].name(), "Account2");
  }
}

contract CreateAction is LlamaCoreTest {
  function test_CreatesAnAction() public {
    vm.expectEmit();
    emit ActionCreated(0, actionCreatorAaron, mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));
    vm.prank(actionCreatorAaron);
    uint256 _actionId = mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );

    Action memory action = mpCore.getAction(_actionId);
    uint256 approvalPeriodEnd = toRelativeStrategy(action.strategy).approvalEndTime(_actionId);

    assertEq(_actionId, 0);
    assertEq(mpCore.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(approvalPeriodEnd, block.timestamp + 2 days);
    assertEq(toRelativeStrategy(action.strategy).actionApprovalSupply(_actionId), 3);
    assertEq(toRelativeStrategy(action.strategy).actionDisapprovalSupply(_actionId), 3);
  }

  function testFuzz_CreatesAnAction(address _target, uint256 _value, bytes memory _data) public {
    vm.assume(_target != address(mockProtocol));

    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    vm.prank(actionCreatorAaron);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(_target), _value, PAUSE_SELECTOR, abi.encode(_data)
    );
  }

  function test_RevertIf_ActionGuardProhibitsAction() public {
    IActionGuard guard = IActionGuard(new MockActionGuard(false, true, true, "no action creation"));
    bytes memory expectedErr = bytes.concat(LlamaCore.ProhibitedByActionGuard.selector, bytes32("no action creation"));

    vm.prank(address(mpCore));
    mpCore.setGuard(address(mockProtocol), PAUSE_SELECTOR, guard);

    vm.prank(actionCreatorAaron);
    vm.expectRevert(expectedErr);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function test_RevertIf_StrategyUnauthorized() public {
    ILlamaStrategy unauthorizedStrategy = ILlamaStrategy(makeAddr("unauthorized strategy"));
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.InvalidStrategy.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), unauthorizedStrategy, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function test_RevertIf_StrategyIsFromAnotherLlama() public {
    ILlamaStrategy unauthorizedStrategy = rootStrategy1;
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.InvalidStrategy.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), unauthorizedStrategy, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function testFuzz_RevertIf_PolicyholderNotMinted(address policyholder) public {
    if (policyholder == address(0)) policyholder = address(100); // Faster than vm.assume, since 0 comes up a lot.
    vm.assume(mpPolicy.balanceOf(policyholder) == 0);
    vm.prank(policyholder);
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function test_RevertIf_NoPermissionForStrategy() public {
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy2, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function testFuzz_RevertIf_NoPermissionForTarget(address _incorrectTarget) public {
    vm.assume(_incorrectTarget != address(mockProtocol));
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, _incorrectTarget, 0, PAUSE_SELECTOR, abi.encode(true));
  }

  function testFuzz_RevertIf_BadPermissionForSelector(bytes4 _badSelector) public {
    vm.assume(_badSelector != PAUSE_SELECTOR && _badSelector != FAIL_SELECTOR && _badSelector != RECEIVE_ETH_SELECTOR);
    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, _badSelector, abi.encode(true)
    );
  }

  function testFuzz_RevertIf_PermissionExpired(uint64 _expirationTimestamp) public {
    vm.assume(_expirationTimestamp > block.timestamp + 1 && _expirationTimestamp < type(uint64).max - 1);
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.ActionCreator), actionCreatorAustin, DEFAULT_ROLE_QTY, _expirationTimestamp);
    vm.stopPrank();

    vm.prank(address(actionCreatorAustin));
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );

    vm.warp(_expirationTimestamp + 1);
    mpPolicy.revokeExpiredRole(uint8(Roles.ActionCreator), actionCreatorAustin);

    vm.startPrank(address(actionCreatorAustin));
    vm.expectRevert(LlamaCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }
}

contract CreateActionBySig is LlamaCoreTest {
  function createOffchainSignature(uint256 privateKey) internal view returns (uint8 v, bytes32 r, bytes32 s) {
    LlamaCoreSigUtils.CreateAction memory createAction = LlamaCoreSigUtils.CreateAction({
      role: uint8(Roles.ActionCreator),
      strategy: address(mpStrategy1),
      target: address(mockProtocol),
      value: 0,
      selector: PAUSE_SELECTOR,
      data: abi.encode(true),
      policyholder: actionCreatorAaron,
      nonce: 0
    });
    bytes32 digest = getCreateActionTypedDataHash(createAction);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function createActionBySig(uint8 v, bytes32 r, bytes32 s) internal returns (uint256 actionId) {
    actionId = mpCore.createActionBySig(
      uint8(Roles.ActionCreator),
      mpStrategy1,
      address(mockProtocol),
      0,
      PAUSE_SELECTOR,
      abi.encode(true),
      actionCreatorAaron,
      v,
      r,
      s
    );
  }

  function test_CreatesActionBySig() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionCreatorAaronPrivateKey);

    vm.expectEmit();
    emit ActionCreated(0, actionCreatorAaron, mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));

    uint256 _actionId = createActionBySig(v, r, s);

    Action memory action = mpCore.getAction(_actionId);
    uint256 approvalPeriodEnd = toRelativeStrategy(action.strategy).approvalEndTime(_actionId);

    assertEq(_actionId, 0);
    assertEq(mpCore.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(approvalPeriodEnd, block.timestamp + 2 days);
    assertEq(toRelativeStrategy(action.strategy).actionApprovalSupply(_actionId), 3);
    assertEq(toRelativeStrategy(action.strategy).actionDisapprovalSupply(_actionId), 3);
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
}

contract CancelAction is LlamaCoreTest {
  function setUp() public override {
    LlamaCoreTest.setUp();
    _createAction();
  }

  function test_CreatorCancelFlow() public {
    vm.prank(actionCreatorAaron);
    vm.expectEmit();
    emit ActionCanceled(0);
    mpCore.cancelAction(0);

    uint256 state = uint256(mpCore.getActionState(0));
    uint256 canceled = uint256(ActionState.Canceled);
    assertEq(state, canceled);
  }

  function testFuzz_RevertIf_NotCreator(address _randomCaller) public {
    vm.assume(_randomCaller != actionCreatorAaron);
    vm.prank(_randomCaller);
    vm.expectRevert(LlamaCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }

  function testFuzz_RevertIf_InvalidActionId(uint256 invalidActionId) public {
    invalidActionId = bound(invalidActionId, mpCore.actionsCount(), type(uint256).max);
    vm.prank(actionCreatorAaron);
    // We expect a low-level revert with no error message because if the action doesn't exist the strategy will be the
    // zero address, and Solidity will revert when the `isActionCancelationValid` call has no return data.
    vm.expectRevert();
    mpCore.cancelAction(invalidActionId);
  }

  function test_RevertIf_AlreadyCanceled() public {
    vm.startPrank(actionCreatorAaron);
    mpCore.cancelAction(0);
    vm.expectRevert(LlamaCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }

  function test_RevertIf_ActionExecuted() public {
    _executeCompleteActionFlow();

    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }

  function test_RevertIf_ActionExpired() public {
    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(0), true);
    _queueAction();

    _disapproveAction(disapproverDave);

    vm.warp(block.timestamp + 15 days);

    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }

  function test_RevertIf_ActionFailed() public {
    _approveAction(approverAdam);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(0), false);

    vm.expectRevert(LlamaCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }

  function test_RevertIf_DisapprovalDoesNotReachQuorum() public {
    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(0), true);
    _queueAction();

    vm.expectRevert(LlamaCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }
}

contract QueueAction is LlamaCoreTest {
  function test_RevertIf_NotApproved() public {
    _createAction();
    _approveAction(approverAdam);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(abi.encodePacked(LlamaCore.InvalidActionState.selector, uint256(ActionState.Approved)));
    mpCore.queueAction(0);
  }

  function testFuzz_RevertIf_InvalidActionId(uint256 invalidActionId) public {
    bound(invalidActionId, mpCore.actionsCount(), type(uint256).max);
    _createAction();
    _approveAction(approverAdam);
    _approveAction(approverAlicia);
    _approveAction(approverAndy);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(LlamaCore.InvalidActionId.selector);
    mpCore.queueAction(1);
  }
}

contract ExecuteAction is LlamaCoreTest {
  uint256 actionId;

  function setUp() public override {
    LlamaCoreTest.setUp();

    actionId = _createAction();
    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionId), true);
  }

  function test_ActionExecution() public {
    mpCore.queueAction(0);
    vm.warp(block.timestamp + 6 days);

    vm.expectEmit();
    emit ActionExecuted(0, address(this), mpStrategy1, actionCreatorAaron, bytes(""));
    mpCore.executeAction(0);
  }

  function test_ScriptsAlwaysUseDelegatecall() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    vm.prank(address(mpCore));
    mpCore.authorizeScript(address(mockScript), true);

    vm.prank(actionCreatorAustin);
    actionId = mpCore.createAction(
      uint8(Roles.TestRole2),
      mpStrategy1,
      address(mockScript),
      0, // value
      EXECUTE_SCRIPT_SELECTOR,
      abi.encode("")
    );

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectEmit();
    // Checking that the result is a delegatecall because msg.sender is this contract and not mpCore
    emit ActionExecuted(actionId, address(this), mpStrategy1, actionCreatorAustin, abi.encode(address(this)));
    mpCore.executeAction(actionId);
  }

  function test_RevertIf_NotQueued() public {
    vm.expectRevert(abi.encodePacked(LlamaCore.InvalidActionState.selector, uint256(ActionState.Queued)));
    mpCore.executeAction(actionId);

    // Check that it's in the Approved state
    assertEq(uint256(mpCore.getActionState(0)), uint256(3));
  }

  function test_RevertIf_ActionGuardProhibitsActionPreExecution() public {
    IActionGuard guard = IActionGuard(new MockActionGuard(true, false, true, "no action pre-execution"));
    bytes memory expectedErr =
      bytes.concat(LlamaCore.ProhibitedByActionGuard.selector, bytes32("no action pre-execution"));

    vm.prank(address(mpCore));
    mpCore.setGuard(address(mockProtocol), PAUSE_SELECTOR, guard);

    mpCore.queueAction(0);
    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(expectedErr);
    mpCore.executeAction(0);
  }

  function test_RevertIf_ActionGuardProhibitsActionPostExecution() public {
    IActionGuard guard = IActionGuard(new MockActionGuard(true, true, false, "no action post-execution"));
    bytes memory expectedErr =
      bytes.concat(LlamaCore.ProhibitedByActionGuard.selector, bytes32("no action post-execution"));

    vm.prank(address(mpCore));
    mpCore.setGuard(address(mockProtocol), PAUSE_SELECTOR, guard);

    mpCore.queueAction(0);
    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(expectedErr);
    mpCore.executeAction(0);
  }

  function testFuzz_RevertIf_InvalidActionId(uint256 invalidActionId) public {
    bound(invalidActionId, mpCore.actionsCount(), type(uint256).max);
    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(LlamaCore.InvalidActionId.selector);
    mpCore.executeAction(actionId + 1);
  }

  function testFuzz_RevertIf_TimelockNotFinished(uint256 timeElapsed) public {
    // Using a reasonable upper limit for elapsedTime
    vm.assume(timeElapsed < 10_000 days);
    mpCore.queueAction(actionId);
    uint256 executionTime = mpCore.getAction(actionId).minExecutionTime;

    vm.warp(block.timestamp + timeElapsed);

    if (executionTime > block.timestamp) {
      vm.expectRevert(LlamaCore.TimelockNotFinished.selector);
      mpCore.executeAction(actionId);
    }
  }

  function test_RevertIf_InsufficientMsgValue() public {
    vm.prank(actionCreatorAaron);
    actionId = mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 1e18, RECEIVE_ETH_SELECTOR, abi.encode(true)
    );
    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(LlamaCore.InsufficientMsgValue.selector);
    mpCore.executeAction(actionId);
  }

  function test_RevertIf_FailedActionExecution() public {
    vm.prank(actionCreatorAaron);
    actionId = mpCore.createAction(
      uint8(Roles.ActionCreator),
      mpStrategy1,
      address(mockProtocol),
      0, // value
      FAIL_SELECTOR,
      abi.encode("")
    );
    bytes memory expectedErr = abi.encodeWithSelector(
      LlamaCore.FailedActionExecution.selector, abi.encodeWithSelector(MockProtocol.Failed.selector)
    );

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(actionId), true);

    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(expectedErr);
    mpCore.executeAction(actionId);
  }

  function test_HandlesReentrancy() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");
    bytes memory expectedErr = abi.encodeWithSelector(
      LlamaCore.FailedActionExecution.selector,
      abi.encodeWithSelector(LlamaCore.InvalidActionState.selector, (ActionState.Queued))
    );

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.stopPrank();

    vm.prank(actionCreatorAustin);
    actionId = mpCore.createAction(
      uint8(Roles.TestRole2),
      mpStrategy1,
      address(mpCore),
      0, // value
      EXECUTE_ACTION_SELECTOR,
      abi.encode(actionId)
    );

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(expectedErr);
    mpCore.executeAction(actionId);
  }
}

contract CastApproval is LlamaCoreTest {
  uint256 actionId;

  function test_SuccessfulApproval() public {
    actionId = _createAction();
    _approveAction(approverAdam, actionId);
    assertEq(mpCore.getAction(0).totalApprovals, 1);
    assertEq(mpCore.approvals(0, approverAdam), true);
  }

  function test_SuccessfulApprovalWithReason(string calldata reason) public {
    actionId = _createAction();
    vm.expectEmit();
    emit ApprovalCast(actionId, approverAdam, 1, reason);
    vm.prank(approverAdam);
    mpCore.castApproval(actionId, uint8(Roles.Approver), reason);
  }

  function test_RevertIf_ActionNotActive() public {
    actionId = _createAction();
    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionId);

    vm.expectRevert(abi.encodePacked(LlamaCore.InvalidActionState.selector, uint256(ActionState.Active)));
    mpCore.castApproval(actionId, uint8(Roles.Approver));
  }

  function test_RevertIf_DuplicateApproval() public {
    actionId = _createAction();
    _approveAction(approverAdam, actionId);

    vm.expectRevert(LlamaCore.DuplicateCast.selector);
    vm.prank(approverAdam);
    mpCore.castApproval(actionId, uint8(Roles.Approver));
  }

  function test_RevertIf_InvalidPolicyholder() public {
    actionId = _createAction();
    address notPolicyholder = 0x9D3de545F58C696946b4Cf2c884fcF4f7914cB53;
    vm.prank(notPolicyholder);

    vm.expectRevert(LlamaCore.InvalidPolicyholder.selector);
    mpCore.castApproval(actionId, uint8(Roles.Approver));

    vm.prank(approverAdam);
    mpCore.castApproval(actionId, uint8(Roles.Approver));
  }
}

contract CastApprovalBySig is LlamaCoreTest {
  function createOffchainSignature(uint256 _actionId, uint256 privateKey)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    LlamaCoreSigUtils.CastApproval memory castApproval = LlamaCoreSigUtils.CastApproval({
      actionId: _actionId,
      role: uint8(Roles.Approver),
      reason: "",
      policyholder: approverAdam,
      nonce: 0
    });
    bytes32 digest = getCastApprovalTypedDataHash(castApproval);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function castApprovalBySig(uint256 actionId, uint8 v, bytes32 r, bytes32 s) internal {
    mpCore.castApprovalBySig(actionId, uint8(Roles.Approver), "", approverAdam, v, r, s);
  }

  function test_CastsApprovalBySig() public {
    uint256 actionId = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, approverAdamPrivateKey);

    vm.expectEmit();
    emit ApprovalCast(actionId, approverAdam, 1, "");

    castApprovalBySig(actionId, v, r, s);

    assertEq(mpCore.getAction(0).totalApprovals, 1);
    assertEq(mpCore.approvals(0, approverAdam), true);
  }

  function test_CheckNonceIncrements() public {
    uint256 actionId = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, approverAdamPrivateKey);

    assertEq(mpCore.nonces(approverAdam, LlamaCore.castApprovalBySig.selector), 0);
    castApprovalBySig(actionId, v, r, s);
    assertEq(mpCore.nonces(approverAdam, LlamaCore.castApprovalBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    uint256 actionId = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, approverAdamPrivateKey);
    castApprovalBySig(actionId, v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castApprovalBySig(actionId, v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    uint256 actionId = _createAction();

    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address is not the same as the policyholder passed in as
    // parameter.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castApprovalBySig(actionId, v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    uint256 actionId = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, approverAdamPrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castApprovalBySig(actionId, (v + 1), r, s);
  }
}

contract CastDisapproval is LlamaCoreTest {
  uint256 actionId;

  function _createApproveAndQueueAction() internal returns (uint256 _actionId) {
    _actionId = _createAction();
    _approveAction(approverAdam, _actionId);
    _approveAction(approverAlicia, _actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(_actionId), true);
    _queueAction(_actionId);
  }

  function test_SuccessfulDisapproval() public {
    actionId = _createApproveAndQueueAction();

    vm.prank(disapproverDrake);
    vm.expectEmit();
    emit DisapprovalCast(actionId, disapproverDrake, 1, "");

    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));

    assertEq(mpCore.getAction(0).totalDisapprovals, 1);
    assertEq(mpCore.disapprovals(0, disapproverDrake), true);
  }

  function test_SuccessfulDisapprovalWithReason(string calldata reason) public {
    actionId = _createApproveAndQueueAction();
    vm.expectEmit();
    emit DisapprovalCast(actionId, disapproverDrake, 1, reason);
    vm.prank(disapproverDrake);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover), reason);
  }

  function test_RevertIf_ActionNotQueued() public {
    actionId = _createAction();

    vm.expectRevert(abi.encodePacked(LlamaCore.InvalidActionState.selector, uint256(ActionState.Queued)));
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));
  }

  function test_RevertIf_InvalidPolicyholder() public {
    actionId = _createApproveAndQueueAction();
    address notPolicyholder = 0x9D3de545F58C696946b4Cf2c884fcF4f7914cB53;
    vm.prank(notPolicyholder);

    vm.expectRevert(LlamaCore.InvalidPolicyholder.selector);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));

    vm.prank(disapproverDrake);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));
  }

  function test_FailsIfDisapproved() public {
    actionId = _createApproveAndQueueAction();

    vm.prank(disapproverDave);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover)); // since the disapproval pct is 20%, one disapproval is
      // all that is needed for the action to fail

    ActionState state = mpCore.getActionState(actionId);
    assertEq(uint8(state), uint8(ActionState.Failed));

    vm.expectRevert(abi.encodeWithSelector(LlamaCore.InvalidActionState.selector, ActionState.Queued));
    mpCore.executeAction(actionId);
  }
}

contract CastDisapprovalBySig is LlamaCoreTest {
  function createOffchainSignature(uint256 _actionId, uint256 privateKey)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    LlamaCoreSigUtils.CastDisapproval memory castDisapproval = LlamaCoreSigUtils.CastDisapproval({
      actionId: _actionId,
      role: uint8(Roles.Disapprover),
      reason: "",
      policyholder: disapproverDrake,
      nonce: 0
    });
    bytes32 digest = getCastDisapprovalTypedDataHash(castDisapproval);
    (v, r, s) = vm.sign(privateKey, digest);
  }

  function castDisapprovalBySig(uint256 actionId, uint8 v, bytes32 r, bytes32 s) internal {
    mpCore.castDisapprovalBySig(actionId, uint8(Roles.Disapprover), "", disapproverDrake, v, r, s);
  }

  function _createApproveAndQueueAction() internal returns (uint256 _actionId) {
    _actionId = _createAction();
    _approveAction(approverAdam, _actionId);
    _approveAction(approverAlicia, _actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(_actionId), true);
    _queueAction(_actionId);
  }

  function test_CastsDisapprovalBySig() public {
    uint256 actionId = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, disapproverDrakePrivateKey);

    vm.expectEmit();
    emit DisapprovalCast(actionId, disapproverDrake, 1, "");

    castDisapprovalBySig(actionId, v, r, s);

    assertEq(mpCore.getAction(0).totalDisapprovals, 1);
    assertEq(mpCore.disapprovals(0, disapproverDrake), true);
  }

  function test_CheckNonceIncrements() public {
    uint256 actionId = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, disapproverDrakePrivateKey);

    assertEq(mpCore.nonces(disapproverDrake, LlamaCore.castDisapprovalBySig.selector), 0);
    castDisapprovalBySig(actionId, v, r, s);
    assertEq(mpCore.nonces(disapproverDrake, LlamaCore.castDisapprovalBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    uint256 actionId = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, disapproverDrakePrivateKey);
    castDisapprovalBySig(actionId, v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castDisapprovalBySig(actionId, v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    uint256 actionId = _createApproveAndQueueAction();

    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castDisapprovalBySig(actionId, v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    uint256 actionId = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, disapproverDrakePrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(LlamaCore.InvalidSignature.selector);
    castDisapprovalBySig(actionId, (v + 1), r, s);
  }

  function test_FailsIfDisapproved() public {
    uint256 actionId = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, disapproverDrakePrivateKey);

    vm.expectEmit();
    emit DisapprovalCast(actionId, disapproverDrake, 1, "");

    castDisapprovalBySig(actionId, v, r, s);

    assertEq(mpCore.getAction(actionId).totalDisapprovals, 1);

    ActionState state = mpCore.getActionState(actionId);
    assertEq(uint8(state), uint8(ActionState.Failed));

    vm.expectRevert(abi.encodeWithSelector(LlamaCore.InvalidActionState.selector, ActionState.Queued));
    mpCore.executeAction(actionId);
  }
}

contract CreateAndAuthorizeStrategies is LlamaCoreTest {
  function testFuzz_RevertIf_CallerIsNotLlama(address caller) public {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(LlamaCore.OnlyLlama.selector);
    RelativeStrategyConfig[] memory newStrategies = new RelativeStrategyConfig[](3);

    vm.prank(caller);
    mpCore.createAndAuthorizeStrategies(relativeStrategyLogic, encodeStrategyConfigs(newStrategies));
  }

  function test_CreateNewStrategies(uint256 salt1, uint256 salt2, uint256 salt3, bool isFixedLengthApprovalPeriod)
    public
  {
    RelativeStrategyConfig[] memory newStrategies = new RelativeStrategyConfig[](3);
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);
    vm.assume(salt1 != salt2);
    vm.assume(salt1 != salt3);
    vm.assume(salt2 != salt3);

    newStrategies[0] = _createStrategy(salt1, isFixedLengthApprovalPeriod);
    newStrategies[1] = _createStrategy(salt2, isFixedLengthApprovalPeriod);
    newStrategies[2] = _createStrategy(salt3, isFixedLengthApprovalPeriod);

    for (uint256 i; i < newStrategies.length; i++) {
      strategyAddresses[i] = lens.computeLlamaStrategyAddress(
        address(relativeStrategyLogic), encodeStrategy(newStrategies[i]), address(mpCore)
      );
    }

    vm.startPrank(address(mpCore));

    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[0], address(relativeStrategyLogic), encodeStrategy(newStrategies[0]));
    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[1], address(relativeStrategyLogic), encodeStrategy(newStrategies[1]));
    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[2], address(relativeStrategyLogic), encodeStrategy(newStrategies[2]));

    mpCore.createAndAuthorizeStrategies(relativeStrategyLogic, encodeStrategyConfigs(newStrategies));

    assertEq(mpCore.authorizedStrategies(strategyAddresses[0]), true);
    assertEq(mpCore.authorizedStrategies(strategyAddresses[1]), true);
    assertEq(mpCore.authorizedStrategies(strategyAddresses[2]), true);
  }

  function test_CreateNewStrategiesWithAdditionalStrategyLogic() public {
    address additionalStrategyLogic = _deployAndAuthorizeAdditionalStrategyLogic();

    RelativeStrategyConfig[] memory newStrategies = new RelativeStrategyConfig[](3);
    ILlamaStrategy[] memory strategyAddresses = new ILlamaStrategy[](3);

    newStrategies[0] = RelativeStrategyConfig({
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

    newStrategies[1] = RelativeStrategyConfig({
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

    newStrategies[2] = RelativeStrategyConfig({
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

    for (uint256 i; i < newStrategies.length; i++) {
      strategyAddresses[i] =
        lens.computeLlamaStrategyAddress(additionalStrategyLogic, encodeStrategy(newStrategies[i]), address(mpCore));
    }

    vm.startPrank(address(mpCore));

    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[0], additionalStrategyLogic, encodeStrategy(newStrategies[0]));
    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[1], additionalStrategyLogic, encodeStrategy(newStrategies[1]));
    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[2], additionalStrategyLogic, encodeStrategy(newStrategies[2]));

    mpCore.createAndAuthorizeStrategies(ILlamaStrategy(additionalStrategyLogic), encodeStrategyConfigs(newStrategies));

    assertEq(mpCore.authorizedStrategies(strategyAddresses[0]), true);
    assertEq(mpCore.authorizedStrategies(strategyAddresses[1]), true);
    assertEq(mpCore.authorizedStrategies(strategyAddresses[2]), true);
  }

  function test_RevertIf_StrategyLogicNotAuthorized() public {
    RelativeStrategyConfig[] memory newStrategies = new RelativeStrategyConfig[](1);

    newStrategies[0] = RelativeStrategyConfig({
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

    vm.startPrank(address(mpCore));

    vm.expectRevert(LlamaCore.UnauthorizedStrategyLogic.selector);
    mpCore.createAndAuthorizeStrategies(ILlamaStrategy(randomLogicAddress), encodeStrategyConfigs(newStrategies));
  }

  function test_RevertIf_StrategiesAreIdentical() public {
    RelativeStrategyConfig[] memory newStrategies = new RelativeStrategyConfig[](2);

    RelativeStrategyConfig memory duplicateStrategy = RelativeStrategyConfig({
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

    vm.startPrank(address(mpCore));

    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createAndAuthorizeStrategies(relativeStrategyLogic, encodeStrategyConfigs(newStrategies));
  }

  function test_RevertIf_IdenticalStrategyIsAlreadyDeployed() public {
    RelativeStrategyConfig[] memory newStrategies1 = new RelativeStrategyConfig[](1);
    RelativeStrategyConfig[] memory newStrategies2 = new RelativeStrategyConfig[](1);

    RelativeStrategyConfig memory duplicateStrategy = RelativeStrategyConfig({
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

    vm.startPrank(address(mpCore));
    mpCore.createAndAuthorizeStrategies(relativeStrategyLogic, encodeStrategyConfigs(newStrategies1));

    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createAndAuthorizeStrategies(relativeStrategyLogic, encodeStrategyConfigs(newStrategies2));
  }

  function test_CanBeCalledByASuccessfulAction() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    RelativeStrategyConfig[] memory newStrategies = new RelativeStrategyConfig[](1);

    newStrategies[0] = RelativeStrategyConfig({
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
      address(relativeStrategyLogic), encodeStrategy(newStrategies[0]), address(mpCore)
    );

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole2),
      mpStrategy1,
      address(mpCore),
      0, // value
      CREATE_STRATEGY_SELECTOR,
      abi.encode(address(relativeStrategyLogic), encodeStrategyConfigs(newStrategies))
    );

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    mpCore.executeAction(actionId);

    assertEq(mpCore.authorizedStrategies(strategyAddress), true);
  }
}

contract UnauthorizeStrategies is LlamaCoreTest {
  function testFuzz_RevertIf_CallerIsNotLlama(address caller) public {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(LlamaCore.OnlyLlama.selector);
    ILlamaStrategy[] memory strategies = new ILlamaStrategy[](0);

    vm.prank(caller);
    mpCore.unauthorizeStrategies(strategies);
  }

  function test_UnauthorizeStrategies() public {
    vm.startPrank(address(mpCore));
    assertEq(mpCore.authorizedStrategies(mpStrategy1), true);
    assertEq(mpCore.authorizedStrategies(mpStrategy2), true);

    vm.expectEmit();
    emit StrategyUnauthorized(mpStrategy1);
    vm.expectEmit();
    emit StrategyUnauthorized(mpStrategy2);

    ILlamaStrategy[] memory strategies = new ILlamaStrategy[](2);
    strategies[0] = mpStrategy1;
    strategies[1] = mpStrategy2;

    mpCore.unauthorizeStrategies(strategies);

    assertEq(mpCore.authorizedStrategies(mpStrategy1), false);
    assertEq(mpCore.authorizedStrategies(mpStrategy2), false);
    vm.stopPrank();

    vm.prank(actionCreatorAaron);
    vm.expectRevert(LlamaCore.InvalidStrategy.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator),
      mpStrategy1,
      address(mockProtocol),
      0, // value
      PAUSE_SELECTOR,
      abi.encode(true)
    );
  }
}

contract CreateAccounts is LlamaCoreTest {
  function testFuzz_RevertIf_CallerIsNotLlama(address caller) public {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(LlamaCore.OnlyLlama.selector);
    string[] memory newAccounts = Solarray.strings("LlamaAccount2", "LlamaAccount3", "LlamaAccount4");

    vm.prank(caller);
    mpCore.createAccounts(newAccounts);
  }

  function test_CreateNewAccounts() public {
    string[] memory newAccounts = Solarray.strings("LlamaAccount2", "LlamaAccount3", "LlamaAccount4");
    LlamaAccount[] memory accountAddresses = new LlamaAccount[](3);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeLlamaAccountAddress(address(accountLogic), newAccounts[i], address(mpCore));
    }

    vm.expectEmit();
    emit AccountCreated(accountAddresses[0], newAccounts[0]);
    vm.expectEmit();
    emit AccountCreated(accountAddresses[1], newAccounts[1]);
    vm.expectEmit();
    emit AccountCreated(accountAddresses[2], newAccounts[2]);

    vm.prank(address(mpCore));
    mpCore.createAccounts(newAccounts);
  }

  function test_RevertIf_Reinitialized() public {
    string[] memory newAccounts = Solarray.strings("LlamaAccount2", "LlamaAccount3", "LlamaAccount4");
    LlamaAccount[] memory accountAddresses = new LlamaAccount[](3);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeLlamaAccountAddress(address(accountLogic), newAccounts[i], address(mpCore));
    }

    vm.startPrank(address(mpCore));
    mpCore.createAccounts(newAccounts);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[0].initialize(newAccounts[0]);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[1].initialize(newAccounts[1]);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[2].initialize(newAccounts[2]);
  }

  function test_RevertIf_AccountsAreIdentical() public {
    string[] memory newAccounts = Solarray.strings("LlamaAccount1", "LlamaAccount1");
    vm.prank(address(mpCore));
    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createAccounts(newAccounts);
  }

  function test_RevertIf_IdenticalAccountIsAlreadyDeployed() public {
    string[] memory newAccounts1 = Solarray.strings("LlamaAccount1");
    string[] memory newAccounts2 = Solarray.strings("LlamaAccount1");
    vm.startPrank(address(mpCore));
    mpCore.createAccounts(newAccounts1);

    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createAccounts(newAccounts2);
  }

  function test_CanBeCalledByASuccessfulAction() public {
    string memory name = "LlamaAccount1";
    address actionCreatorAustin = makeAddr("actionCreatorAustin");
    string[] memory newAccounts = Solarray.strings(name);

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    LlamaAccount accountAddress = lens.computeLlamaAccountAddress(address(accountLogic), name, address(mpCore));

    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole2),
      mpStrategy1,
      address(mpCore),
      0, // value
      CREATE_ACCOUNT_SELECTOR,
      abi.encode(newAccounts)
    );

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectEmit();
    emit AccountCreated(accountAddress, name);
    mpCore.executeAction(actionId);
  }
}

contract SetGuard is LlamaCoreTest {
  event ActionGuardSet(address indexed target, bytes4 indexed selector, IActionGuard actionGuard);

  function testFuzz_RevertIf_CallerIsNotLlama(address caller, address target, bytes4 selector, IActionGuard guard)
    public
  {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(LlamaCore.OnlyLlama.selector);
    vm.prank(caller);
    mpCore.setGuard(target, selector, guard);
  }

  function testFuzz_UpdatesGuardAndEmitsActionGuardSetEvent(address target, bytes4 selector, IActionGuard guard) public {
    vm.assume(target != address(mpCore) && target != address(mpPolicy));
    vm.prank(address(mpCore));
    vm.expectEmit();
    emit ActionGuardSet(target, selector, guard);
    mpCore.setGuard(target, selector, guard);
    assertEq(address(mpCore.actionGuard(target, selector)), address(guard));
  }

  function testFuzz_RevertIf_TargetIsCore(bytes4 selector, IActionGuard guard) public {
    vm.prank(address(mpCore));
    vm.expectRevert(LlamaCore.CannotUseCoreOrPolicy.selector);
    mpCore.setGuard(address(mpCore), selector, guard);
  }

  function testFuzz_RevertIf_TargetIsPolicy(bytes4 selector, IActionGuard guard) public {
    vm.prank(address(mpCore));
    vm.expectRevert(LlamaCore.CannotUseCoreOrPolicy.selector);
    mpCore.setGuard(address(mpPolicy), selector, guard);
  }
}

contract AuthorizeScript is LlamaCoreTest {
  event ScriptAuthorized(address indexed script, bool authorized);

  function testFuzz_RevertIf_CallerIsNotLlama(address caller, address script, bool authorized) public {
    vm.assume(caller != address(mpCore));
    vm.expectRevert(LlamaCore.OnlyLlama.selector);
    vm.prank(caller);
    mpCore.authorizeScript(script, authorized);
  }

  function testFuzz_UpdatesScriptMappingAndEmitsScriptAuthorizedEvent(address script, bool authorized) public {
    vm.assume(script != address(mpCore) && script != address(mpPolicy));
    vm.prank(address(mpCore));
    vm.expectEmit();
    emit ScriptAuthorized(script, authorized);
    mpCore.authorizeScript(script, authorized);
    assertEq(mpCore.authorizedScripts(script), authorized);
  }

  function testFuzz_RevertIf_ScriptIsCore(bool authorized) public {
    vm.prank(address(mpCore));
    vm.expectRevert(LlamaCore.CannotUseCoreOrPolicy.selector);
    mpCore.authorizeScript(address(mpCore), authorized);
  }

  function testFuzz_RevertIf_ScriptIsPolicy(bool authorized) public {
    vm.prank(address(mpCore));
    vm.expectRevert(LlamaCore.CannotUseCoreOrPolicy.selector);
    mpCore.authorizeScript(address(mpPolicy), authorized);
  }
}

contract GetActionState is LlamaCoreTest {
  function testFuzz_RevertsOnInvalidAction(uint256 invalidActionId) public {
    vm.expectRevert(LlamaCore.InvalidActionId.selector);
    mpCore.getActionState(invalidActionId);
  }

  function test_CanceledActionsHaveStateCanceled() public {
    uint256 actionId = _createAction();
    vm.prank(actionCreatorAaron);
    mpCore.cancelAction(actionId);

    uint256 currentState = uint256(mpCore.getActionState(0));
    uint256 canceledState = uint256(ActionState.Canceled);
    assertEq(currentState, canceledState);
  }

  function test_UnpassedActionsPriorToApprovalPeriodEndHaveStateActive() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.stopPrank();

    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole2),
      mpStrategy2,
      address(mockProtocol),
      0, // value
      PAUSE_SELECTOR,
      abi.encode(true)
    );

    uint256 currentState = uint256(mpCore.getActionState(actionId));
    uint256 activeState = uint256(ActionState.Active);
    assertEq(currentState, activeState);
  }

  function test_ApprovedActionsWithFixedLengthHaveStateActive() public {
    uint256 actionId = _createAction();
    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 1 days);

    uint256 currentState = uint256(mpCore.getActionState(actionId));
    uint256 activeState = uint256(ActionState.Active);
    assertEq(currentState, activeState);
  }

  function test_PassedActionsPriorToApprovalPeriodEndHaveStateApproved() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    vm.stopPrank();

    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole2),
      mpStrategy2,
      address(mockProtocol),
      0, // value
      PAUSE_SELECTOR,
      abi.encode(true)
    );
    vm.warp(block.timestamp + 1);

    uint256 currentState = uint256(mpCore.getActionState(actionId));
    uint256 activeState = uint256(ActionState.Active);
    assertEq(currentState, activeState);

    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);
    _approveAction(approverAndy, actionId);

    currentState = uint256(mpCore.getActionState(actionId));
    uint256 approvedState = uint256(ActionState.Approved);
    assertEq(currentState, approvedState);
  }

  function testFuzz_ApprovedActionsHaveStateApproved(uint256 _timeSinceCreation) public {
    uint256 actionId = _createAction();
    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);
    Action memory action = mpCore.getAction(actionId);
    uint256 approvalEndTime = toRelativeStrategy(action.strategy).approvalEndTime(actionId);
    vm.assume(_timeSinceCreation < toRelativeStrategy(mpStrategy1).approvalPeriod() * 2);
    vm.warp(block.timestamp + _timeSinceCreation);

    uint256 currentState = uint256(mpCore.getActionState(actionId));
    uint256 expectedState = uint256(block.timestamp < approvalEndTime ? ActionState.Active : ActionState.Approved);
    assertEq(currentState, expectedState);
  }

  function test_QueuedActionsHaveStateQueued() public {
    _createAction();

    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(0), true);
    _queueAction();

    uint256 currentState = uint256(mpCore.getActionState(0));
    uint256 queuedState = uint256(ActionState.Queued);
    assertEq(currentState, queuedState);
  }

  function test_ExecutedActionsHaveStateExecuted() public {
    _createAction();

    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionApproved(0), true);
    _queueAction();

    vm.warp(block.timestamp + 5 days);

    _executeAction();

    uint256 currentState = uint256(mpCore.getActionState(0));
    uint256 executedState = uint256(ActionState.Executed);
    assertEq(currentState, executedState);
  }

  function test_RejectedActionsHaveStateFailed() public {
    _createAction();
    vm.warp(block.timestamp + 12 days);

    uint256 currentState = uint256(mpCore.getActionState(0));
    uint256 failedState = uint256(ActionState.Failed);
    assertEq(currentState, failedState);
  }
}
