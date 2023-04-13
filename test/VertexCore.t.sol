// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Solarray} from "@solarray/Solarray.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IActionGuard} from "src/interfaces/IActionGuard.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexFactoryWithoutInitialization} from "test/utils/VertexFactoryWithoutInitialization.sol";
import {MockProtocol} from "test/mock/MockProtocol.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, Strategy, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {MockActionGuard} from "test/mock/MockActionGuard.sol";
import {Roles, VertexTestSetup} from "test/utils/VertexTestSetup.sol";
import {SolarrayVertex} from "test/utils/SolarrayVertex.sol";
import {VertexCoreSigUtils} from "test/utils/VertexCoreSigUtils.sol";

contract VertexCoreTest is VertexTestSetup, VertexCoreSigUtils {
  event ActionCreated(
    uint256 id,
    address indexed creator,
    VertexStrategy indexed strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes data
  );
  event ActionCanceled(uint256 id);
  event ActionQueued(
    uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator, uint256 executionTime
  );
  event ActionExecuted(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator);
  event ApprovalCast(uint256 id, address indexed policyholder, uint256 weight, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint256 weight, string reason);
  event StrategyAuthorized(VertexStrategy indexed strategy, address indexed strategyLogic, Strategy strategyData);
  event StrategyUnauthorized(VertexStrategy indexed strategy);
  event AccountAuthorized(VertexAccount indexed account, address indexed accountLogic, string name);

  function setUp() public virtual override {
    VertexTestSetup.setUp();

    setDomainHash(
      VertexCoreSigUtils.EIP712Domain({
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
    uint256 executionTime = block.timestamp + mpStrategy1.queuingPeriod();
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
    emit ActionExecuted(0, address(this), mpStrategy1, actionCreatorAaron);
    mpCore.executeAction(0);

    Action memory action = mpCore.getAction(0);
    assertEq(action.executed, true);
  }

  function _executeCompleteActionFlow() internal {
    _createAction();

    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(0), true);
    _queueAction();

    _disapproveAction(disapproverDave);

    vm.warp(block.timestamp + 5 days);

    _executeAction();
  }

  function _deployAndAuthorizeAdditionalStrategyLogic() internal returns (address) {
    VertexStrategy additionalStrategyLogic = new VertexStrategy();
    vm.prank(address(rootCore));
    factory.authorizeStrategyLogic(address(additionalStrategyLogic));
    return address(additionalStrategyLogic);
  }

  function _deployAndAuthorizeAdditionalAccountLogic() internal returns (address) {
    VertexAccount additionalAccountLogic = new VertexAccount();
    vm.prank(address(rootCore));
    factory.authorizeAccountLogic(address(additionalAccountLogic));
    return address(additionalAccountLogic);
  }

  function _createStrategy(uint256 salt, bool isFixedLengthApprovalPeriod) internal pure returns (Strategy memory) {
    return Strategy({
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

contract Setup is VertexCoreTest {
  function test_setUp() public {
    assertEq(mpCore.name(), "Mock Protocol Vertex");

    assertTrue(mpCore.authorizedStrategies(mpStrategy1));
    assertTrue(mpCore.authorizedStrategies(mpStrategy1));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount1.initialize("VertexAccount0");

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount2.initialize("VertexAccount1");
  }
}

contract Initialize is VertexCoreTest {
  function deployWithoutInitialization()
    internal
    returns (VertexFactoryWithoutInitialization modifiedFactory, VertexCore vertex, VertexPolicy policy)
  {
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account 1", "Account 2", "Account 3");
    RoleHolderData[] memory roleHolders = defaultActionCreatorRoleHolder(actionCreatorAaron);
    modifiedFactory = new VertexFactoryWithoutInitialization(
      coreLogic,
      strategyLogic,
      accountLogic,
      policyLogic,
      policyTokenUri,
      "Root Vertex",
      strategies,
      accounts,
      SolarrayVertex.roleDescription("AllHolders","ActionCreator","Approver","Disapprover","TestRole1","TestRole2","MadeUpRole"),
      roleHolders,
      new RolePermissionData[](0)
    );

    (vertex, policy) = modifiedFactory.deployWithoutInitialization(
      "NewProject",
      SolarrayVertex.roleDescription(
        "AllHolders", "ActionCreator", "Approver", "Disapprover", "TestRole1", "TestRole2", "MadeUpRole"
      ),
      roleHolders,
      new RolePermissionData[](0)
    );
  }

  function test_StrategiesAreDeployedAtExpectedAddress() public {
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    VertexStrategy[] memory strategyAddresses = new VertexStrategy[](2);
    for (uint256 i; i < strategies.length; i++) {
      strategyAddresses[i] =
        lens.computeVertexStrategyAddress(address(strategyLogic), strategies[i], address(uninitializedVertex));
    }

    assertEq(address(strategyAddresses[0]).code.length, 0);
    assertEq(address(strategyAddresses[1]).code.length, 0);

    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(accountLogic), strategies, accounts
    );

    assertGt(address(strategyAddresses[0]).code.length, 0);
    assertGt(address(strategyAddresses[1]).code.length, 0);
  }

  function test_EmitsStrategyAuthorizedEventForEachStrategy() public {
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    VertexStrategy[] memory strategyAddresses = new VertexStrategy[](2);
    for (uint256 i; i < strategies.length; i++) {
      strategyAddresses[i] =
        lens.computeVertexStrategyAddress(address(strategyLogic), strategies[i], address(uninitializedVertex));
    }

    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[0], address(strategyLogic), strategies[0]);
    emit StrategyAuthorized(strategyAddresses[1], address(strategyLogic), strategies[1]);
    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(accountLogic), strategies, accounts
    );
  }

  function test_StrategiesHaveVertexCoreAddressInStorage() public {
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    VertexStrategy[] memory strategyAddresses = new VertexStrategy[](2);
    for (uint256 i; i < strategies.length; i++) {
      strategyAddresses[i] =
        lens.computeVertexStrategyAddress(address(strategyLogic), strategies[i], address(uninitializedVertex));
    }

    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(accountLogic), strategies, accounts
    );

    assertEq(address(strategyAddresses[0].vertex()), address(uninitializedVertex));
    assertEq(address(strategyAddresses[1].vertex()), address(uninitializedVertex));
  }

  function test_StrategiesHavePolicyAddressInStorage() public {
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    VertexStrategy[] memory strategyAddresses = new VertexStrategy[](2);
    for (uint256 i; i < strategies.length; i++) {
      strategyAddresses[i] =
        lens.computeVertexStrategyAddress(address(strategyLogic), strategies[i], address(uninitializedVertex));
    }

    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(accountLogic), strategies, accounts
    );

    assertEq(address(strategyAddresses[0].policy()), address(policy));
    assertEq(address(strategyAddresses[1].policy()), address(policy));
  }

  function test_StrategiesAreAuthorizedByVertexCore() public {
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    VertexStrategy[] memory strategyAddresses = new VertexStrategy[](2);
    for (uint256 i; i < strategies.length; i++) {
      strategyAddresses[i] =
        lens.computeVertexStrategyAddress(address(strategyLogic), strategies[i], address(uninitializedVertex));
    }

    assertEq(uninitializedVertex.authorizedStrategies(strategyAddresses[0]), false);
    assertEq(uninitializedVertex.authorizedStrategies(strategyAddresses[1]), false);

    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(accountLogic), strategies, accounts
    );

    assertEq(uninitializedVertex.authorizedStrategies(strategyAddresses[0]), true);
    assertEq(uninitializedVertex.authorizedStrategies(strategyAddresses[1]), true);
  }

  function testFuzz_RevertIf_StrategyLogicIsNotAuthorized(address notStrategyLogic) public {
    vm.assume(notStrategyLogic != address(strategyLogic));
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");

    vm.expectRevert(VertexCore.UnauthorizedStrategyLogic.selector);
    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", notStrategyLogic, address(accountLogic), strategies, accounts
    );
  }

  function test_AccountsAreDeployedAtExpectedAddress() public {
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    VertexAccount[] memory accountAddresses = new VertexAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeVertexAccountAddress(address(accountLogic), accounts[i], address(uninitializedVertex));
    }

    assertEq(address(accountAddresses[0]).code.length, 0);
    assertEq(address(accountAddresses[1]).code.length, 0);

    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(accountLogic), strategies, accounts
    );

    assertGt(address(accountAddresses[0]).code.length, 0);
    assertGt(address(accountAddresses[1]).code.length, 0);
  }

  function test_EmitsAccountAuthorizedEventForEachAccount() public {
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    VertexAccount[] memory accountAddresses = new VertexAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeVertexAccountAddress(address(accountLogic), accounts[i], address(uninitializedVertex));
    }

    vm.expectEmit();
    emit AccountAuthorized(accountAddresses[0], address(accountLogic), accounts[0]);
    emit AccountAuthorized(accountAddresses[1], address(accountLogic), accounts[1]);
    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(accountLogic), strategies, accounts
    );
  }

  function test_AccountsHaveVertexCoreAddressInStorage() public {
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    VertexAccount[] memory accountAddresses = new VertexAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeVertexAccountAddress(address(accountLogic), accounts[i], address(uninitializedVertex));
    }

    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(accountLogic), strategies, accounts
    );

    assertEq(address(accountAddresses[0].vertex()), address(uninitializedVertex));
    assertEq(address(accountAddresses[1].vertex()), address(uninitializedVertex));
  }

  function test_AccountsHaveNameInStorage() public {
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");
    VertexAccount[] memory accountAddresses = new VertexAccount[](2);
    for (uint256 i; i < accounts.length; i++) {
      accountAddresses[i] =
        lens.computeVertexAccountAddress(address(accountLogic), accounts[i], address(uninitializedVertex));
    }

    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(accountLogic), strategies, accounts
    );

    assertEq(accountAddresses[0].name(), "Account1");
    assertEq(accountAddresses[1].name(), "Account2");
  }

  function test_RevertIf_AccountLogicIsNotAuthorized(address notAccountLogic) public {
    vm.assume(uint160(notAccountLogic) != uint160(address(accountLogic)));
    (VertexFactoryWithoutInitialization modifiedFactory, VertexCore uninitializedVertex, VertexPolicy policy) =
      deployWithoutInitialization();
    Strategy[] memory strategies = defaultStrategies();
    string[] memory accounts = Solarray.strings("Account1", "Account2");

    vm.expectRevert(VertexCore.UnauthorizedAccountLogic.selector);
    modifiedFactory.initialize(
      uninitializedVertex, policy, "NewProject", address(strategyLogic), address(notAccountLogic), strategies, accounts
    );
  }
}

contract CreateAction is VertexCoreTest {
  function test_CreatesAnAction() public {
    vm.expectEmit();
    emit ActionCreated(0, actionCreatorAaron, mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));
    vm.prank(actionCreatorAaron);
    uint256 _actionId = mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );

    Action memory action = mpCore.getAction(_actionId);
    uint256 ApprovalPeriodEnd = block.timestamp + action.strategy.approvalPeriod();

    assertEq(_actionId, 0);
    assertEq(mpCore.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(ApprovalPeriodEnd, block.timestamp + 2 days);
    assertEq(action.approvalPolicySupply, 3);
    assertEq(action.disapprovalPolicySupply, 3);
  }

  function testFuzz_CreatesAnAction(address _target, uint256 _value, bytes memory _data) public {
    vm.assume(_target != address(mockProtocol));

    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    vm.prank(actionCreatorAaron);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(_target), _value, PAUSE_SELECTOR, abi.encode(_data)
    );
  }

  function test_RevertIf_ActionGuardProhibitsAction() public {
    IActionGuard guard = IActionGuard(new MockActionGuard(false, true, true, "no action creation"));
    bytes memory expectedErr = bytes.concat(VertexCore.ProhibitedByActionGuard.selector, bytes32("no action creation"));

    vm.prank(address(mpCore));
    mpCore.setGuard(address(mockProtocol), PAUSE_SELECTOR, guard);

    vm.prank(actionCreatorAaron);
    vm.expectRevert(expectedErr);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function test_RevertIf_StrategyUnauthorized() public {
    VertexStrategy unauthorizedStrategy = VertexStrategy(makeAddr("unauthorized strategy"));
    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.InvalidStrategy.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), unauthorizedStrategy, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function test_RevertIf_StrategyIsFromAnotherVertex() public {
    VertexStrategy unauthorizedStrategy = rootStrategy1;
    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.InvalidStrategy.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), unauthorizedStrategy, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function testFuzz_RevertIf_PolicyholderNotMinted(address user) public {
    if (user == address(0)) user = address(100); // Faster than vm.assume, since 0 comes up a lot.
    vm.assume(mpPolicy.balanceOf(user) == 0);
    vm.prank(user);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function test_RevertIf_NoPermissionForStrategy() public {
    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy2, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function testFuzz_RevertIf_NoPermissionForTarget(address _incorrectTarget) public {
    vm.assume(_incorrectTarget != address(mockProtocol));
    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, _incorrectTarget, 0, PAUSE_SELECTOR, abi.encode(true));
  }

  function testFuzz_RevertIf_BadPermissionForSelector(bytes4 _badSelector) public {
    vm.assume(_badSelector != PAUSE_SELECTOR && _badSelector != FAIL_SELECTOR && _badSelector != RECEIVE_ETH_SELECTOR);
    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
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
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }
}

contract CreateActionBySig is VertexCoreTest {
  function createOffchainSignature(uint256 privateKey) internal view returns (uint8 v, bytes32 r, bytes32 s) {
    VertexCoreSigUtils.CreateAction memory createAction = VertexCoreSigUtils.CreateAction({
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
    uint256 ApprovalPeriodEnd = block.timestamp + action.strategy.approvalPeriod();

    assertEq(_actionId, 0);
    assertEq(mpCore.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(ApprovalPeriodEnd, block.timestamp + 2 days);
    assertEq(action.approvalPolicySupply, 3);
    assertEq(action.disapprovalPolicySupply, 3);
  }

  function test_CheckNonceIncrements() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionCreatorAaronPrivateKey);
    assertEq(mpCore.nonces(actionCreatorAaron, VertexCore.createActionBySig.selector), 0);
    createActionBySig(v, r, s);
    assertEq(mpCore.nonces(actionCreatorAaron, VertexCore.createActionBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionCreatorAaronPrivateKey);
    createActionBySig(v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(VertexCore.InvalidSignature.selector);
    createActionBySig(v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address is not the same as the policyholder passed in as
    // parameter.
    vm.expectRevert(VertexCore.InvalidSignature.selector);
    createActionBySig(v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionCreatorAaronPrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(VertexCore.InvalidSignature.selector);
    createActionBySig((v + 1), r, s);
  }
}

contract CancelAction is VertexCoreTest {
  function setUp() public override {
    VertexCoreTest.setUp();
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
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
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
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }

  function test_RevertIf_ActionExecuted() public {
    _executeCompleteActionFlow();

    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }

  function test_RevertIf_ActionExpired() public {
    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(0), true);
    _queueAction();

    _disapproveAction(disapproverDave);

    vm.warp(block.timestamp + 15 days);

    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }

  function test_RevertIf_ActionFailed() public {
    _approveAction(approverAdam);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(0), false);

    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }

  function test_CancelIfDisapproved() public {
    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(0), true);
    _queueAction();

    _disapproveAction(disapproverDave);
    _disapproveAction(disapproverDiane);
    _disapproveAction(disapproverDrake);

    vm.expectEmit();
    emit ActionCanceled(0);
    mpCore.cancelAction(0);
  }

  function test_RevertIf_DisapprovalDoesNotReachQuorum() public {
    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(0), true);
    _queueAction();

    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
  }
}

contract QueueAction is VertexCoreTest {
  function test_RevertIf_NotApproved() public {
    _createAction();
    _approveAction(approverAdam);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(abi.encodePacked(VertexCore.InvalidActionState.selector, uint256(ActionState.Approved)));
    mpCore.queueAction(0);
  }

  function testFuzz_RevertIf_InvalidActionId(uint256 invalidActionId) public {
    bound(invalidActionId, mpCore.actionsCount(), type(uint256).max);
    _createAction();
    _approveAction(approverAdam);
    _approveAction(approverAlicia);
    _approveAction(approverAndy);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(VertexCore.InvalidActionId.selector);
    mpCore.queueAction(1);
  }
}

contract ExecuteAction is VertexCoreTest {
  uint256 actionId;

  function setUp() public override {
    VertexCoreTest.setUp();

    actionId = _createAction();
    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(actionId), true);
  }

  function test_ActionExecution() public {
    mpCore.queueAction(0);
    vm.warp(block.timestamp + 6 days);

    vm.expectEmit();
    emit ActionExecuted(0, address(this), mpStrategy1, actionCreatorAaron);
    bytes memory result = mpCore.executeAction(0);
    assertEq(result, "");
  }

  function test_RevertIf_NotQueued() public {
    vm.expectRevert(abi.encodePacked(VertexCore.InvalidActionState.selector, uint256(ActionState.Queued)));
    mpCore.executeAction(actionId);

    // Check that it's in the Approved state
    assertEq(uint256(mpCore.getActionState(0)), uint256(3));
  }

  function test_RevertIf_ActionGuardProhibitsActionPreExecution() public {
    IActionGuard guard = IActionGuard(new MockActionGuard(true, false, true, "no action pre-execution"));
    bytes memory expectedErr =
      bytes.concat(VertexCore.ProhibitedByActionGuard.selector, bytes32("no action pre-execution"));

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
      bytes.concat(VertexCore.ProhibitedByActionGuard.selector, bytes32("no action post-execution"));

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

    vm.expectRevert(VertexCore.InvalidActionId.selector);
    mpCore.executeAction(actionId + 1);
  }

  function testFuzz_RevertIf_TimelockNotFinished(uint256 timeElapsed) public {
    // Using a reasonable upper limit for elapsedTime
    vm.assume(timeElapsed < 10_000 days);
    mpCore.queueAction(actionId);
    uint256 executionTime = mpCore.getAction(actionId).minExecutionTime;

    vm.warp(block.timestamp + timeElapsed);

    if (executionTime > block.timestamp) {
      vm.expectRevert(VertexCore.TimelockNotFinished.selector);
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

    vm.expectRevert(VertexCore.InsufficientMsgValue.selector);
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
    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(actionId), true);

    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(VertexCore.FailedActionExecution.selector);
    mpCore.executeAction(actionId);
  }

  function test_HandlesReentrancy() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

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

    vm.expectRevert(VertexCore.FailedActionExecution.selector);
    mpCore.executeAction(actionId);
  }
}

contract CastApproval is VertexCoreTest {
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

    vm.expectRevert(abi.encodePacked(VertexCore.InvalidActionState.selector, uint256(ActionState.Active)));
    mpCore.castApproval(actionId, uint8(Roles.Approver));
  }

  function test_RevertIf_DuplicateApproval() public {
    actionId = _createAction();
    _approveAction(approverAdam, actionId);

    vm.expectRevert(VertexCore.DuplicateApproval.selector);
    vm.prank(approverAdam);
    mpCore.castApproval(actionId, uint8(Roles.Approver));
  }

  function test_RevertIf_InvalidPolicyholder() public {
    actionId = _createAction();
    address notPolicyholder = 0x9D3de545F58C696946b4Cf2c884fcF4f7914cB53;
    vm.prank(notPolicyholder);

    vm.expectRevert(VertexCore.InvalidPolicyholder.selector);
    mpCore.castApproval(actionId, uint8(Roles.Approver));

    vm.prank(approverAdam);
    mpCore.castApproval(actionId, uint8(Roles.Approver));
  }
}

contract CastApprovalBySig is VertexCoreTest {
  function createOffchainSignature(uint256 _actionId, uint256 privateKey)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    VertexCoreSigUtils.CastApproval memory castApproval = VertexCoreSigUtils.CastApproval({
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

    assertEq(mpCore.nonces(approverAdam, VertexCore.castApprovalBySig.selector), 0);
    castApprovalBySig(actionId, v, r, s);
    assertEq(mpCore.nonces(approverAdam, VertexCore.castApprovalBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    uint256 actionId = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, approverAdamPrivateKey);
    castApprovalBySig(actionId, v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(VertexCore.InvalidSignature.selector);
    castApprovalBySig(actionId, v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    uint256 actionId = _createAction();

    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address is not the same as the policyholder passed in as
    // parameter.
    vm.expectRevert(VertexCore.InvalidSignature.selector);
    castApprovalBySig(actionId, v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    uint256 actionId = _createAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, approverAdamPrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(VertexCore.InvalidSignature.selector);
    castApprovalBySig(actionId, (v + 1), r, s);
  }
}

contract CastDisapproval is VertexCoreTest {
  uint256 actionId;

  function _createApproveAndQueueAction() internal returns (uint256 _actionId) {
    _actionId = _createAction();
    _approveAction(approverAdam, _actionId);
    _approveAction(approverAlicia, _actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(_actionId), true);
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

    vm.expectRevert(abi.encodePacked(VertexCore.InvalidActionState.selector, uint256(ActionState.Queued)));
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));
  }

  function test_RevertIf_DuplicateDisapproval() public {
    actionId = _createApproveAndQueueAction();

    _disapproveAction(disapproverDrake, actionId);

    vm.expectRevert(VertexCore.DuplicateDisapproval.selector);
    vm.prank(disapproverDrake);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));
  }

  function test_RevertIf_InvalidPolicyholder() public {
    actionId = _createApproveAndQueueAction();
    address notPolicyholder = 0x9D3de545F58C696946b4Cf2c884fcF4f7914cB53;
    vm.prank(notPolicyholder);

    vm.expectRevert(VertexCore.InvalidPolicyholder.selector);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));

    vm.prank(disapproverDrake);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));
  }
}

contract CastDisapprovalBySig is VertexCoreTest {
  function createOffchainSignature(uint256 _actionId, uint256 privateKey)
    internal
    view
    returns (uint8 v, bytes32 r, bytes32 s)
  {
    VertexCoreSigUtils.CastDisapproval memory castDisapproval = VertexCoreSigUtils.CastDisapproval({
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

    assertEq(mpStrategy1.isActionPassed(_actionId), true);
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

    assertEq(mpCore.nonces(disapproverDrake, VertexCore.castDisapprovalBySig.selector), 0);
    castDisapprovalBySig(actionId, v, r, s);
    assertEq(mpCore.nonces(disapproverDrake, VertexCore.castDisapprovalBySig.selector), 1);
  }

  function test_OperationCannotBeReplayed() public {
    uint256 actionId = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, disapproverDrakePrivateKey);
    castDisapprovalBySig(actionId, v, r, s);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(VertexCore.InvalidSignature.selector);
    castDisapprovalBySig(actionId, v, r, s);
  }

  function test_RevertIf_SignerIsNotPolicyHolder() public {
    uint256 actionId = _createApproveAndQueueAction();

    (, uint256 randomSignerPrivateKey) = makeAddrAndKey("randomSigner");
    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, randomSignerPrivateKey);
    // Invalid Signature error since the recovered signer address during the second call is not the same as policyholder
    // since nonce has increased.
    vm.expectRevert(VertexCore.InvalidSignature.selector);
    castDisapprovalBySig(actionId, v, r, s);
  }

  function test_RevertIf_SignerIsZeroAddress() public {
    uint256 actionId = _createApproveAndQueueAction();

    (uint8 v, bytes32 r, bytes32 s) = createOffchainSignature(actionId, disapproverDrakePrivateKey);
    // Invalid Signature error since the recovered signer address is zero address due to invalid signature values
    // (v,r,s).
    vm.expectRevert(VertexCore.InvalidSignature.selector);
    castDisapprovalBySig(actionId, (v + 1), r, s);
  }
}

contract CreateAndAuthorizeStrategies is VertexCoreTest {
  function test_CreateNewStrategies(uint256 salt1, uint256 salt2, uint256 salt3, bool isFixedLengthApprovalPeriod)
    public
  {
    Strategy[] memory newStrategies = new Strategy[](3);
    VertexStrategy[] memory strategyAddresses = new VertexStrategy[](3);
    vm.assume(salt1 != salt2);
    vm.assume(salt1 != salt3);
    vm.assume(salt2 != salt3);

    newStrategies[0] = _createStrategy(salt1, isFixedLengthApprovalPeriod);
    newStrategies[1] = _createStrategy(salt2, isFixedLengthApprovalPeriod);
    newStrategies[2] = _createStrategy(salt3, isFixedLengthApprovalPeriod);

    for (uint256 i; i < newStrategies.length; i++) {
      strategyAddresses[i] =
        lens.computeVertexStrategyAddress(address(strategyLogic), newStrategies[i], address(mpCore));
    }

    vm.startPrank(address(mpCore));

    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[0], address(strategyLogic), newStrategies[0]);
    emit StrategyAuthorized(strategyAddresses[1], address(strategyLogic), newStrategies[1]);
    emit StrategyAuthorized(strategyAddresses[2], address(strategyLogic), newStrategies[2]);

    mpCore.createAndAuthorizeStrategies(address(strategyLogic), newStrategies);

    assertEq(mpCore.authorizedStrategies(strategyAddresses[0]), true);
    assertEq(mpCore.authorizedStrategies(strategyAddresses[1]), true);
    assertEq(mpCore.authorizedStrategies(strategyAddresses[2]), true);
  }

  function test_CreateNewStrategiesWithAdditionalStrategyLogic() public {
    address additionalStrategyLogic = _deployAndAuthorizeAdditionalStrategyLogic();

    Strategy[] memory newStrategies = new Strategy[](3);
    VertexStrategy[] memory strategyAddresses = new VertexStrategy[](3);

    newStrategies[0] = Strategy({
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

    newStrategies[1] = Strategy({
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

    newStrategies[2] = Strategy({
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
        lens.computeVertexStrategyAddress(additionalStrategyLogic, newStrategies[i], address(mpCore));
    }

    vm.startPrank(address(mpCore));

    vm.expectEmit();
    emit StrategyAuthorized(strategyAddresses[0], additionalStrategyLogic, newStrategies[0]);
    emit StrategyAuthorized(strategyAddresses[1], additionalStrategyLogic, newStrategies[1]);
    emit StrategyAuthorized(strategyAddresses[2], additionalStrategyLogic, newStrategies[2]);

    mpCore.createAndAuthorizeStrategies(additionalStrategyLogic, newStrategies);

    assertEq(mpCore.authorizedStrategies(strategyAddresses[0]), true);
    assertEq(mpCore.authorizedStrategies(strategyAddresses[1]), true);
    assertEq(mpCore.authorizedStrategies(strategyAddresses[2]), true);
  }

  function test_RevertIf_StrategyLogicNotAuthorized() public {
    Strategy[] memory newStrategies = new Strategy[](1);

    newStrategies[0] = Strategy({
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

    vm.expectRevert(VertexCore.UnauthorizedStrategyLogic.selector);
    mpCore.createAndAuthorizeStrategies(randomLogicAddress, newStrategies);
  }

  function test_RevertIf_StrategiesAreIdentical() public {
    Strategy[] memory newStrategies = new Strategy[](2);

    Strategy memory duplicateStrategy = Strategy({
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
    mpCore.createAndAuthorizeStrategies(address(strategyLogic), newStrategies);
  }

  function test_RevertIf_IdenticalStrategyIsAlreadyDeployed() public {
    Strategy[] memory newStrategies1 = new Strategy[](1);
    Strategy[] memory newStrategies2 = new Strategy[](1);

    Strategy memory duplicateStrategy = Strategy({
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
    mpCore.createAndAuthorizeStrategies(address(strategyLogic), newStrategies1);

    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createAndAuthorizeStrategies(address(strategyLogic), newStrategies2);
  }

  function test_CanBeCalledByASuccessfulAction() public {
    address actionCreatorAustin = makeAddr("actionCreatorAustin");

    Strategy[] memory newStrategies = new Strategy[](1);

    newStrategies[0] = Strategy({
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

    VertexStrategy strategyAddress =
      lens.computeVertexStrategyAddress(address(strategyLogic), newStrategies[0], address(mpCore));

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole2),
      mpStrategy1,
      address(mpCore),
      0, // value
      CREATE_STRATEGY_SELECTOR,
      abi.encode(address(strategyLogic), newStrategies)
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

contract UnauthorizeStrategies is VertexCoreTest {
  function test_UnauthorizeStrategies() public {
    vm.startPrank(address(mpCore));
    assertEq(mpCore.authorizedStrategies(mpStrategy1), true);
    assertEq(mpCore.authorizedStrategies(mpStrategy2), true);

    vm.expectEmit();
    emit StrategyUnauthorized(mpStrategy1);
    emit StrategyUnauthorized(mpStrategy2);

    VertexStrategy[] memory strategies = new VertexStrategy[](2);
    strategies[0] = mpStrategy1;
    strategies[1] = mpStrategy2;

    mpCore.unauthorizeStrategies(strategies);

    assertEq(mpCore.authorizedStrategies(mpStrategy1), false);
    assertEq(mpCore.authorizedStrategies(mpStrategy2), false);
    vm.stopPrank();

    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.InvalidStrategy.selector);
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

contract CreateAndAuthorizeAccounts is VertexCoreTest {
  function test_CreateNewAccounts() public {
    string[] memory newAccounts = Solarray.strings("VertexAccount2", "VertexAccount3", "VertexAccount4");
    VertexAccount[] memory accountAddresses = new VertexAccount[](3);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeVertexAccountAddress(address(accountLogic), newAccounts[i], address(mpCore));
    }

    vm.expectEmit();
    emit AccountAuthorized(accountAddresses[0], address(accountLogic), newAccounts[0]);
    emit AccountAuthorized(accountAddresses[1], address(accountLogic), newAccounts[1]);
    emit AccountAuthorized(accountAddresses[2], address(accountLogic), newAccounts[2]);

    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeAccounts(address(accountLogic), newAccounts);
  }

  function test_RevertIf_Reinitialized() public {
    string[] memory newAccounts = Solarray.strings("VertexAccount2", "VertexAccount3", "VertexAccount4");
    VertexAccount[] memory accountAddresses = new VertexAccount[](3);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeVertexAccountAddress(address(accountLogic), newAccounts[i], address(mpCore));
    }

    vm.startPrank(address(mpCore));
    mpCore.createAndAuthorizeAccounts(address(accountLogic), newAccounts);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[0].initialize(newAccounts[0]);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[1].initialize(newAccounts[1]);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[2].initialize(newAccounts[2]);
  }

  function test_CreateNewAccountsWithAdditionalAccountLogic() public {
    address additionalAccountLogic = _deployAndAuthorizeAdditionalAccountLogic();

    string[] memory newAccounts = Solarray.strings("VertexAccount2", "VertexAccount3", "VertexAccount4");
    VertexAccount[] memory accountAddresses = new VertexAccount[](3);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeVertexAccountAddress(additionalAccountLogic, newAccounts[i], address(mpCore));
    }

    vm.expectEmit();
    emit AccountAuthorized(accountAddresses[0], additionalAccountLogic, newAccounts[0]);
    emit AccountAuthorized(accountAddresses[1], additionalAccountLogic, newAccounts[1]);
    emit AccountAuthorized(accountAddresses[2], additionalAccountLogic, newAccounts[2]);

    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeAccounts(additionalAccountLogic, newAccounts);
  }

  function test_RevertIf_AccountLogicNotAuthorized() public {
    string[] memory newAccounts = Solarray.strings("VertexAccount2", "VertexAccount3", "VertexAccount4");

    vm.expectRevert(VertexCore.UnauthorizedAccountLogic.selector);
    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeAccounts(randomLogicAddress, newAccounts);
  }

  function test_RevertIf_AccountsAreIdentical() public {
    string[] memory newAccounts = Solarray.strings("VertexAccount1", "VertexAccount1");
    vm.prank(address(mpCore));
    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createAndAuthorizeAccounts(address(accountLogic), newAccounts);
  }

  function test_RevertIf_IdenticalAccountIsAlreadyDeployed() public {
    string[] memory newAccounts1 = Solarray.strings("VertexAccount1");
    string[] memory newAccounts2 = Solarray.strings("VertexAccount1");
    vm.startPrank(address(mpCore));
    mpCore.createAndAuthorizeAccounts(address(accountLogic), newAccounts1);

    vm.expectRevert("ERC1167: create2 failed");
    mpCore.createAndAuthorizeAccounts(address(accountLogic), newAccounts2);
  }

  function test_CanBeCalledByASuccessfulAction() public {
    string memory name = "VertexAccount1";
    address actionCreatorAustin = makeAddr("actionCreatorAustin");
    string[] memory newAccounts = Solarray.strings(name);

    vm.prank(address(mpCore));
    mpPolicy.setRoleHolder(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);

    VertexAccount accountAddress = lens.computeVertexAccountAddress(address(accountLogic), name, address(mpCore));

    vm.prank(actionCreatorAustin);
    uint256 actionId = mpCore.createAction(
      uint8(Roles.TestRole2),
      mpStrategy1,
      address(mpCore),
      0, // value
      CREATE_ACCOUNT_SELECTOR,
      abi.encode(address(accountLogic), newAccounts)
    );

    vm.warp(block.timestamp + 1);

    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectEmit();
    emit AccountAuthorized(accountAddress, address(accountLogic), name);
    mpCore.executeAction(actionId);
  }
}

contract SetGuard is VertexCoreTest {
  event ActionGuardSet(address indexed target, bytes4 indexed selector, IActionGuard actionGuard);

  function testFuzz_RevertIf_CallerIsNotVertex(address caller, address target, bytes4 selector, IActionGuard guard)
    public
  {
    vm.assume(caller != address(rootCore));
    vm.expectRevert(VertexFactory.OnlyVertex.selector);
    vm.prank(caller);
    mpCore.setGuard(target, selector, guard);
  }

  function testFuzz_UpdatesGuardAndEmitsActionGuardSetEvent(address target, bytes4 selector, IActionGuard guard) public {
    vm.prank(address(mpCore));
    vm.expectEmit();
    emit ActionGuardSet(target, selector, guard);
    mpCore.setGuard(target, selector, guard);
    assertEq(address(mpCore.actionGuard(target, selector)), address(guard));
  }
}

contract GetActionState is VertexCoreTest {
  function testFuzz_RevertsOnInvalidAction(uint256 invalidActionId) public {
    vm.expectRevert(VertexCore.InvalidActionId.selector);
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
    uint256 approvalEndTime = action.creationTime + action.strategy.approvalPeriod();
    vm.assume(_timeSinceCreation < mpStrategy1.approvalPeriod() * 2);
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

    assertEq(mpStrategy1.isActionPassed(0), true);
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

    assertEq(mpStrategy1.isActionPassed(0), true);
    _queueAction();

    _disapproveAction(disapproverDave);

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
