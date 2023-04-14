// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";

import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {DefaultStrategy} from "src/strategies/DefaultStrategy.sol";

import {BaseHandler} from "test/invariants/BaseHandler.sol";
import {Roles, VertexTestSetup} from "test/utils/VertexTestSetup.sol";

contract VertexFactoryHandler is BaseHandler {
  uint128 DEFAULT_ROLE_QTY = 1;
  uint64 DEFAULT_ROLE_EXPIRATION = type(uint64).max;

  // =========================
  // ======== Storage ========
  // =========================

  // The default strategy and account logic contracts.
  IVertexStrategy public strategyLogic;
  VertexAccount public accountLogic;

  // Used to track the last seen `vertexCount` value.
  uint256[] public vertexCounts;

  // =============================
  // ======== Constructor ========
  // =============================

  constructor(
    VertexFactory _vertexFactory,
    VertexCore _vertexCore,
    IVertexStrategy _strategyLogic,
    VertexAccount _accountLogic
  ) BaseHandler(_vertexFactory, _vertexCore) {
    vertexCounts.push(VERTEX_FACTORY.vertexCount());
    strategyLogic = _strategyLogic;
    accountLogic = _accountLogic;
  }

  // ==========================
  // ======== Helpers =========
  // ==========================

  // The salt is a function of name and symbol. To ensure we get a different contract address each
  // time we use this method.
  function name() internal view returns (string memory currentName) {
    uint256 lastCount = vertexCounts[vertexCounts.length - 1];
    currentName = string.concat("NAME_", vm.toString(lastCount));
  }

  function getVertexCounts() public view returns (uint256[] memory) {
    return vertexCounts;
  }

  function callSummary() public view override {
    BaseHandler.callSummary();
    console2.log("vertexFactory_deploy             ", calls["vertexFactory_deploy"]);
  }

  // =====================================
  // ======== Methods for Fuzzer =========
  // =====================================

  function vertexFactory_deploy() public recordCall("vertexFactory_deploy") useCurrentTimestamp {
    // We don't care about the parameters, we just need it to execute successfully.
    RoleHolderData[] memory roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(
      uint8(Roles.ActionCreator), makeAddr("dummyActionCreator"), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION
    );

    RoleDescription[] memory roleDescriptions = new RoleDescription[](1);
    roleDescriptions[0] = RoleDescription.wrap("Action Creator");

    vm.prank(address(VERTEX_FACTORY.ROOT_VERTEX()));
    VERTEX_FACTORY.deploy(
      name(),
      strategyLogic,
      accountLogic,
      new bytes[](0),
      new string[](0),
      roleDescriptions,
      roleHolders,
      new RolePermissionData[](0)
    );
    vertexCounts.push(VERTEX_FACTORY.vertexCount());
  }

  function vertexFactory_authorizeStrategyLogic(IVertexStrategy newStrategyLogic)
    public
    recordCall("vertexFactory_authorizeStrategyLogic")
    useCurrentTimestamp
  {
    vm.prank(address(VERTEX_FACTORY.ROOT_VERTEX()));
    VERTEX_FACTORY.authorizeStrategyLogic(newStrategyLogic);
  }

  function vertexFactory_authorizeAccountLogic(VertexAccount newAccountLogic)
    public
    recordCall("vertexFactory_authorizeAccountLogic")
    useCurrentTimestamp
  {
    vm.prank(address(VERTEX_FACTORY.ROOT_VERTEX()));
    VERTEX_FACTORY.authorizeAccountLogic(newAccountLogic);
  }

  function vertexFactory_setPolicyMetadata(VertexPolicyTokenURI newPolicyTokenURI)
    public
    recordCall("vertexFactory_setPolicyMetadata")
    useCurrentTimestamp
  {
    vm.prank(address(VERTEX_FACTORY.ROOT_VERTEX()));
    VERTEX_FACTORY.setPolicyMetadata(newPolicyTokenURI);
  }
}

contract VertexFactoryInvariants is VertexTestSetup {
  VertexFactoryHandler public handler;

  function setUp() public override {
    VertexTestSetup.setUp();
    handler = new VertexFactoryHandler(factory, mpCore, strategyLogic, accountLogic);

    // Target the handler contract and only call it's `vertexFactory_deploy` method. We use
    // `excludeArtifact` to prevent contracts deployed by the factory from automatically being
    // added to the target contracts list (by default, deployed contracts are automatically
    // added to the target contracts list). We then use `targetSelector` to filter out all
    // methods from the handler except for `vertexFactory_deploy`.
    excludeArtifact("VertexAccount");
    excludeArtifact("VertexCore");
    excludeArtifact("VertexPolicy");
    excludeArtifact("DefaultStrategy");

    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = handler.vertexFactory_deploy.selector;
    selectors[1] = handler.handler_increaseTimestampBy.selector;
    FuzzSelector memory selector = FuzzSelector({addr: address(handler), selectors: selectors});
    targetSelector(selector);

    targetContract(address(handler));
    targetSender(msg.sender);
  }

  // ======================================
  // ======== Invariant Assertions ========
  // ======================================

  // The vertexCount state variable should only increase, and be incremented by 1 with each
  // successful deploy.
  function assertInvariant_VertexCountMonotonicallyIncreases() internal view {
    uint256[] memory vertexCounts = handler.getVertexCounts();
    for (uint256 i = 1; i < vertexCounts.length; i++) {
      require(vertexCounts[i] == vertexCounts[i - 1] + 1, "vertexCount did not monotonically increase");
    }
  }

  // =================================
  // ======== Invariant Tests ========
  // =================================

  function invariant_AllFactoryInvariants() public view {
    assertInvariant_VertexCountMonotonicallyIncreases();
  }

  function invariant_CallSummary() public view {
    handler.callSummary();
  }
}
