// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {VertexCore} from "src/core/VertexCore.sol";
import {VertexFactory} from "src/factory/VertexFactory.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {Strategy, PolicyGrantData} from "src/utils/Structs.sol";

import {VertexCoreTest} from "tests/VertexCore.t.sol";
import {BaseHandler} from "tests/invariants/BaseHandler.sol";

contract VertexFactoryHandler is BaseHandler {
    // =========================
    // ======== Storage ========
    // =========================

    // Used to track the last seen `vertexCount` value.
    uint256[] public vertexCounts;

    // The salt is a function of name and symbol. To ensure we get a different contract address each
    // time we deterministically update this value to track what the next name and symbol will be.
    uint256 nextNameCounter = 0;

    // =============================
    // ======== Constructor ========
    // =============================

    constructor(VertexFactory _vertexFactory, VertexCore _vertexCore) BaseHandler(_vertexFactory, _vertexCore) {
        vertexCounts.push(vertexFactory.vertexCount());
    }

    // ==========================
    // ======== Helpers =========
    // ==========================

    function name() private returns (string memory currentName) {
        currentName = string.concat("NAME_", vm.toString(nextNameCounter++));
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

    function vertexFactory_deploy() public recordCall("vertexFactory_deploy") {
        // We don't care about the parameters, we just need it to execute successfully.
        vm.prank(address(vertexFactory.rootVertex()));
        PolicyGrantData[] memory _policyGrantData = new PolicyGrantData[](0);
        vertexFactory.deploy(name(), name(), new Strategy[](0), new string[](0), _policyGrantData);
        vertexCounts.push(vertexFactory.vertexCount());
    }
}

contract VertexFactoryInvariants is VertexCoreTest {
    // TODO Remove inheritance on VertexCoreTest once https://github.com/llama-community/vertex-v1/issues/38 is
    // completed. Inheriting from it now just to simplify the test setup, but ideally our invariant
    // tests would not be coupled to our unit tests in this way.

    VertexFactoryHandler public handler;

    function setUp() public override {
        VertexCoreTest.setUp();
        handler = new VertexFactoryHandler(vertexFactory, vertex);

        // Target the handler contract and only call it's `vertexFactory_deploy` method. We use
        // `excludeArtifact` to prevent contracts deployed by the factory from automatically being
        // added to the target contracts list (by default, deployed contracts are automatically
        // added to the target contracts list). We then use `targetSelector` to filter out all
        // methods from the handler except for `vertexFactory_deploy`.
        targetSender(makeAddr("invariantSender")); // TODO why does removing this result in failure due to clone being deployed to a sender's address?

        excludeArtifact("VertexCore");
        excludeArtifact("VertexPolicyNFT");
        excludeArtifact("VertexStrategy");
        excludeArtifact("VertexAccount");

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.vertexFactory_deploy.selector;
        FuzzSelector memory selector = FuzzSelector({addr: address(handler), selectors: selectors});
        targetSelector(selector);
        targetContract(address(handler));
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

    function invariant_VertexCountMonotonicallyIncreases() public view {
        assertInvariant_VertexCountMonotonicallyIncreases();
    }

    function invariant_CallSummary() public view {
        handler.callSummary();
    }
}
