// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {PermissionIdCheckpoint, Strategy} from "src/lib/Structs.sol";

import {VertexCoreTest} from "test/VertexCore.t.sol";
import {BaseHandler} from "test/invariants/BaseHandler.sol";

contract VertexCoreHandler is BaseHandler {
  // =============================
  // ======== Constructor ========
  // =============================

  constructor(VertexFactory _vertexFactory, VertexCore _vertexCore) BaseHandler(_vertexFactory, _vertexCore) {
    // TODO Set some initial permissions, each actor is a policyholder.
  }

  // ==========================
  // ======== Helpers =========
  // ==========================

  function callSummary() public view override {
    BaseHandler.callSummary();
    console2.log("vertexCore_createAction                 ", calls["vertexCore_createAction"]);
    console2.log("vertexCore_queueAction                  ", calls["vertexCore_queueAction"]);
    console2.log("vertexCore_executeAction                ", calls["vertexCore_executeAction"]);
    console2.log("vertexCore_cancelAction                 ", calls["vertexCore_cancelAction"]);
    console2.log("vertexCore_castApproval               ", calls["vertexCore_castApproval"]);
    console2.log("vertexCore_castApprovalBySig    ", calls["vertexCore_castApprovalBySig"]);
    console2.log("vertexCore_castDisapproval            ", calls["vertexCore_castDisapproval"]);
    console2.log("vertexCore_castDisapprovalBySig ", calls["vertexCore_castDisapprovalBySig"]);
    console2.log("vertexCore_createAndAuthorizeStrategies ", calls["vertexCore_createAndAuthorizeStrategies"]);
    console2.log("vertexCore_unauthorizeStrategies        ", calls["vertexCore_unauthorizeStrategies"]);
    console2.log("vertexCore_createAndAuthorizeAccounts   ", calls["vertexCore_createAndAuthorizeAccounts"]);
    console2.log("-----------------------------------------------");
    console2.log("policyholdersHadBalanceOf_0      ", calls["policyholdersHadBalanceOf_0"]);
    console2.log("policyholdersHadBalanceOf_1      ", calls["policyholdersHadBalanceOf_1"]);
  }

  // =====================================
  // ======== Methods for Fuzzer =========
  // =====================================

  function vertexCore_createAction() public recordCall("vertexCore_createAction") {}
  function vertexCore_queueAction() public recordCall("vertexCore_queueAction") {}
  function vertexCore_executeAction() public recordCall("vertexCore_executeAction") {}
  function vertexCore_cancelAction() public recordCall("vertexCore_cancelAction") {}
  function vertexCore_castApproval() public recordCall("vertexCore_castApproval") {}
  function vertexCore_castApprovalBySig() public recordCall("vertexCore_castApprovalBySig") {}
  function vertexCore_castDisapproval() public recordCall("vertexCore_castDisapproval") {}
  function vertexCore_castDisapprovalBySig() public recordCall("vertexCore_castDisapprovalBySig") {}
  function vertexCore_createAndAuthorizeStrategies() public recordCall("vertexCore_createAndAuthorizeStrategies") {}
  function vertexCore_unauthorizeStrategies() public recordCall("vertexCore_unauthorizeStrategies") {}
  function vertexCore_createAndAuthorizeAccounts() public recordCall("vertexCore_createAndAuthorizeAccounts") {}
}

contract VertexFactoryInvariants is VertexCoreTest {
  // TODO Remove inheritance on VertexCoreTest once https://github.com/llama-community/vertex-v1/issues/38 is
  // completed. Inheriting from it now just to simplify the test setup, but ideally our invariant
  // tests would not be coupled to our unit tests in this way.

  VertexCoreHandler public handler;

  function setUp() public override {
    VertexCoreTest.setUp();
    handler = new VertexCoreHandler(factory, core);

    // TODO Set this up and write tests.
    targetSender(makeAddr("invariantSender")); // TODO why does removing this result in failure due to clone being
      // deployed to a sender's address?
    targetContract(address(handler));
  }

  // ======================================
  // ======== Invariant Assertions ========
  // ======================================

  // The `actionsCount` state variable should only increase, and be incremented by 1 with each
  // successful `createAction` call.
  function assertInvariant_ActionsCountMonotonicallyIncreases() internal {}

  // Once an action is executed, it's state is final and should never change, i.e. it cannot be
  // queued or executed again.
  function assertInvariant_ExecutedActionsAreFinalized() internal {}

  // Once an action is canceled, it's state is final and should never change, i.e. it cannot
  // cannot be later be queued, executed, or canceled again.
  function assertInvariant_CanceledActionsAreFinalized() internal {}

  // Once an action is expired, it's state is final and should never change, i.e. it cannot be
  //later be queued and executed.
  function assertInvariant_ExpiredActionsAreFinalized() internal {}

  // =================================
  // ======== Invariant Tests ========
  // =================================

  function invariant_AllInvariants() public {
    assertInvariant_ActionsCountMonotonicallyIncreases();
    assertInvariant_ExecutedActionsAreFinalized();
    assertInvariant_CanceledActionsAreFinalized();
    assertInvariant_ExpiredActionsAreFinalized();
  }

  function invariant_CallSummary() public view {
    handler.callSummary();
  }
}
