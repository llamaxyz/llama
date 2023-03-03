// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {VertexCore} from "src/VertexCore.sol";
import {IVertexCore} from "src/interfaces/IVertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {ProtocolXYZ} from "test/mock/ProtocolXYZ.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexLens} from "src/VertexLens.sol";
import {
  Action,
  Strategy,
  PermissionData,
  WeightByPermission,
  PolicyGrantData,
  PermissionMetadata
} from "src/lib/Structs.sol";

contract VertexCoreTest is Test {
  // Vertex system
  VertexCore public vertex;
  VertexCore public vertexCore;
  VertexAccount public vertexAccountImplementation;
  VertexPolicy public vertexPolicyImplementation;
  VertexFactory public vertexFactory;
  VertexStrategy[] public strategies;
  VertexAccount[] public accounts;
  VertexPolicy public policy;
  VertexLens public lens = new VertexLens();

  // Mock protocol for action targets.
  ProtocolXYZ public targetProtocol;

  // Testing agents
  address public constant actionCreator = address(0x1337);
  address public constant policyholder1 = address(0x1338);
  address public constant policyholder2 = address(0x1339);
  address public constant policyholder3 = address(0x1340);
  address public constant policyholder4 = address(0x1341);
  bytes4 public constant pauseSelector = 0x02329a29;
  bytes4 public constant failSelector = 0xa9cc4718;
  bytes4 public constant receiveETHSelector = 0x4185f8eb;

  PermissionData public permission;
  uint256[][] public expirationTimestamps;
  uint256[] public policyIds;

  address[] public initialPolicies;
  PolicyGrantData[] public initialPermissions;
  // Strategy config
  // TODO fuzz over these values rather than hardcoding
  uint256 public constant approvalPeriod = 2 days;
  uint256 public constant queuingPeriod = 4 days;
  uint256 public constant expirationPeriod = 8 days;
  bool public constant isFixedLengthApprovalPeriod = true;
  uint256 public constant minApprovalPct = 4000;
  uint256 public constant minDisapprovalPct = 2000;

  // Events
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
  event PolicyholderApproved(uint256 id, address indexed policyholder, uint256 weight);
  event PolicyholderDisapproved(uint256 id, address indexed policyholder, uint256 weight);
  event StrategyAuthorized(VertexStrategy indexed strategy, Strategy strategyData);
  event StrategyUnauthorized(VertexStrategy indexed strategy);
  event AccountAuthorized(VertexAccount indexed account, string name);

  function setUp() public virtual {
    // Setup strategy parameters
    WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](0);
    WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](0);
    Strategy[] memory initialStrategies = new Strategy[](2);
    string[] memory initialAccounts = new string[](2);

    initialStrategies[0] = Strategy({
      approvalPeriod: approvalPeriod,
      queuingPeriod: queuingPeriod,
      expirationPeriod: expirationPeriod,
      isFixedLengthApprovalPeriod: isFixedLengthApprovalPeriod,
      minApprovalPct: minApprovalPct,
      minDisapprovalPct: minDisapprovalPct,
      approvalWeightByPermission: approvalWeightByPermission,
      disapprovalWeightByPermission: disapprovalWeightByPermission
    });

    initialStrategies[1] = Strategy({
      approvalPeriod: approvalPeriod,
      queuingPeriod: 0,
      expirationPeriod: 1 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 8000,
      minDisapprovalPct: 10_001,
      approvalWeightByPermission: approvalWeightByPermission,
      disapprovalWeightByPermission: disapprovalWeightByPermission
    });

    initialAccounts[0] = "VertexAccount0";
    initialAccounts[1] = "VertexAccount1";

    // We don't instantiate any initial policies b/c we can't compute the strategy addresses yet.
    PolicyGrantData[] memory initialPolicyData = new PolicyGrantData[](0);

    // Deploy vertex and mock protocol
    vertexCore = new VertexCore();
    vertexAccountImplementation = new VertexAccount();
    vertexPolicyImplementation = new VertexPolicy();
    vertexFactory = new VertexFactory(
          vertexCore,
          vertexAccountImplementation,
          vertexPolicyImplementation,
          "ProtocolXYZ",
          "VXP",
          initialStrategies,
          initialAccounts,
          initialPolicyData
        );
    vertex = VertexCore(vertexFactory.rootVertex());
    targetProtocol = new ProtocolXYZ(address(vertex));

    strategies.push(_computeVertexStrategyAddress(initialStrategies[0]));
    strategies.push(_computeVertexStrategyAddress(initialStrategies[1]));

    accounts.push(_computeVertexAccountAddress(initialAccounts[0]));
    accounts.push(_computeVertexAccountAddress(initialAccounts[1]));

    // Set vertex's policy
    policy = vertex.policy();

    // Create and assign policies
    _grantPermissions(strategies[0], policy);
    vm.stopPrank();

    vm.label(actionCreator, "Action Creator");
    vm.label(address(targetProtocol), "ProtocolXYZ");
  }

  /*///////////////////////////////////////////////////////////////
                        Helpers
    //////////////////////////////////////////////////////////////*/

  function _createAction() public returns (uint256 actionId) {
    vm.prank(actionCreator);
    actionId = vertex.createAction(
      strategies[0],
      address(targetProtocol),
      0, // value
      pauseSelector,
      abi.encode(true)
    );
  }

  function _grantPermissions(VertexStrategy initialStrategy, VertexPolicy _policy) public {
    PermissionMetadata[] memory creatorPermissions = new PermissionMetadata[](3);
    PermissionMetadata[] memory pauserPermissions = new PermissionMetadata[](1);

    PermissionData memory pausePermission =
      PermissionData({target: address(targetProtocol), selector: pauseSelector, strategy: initialStrategy});
    PermissionData memory failPermission =
      PermissionData({target: address(targetProtocol), selector: failSelector, strategy: initialStrategy});
    PermissionData memory receiveETHPermission =
      PermissionData({target: address(targetProtocol), selector: receiveETHSelector, strategy: initialStrategy});
    creatorPermissions[0] = PermissionMetadata(lens.hashPermission(failPermission), 0);
    creatorPermissions[1] = PermissionMetadata(lens.hashPermission(pausePermission), 0);
    creatorPermissions[2] = PermissionMetadata(lens.hashPermission(receiveETHPermission), 0);
    pauserPermissions[0] = PermissionMetadata(lens.hashPermission(pausePermission), 0);

    PolicyGrantData[] memory initialPolicyData = new PolicyGrantData[](5);
    initialPolicyData[0] = PolicyGrantData(actionCreator, creatorPermissions);
    initialPolicyData[1] = PolicyGrantData(policyholder1, pauserPermissions);
    initialPolicyData[2] = PolicyGrantData(policyholder2, pauserPermissions);
    initialPolicyData[3] = PolicyGrantData(policyholder3, pauserPermissions);
    initialPolicyData[4] = PolicyGrantData(policyholder4, pauserPermissions);

    vm.prank(address(vertex));
    _policy.batchGrantPolicies(initialPolicyData);
  }

  function _approveAction(address _policyholder, uint256 _actionId) public {
    vm.expectEmit(true, true, true, true);
    emit PolicyholderApproved(_actionId, _policyholder, 1);
    vm.prank(_policyholder);
    vertex.submitApproval(_actionId);
  }

  function _approveAction(address _policyholder) public {
    uint256 _assumedActionId = 0;
    _approveAction(_policyholder, _assumedActionId);
  }

  function _disapproveAction(address _policyholder, uint256 _actionId) public {
    vm.expectEmit(true, true, true, true);
    emit PolicyholderDisapproved(_actionId, _policyholder, 1);
    vm.prank(_policyholder);
    vertex.submitDisapproval(_actionId);
  }

  function _disapproveAction(address _policyholder) public {
    uint256 _assumedActionId = 0;
    _disapproveAction(_policyholder, _assumedActionId);
  }

  function _queueAction(uint256 _actionId) public {
    uint256 executionTime = block.timestamp + strategies[0].queuingPeriod();
    vm.expectEmit(true, true, true, true);
    emit ActionQueued(_actionId, address(this), strategies[0], actionCreator, executionTime);
    vertex.queueAction(_actionId);
  }

  function _queueAction() public {
    uint256 _assumedActionId = 0;
    _queueAction(_assumedActionId);
  }

  function _executeAction() public {
    vm.expectEmit(true, true, true, true);
    emit ActionExecuted(0, address(this), strategies[0], actionCreator);
    vertex.executeAction(0);

    Action memory action = vertex.getAction(0);
    assertEq(action.executed, true);
  }

  function _executeCompleteActionFlow() internal {
    _createAction();

    _approveAction(policyholder1);
    _approveAction(policyholder2);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategies[0].isActionPassed(0), true);
    _queueAction();

    _disapproveAction(policyholder1);

    vm.warp(block.timestamp + 5 days);

    _executeAction();
  }

  function _computeVertexStrategyAddress(Strategy memory _strategy) internal view returns (VertexStrategy) {
    bytes memory bytecode = type(VertexStrategy).creationCode;
    return VertexStrategy(
      computeCreate2Address(
        keccak256(
          abi.encodePacked(
            _strategy.approvalPeriod,
            _strategy.queuingPeriod,
            _strategy.expirationPeriod,
            _strategy.minApprovalPct,
            _strategy.minDisapprovalPct,
            _strategy.isFixedLengthApprovalPeriod
          )
        ), // salt
        keccak256(abi.encodePacked(bytecode, abi.encode(_strategy, vertex.policy(), address(vertex)))),
        address(vertex) // deployer
      )
    );
  }

  function _computeVertexAccountAddress(string memory _name) internal view returns (VertexAccount) {
    address _computedAddress = Clones.predictDeterministicAddress(
      address(vertexAccountImplementation),
      keccak256(abi.encode(_name)), // salt
      address(vertex) // deployer
    );
    return VertexAccount(payable(_computedAddress));
  }
}

contract Setup is VertexCoreTest {
  function test_setUp() public {
    assertEq(vertex.name(), "ProtocolXYZ");

    assertTrue(vertex.authorizedStrategies(strategies[0]));
    assertTrue(vertex.authorizedStrategies(strategies[1]));
    assertEq(strategies.length, 2);

    assertEq(accounts.length, 2);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accounts[0].initialize("VertexAccount0", address(vertex));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accounts[1].initialize("VertexAccount1", address(vertex));
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
    emit ActionCreated(0, actionCreator, strategies[0], address(targetProtocol), 0, pauseSelector, abi.encode(true));
    vm.prank(actionCreator);
    uint256 _actionId = vertex.createAction(strategies[0], address(targetProtocol), 0, pauseSelector, abi.encode(true));

    Action memory action = vertex.getAction(_actionId);
    uint256 approvalEndTime = block.timestamp + action.strategy.approvalPeriod();

    assertEq(_actionId, 0);
    assertEq(vertex.actionsCount(), 1);
    assertEq(action.creationTime, block.timestamp);
    assertEq(approvalEndTime, block.timestamp + 2 days);
    assertEq(action.approvalPolicySupply, 5);
    assertEq(action.disapprovalPolicySupply, 5);
  }

  function test_RevertIfStrategyUnauthorized() public {
    VertexStrategy unauthorizedStrategy = VertexStrategy(makeAddr("unauthorized strategy"));
    vm.prank(actionCreator);
    vm.expectRevert(VertexCore.InvalidStrategy.selector);
    vertex.createAction(unauthorizedStrategy, address(targetProtocol), 0, pauseSelector, abi.encode(true));
  }

  function test_RevertIfStrategyIsFromAnotherVertex() public {
    // TODO like the previous test, but deploy a real strategy and use that as unauthorizedStrategy
  }

  function testFuzz_RevertIfPolicyholderNotMinted(address _notActionCreator) public {
    vm.assume(_notActionCreator != actionCreator);
    vm.prank(_notActionCreator);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    vertex.createAction(strategies[1], address(targetProtocol), 0, pauseSelector, abi.encode(true));
  }

  function test_RevertIfNoPermissionForStrategy() public {
    vm.prank(actionCreator);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    vertex.createAction(strategies[1], address(targetProtocol), 0, pauseSelector, abi.encode(true));
  }

  function testFuzz_RevertIfNoPermissionForTarget(address _incorrectTarget) public {
    vm.assume(_incorrectTarget != address(targetProtocol));
    vm.prank(actionCreator);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    vertex.createAction(strategies[0], _incorrectTarget, 0, pauseSelector, abi.encode(true));
  }

  function testFuzz_RevertIfBadPermissionForSelector(bytes4 _badSelector) public {
    vm.assume(_badSelector != pauseSelector && _badSelector != failSelector && _badSelector != receiveETHSelector);
    vm.prank(actionCreator);
    vm.expectRevert(VertexCore.PolicyholderDoesNotHavePermission.selector);
    vertex.createAction(strategies[0], address(targetProtocol), 0, _badSelector, abi.encode(true));
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
    vertex.cancelAction(0);
    vm.stopPrank();
    // TODO confirm storage changes, e.g. action.canceled, queuedActions
  }

  function testFuzz_RevertIfNotCreator(address _randomCaller) public {
    vm.assume(_randomCaller != actionCreator);
    vm.prank(_randomCaller);
    vm.expectRevert(VertexCore.ActionCannotBeCanceled.selector);
    vertex.cancelAction(0);
  }

  // TODO fuzz over action IDs, bound(actionsCount, type(uint).max)
  function test_RevertIfInvalidActionId() public {
    vm.startPrank(actionCreator);
    vm.expectRevert(VertexCore.InvalidActionId.selector);
    vertex.cancelAction(1);
    vm.stopPrank();
  }

  function test_RevertIfAlreadyCanceled() public {
    vm.startPrank(actionCreator);
    vertex.cancelAction(0);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    vertex.cancelAction(0);
    vm.stopPrank();
  }

  function test_RevertIfActionExecuted() public {
    _executeCompleteActionFlow();

    vm.startPrank(actionCreator);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    vertex.cancelAction(0);
    vm.stopPrank();
  }

  function test_RevertIfActionExpired() public {
    _approveAction(policyholder1);
    _approveAction(policyholder2);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategies[0].isActionPassed(0), true);
    _queueAction();

    _disapproveAction(policyholder1);

    vm.warp(block.timestamp + 15 days);

    vm.startPrank(actionCreator);
    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    vertex.cancelAction(0);
    vm.stopPrank();
  }

  function test_RevertIfActionFailed() public {
    _approveAction(policyholder1);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategies[0].isActionPassed(0), false);

    vm.expectRevert(VertexCore.InvalidCancelation.selector);
    vertex.cancelAction(0);
  }

  function test_CancelIfDisapproved() public {
    _approveAction(policyholder1);
    _approveAction(policyholder2);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategies[0].isActionPassed(0), true);
    _queueAction();

    _disapproveAction(policyholder1);
    _disapproveAction(policyholder2);
    _disapproveAction(policyholder3);

    vm.expectEmit(true, true, true, true);
    emit ActionCanceled(0);
    vertex.cancelAction(0);
  }

  function test_RevertIfDisapprovalDoesNotReachQuorum() public {
    _approveAction(policyholder1);
    _approveAction(policyholder2);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategies[0].isActionPassed(0), true);
    _queueAction();

    vm.expectRevert(VertexCore.ActionCannotBeCanceled.selector);
    vertex.cancelAction(0);
  }
}

contract QueueAction is VertexCoreTest {
  function test_RevertIfNotApproved() public {
    _createAction();
    _approveAction(policyholder1);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(VertexCore.InvalidStateForQueue.selector);
    vertex.queueAction(0);
  }

  // TODO fuzz over action IDs, bound(actionsCount, type(uint).max)
  function test_RevertIfInvalidActionId() public {
    _createAction();
    _approveAction(policyholder1);
    _approveAction(policyholder2);
    _approveAction(policyholder3);

    vm.warp(block.timestamp + 6 days);

    vm.expectRevert(VertexCore.InvalidActionId.selector);
    vertex.queueAction(1);
  }
}

contract ExecuteAction is VertexCoreTest {
  uint256 actionId;

  function setUp() public override {
    VertexCoreTest.setUp();

    actionId = _createAction();
    _approveAction(policyholder1, actionId);
    _approveAction(policyholder2, actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategies[0].isActionPassed(actionId), true);
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
    vertex.executeAction(actionId);
  }

  // TODO fuzz over action IDs, bound(actionsCount, type(uint).max)
  function test_RevertIfInvalidActionId() public {
    vertex.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(VertexCore.InvalidActionId.selector);
    vertex.executeAction(actionId + 1);
  }

  // TODO fuzz over seconds jumped forward, only assert the revert if < exectionTime
  function test_RevertIfTimelockNotFinished() public {
    vertex.queueAction(actionId);

    vm.warp(block.timestamp + 6 hours);

    vm.expectRevert(VertexCore.TimelockNotFinished.selector);
    vertex.executeAction(actionId);
  }

  function test_RevertIfInsufficientMsgValue() public {
    vm.prank(actionCreator);
    actionId = vertex.createAction(strategies[0], address(targetProtocol), 1e18, receiveETHSelector, abi.encode(true));

    _approveAction(policyholder1, actionId);
    _approveAction(policyholder2, actionId);

    vm.warp(block.timestamp + 6 days);

    vertex.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(VertexCore.InsufficientMsgValue.selector);
    vertex.executeAction(actionId);
  }

  function test_RevertIfFailedActionExecution() public {
    vm.prank(actionCreator);
    actionId = vertex.createAction(
      strategies[0],
      address(targetProtocol),
      0, // value
      failSelector,
      abi.encode("")
    );

    _approveAction(policyholder1, actionId);
    _approveAction(policyholder2, actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategies[0].isActionPassed(actionId), true);

    vertex.queueAction(actionId);

    vm.warp(block.timestamp + 5 days);

    vm.expectRevert(VertexCore.FailedActionExecution.selector);
    vertex.executeAction(actionId);
  }

  function test_HandlesReentrancy() public {
    // TODO
    // What happens if somone queues an action to call vertex.executeAction?
    // Calling executeAction on that action should revert with OnlyQueuedActions.
    // We should confirm that nothing weird happens if this is done
  }

  function test_RevertsIfExternalCallIsUnsuccessful() public {
    // TODO
    // expect the call to revert with FailedActionExecution
  }
}

contract SubmitApproval is VertexCoreTest {
  uint256 actionId;

  function test_SuccessfulApproval() public {
    // TODO
    // This is a happy path test.
    // Assert changes to Action storage.
    // Assert changes to Approval storage.
    // Assert event emission.
  }

  function test_RevertIfActionNotActive() public {
    actionId = _createAction();
    _approveAction(policyholder1, actionId);
    _approveAction(policyholder2, actionId);

    vm.warp(block.timestamp + 6 days);

    vertex.queueAction(actionId);

    vm.expectRevert(VertexCore.ActionNotActive.selector);
    vertex.submitApproval(actionId);
  }

  function test_RevertIfDuplicateApproval() public {
    actionId = _createAction();
    _approveAction(policyholder1, actionId);

    vm.expectRevert(VertexCore.DuplicateApproval.selector);
    vm.prank(policyholder1);
    vertex.submitApproval(actionId);
  }

  function test_RevertsIfCallerIsNotPolicyHolder() public {
    // TODO
    // https://github.com/llama-community/vertex-v1/issues/62
  }
}

contract SubmitApprovalBySignature is VertexCoreTest {
  function test_SuccessfulApprovalBySignature() public {
    // TODO
    // This is a happy path test.
    // Assert changes to Action storage.
    // Assert changes to Approval storage.
    // Assert event emission.
  }

  function test_RevertsIfCallerIsNotPolicyHolder() public {
    // TODO
    // https://github.com/llama-community/vertex-v1/issues/62
  }
}

contract SubmitDisapproval is VertexCoreTest {
  uint256 actionId;

  function _createApproveAndQueueAction() internal returns (uint256 _actionId) {
    _actionId = _createAction();
    _approveAction(policyholder1, _actionId);
    _approveAction(policyholder2, _actionId);

    vm.warp(block.timestamp + 6 days);

    assertEq(strategies[0].isActionPassed(_actionId), true);
    _queueAction(_actionId);
  }

  function test_SuccessfulDisapproval() public {
    // TODO
    // This is a happy path test.
    // Assert changes to Action storage.
    // Assert changes to Disapproval storage.
    // Assert event emission.
  }

  function test_RevertIfActionNotQueued() public {
    actionId = _createAction();

    vm.expectRevert(VertexCore.ActionNotQueued.selector);
    vertex.submitDisapproval(actionId);
  }

  function test_RevertIfDuplicateDisapproval() public {
    actionId = _createApproveAndQueueAction();

    _disapproveAction(policyholder1, actionId);

    vm.expectRevert(VertexCore.DuplicateDisapproval.selector);
    vm.prank(policyholder1);
    vertex.submitDisapproval(actionId);
  }

  function test_RevertsIfCallerIsNotPolicyHolder() public {
    // TODO
    // https://github.com/llama-community/vertex-v1/issues/62
  }
}

contract SubmitDisapprovalBySignature is VertexCoreTest {
  function test_SuccessfulDisapprovalBySignature() public {
    // TODO
    // This is a happy path test.
    // Sign a message and have one account submit disapproval on behalf of another.
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
    WeightByPermission[] memory approvalWeightByPermission = new WeightByPermission[](0);
    WeightByPermission[] memory disapprovalWeightByPermission = new WeightByPermission[](0);

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
      approvalWeightByPermission: approvalWeightByPermission,
      disapprovalWeightByPermission: disapprovalWeightByPermission
    });

    newStrategies[1] = Strategy({
      approvalPeriod: 5 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalWeightByPermission: approvalWeightByPermission,
      disapprovalWeightByPermission: disapprovalWeightByPermission
    });

    newStrategies[2] = Strategy({
      approvalPeriod: 6 days,
      queuingPeriod: 14 days,
      expirationPeriod: 3 days,
      isFixedLengthApprovalPeriod: false,
      minApprovalPct: 0,
      minDisapprovalPct: 2000,
      approvalWeightByPermission: approvalWeightByPermission,
      disapprovalWeightByPermission: disapprovalWeightByPermission
    });

    for (uint256 i; i < newStrategies.length; i++) {
      strategyAddresses[i] = _computeVertexStrategyAddress(newStrategies[i]);
    }

    vm.startPrank(address(vertex));

    vm.expectEmit(true, true, true, true);
    emit StrategyAuthorized(strategyAddresses[0], newStrategies[0]);
    vm.expectEmit(true, true, true, true);
    emit StrategyAuthorized(strategyAddresses[1], newStrategies[1]);
    vm.expectEmit(true, true, true, true);
    emit StrategyAuthorized(strategyAddresses[2], newStrategies[2]);

    vertex.createAndAuthorizeStrategies(newStrategies);

    assertEq(vertex.authorizedStrategies(strategyAddresses[0]), true);
    assertEq(vertex.authorizedStrategies(strategyAddresses[1]), true);
    assertEq(vertex.authorizedStrategies(strategyAddresses[2]), true);
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
    vm.startPrank(address(vertex));
    assertEq(vertex.authorizedStrategies(strategies[0]), true);
    assertEq(vertex.authorizedStrategies(strategies[1]), true);

    vm.expectEmit(true, true, true, true);
    emit StrategyUnauthorized(strategies[0]);
    vm.expectEmit(true, true, true, true);
    emit StrategyUnauthorized(strategies[1]);

    vertex.unauthorizeStrategies(strategies);

    assertEq(vertex.authorizedStrategies(strategies[0]), false);
    assertEq(vertex.authorizedStrategies(strategies[1]), false);

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
      accountAddresses[i] = _computeVertexAccountAddress(newAccounts[i]);
    }

    vm.startPrank(address(vertex));

    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[0], newAccounts[0]);
    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[1], newAccounts[1]);
    vm.expectEmit(true, true, true, true);
    emit AccountAuthorized(accountAddresses[2], newAccounts[2]);
    vertex.createAndAuthorizeAccounts(newAccounts);
  }

  function test_RevertIfReinitialized() public {
    string[] memory newAccounts = new string[](3);
    VertexAccount[] memory accountAddresses = new VertexAccount[](3);

    newAccounts[0] = "VertexAccount2";
    newAccounts[1] = "VertexAccount3";
    newAccounts[2] = "VertexAccount4";

    for (uint256 i; i < newAccounts.length; i++) {
      bytes32 accountSalt = bytes32(keccak256(abi.encode(newAccounts[i])));
      accountAddresses[i] = VertexAccount(
        payable(Clones.predictDeterministicAddress(address(vertexAccountImplementation), accountSalt, address(vertex)))
      );
    }

    vm.startPrank(address(vertex));
    vertex.createAndAuthorizeAccounts(newAccounts);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[0].initialize(newAccounts[0], address(vertex));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[1].initialize(newAccounts[1], address(vertex));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    accountAddresses[2].initialize(newAccounts[2], address(vertex));
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
