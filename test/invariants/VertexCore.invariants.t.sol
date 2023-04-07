// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";

import {ActionState} from "src/lib/Enums.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {BaseHandler} from "test/invariants/BaseHandler.sol";
import {Roles, VertexTestSetup} from "test/utils/VertexTestSetup.sol";

contract VertexCoreHandler is BaseHandler {
  // =========================
  // ======== Storage ========
  // =========================

  // Actions that we'll reference in our invariant tests.
  uint256 executedActionId;
  uint256 canceledActionId;
  uint256 expiredActionId;

  // Parameters we'll need to create valid actions.
  address mockProtocol;
  VertexStrategy[2] strategies;
  bytes32[3] permissionIds;

  // Duplicated parameters from `VertexTestSetup` that we use here.
  address actionCreatorAaron = makeAddr("actionCreatorAaron");

  // Used to track the last seen `actionsCount` value.
  uint256[] public actionsCounts;

  // =============================
  // ======== Constructor ========
  // =============================

  constructor(
    VertexFactory _vertexFactory,
    VertexCore _vertexCore,
    VertexStrategy[2] memory _strategies,
    bytes32[3] memory _permissionIds,
    address _mockProtocol
  ) BaseHandler(_vertexFactory, _vertexCore) {
    strategies = _strategies;
    permissionIds = _permissionIds;
    mockProtocol = _mockProtocol;

    // Save off each existing action
    for (uint256 i = 0; i < VERTEX_CORE.actionsCount(); i++) {
      actionsCounts.push(i);
    }
  }

  // ==========================
  // ======== Helpers =========
  // ==========================

  function getAction(uint256 index) internal view returns (uint256) {
    return _bound(index, actionsCounts[0], actionsCounts[actionsCounts.length - 1]);
  }

  // Note this function is sensitive to the order of the `permissionIds` array and the configuration
  // in `VertexTestSetup`. If you change either of those, you'll need to update this function.
  function permissionIdIndexToData(uint256 index)
    internal
    view
    returns (address target, bytes4 selector, VertexStrategy strategy)
  {
    index = _bound(index, 0, permissionIds.length - 1);

    // pausePermissionId
    if (index == 0) return (mockProtocol, bytes4(keccak256("pause(bool)")), strategies[0]);
    // failPermissionId
    else if (index == 1) return (mockProtocol, bytes4(keccak256("fail()")), strategies[0]);
    // receiveEthPermissionId
    else if (index == 2) return (mockProtocol, bytes4(keccak256("receiveEth()")), strategies[0]);

    revert("unhandled index");
  }

  function getActionsCounts() public view returns (uint256[] memory) {
    return actionsCounts;
  }

  function callSummary() public view override {
    BaseHandler.callSummary();
    console2.log("vertexCore_createAction                 ", calls["vertexCore_createAction"]);
    console2.log("vertexCore_queueAction                  ", calls["vertexCore_queueAction"]);
    console2.log("vertexCore_executeAction                ", calls["vertexCore_executeAction"]);
    console2.log("vertexCore_cancelAction                 ", calls["vertexCore_cancelAction"]);
    console2.log("vertexCore_castApproval                 ", calls["vertexCore_castApproval"]);
    console2.log("vertexCore_castApprovalWithReason       ", calls["vertexCore_castApprovalWithReason"]);
    console2.log("vertexCore_castApprovalBySig            ", calls["vertexCore_castApprovalBySig"]);
    console2.log("vertexCore_castDisapproval              ", calls["vertexCore_castDisapproval"]);
    console2.log("vertexCore_castDisapprovalWithReason    ", calls["vertexCore_castDisapprovalWithReason"]);
    console2.log("vertexCore_castDisapprovalBySig         ", calls["vertexCore_castDisapprovalBySig"]);
    console2.log("vertexCore_createAndAuthorizeStrategies ", calls["vertexCore_createAndAuthorizeStrategies"]);
    console2.log("vertexCore_unauthorizeStrategies        ", calls["vertexCore_unauthorizeStrategies"]);
    console2.log("vertexCore_createAndAuthorizeAccounts   ", calls["vertexCore_createAndAuthorizeAccounts"]);
    console2.log("-----------------------------------------------");
    console2.log("vertexCore_queueAction_queued           ", calls["vertexCore_queueAction_queued"]);
    console2.log("vertexCore_queueAction_noop             ", calls["vertexCore_queueAction_noop"]);
    console2.log("policyholdersHadBalanceOf_0             ", calls["policyholdersHadBalanceOf_0"]);
    console2.log("policyholdersHadBalanceOf_1             ", calls["policyholdersHadBalanceOf_1"]);
  }

  // =====================================
  // ======== Methods for Fuzzer =========
  // =====================================

  function vertexCore_createAction(uint256 permissionIdIndex, uint256 value, uint256 dataSeed)
    public
    recordCall("vertexCore_createAction")
  {
    // We don't want action creation to revert, so we pull from arrays of known good values instead
    // of lettings the fuzzer have full control over input values.
    (address target, bytes4 selector, VertexStrategy strategy) = permissionIdIndexToData(permissionIdIndex);

    // We only have one function that can receive ETH, if we're calling that function, we randomize
    // how much ETH to send, otherwise we send 0.
    value = selector == bytes4(keccak256("receiveEth()")) ? _bound(value, 0, 1000 ether) : 0;

    // We only have one function that takes calldata, if we're calling that function, we randomize
    // the calldata;
    bytes memory data = selector == bytes4(keccak256("pause(bool)")) ? abi.encode(_bound(dataSeed, 0, 1)) : bytes("");

    // We can now execute the action.
    vm.prank(actionCreatorAaron);
    uint256 actionId = VERTEX_CORE.createAction(uint8(Roles.ActionCreator), strategy, target, value, selector, data);
    actionsCounts.push(actionId);
  }

  function vertexCore_queueAction(uint256 index) public recordCall("vertexCore_queueAction") {
    // We only want to queue actions that are in the `Approved` state. We start with the index given
    // then incrementally increase until we traverse the entire array of action IDs. If none are
    // ready to be queued, we exit and this is a no-op.
    uint256 actionId = _bound(index, 0, actionsCounts.length - 1);
    uint256 numIterations;
    for (uint256 i = 0; i < actionsCounts.length; i++) {
      if (VERTEX_CORE.getActionState(getAction(actionId)) == ActionState.Approved) {
        VERTEX_CORE.queueAction(getAction(index));
        recordMetric("vertexCore_queueAction_queued");
        return;
      }

      if (numIterations == actionsCounts.length) {
        recordMetric("vertexCore_queueAction_noop");
        return;
      }

      numIterations++;
      actionId = actionsCounts[(actionId + 1) % actionsCounts.length];
    }
  }

  // TODO: Implement the rest of the methods.
  // function vertexCore_executeAction() public recordCall("vertexCore_executeAction") {}
  // function vertexCore_cancelAction() public recordCall("vertexCore_cancelAction") {}
  // function vertexCore_castApproval() public recordCall("vertexCore_castApproval") {}
  // function vertexCore_castApprovalWithReason() public recordCall("vertexCore_castApprovalWithReason") {}
  // function vertexCore_castApprovalBySig() public recordCall("vertexCore_castApprovalBySig") {}
  // function vertexCore_castDisapproval() public recordCall("vertexCore_castDisapproval") {}
  // function vertexCore_castDisapprovalWithReason() public recordCall("vertexCore_castDisapprovalWithReason") {}
  // function vertexCore_castDisapprovalBySig() public recordCall("vertexCore_castDisapprovalBySig") {}
  // function vertexCore_createAndAuthorizeStrategies() public recordCall("vertexCore_createAndAuthorizeStrategies") {}
  // function vertexCore_unauthorizeStrategies() public recordCall("vertexCore_unauthorizeStrategies") {}
  // function vertexCore_createAndAuthorizeAccounts() public recordCall("vertexCore_createAndAuthorizeAccounts") {}
}

contract VertexFactoryInvariants is VertexTestSetup {
  VertexCoreHandler public handler;

  uint256 executedActionId;
  uint256 canceledActionId;
  uint256 expiredActionId;

  function setUp() public override {
    VertexTestSetup.setUp();

    // We push through 3 actions: one that's executed, one that's canceled, and one that's expired.
    // First, we execute an action.
    executedActionId = createAction();
    approveAction(approverAdam, executedActionId);
    approveAction(approverAlicia, executedActionId);
    vm.warp(block.timestamp + 6 days);
    mpCore.queueAction(executedActionId);
    vm.warp(block.timestamp + 5 days);
    mpCore.executeAction(executedActionId);
    vm.warp(block.timestamp + 1 days);

    // Now we cancel an action.
    canceledActionId = createAction();
    vm.prank(actionCreatorAaron);
    mpCore.cancelAction(canceledActionId);
    vm.warp(block.timestamp + 1 days);

    // Lastly, we let an action expire.
    expiredActionId = createAction();
    approveAction(approverAdam, expiredActionId);
    approveAction(approverAlicia, expiredActionId);
    vm.warp(block.timestamp + 6 days);
    mpCore.queueAction(expiredActionId);
    vm.warp(block.timestamp + 15 days);

    // Verify our setup. Note that we rely on the fact that the action IDs are assigned sequentially in the handler.
    require(executedActionId == 0, "executedActionId");
    require(canceledActionId == 1, "canceledActionId");
    require(expiredActionId == 2, "expiredActionId");
    require(mpCore.getActionState(executedActionId) == ActionState.Executed, "executedActionId");
    require(mpCore.getActionState(canceledActionId) == ActionState.Canceled, "canceledActionId");
    require(mpCore.getActionState(expiredActionId) == ActionState.Expired, "expiredActionId");

    // Now we deploy our handler and inform it of these actions.
    VertexStrategy[2] memory strategies = [mpStrategy1, mpStrategy2];
    bytes32[3] memory permissionIds = [pausePermissionId, failPermissionId, receiveEthPermissionId];
    handler = new VertexCoreHandler(factory, mpCore, strategies, permissionIds, address(mockProtocol));

    targetContract(address(handler));
    targetSender(msg.sender);
  }

  // =========================
  // ======== Helpers ========
  // =========================

  function createAction() internal returns (uint256 actionId) {
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

  function approveAction(address policyholder, uint256 actionId) public {
    vm.prank(policyholder);
    mpCore.castApproval(actionId, uint8(Roles.Approver));
  }

  // ======================================
  // ======== Invariant Assertions ========
  // ======================================

  // The `actionsCount` state variable should only increase, and be incremented by 1 with each
  // successful `createAction` call.
  function assertInvariant_ActionsCountMonotonicallyIncreases() internal view {
    uint256[] memory vertexCounts = handler.getActionsCounts();
    for (uint256 i = 1; i < vertexCounts.length; i++) {
      require(vertexCounts[i] == vertexCounts[i - 1] + 1, "vertexCount did not monotonically increase");
    }
  }

  // Once an action is executed, it's state is final and should never change, i.e. it cannot be
  // queued or executed again.
  function assertInvariant_ExecutedActionsAreFinalized() internal view {
    require(mpCore.getActionState(executedActionId) == ActionState.Executed, "executedActionId state changed");
  }

  // Once an action is canceled, it's state is final and should never change, i.e. it cannot
  // cannot be later be queued, executed, or canceled again.
  function assertInvariant_CanceledActionsAreFinalized() internal view {
    require(mpCore.getActionState(canceledActionId) == ActionState.Canceled, "canceledActionId state changed");
  }

  // Once an action is expired, it's state is final and should never change, i.e. it cannot be
  // later be queued and executed.
  function assertInvariant_ExpiredActionsAreFinalized() internal view {
    require(mpCore.getActionState(expiredActionId) == ActionState.Expired, "expiredActionId state changed");
  }

  // =================================
  // ======== Invariant Tests ========
  // =================================

  function invariant_AllInvariants() public view {
    assertInvariant_ActionsCountMonotonicallyIncreases();
    assertInvariant_ExecutedActionsAreFinalized();
    assertInvariant_CanceledActionsAreFinalized();
    assertInvariant_ExpiredActionsAreFinalized();
  }

  function invariant_CallSummary() public view {
    handler.callSummary();
  }
}
