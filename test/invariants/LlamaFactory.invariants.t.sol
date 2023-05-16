// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";

import {BaseHandler} from "test/invariants/BaseHandler.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicyMetadata} from "src/LlamaPolicyMetadata.sol";

contract LlamaFactoryHandler is BaseHandler {
  uint128 DEFAULT_ROLE_QTY = 1;
  uint64 DEFAULT_ROLE_EXPIRATION = type(uint64).max;

  // =========================
  // ======== Storage ========
  // =========================

  // The default strategy and account logic contracts.
  ILlamaStrategy public relativeStrategyLogic;
  LlamaAccount public accountLogic;

  // Used to track the last seen `llamaCount` value.
  uint256[] public llamaCounts;

  // =============================
  // ======== Constructor ========
  // =============================

  constructor(
    LlamaFactory _llamaFactory,
    LlamaCore _llamaCore,
    ILlamaStrategy _relativeStrategyLogic,
    LlamaAccount _accountLogic
  ) BaseHandler(_llamaFactory, _llamaCore) {
    llamaCounts.push(LLAMA_FACTORY.llamaCount());
    relativeStrategyLogic = _relativeStrategyLogic;
    accountLogic = _accountLogic;
  }

  // =========================
  // ======== Helpers ========
  // =========================

  // The salt is a function of name and symbol. To ensure we get a different contract address each
  // time we use this method.
  function name() internal view returns (string memory currentName) {
    uint256 lastCount = llamaCounts[llamaCounts.length - 1];
    currentName = string.concat("NAME_", vm.toString(lastCount));
  }

  function getLlamaCounts() public view returns (uint256[] memory) {
    return llamaCounts;
  }

  function callSummary() public view override {
    BaseHandler.callSummary();
    console2.log("llamaFactory_deploy             ", calls["llamaFactory_deploy"]);
  }

  // ====================================
  // ======== Methods for Fuzzer ========
  // ====================================

  function llamaFactory_deploy() public recordCall("llamaFactory_deploy") useCurrentTimestamp {
    // We don't care about the parameters, we just need it to execute successfully.
    RoleHolderData[] memory roleHolders = new RoleHolderData[](1);
    roleHolders[0] = RoleHolderData(
      uint8(Roles.ActionCreator), makeAddr("dummyActionCreator"), DEFAULT_ROLE_QTY, DEFAULT_ROLE_EXPIRATION
    );

    RoleDescription[] memory roleDescriptions = new RoleDescription[](1);
    roleDescriptions[0] = RoleDescription.wrap("Action Creator");

    vm.prank(address(LLAMA_FACTORY.ROOT_LLAMA_EXECUTOR()));
    LLAMA_FACTORY.deploy(
      name(),
      relativeStrategyLogic,
      new bytes[](0),
      new string[](0),
      roleDescriptions,
      roleHolders,
      new RolePermissionData[](0)
    );
    llamaCounts.push(LLAMA_FACTORY.llamaCount());
  }

  function llamaFactory_authorizeStrategyLogic(ILlamaStrategy newStrategyLogic)
    public
    recordCall("llamaFactory_authorizeStrategyLogic")
    useCurrentTimestamp
  {
    vm.prank(address(LLAMA_FACTORY.ROOT_LLAMA_EXECUTOR()));
    LLAMA_FACTORY.authorizeStrategyLogic(newStrategyLogic);
  }

  function llamaFactory_setPolicyTokenMetadata(LlamaPolicyMetadata newPolicyTokenMetadata)
    public
    recordCall("llamaFactory_setPolicyTokenMetadata")
    useCurrentTimestamp
  {
    vm.prank(address(LLAMA_FACTORY.ROOT_LLAMA_EXECUTOR()));
    LLAMA_FACTORY.setPolicyTokenMetadata(newPolicyTokenMetadata);
  }
}

contract LlamaFactoryInvariants is LlamaTestSetup {
  LlamaFactoryHandler public handler;

  function setUp() public override {
    LlamaTestSetup.setUp();
    handler = new LlamaFactoryHandler(factory, mpCore, relativeStrategyLogic, accountLogic);

    // Target the handler contract and only call it's `llamaFactory_deploy` method. We use
    // `excludeArtifact` to prevent contracts deployed by the factory from automatically being
    // added to the target contracts list (by default, deployed contracts are automatically
    // added to the target contracts list). We then use `targetSelector` to filter out all
    // methods from the handler except for `llamaFactory_deploy`.
    excludeArtifact("LlamaAccount");
    excludeArtifact("LlamaCore");
    excludeArtifact("LlamaExecutor");
    excludeArtifact("LlamaPolicy");
    excludeArtifact("RelativeStrategy");

    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = handler.llamaFactory_deploy.selector;
    selectors[1] = handler.handler_increaseTimestampBy.selector;
    FuzzSelector memory selector = FuzzSelector({addr: address(handler), selectors: selectors});
    targetSelector(selector);

    targetContract(address(handler));
    targetSender(msg.sender);
  }

  // ======================================
  // ======== Invariant Assertions ========
  // ======================================

  // The llamaCount state variable should only increase, and be incremented by 1 with each
  // successful deploy.
  function assertInvariant_LlamaCountMonotonicallyIncreases() internal view {
    uint256[] memory llamaCounts = handler.getLlamaCounts();
    for (uint256 i = 1; i < llamaCounts.length; i++) {
      require(llamaCounts[i] == llamaCounts[i - 1] + 1, "llamaCount did not monotonically increase");
    }
  }

  // =================================
  // ======== Invariant Tests ========
  // =================================

  function invariant_AllFactoryInvariants() public view {
    assertInvariant_LlamaCountMonotonicallyIncreases();
  }

  function invariant_CallSummary() public view {
    handler.callSummary();
  }
}
