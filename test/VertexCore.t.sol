// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Solarray} from "@solarray/Solarray.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {ProtocolXYZ} from "test/mock/ProtocolXYZ.sol";
import {VertexFactoryWithoutInitialization} from "test/utils/VertexFactoryWithoutInitialization.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, ExpiredRole, Strategy, PermissionData, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {Roles, VertexTestSetup} from "test/utils/VertexTestSetup.sol";
import {SolarrayVertex} from "test/utils/SolarrayVertex.sol";

contract VertexCoreTest is VertexTestSetup {
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
  event PolicyholderApproved(uint256 id, address indexed policyholder, uint256 weight, string reason);
  event PolicyholderDisapproved(uint256 id, address indexed policyholder, uint256 weight, string reason);
  event StrategyAuthorized(VertexStrategy indexed strategy, address indexed strategyLogic, Strategy strategyData);
  event StrategyUnauthorized(VertexStrategy indexed strategy);
  event AccountAuthorized(VertexAccount indexed account, address indexed accountLogic, string name);

  function setUp() public virtual override {
    VertexTestSetup.setUp();
  }

  /*///////////////////////////////////////////////////////////////
                        Helpers
    //////////////////////////////////////////////////////////////*/

  function _createAction() public returns (uint256 actionId) {
    vm.prank(adminAlice);
    actionId = mpCore.createAction(
      uint8(Roles.Admin),
      mpStrategy1,
      address(mockProtocol),
      0, // value
      PAUSE_SELECTOR,
      abi.encode(true)
    );
    vm.warp(block.timestamp + 1);
  }

  function _approveAction(address _policyholder, uint256 _actionId) public {
    vm.expectEmit(true, true, true, true);
    emit PolicyholderApproved(_actionId, _policyholder, 1, "");
    vm.prank(_policyholder);
    mpCore.castApproval(_actionId, uint8(Roles.Approver));
  }

  function _approveAction(address _policyholder) public {
    uint256 _assumedActionId = 0;
    _approveAction(_policyholder, _assumedActionId);
  }

  function _disapproveAction(address _policyholder, uint256 _actionId) public {
    vm.expectEmit(true, true, true, true);
    emit PolicyholderDisapproved(_actionId, _policyholder, 1, "");
    vm.prank(_policyholder);
    mpCore.castDisapproval(_actionId, uint8(Roles.Disapprover));
  }

  function _disapproveAction(address _policyholder) public {
    uint256 _assumedActionId = 0;
    _disapproveAction(_policyholder, _assumedActionId);
  }

  function _queueAction(uint256 _actionId) public {
    uint256 executionTime = block.timestamp + mpStrategy1.queuingPeriod();
    vm.expectEmit(true, true, true, true);
    emit ActionQueued(_actionId, address(this), mpStrategy1, adminAlice, executionTime);
    mpCore.queueAction(_actionId);
  }

  function _queueAction() public {
    uint256 _assumedActionId = 0;
    _queueAction(_assumedActionId);
  }

  function _executeAction() public {
    vm.expectEmit(true, true, true, true);
    emit ActionExecuted(0, address(this), mpStrategy1, adminAlice);
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
    RoleHolderData[] memory roleHolders = defaultAdminRoleHolder(adminAlice);
    modifiedFactory = new VertexFactoryWithoutInitialization(
      coreLogic,
      address(strategyLogic),
      address(accountLogic),
      policyLogic,
      policyMetadata,
      "Root Vertex",
      strategies,
      accounts,
      SolarrayVertex.roleDescription(getRoleDescription("AllHolders"), getRoleDescription("ActionCreator"), getRoleDescription("Approver"), getRoleDescription("Disapprover"), getRoleDescription("TestRole1"), getRoleDescription("TestRole2"), getRoleDescription("MadeUpRole")),
      roleHolders,
      new RolePermissionData[](0)
    );

    (vertex, policy) = modifiedFactory.deployWithoutInitialization(
      "NewProject",
      SolarrayVertex.roleDescription(
        getRoleDescription("AllHolders"),
        getRoleDescription("ActionCreator"),
        getRoleDescription("Approver"),
        getRoleDescription("Disapprover"),
        getRoleDescription("TestRole1"),
        getRoleDescription("TestRole2"),
        getRoleDescription("MadeUpRole")
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

    vm.expectEmit(true, true, true, true);
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

    vm.expectEmit(true, true, true, true);
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
    vm.expectEmit(true, true, true, true);
    emit ActionCreated(0, adminAlice, mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));
    vm.prank(adminAlice);
    uint256 _actionId =
      mpCore.createAction(uint8(Roles.Admin), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));

    Action memory action = mpCore.getAction(_actionId);
    uint256 approvalEndTime = block.timestamp + action.strategy.approvalPeriod();

    assertEq(_actionId, 0);
    assertEq(mpCore.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(approvalEndTime, block.timestamp + 2 days);
    assertEq(action.approvalPolicySupply, 3);
    assertEq(action.disapprovalPolicySupply, 3);
  }

  function testFuzz_CreatesAnAction(address _target, uint256 _value, bytes memory _data) public {
    vm.assume(_target != address(mockProtocol));

    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    vm.prank(actionCreatorAaron);
    mpCore.createAction(uint8(Roles.Admin), mpStrategy1, address(_target), _value, PAUSE_SELECTOR, abi.encode(_data));
  }

  function test_RevertIfStrategyUnauthorized() public {
    VertexStrategy unauthorizedStrategy = VertexStrategy(makeAddr("unauthorized strategy"));
    vm.prank(adminAlice);
    vm.expectRevert(VertexCore.InvalidStrategy.selector);
    mpCore.createAction(
      uint8(Roles.Admin), unauthorizedStrategy, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function test_RevertIfStrategyIsFromAnotherVertex() public {
    VertexStrategy unauthorizedStrategy = rootStrategy1;
    vm.prank(adminAlice);
    vm.expectRevert(VertexCore.InvalidStrategy.selector);
    mpCore.createAction(
      uint8(Roles.Admin), unauthorizedStrategy, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }

  function testFuzz_RevertIfPolicyholderNotMinted(address user) public {
    if (user == address(0)) user = address(100); // Faster than vm.assume, since 0 comes up a lot.
    vm.assume(mpPolicy.balanceOf(user) == 0);
    vm.prank(user);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.Admin), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));
  }

  function test_RevertIfNoPermissionForStrategy() public {
    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.Admin), mpStrategy2, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));
  }

  function testFuzz_RevertIfNoPermissionForTarget(address _incorrectTarget) public {
    vm.assume(_incorrectTarget != address(mockProtocol));
    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.Admin), mpStrategy1, _incorrectTarget, 0, PAUSE_SELECTOR, abi.encode(true));
  }

  function testFuzz_RevertIfBadPermissionForSelector(bytes4 _badSelector) public {
    vm.assume(_badSelector != PAUSE_SELECTOR && _badSelector != FAIL_SELECTOR && _badSelector != RECEIVE_ETH_SELECTOR);
    vm.prank(actionCreatorAaron);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(uint8(Roles.Admin), mpStrategy1, address(mockProtocol), 0, _badSelector, abi.encode(true));
  }

  function testFuzz_RevertIfPermissionExpired(uint64 _expirationTimestamp) public {
    vm.assume(_expirationTimestamp > block.timestamp + 1 && _expirationTimestamp < type(uint64).max - 1);

    address actionCreatorAustin = makeAddr("actionCreatorAustin");
    // forgefmt: disable-start
    RoleHolderData[] memory mpRoleHoldersNew = new RoleHolderData[](1);
    mpRoleHoldersNew[0] = RoleHolderData(uint8(Roles.ActionCreator), actionCreatorAustin, DEFAULT_ROLE_QTY, _expirationTimestamp);
    // forgefmt: disable-end

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolders(mpRoleHoldersNew);
    vm.stopPrank();

    vm.prank(address(actionCreatorAustin));
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );

    vm.warp(_expirationTimestamp + 1);
    ExpiredRole[] memory expiredRoles = new ExpiredRole[](1);
    expiredRoles[0] = ExpiredRole(uint8(Roles.ActionCreator), actionCreatorAustin);
    mpPolicy.revokeExpiredRoles(expiredRoles);

    vm.startPrank(address(actionCreatorAustin));
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    mpCore.createAction(
      uint8(Roles.ActionCreator), mpStrategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true)
    );
  }
}

contract CancelAction is VertexCoreTest {
  function setUp() public override {
    VertexCoreTest.setUp();
    _createAction();
  }

  function test_CreatorCancelFlow() public {
    vm.startPrank(adminAlice);
    vm.expectEmit(true, true, true, true);
    emit ActionCanceled(0);
    mpCore.cancelAction(0);
    vm.stopPrank();
    uint256 state = uint256(mpCore.getActionState(0));
    uint256 canceled = uint256(ActionState.Canceled);
    assertEq(state, canceled);
  }

  function testFuzz_RevertIfNotCreator(address _randomCaller) public {
    vm.assume(_randomCaller != adminAlice);
    vm.prank(_randomCaller);
    vm.expectRevert(VertexCore.ActionCannotBeCanceled.selector);
    mpCore.cancelAction(0);
  }

  function testFuzz_RevertIf_InvalidActionId(uint256 invalidActionId) public {
    bound(invalidActionId, mpCore.actionsCount(), type(uint256).max);
    vm.startPrank(adminAlice);
    vm.expectRevert(VertexCore.InvalidActionId.selector);
    mpCore.cancelAction(1);
    vm.stopPrank();
  }

  function test_RevertIfAlreadyCanceled() public {
    vm.startPrank(adminAlice);
    mpCore.cancelAction(0);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
    vm.stopPrank();
  }

  function test_RevertIfActionExecuted() public {
    _executeCompleteActionFlow();

    vm.startPrank(adminAlice);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
    vm.stopPrank();
  }

  function test_RevertIfActionExpired() public {
    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(0), true);
    _queueAction();

    _disapproveAction(disapproverDave);

    vm.warp(block.timestamp + 15 days);

    vm.startPrank(adminAlice);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    mpCore.cancelAction(0);
    vm.stopPrank();
  }

  function test_RevertIfActionFailed() public {
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

    vm.expectEmit(true, true, true, true);
    emit ActionCanceled(0);
    mpCore.cancelAction(0);
  }

  function test_RevertIfDisapprovalDoesNotReachQuorum() public {
    _approveAction(approverAdam);
    _approveAction(approverAlicia);

    vm.warp(block.timestamp + 6 days);

    assertEq(mpStrategy1.isActionPassed(0), true);
    _queueAction();

    vm.expectRevert(VertexCore.ActionCannotBeCanceled.selector);
    mpCore.cancelAction(0);
  }
}

contract QueueAction is VertexCoreTest {
  function test_RevertIfNotApproved() public {
    _createAction();
    _approveAction(approverAdam);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(VertexCore.InvalidStateForQueue.selector);
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

    vm.expectEmit(true, true, true, true);
    emit ActionExecuted(0, address(this), mpStrategy1, adminAlice);
    bytes memory result = mpCore.executeAction(0);
    assertEq(result, "");
  }

  function test_RevertIfNotQueued() public {
    vm.expectRevert(VertexCore.OnlyQueuedActions.selector);
    mpCore.executeAction(actionId);

    // Check that it's in the Approved state
    assertEq(uint256(mpCore.getActionState(0)), uint256(3));
  }

  function testFuzz_RevertIf_InvalidActionId(uint256 invalidActionId) public {
    bound(invalidActionId, mpCore.actionsCount(), type(uint256).max);
    mpCore.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(VertexCore.InvalidActionId.selector);
    mpCore.executeAction(actionId + 1);
  }

  function testFuzz_RevertIfTimelockNotFinished(uint256 timeElapsed) public {
    // Using a reasonable upper limit for elapsedTime
    vm.assume(timeElapsed < 10_000 days);
    mpCore.queueAction(actionId);
    uint256 executionTime = mpCore.getAction(actionId).executionTime;

    vm.warp(block.timestamp + timeElapsed);

    if (executionTime > block.timestamp) {
      vm.expectRevert(VertexCore.TimelockNotFinished.selector);
      mpCore.executeAction(actionId);
    }
  }

  function test_RevertIfInsufficientMsgValue() public {
    vm.prank(adminAlice);
    actionId = mpCore.createAction(
      uint8(Roles.Admin), mpStrategy1, address(mockProtocol), 1e18, RECEIVE_ETH_SELECTOR, abi.encode(true)
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

  function test_RevertIfFailedActionExecution() public {
    vm.prank(adminAlice);
    actionId = mpCore.createAction(
      uint8(Roles.Admin),
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
    // forgefmt: disable-start
    RoleHolderData[] memory mpRoleHoldersNew = new RoleHolderData[](1);
    mpRoleHoldersNew[0] = RoleHolderData(uint8(Roles.TestRole2), actionCreatorAustin, DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION);
    // forgefmt: disable-end

    vm.startPrank(address(mpCore));
    mpPolicy.setRoleHolders(mpRoleHoldersNew);
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

  function test_RevertsIfExternalCallIsUnsuccessful() public {
    // TODO
    // expect the call to revert with FailedActionExecution
  }
}

contract CastApproval is VertexCoreTest {
  uint256 actionId;

  function test_SuccessfulApproval() public {
    // TODO
    // This is a happy path test.
    // Assert changes to Action storage.
    // Assert changes to Approval storage.
    // Assert event emission.
    actionId = _createAction();
    _approveAction(approverAdam, actionId);
    assertEq(mpCore.getAction(0).totalApprovals, 1);
    assertEq(mpCore.approvals(0, approverAdam), true);
  }

  function test_SuccessfulApprovalWithReason(string calldata reason) public {
    actionId = _createAction();
    vm.expectEmit(true, true, true, true);
    emit PolicyholderApproved(actionId, approverAdam, 1, reason);
    vm.prank(approverAdam);
    mpCore.castApproval(actionId, uint8(Roles.Approver), reason);
  }

  function test_RevertIfActionNotActive() public {
    actionId = _createAction();
    _approveAction(approverAdam, actionId);
    _approveAction(approverAlicia, actionId);

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionId);

    vm.expectRevert(VertexCore.ActionNotActive.selector);
    mpCore.castApproval(actionId, uint8(Roles.Approver));
  }

  function test_RevertIfDuplicateApproval() public {
    actionId = _createAction();
    _approveAction(approverAdam, actionId);

    vm.expectRevert(VertexCore.DuplicateApproval.selector);
    vm.prank(approverAdam);
    mpCore.castApproval(actionId, uint8(Roles.Approver));
  }

  function test_RevertIfInvalidPolicyholder() public {
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
  function test_SuccessfulApprovalBySignature() public {
    // TODO
    // This is a happy path test.
    // Assert changes to Action storage.
    // Assert changes to Approval storage.
    // Assert event emission.
  }

  function test_RevertsIfInvalidPolicyholder() public {
    // TODO
    // https://github.com/llama-community/vertex-v1/issues/62
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
    // TODO
    // This is a happy path test.
    // Assert changes to Action storage.
    // Assert changes to Disapproval storage.
    // Assert event emission.
  }

  function test_SuccessfulDisapprovalWithReason(string calldata reason) public {
    actionId = _createApproveAndQueueAction();
    vm.expectEmit(true, true, true, true);
    emit PolicyholderDisapproved(actionId, disapproverDrake, 1, reason);
    vm.prank(disapproverDrake);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover), reason);
  }

  function test_RevertIfActionNotQueued() public {
    actionId = _createAction();

    vm.expectRevert(VertexCore.ActionNotQueued.selector);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));
  }

  function test_RevertIfDuplicateDisapproval() public {
    actionId = _createApproveAndQueueAction();

    _disapproveAction(disapproverDrake, actionId);

    vm.expectRevert(VertexCore.DuplicateDisapproval.selector);
    vm.prank(disapproverDrake);
    mpCore.castDisapproval(actionId, uint8(Roles.Disapprover));
  }

  function test_RevertIfInvalidPolicyholder() public {
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
  function test_SuccessfulDisapprovalBySignature() public {
    // TODO
    // This is a happy path test.
    // Sign a message and have one account cast a disapproval on behalf of another.
    // Assert changes to Action storage.
    // Assert changes to Disapproval storage.
    // Assert event emission.
  }

  function test_RevertsIfCallerIsNotPolicyHolder() public {
    // TODO
    // https://github.com/llama-community/vertex-v1/issues/62
  }
}

contract CreateAndAuthorizeStrategies is VertexCoreTest {
  // TODO convert this to a fuzz test using random approvalPeriods, queuingDuration, etc
  function test_CreateNewStrategies() public {
    Strategy[] memory newStrategies = new Strategy[](3);
    VertexStrategy[] memory strategyAddresses = new VertexStrategy[](3);

    // TODO one option might be to create a new function to generate random
    // strategies that just takes a salt generated by the fuzzer, e.g.
    // _createStrategy(salt), that function could then return the input args
    // it used to instantiate the Strategy so that you can assert against
    // them below.
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
        lens.computeVertexStrategyAddress(address(strategyLogic), newStrategies[i], address(mpCore));
    }

    vm.startPrank(address(mpCore));

    vm.expectEmit(true, true, true, true);
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

    vm.expectEmit(true, true, true, true);
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

  function test_UniquenessOfInput() public {
    // TODO
    // What happens if duplicate strategies are in the input array?
  }

  function test_Idempotency() public {
    // TODO
    // What happens if it is called twice with the same input?
  }

  function test_CanBeCalledByASuccessfulAction() public {
    // TODO
    // Submit an action to call this function and authorize a new Strategy.
    // Approve and queue the action.
    // Execute the action.
    // Ensure that the strategy is now authorized.
  }
}

contract UnauthorizeStrategies is VertexCoreTest {
  function test_UnauthorizeStrategies() public {
    vm.startPrank(address(mpCore));
    assertEq(mpCore.authorizedStrategies(mpStrategy1), true);
    assertEq(mpCore.authorizedStrategies(mpStrategy2), true);

    vm.expectEmit(true, true, true, true);
    emit StrategyUnauthorized(mpStrategy1);
    emit StrategyUnauthorized(mpStrategy2);

    VertexStrategy[] memory strategies = new VertexStrategy[](2);
    strategies[0] = mpStrategy1;
    strategies[1] = mpStrategy2;

    mpCore.unauthorizeStrategies(strategies);

    assertEq(mpCore.authorizedStrategies(mpStrategy1), false);
    assertEq(mpCore.authorizedStrategies(mpStrategy2), false);

    // TODO assert that calling createAction on a freshly unauthorized
    // strategy will revert with InvalidStrategy.
  }

  // TODO decide what should happen to actions attached to strategies that
  // have been unauthorized and test that behavior (if any).
}

contract CreateAndAuthorizeAccounts is VertexCoreTest {
  function test_CreateNewAccounts() public {
    string[] memory newAccounts = Solarray.strings("VertexAccount2", "VertexAccount3", "VertexAccount4");
    VertexAccount[] memory accountAddresses = new VertexAccount[](3);

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeVertexAccountAddress(address(accountLogic), newAccounts[i], address(mpCore));
    }

    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[0], address(accountLogic), newAccounts[0]);
    emit AccountAuthorized(accountAddresses[1], address(accountLogic), newAccounts[1]);
    emit AccountAuthorized(accountAddresses[2], address(accountLogic), newAccounts[2]);

    vm.prank(address(mpCore));
    mpCore.createAndAuthorizeAccounts(address(accountLogic), newAccounts);
  }

  function test_RevertIfReinitialized() public {
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

    vm.expectEmit(true, true, true, true);
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

  function test_UniquenessOfInput() public {
    // TODO
    // What happens if duplicate account names are in the input array?
  }

  function test_Idempotency() public {
    // TODO
    // What happens if it is called twice with the same inputs?
  }

  function test_CanBeCalledByASuccessfulAction() public {
    // TODO
    // Submit an action to call this function and authorize a new Account.
    // Approve and queue the action.
    // Execute the action.
    // Ensure that the account is now authorized.
  }
}

contract GetActionState is VertexCoreTest {
  function testFuzz_RevertsOnInvalidAction(uint256 invalidActionId) public {
    vm.expectRevert(VertexCore.InvalidActionId.selector);
    mpCore.getActionState(invalidActionId);
  }

  function test_CanceledActionsHaveStateCanceled() public {
    uint256 actionId = _createAction();
    vm.prank(adminAlice);
    mpCore.cancelAction(actionId);

    uint256 currentState = uint256(mpCore.getActionState(0));
    uint256 canceledState = uint256(ActionState.Canceled);
    assertEq(currentState, canceledState);
  }

  function test_UnpassedActionsPriorToApprovalEndBlockHaveStateActive() public {
    // TODO
    // create an action such that action.strategy.isFixedLengthApprovalPeriod == false
    // confirm its state begins at Active
  }
  function test_ApprovedActionsWithFixedLengthHaveStateActive() public {
    // TODO
    // create an action such that action.strategy.isFixedLengthApprovalPeriod == true
    // have enough accounts approve it before the end of the approvalEndBlock so that it will succeed
    // confirm its state is still Active, not Approved
  }
  function test_PassedActionsPriorToApprovalEndBlockHaveStateApproved() public {
    // TODO
    // create an action such that action.strategy.isFixedLengthApprovalPeriod == false
    // confirm its state begins at Active
  }
  function testFuzz_ApprovedActionsHaveStateApproved(uint256 _blocksSinceCreation) public {
    // TODO
    // create an action such that action.strategy.isFixedLengthApprovalPeriod == false
    // have enough accounts approve it so that it will pass
    // bound(_blocksSinceCreation, 0, approvalPeriod * 2);
    // vm.roll(_blocksSinceCreation)
    // if _blocksSinceCreation => approvalPeriod --> expect Approved
    // if _blocksSinceCreation < approvalPeriod --> expect Active
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

contract Integration is VertexCoreTest {
  function test_CompleteActionFlow() public {
    _executeCompleteActionFlow();
  }

  function testFuzz_NewVertexInstancesCanBeDeployed() public {
    // TODO
    // Test that the root/llama VertexCore can deploy new client VertexCore
    // instances by creating an action to call VertexFactory.deploy.
  }

  function testFuzz_ETHSendFromAccountViaActionApproval(uint256 _ethAmount) public {
    // TODO test that funds can be moved from VertexAccounts via actions
    // submitted and approved through VertexCore
  }

  function testFuzz_ERC20SendFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be moved from VertexAccounts via actions
    // submitted and approved through VertexCore
  }

  function testFuzz_ERC20ApprovalFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be approved + transferred from VertexAccounts via actions
    // submitted and approved through VertexCore
  }
}
