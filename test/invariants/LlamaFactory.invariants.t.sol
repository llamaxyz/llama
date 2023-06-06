// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";

import {BaseHandler} from "test/invariants/BaseHandler.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
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
  ILlamaStrategy public relativeQuorumLogic;
  ILlamaAccount public accountLogic;

  // Used to track the last seen `llamaCount` value.
  uint256[] public llamaCounts;

  // =============================
  // ======== Constructor ========
  // =============================

  constructor(
    LlamaFactory _llamaFactory,
    LlamaCore _llamaCore,
    ILlamaStrategy _relativeQuorumLogic,
    ILlamaAccount _accountLogic
  ) BaseHandler(_llamaFactory, _llamaCore) {
    llamaCounts.push(LLAMA_FACTORY.llamaCount());
    relativeQuorumLogic = _relativeQuorumLogic;
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
      relativeQuorumLogic,
      accountLogic,
      new bytes[](0),
      new bytes[](0),
      roleDescriptions,
      roleHolders,
      new RolePermissionData[](0),
      "#FF0420",
      '<g xmlns="http://www.w3.org/2000/svg" fill="#FF0420" clip-path="url(#j)"><path d="M44.876 462c-3.783 0-6.883-.881-9.3-2.645-2.384-1.794-3.576-4.344-3.576-7.65 0-.692.08-1.542.238-2.55.414-2.266 1.002-4.989 1.765-8.169C36.165 432.329 41.744 428 50.742 428c2.448 0 4.641.409 6.58 1.228 1.94.787 3.466 1.983 4.579 3.589 1.112 1.574 1.669 3.463 1.669 5.666 0 .661-.08 1.496-.239 2.503a106.077 106.077 0 0 1-1.716 8.169c-1.113 4.314-3.037 7.54-5.77 9.681-2.735 2.109-6.39 3.164-10.97 3.164Zm.668-6.8c1.78 0 3.29-.52 4.53-1.558 1.272-1.039 2.178-2.629 2.718-4.77.731-2.959 1.288-5.541 1.67-7.744.127-.661.19-1.338.19-2.031 0-2.865-1.51-4.297-4.53-4.297-1.78 0-3.307.519-4.578 1.558-1.24 1.039-2.13 2.629-2.671 4.77-.572 2.109-1.145 4.691-1.717 7.744-.127.63-.19 1.291-.19 1.983 0 2.897 1.526 4.345 4.578 4.345ZM68.409 461.528c-.35 0-.62-.11-.81-.331a1.12 1.12 0 0 1-.144-.85l6.581-30.694c.064-.347.239-.63.525-.85.286-.221.588-.331.906-.331h12.685c3.529 0 6.358.724 8.489 2.172 2.161 1.449 3.242 3.542 3.242 6.281 0 .787-.095 1.605-.286 2.455-.795 3.621-2.4 6.297-4.816 8.028-2.385 1.732-5.66 2.597-9.824 2.597h-6.438l-2.194 10.342a1.35 1.35 0 0 1-.524.85c-.287.221-.588.331-.907.331H68.41Zm16.882-18.039c1.335 0 2.495-.362 3.48-1.086 1.018-.724 1.686-1.763 2.004-3.117a8.185 8.185 0 0 0 .143-1.417c0-.913-.27-1.605-.81-2.077-.541-.504-1.463-.756-2.767-.756H81.62l-1.813 8.453h5.485ZM110.628 461.528c-.349 0-.62-.11-.81-.331-.191-.252-.255-.535-.191-.85l5.293-24.461h-8.488c-.35 0-.62-.11-.811-.33a1.12 1.12 0 0 1-.143-.851l1.097-5.052c.063-.347.238-.63.524-.85.286-.221.588-.331.906-.331h25.657c.35 0 .62.11.811.331.127.189.19.378.19.566a.909.909 0 0 1-.047.284l-1.097 5.052c-.064.347-.239.63-.525.851-.254.22-.556.33-.906.33h-8.441l-5.293 24.461c-.064.346-.239.63-.525.85-.286.221-.588.331-.906.331h-6.295ZM135.88 461.528c-.35 0-.62-.11-.811-.331a1.016 1.016 0 0 1-.191-.85l6.629-30.694a1.35 1.35 0 0 1 .525-.85c.286-.221.588-.331.906-.331h6.438c.349 0 .62.11.81.331.128.189.191.378.191.566a.882.882 0 0 1-.048.284l-6.581 30.694c-.063.346-.238.63-.524.85-.286.221-.588.331-.906.331h-6.438ZM154.038 461.528c-.349 0-.62-.11-.81-.331-.191-.22-.255-.504-.191-.85l6.581-30.694c.064-.347.238-.63.524-.85.287-.221.605-.331.954-.331h5.151c.763 0 1.255.346 1.478 1.039l5.198 14.875 11.588-14.875c.159-.252.382-.488.668-.708.318-.221.7-.331 1.145-.331h5.198c.349 0 .62.11.81.331.127.189.191.378.191.566a.882.882 0 0 1-.048.284l-6.581 30.694c-.063.346-.238.63-.524.85-.286.221-.588.331-.906.331h-5.771c-.349 0-.62-.11-.81-.331a1.118 1.118 0 0 1-.143-.85l3.719-17.425-7.296 9.586c-.318.347-.62.614-.906.803-.286.189-.62.283-1.002.283h-2.479c-.668 0-1.129-.362-1.383-1.086l-3.386-10.011-3.815 17.85c-.064.346-.239.63-.525.85-.286.221-.588.331-.906.331h-5.723ZM196.132 461.528c-.35 0-.62-.11-.81-.331-.191-.252-.255-.535-.191-.85l6.628-30.694a1.35 1.35 0 0 1 .525-.85c.285-.221.588-.331.906-.331h6.438c.35 0 .62.11.811.331.127.189.19.378.19.566a.88.88 0 0 1-.047.284l-6.581 30.694c-.063.346-.238.63-.525.85a1.46 1.46 0 0 1-.907.331h-6.437ZM226.07 462c-2.798 0-5.198-.378-7.201-1.133-1.972-.756-3.466-1.763-4.483-3.022-.986-1.26-1.479-2.661-1.479-4.203 0-.252.033-.63.095-1.134.065-.283.193-.519.383-.708.223-.189.476-.283.763-.283h6.103c.383 0 .668.063.859.188.222.126.445.347.668.662.223.818.731 1.495 1.526 2.03.827.535 1.955.803 3.385.803 1.812 0 3.276-.283 4.388-.85 1.113-.567 1.781-1.338 2.002-2.314a2.42 2.42 0 0 0 .048-.566c0-.788-.491-1.401-1.477-1.842-.986-.473-2.798-1.023-5.437-1.653-3.084-.661-5.421-1.653-7.011-2.975-1.589-1.354-2.383-3.117-2.383-5.289 0-.755.095-1.527.286-2.314.635-2.928 2.21-5.226 4.72-6.894 2.544-1.669 5.818-2.503 9.825-2.503 2.415 0 4.563.425 6.438 1.275 1.875.85 3.321 1.936 4.34 3.258 1.049 1.291 1.572 2.582 1.572 3.873 0 .377-.015.645-.047.802-.063.284-.206.52-.429.709a.975.975 0 0 1-.715.283h-6.391c-.698 0-1.176-.268-1.429-.803-.033-.724-.415-1.338-1.146-1.841-.731-.504-1.685-.756-2.861-.756-1.399 0-2.559.252-3.482.756-.889.503-1.447 1.243-1.668 2.219a3.172 3.172 0 0 0-.049.614c0 .755.445 1.385 1.336 1.889.922.472 2.528.96 4.816 1.464 3.562.692 6.153 1.684 7.774 2.975 1.653 1.29 2.479 3.006 2.479 5.147 0 .724-.095 1.511-.286 2.361-.698 3.211-2.4 5.651-5.103 7.32-2.669 1.636-6.246 2.455-10.729 2.455ZM248.515 461.528c-.35 0-.62-.11-.81-.331-.191-.22-.255-.504-.191-.85l6.581-30.694c.063-.347.238-.63.525-.85.286-.221.604-.331.954-.331h5.149c.763 0 1.256.346 1.479 1.039l5.199 14.875 11.587-14.875c.16-.252.382-.488.668-.708.318-.221.699-.331 1.144-.331h5.199c.35 0 .62.11.811.331.127.189.19.378.19.566a.856.856 0 0 1-.048.284l-6.58 30.694c-.065.346-.24.63-.526.85a1.456 1.456 0 0 1-.906.331h-5.769c-.351 0-.621-.11-.811-.331a1.109 1.109 0 0 1-.143-.85l3.719-17.425-7.296 9.586c-.318.347-.62.614-.906.803a1.776 1.776 0 0 1-1.001.283h-2.481c-.668 0-1.128-.362-1.382-1.086l-3.386-10.011-3.815 17.85a1.36 1.36 0 0 1-.525.85c-.286.221-.588.331-.906.331h-5.723Z"/></g>'
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

  function llamaFactory_setPolicyTokenMetadata(LlamaPolicyMetadata newPolicyMetadata)
    public
    recordCall("llamaFactory_setPolicyMetadata")
    useCurrentTimestamp
  {
    vm.prank(address(LLAMA_FACTORY.ROOT_LLAMA_EXECUTOR()));
    LLAMA_FACTORY.setPolicyMetadata(newPolicyMetadata);
  }
}

contract LlamaFactoryInvariants is LlamaTestSetup {
  LlamaFactoryHandler public handler;

  function setUp() public override {
    LlamaTestSetup.setUp();
    handler = new LlamaFactoryHandler(factory, mpCore, relativeQuorumLogic, accountLogic);

    // Target the handler contract and only call it's `llamaFactory_deploy` method. We use
    // `excludeArtifact` to prevent contracts deployed by the factory from automatically being
    // added to the target contracts list (by default, deployed contracts are automatically
    // added to the target contracts list). We then use `targetSelector` to filter out all
    // methods from the handler except for `llamaFactory_deploy`.
    excludeArtifact("LlamaAccount");
    excludeArtifact("LlamaCore");
    excludeArtifact("LlamaExecutor");
    excludeArtifact("LlamaPolicy");
    excludeArtifact("LlamaRelativeQuorum");

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
