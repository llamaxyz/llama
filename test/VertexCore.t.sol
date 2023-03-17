// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {ProtocolXYZ} from "test/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {Action, Strategy, PermissionData, PolicyGrantData, PermissionMetadata} from "src/lib/Structs.sol";
import {VertexTestSetup} from "test/utils/VertexTestSetup.sol";

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
  event StrategyAuthorized(VertexStrategy indexed strategy, Strategy strategyData);
  event StrategyUnauthorized(VertexStrategy indexed strategy);
  event AccountAuthorized(VertexAccount indexed account, string name);

  function setUp() public virtual override {
    VertexTestSetup.setUp();
  }

  /*///////////////////////////////////////////////////////////////
                        Helpers
    //////////////////////////////////////////////////////////////*/

  function _createAction() public returns (uint256 actionId) {
    vm.prank(actionCreator);
    actionId = core.createAction(
      strategy1,
      address(mockProtocol),
      0, // value
      PAUSE_SELECTOR,
      abi.encode(true)
    );
  }

  function _approveAction(address _policyholder, uint256 _actionId) public {
    vm.expectEmit(true, true, true, true);
    emit PolicyholderApproved(_actionId, _policyholder, 1, "");
    vm.prank(_policyholder);
    core.castApproval(_actionId, "approver");
  }

  function _approveAction(address _policyholder) public {
    uint256 _assumedActionId = 0;
    _approveAction(_policyholder, _assumedActionId);
  }

  function _disapproveAction(address _policyholder, uint256 _actionId) public {
    vm.expectEmit(true, true, true, true);
    emit PolicyholderDisapproved(_actionId, _policyholder, 1, "");
    vm.prank(_policyholder);
    core.castDisapproval(_actionId, "disapprover");
  }

  function _disapproveAction(address _policyholder) public {
    uint256 _assumedActionId = 0;
    _disapproveAction(_policyholder, _assumedActionId);
  }

  function _queueAction(uint256 _actionId) public {
    uint256 executionTime = block.timestamp + strategy1.queuingPeriod();
    vm.expectEmit(true, true, true, true);
    emit ActionQueued(_actionId, address(this), strategy1, actionCreator, executionTime);
    core.queueAction(_actionId);
  }

  function _queueAction() public {
    uint256 _assumedActionId = 0;
    _queueAction(_assumedActionId);
  }

  function _executeAction() public {
    vm.expectEmit(true, true, true, true);
    emit ActionExecuted(0, address(this), strategy1, actionCreator);
    core.executeAction(0);

    Action memory action = core.getAction(0);
    assertEq(action.executed, true);
  }

  function _executeCompleteActionFlow() internal {
    _createAction();

    _approveAction(policyHolderPam);
    _approveAction(policyHolderPatty);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategy1.isActionPassed(0), true);
    _queueAction();

    _disapproveAction(policyHolderPam);

    vm.warp(block.timestamp + 5 days);

    _executeAction();
  }

  function _deployAndAuthorizeAdditionalStrategyLogic() internal returns (address) {
    VertexStrategy additionalStrategyLogic = new VertexStrategy();
    vm.prank(address(core));
    factory.authorizeStrategyLogic(address(additionalStrategyLogic));
    return address(additionalStrategyLogic);
  }

  function _deployAndAuthorizeAdditionalAccountLogic() internal returns (address) {
    VertexAccount additionalAccountLogic = new VertexAccount();
    vm.prank(address(core));
    factory.authorizeAccountLogic(address(additionalAccountLogic));
    return address(additionalAccountLogic);
  }
}

contract Setup is VertexCoreTest {
  function test_setUp() public {
    assertEq(address(core.factory()), address(factory));
    assertEq(core.name(), "Root Vertex");
    assertEq(address(core.policy()), address(policy));

    assertTrue(core.authorizedStrategies(strategy1));
    assertTrue(core.authorizedStrategies(strategy1));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    account1.initialize("VertexAccount0");

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    account2.initialize("VertexAccount1");
  }
}

contract Initialize is VertexCoreTest {
  // TODO might want a new setup function here which deploys a VertexCore
  // without initializing it, then allows the test functions below to initialize

  function test_StrategiesAreDeployedAtExpectedAddress() public {
    // TODO confirm strateges have been deployed at expected addresses
  }

  function test_EmitsStrategyAuthorizedEventForEachStrategy() public {
    // TODO confirm strategy events have been emitted
  }

  function test_StrategiesHaveVertexCoreAddressInStorage() public {
    // TODO confirm strategies have this vertex core address in storage
  }

  function test_StrategiesHavePolicyAddressInStorage() public {
    // TODO confirm strategies have the correct policy address in storage
  }

  function test_StrategiesAreAuthorizedByVertexCore() public {
    // TODO confirm strategies are authorized
  }

  function test_AccountsAreDeployedAtExpectedAddress() public {
    // TODO confirm accounts have been deployed at expected addresses
  }

  function test_EmitsAccountAuthorizedEventForEachAccount() public {
    // TODO confirm events have been emitted
  }

  function test_AccountsHaveVertexCoreAddressInStorage() public {
    // TODO confirm accounts have this vertex core address in storage
  }

  function test_AccountsHaveNameInStorage() public {
    // TODO confirm accounts have the correct name in storage
  }

  function test_AccountsAreAuthorizedByVertexCore() public {
    // TODO confirm accounts are authorized
  }
}

contract CreateAction is VertexCoreTest {
  // TODO fuzz
  // function testFuzz_CreatesAnAction(address _target, uint256 _value, bytes memory _data)
  function test_CreatesAnAction() public {
    vm.expectEmit(true, true, true, true);
    emit ActionCreated(0, actionCreator, strategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));
    vm.prank(actionCreator);
    uint256 _actionId = core.createAction(strategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));

    Action memory action = core.getAction(_actionId);
    uint256 approvalEndTime = block.timestamp + action.strategy.approvalPeriod();

    assertEq(_actionId, 0);
    assertEq(core.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(approvalEndTime, block.timestamp + 2 days);
    assertEq(action.approvalPolicySupply, 5);
    assertEq(action.disapprovalPolicySupply, 5);
  }

  function test_RevertIfStrategyUnauthorized() public {
    VertexStrategy unauthorizedStrategy = VertexStrategy(makeAddr("unauthorized strategy"));
    vm.prank(actionCreator);
    vm.expectRevert(VertexCore.InvalidStrategy.selector);
    core.createAction(unauthorizedStrategy, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));
  }

  function test_RevertIfStrategyIsFromAnotherVertex() public {
    // TODO like the previous test, but deploy a real strategy and use that as unauthorizedStrategy
  }

  function testFuzz_RevertIfPolicyholderNotMinted(address user) public {
    if (user == address(0)) user = address(100); // Faster than vm.assume, since 0 comes up a lot.
    vm.assume(policy.balanceOf(user) == 0);
    vm.prank(user);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    core.createAction(strategy1, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));
  }

  function test_RevertIfNoPermissionForStrategy() public {
    vm.prank(actionCreator);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    core.createAction(strategy2, address(mockProtocol), 0, PAUSE_SELECTOR, abi.encode(true));
  }

  function testFuzz_RevertIfNoPermissionForTarget(address _incorrectTarget) public {
    vm.assume(_incorrectTarget != address(mockProtocol));
    vm.prank(actionCreator);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    core.createAction(strategy1, _incorrectTarget, 0, PAUSE_SELECTOR, abi.encode(true));
  }

  function testFuzz_RevertIfBadPermissionForSelector(bytes4 _badSelector) public {
    vm.assume(_badSelector != PAUSE_SELECTOR && _badSelector != FAIL_SELECTOR && _badSelector != RECEIVE_ETH_SELECTOR);
    vm.prank(actionCreator);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    core.createAction(strategy1, address(mockProtocol), 0, _badSelector, abi.encode(true));
  }

  function testFuzz_RevertIfPermissionExpired(uint256 _expirationTimestamp) public {
    // TODO
    // issue a policy NFT to a user which expires at _expirationTimestamp
    // vm.warp to that timestamp
    // try to createAction, expect it to revert
  }
}

contract CancelAction is VertexCoreTest {
  function setUp() public override {
    VertexCoreTest.setUp();
    _createAction();
  }

  function test_CreatorCancelFlow() public {
    vm.startPrank(actionCreator);
    vm.expectEmit(true, true, true, true);
    emit ActionCanceled(0);
    core.cancelAction(0);
    vm.stopPrank();
    // TODO confirm storage changes, e.g. action.canceled, queuedActions
  }

  function testFuzz_RevertIfNotCreator(address _randomCaller) public {
    vm.assume(_randomCaller != actionCreator);
    vm.prank(_randomCaller);
    vm.expectRevert(VertexCore.ActionCannotBeCanceled.selector);
    core.cancelAction(0);
  }

  // TODO fuzz over action IDs, bound(actionsCount, type(uint).max)
  function test_RevertIfInvalidActionId() public {
    vm.startPrank(actionCreator);
    vm.expectRevert(VertexCore.InvalidActionId.selector);
    core.cancelAction(1);
    vm.stopPrank();
  }

  function test_RevertIfAlreadyCanceled() public {
    vm.startPrank(actionCreator);
    core.cancelAction(0);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    core.cancelAction(0);
    vm.stopPrank();
  }

  function test_RevertIfActionExecuted() public {
    _executeCompleteActionFlow();

    vm.startPrank(actionCreator);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    core.cancelAction(0);
    vm.stopPrank();
  }

  function test_RevertIfActionExpired() public {
    _approveAction(policyHolderPam);
    _approveAction(policyHolderPatty);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategy1.isActionPassed(0), true);
    _queueAction();

    _disapproveAction(policyHolderPam);

    vm.warp(block.timestamp + 15 days);

    vm.startPrank(actionCreator);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    core.cancelAction(0);
    vm.stopPrank();
  }

  function test_RevertIfActionFailed() public {
    _approveAction(policyHolderPam);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategy1.isActionPassed(0), false);

    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    core.cancelAction(0);
  }

  function test_CancelIfDisapproved() public {
    _approveAction(policyHolderPam);
    _approveAction(policyHolderPatty);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategy1.isActionPassed(0), true);
    _queueAction();

    _disapproveAction(policyHolderPam);
    _disapproveAction(policyHolderPatty);
    _disapproveAction(policyHolderPaul);

    vm.expectEmit(true, true, true, true);
    emit ActionCanceled(0);
    core.cancelAction(0);
  }

  function test_RevertIfDisapprovalDoesNotReachQuorum() public {
    _approveAction(policyHolderPam);
    _approveAction(policyHolderPatty);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategy1.isActionPassed(0), true);
    _queueAction();

    vm.expectRevert(VertexCore.ActionCannotBeCanceled.selector);
    core.cancelAction(0);
  }
}

contract QueueAction is VertexCoreTest {
  function test_RevertIfNotApproved() public {
    _createAction();
    _approveAction(policyHolderPam);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(VertexCore.InvalidStateForQueue.selector);
    core.queueAction(0);
  }

  // TODO fuzz over action IDs, bound(actionsCount, type(uint).max)
  function test_RevertIfInvalidActionId() public {
    _createAction();
    _approveAction(policyHolderPam);
    _approveAction(policyHolderPatty);
    _approveAction(policyHolderPaul);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(VertexCore.InvalidActionId.selector);
    core.queueAction(1);
  }
}

contract ExecuteAction is VertexCoreTest {
  uint256 actionId;

  function setUp() public override {
    VertexCoreTest.setUp();

    actionId = _createAction();
    _approveAction(policyHolderPam, actionId);
    _approveAction(policyHolderPatty, actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategy1.isActionPassed(actionId), true);
  }

  function test_ActionExecution() public {
    // TODO
    // This is a happy path test.
    // Execute the queued action, confirm the call was performed.
    // Assert that ActionExecuted was emitted.
    // Assert that the call result was returned.
  }

  function test_RevertIfNotQueued() public {
    // TODO assert action state
    vm.expectRevert(VertexCore.OnlyQueuedActions.selector);
    core.executeAction(actionId);
  }

  // TODO fuzz over action IDs, bound(actionsCount, type(uint).max)
  function test_RevertIfInvalidActionId() public {
    core.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(VertexCore.InvalidActionId.selector);
    core.executeAction(actionId + 1);
  }

  // TODO fuzz over seconds jumped forward, only assert the revert if < exectionTime
  function test_RevertIfTimelockNotFinished() public {
    core.queueAction(actionId);

    vm.warp(block.timestamp + 6 hours);

    vm.expectRevert(VertexCore.TimelockNotFinished.selector);
    core.executeAction(actionId);
  }

  function test_RevertIfInsufficientMsgValue() public {
    vm.prank(actionCreator);
    actionId = core.createAction(strategy1, address(mockProtocol), 1e18, RECEIVE_ETH_SELECTOR, abi.encode(true));

    _approveAction(policyHolderPam, actionId);
    _approveAction(policyHolderPatty, actionId);

    vm.warp(block.timestamp + 6 days);

    core.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(VertexCore.InsufficientMsgValue.selector);
    core.executeAction(actionId);
  }

  function test_RevertIfFailedActionExecution() public {
    vm.prank(actionCreator);
    actionId = core.createAction(
      strategy1,
      address(mockProtocol),
      0, // value
      FAIL_SELECTOR,
      abi.encode("")
    );

    _approveAction(policyHolderPam, actionId);
    _approveAction(policyHolderPatty, actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategy1.isActionPassed(actionId), true);

    core.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(VertexCore.FailedActionExecution.selector);
    core.executeAction(actionId);
  }

  function test_HandlesReentrancy() public {
    // TODO
    // What happens if somone queues an action to call core.executeAction?
    // Calling executeAction on that action should revert with OnlyQueuedActions.
    // We should confirm that nothing weird happens if this is done
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
  }

  function test_SuccessfulApprovalWithReason(string calldata reason) public {
    actionId = _createAction();
    vm.expectEmit(true, true, true, true);
    emit PolicyholderApproved(actionId, policyHolderPam, 1, reason);
    vm.prank(policyHolderPam);
    core.castApproval(actionId, "approver", reason);
  }

  function test_RevertIfActionNotActive() public {
    actionId = _createAction();
    _approveAction(policyHolderPam, actionId);
    _approveAction(policyHolderPatty, actionId);

    vm.warp(block.timestamp + 6 days);

    core.queueAction(actionId);

    vm.expectRevert(VertexCore.ActionNotActive.selector);
    core.castApproval(actionId, "approver");
  }

  function test_RevertIfDuplicateApproval() public {
    actionId = _createAction();
    _approveAction(policyHolderPam, actionId);

    vm.expectRevert(VertexCore.DuplicateApproval.selector);
    vm.prank(policyHolderPam);
    core.castApproval(actionId, "approver");
  }

  function test_RevertIfInvalidPolicyholder() public {
    actionId = _createAction();
    address notPolicyholder = 0x9D3de545F58C696946b4Cf2c884fcF4f7914cB53;
    vm.prank(notPolicyholder);

    vm.expectRevert(VertexCore.InvalidPolicyholder.selector);
    core.castApproval(actionId, "approver");

    vm.prank(policyHolderPam);
    core.castApproval(actionId, "approver");
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
    _approveAction(policyHolderPam, _actionId);
    _approveAction(policyHolderPatty, _actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategy1.isActionPassed(_actionId), true);
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
    emit PolicyholderDisapproved(actionId, policyHolderPam, 1, reason);
    vm.prank(policyHolderPam);
    core.castDisapproval(actionId, "disapprover", reason);
  }

  function test_RevertIfActionNotQueued() public {
    actionId = _createAction();

    vm.expectRevert(VertexCore.ActionNotQueued.selector);
    core.castDisapproval(actionId, "disapprover");
  }

  function test_RevertIfDuplicateDisapproval() public {
    actionId = _createApproveAndQueueAction();

    _disapproveAction(policyHolderPam, actionId);

    vm.expectRevert(VertexCore.DuplicateDisapproval.selector);
    vm.prank(policyHolderPam);
    core.castDisapproval(actionId, "disapprover");
  }

  function test_RevertIfInvalidPolicyholder() public {
    actionId = _createApproveAndQueueAction();
    address notPolicyholder = 0x9D3de545F58C696946b4Cf2c884fcF4f7914cB53;
    vm.prank(notPolicyholder);

    vm.expectRevert(VertexCore.InvalidPolicyholder.selector);
    core.castDisapproval(actionId, "disapprover");

    vm.prank(policyHolderPam);
    core.castDisapproval(actionId, "disapprover");
  }
}

contract CastDisapprovalBySig is VertexCoreTest {
  function test_SuccessfulDisapprovalBySignature() public {
    // TODO
    // This is a happy path test.
    // Sign a message and have one account cast a disapproval on behalf of another.
    // Assert changes to Action storage.
    // Assert changes to Dispproval storage.
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
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });

    newStrategies[1] = Strategy({
      approvalPeriod: 5 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });

    newStrategies[2] = Strategy({
      approvalPeriod: 6 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });

    for (uint256 i; i < newStrategies.length; i++) {
      strategyAddresses[i] = lens.computeVertexStrategyAddress(address(strategyLogic), newStrategies[i], address(core));
    }

    vm.startPrank(address(core));

    vm.expectEmit(true, true, true, true);
    emit StrategyAuthorized(strategyAddresses[0], newStrategies[0]);
    vm.expectEmit(true, true, true, true);
    emit StrategyAuthorized(strategyAddresses[1], newStrategies[1]);
    vm.expectEmit(true, true, true, true);
    emit StrategyAuthorized(strategyAddresses[2], newStrategies[2]);

    core.createAndAuthorizeStrategies(address(strategyLogic), newStrategies);

    assertEq(core.authorizedStrategies(strategyAddresses[0]), true);
    assertEq(core.authorizedStrategies(strategyAddresses[1]), true);
    assertEq(core.authorizedStrategies(strategyAddresses[2]), true);
  }

  function test_CreateNewStrategyWithAdditionalStrategyLogic() public {
    address additionalStrategyLogic = _deployAndAuthorizeAdditionalStrategyLogic();

    Strategy[] memory newStrategies = new Strategy[](1);

    newStrategies[0] = Strategy({
      approvalPeriod: 7 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });

    VertexStrategy strategyAddress =
      lens.computeVertexStrategyAddress(additionalStrategyLogic, newStrategies[0], address(core));

    vm.startPrank(address(core));

    vm.expectEmit(true, true, true, true);
    emit StrategyAuthorized(strategyAddress, newStrategies[0]);

    core.createAndAuthorizeStrategies(additionalStrategyLogic, newStrategies);

    assertEq(core.authorizedStrategies(strategyAddress), true);
  }

  function test_RevertIf_StrategyLogicNotAuthorized() public {
    Strategy[] memory newStrategies = new Strategy[](1);

    newStrategies[0] = Strategy({
      approvalPeriod: 7 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalRole: "approver",
      disapprovalRole: "disapprover",
      forceApprovalRoles: new bytes32[](0),
      forceDisapprovalRoles: new bytes32[](0)
    });

    vm.startPrank(address(core));

    vm.expectRevert(VertexCore.UnauthorizedStrategyLogic.selector);
    core.createAndAuthorizeStrategies(address(0x1), newStrategies);
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
    vm.startPrank(address(core));
    assertEq(core.authorizedStrategies(strategy1), true);
    assertEq(core.authorizedStrategies(strategy1), true);

    vm.expectEmit(true, true, true, true);
    emit StrategyUnauthorized(strategy1);
    vm.expectEmit(true, true, true, true);
    emit StrategyUnauthorized(strategy1);

    VertexStrategy[] memory strategies = new VertexStrategy[](2);
    strategies[0] = strategy1;
    strategies[1] = strategy1;

    core.unauthorizeStrategies(strategies);

    assertEq(core.authorizedStrategies(strategy1), false);
    assertEq(core.authorizedStrategies(strategy1), false);

    // TODO assert that calling createAction on a freshly unauthorized
    // strategy will revert with InvalidStrategy.
  }

  // TODO decide what should happen to actions attached to strategies that
  // have been unauthorized and test that behavior (if any).
}

contract CreateAndAuthorizeAccounts is VertexCoreTest {
  function test_CreateNewAccounts() public {
    string[] memory newAccounts = new string[](3);
    VertexAccount[] memory accountAddresses = new VertexAccount[](3);

    newAccounts[0] = "VertexAccount2";
    newAccounts[1] = "VertexAccount3";
    newAccounts[2] = "VertexAccount4";

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeVertexAccountAddress(address(accountLogic), newAccounts[i], address(core));
    }

    vm.startPrank(address(core));

    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[0], newAccounts[0]);
    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[1], newAccounts[1]);
    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[2], newAccounts[2]);
    core.createAndAuthorizeAccounts(address(accountLogic), newAccounts);
  }

  function test_RevertIfReinitialized() public {
    string[] memory newAccounts = new string[](3);
    VertexAccount[] memory accountAddresses = new VertexAccount[](3);

    newAccounts[0] = "VertexAccount2";
    newAccounts[1] = "VertexAccount3";
    newAccounts[2] = "VertexAccount4";

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeVertexAccountAddress(address(accountLogic), newAccounts[i], address(core));
    }

    vm.startPrank(address(core));
    core.createAndAuthorizeAccounts(address(accountLogic), newAccounts);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[0].initialize(newAccounts[0]);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[1].initialize(newAccounts[1]);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[2].initialize(newAccounts[2]);
  }

  function test_CreateNewAccountsWithAdditionalAccountLogic() public {
    address additionalAccountLogic = _deployAndAuthorizeAdditionalAccountLogic();

    string[] memory newAccounts = new string[](3);
    VertexAccount[] memory accountAddresses = new VertexAccount[](3);

    newAccounts[0] = "VertexAccount2";
    newAccounts[1] = "VertexAccount3";
    newAccounts[2] = "VertexAccount4";

    for (uint256 i; i < newAccounts.length; i++) {
      accountAddresses[i] = lens.computeVertexAccountAddress(additionalAccountLogic, newAccounts[i], address(core));
    }

    vm.startPrank(address(core));

    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[0], newAccounts[0]);
    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[1], newAccounts[1]);
    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[2], newAccounts[2]);
    core.createAndAuthorizeAccounts(additionalAccountLogic, newAccounts);
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
  function test_RevertsOnInvalidAction() public {} // TODO
  function test_CanceledActionsHaveStateCanceled() public {} // TODO
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
  function test_QueuedActionsHaveStateQueued() public {} // TODO
  function test_ExecutedActionsHaveStateExecuted() public {} // TODO
  function test_RejectedActionsHaveStateFailed() public {} // TODO
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
    // submitted and approved through VertextCore
  }

  function testFuzz_ERC20SendFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be moved from VertexAccounts via actions
    // submitted and approved through VertextCore
  }

  function testFuzz_ERC20ApprovalFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be approved + transferred from VertexAccounts via actions
    // submitted and approved through VertextCore
  }
}
