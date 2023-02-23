// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {VertexFactory} from "src/factory/VertexFactory.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {Strategy} from "src/utils/Structs.sol";

import {VertexCoreTest} from "tests/VertexCore.t.sol";
import {BaseHandler} from "tests/invariants/BaseHandler.sol";

contract VertexPolicyNFTHandler is BaseHandler {
    // =============================
    // ======== Constructor ========
    // =============================

    constructor(VertexFactory _vertexFactory, VertexPolicyNFT _vertexPolicyNFT) BaseHandler(_vertexFactory, _vertexPolicyNFT) {
        // TODO Set some initial permissions, each actor is a policyholder.
    }

    // ==========================
    // ======== Helpers =========
    // ==========================

    function callSummary() public view override {
        BaseHandler.callSummary();
        console2.log("vertexPolicyNFT_batchGrantPolicies", calls["vertexPolicyNFT_batchGrantPolicies"]);
        console2.log("vertexPolicyNFT_batchUpdatePermissions", calls["vertexPolicyNFT_batchUpdatePermissions"]);
        console2.log("vertexPolicyNFT_batchRevokePolicies", calls["vertexPolicyNFT_batchRevokePolicies"]);
        console2.log("vertexPolicyNFT_revokeExpiredPermission", calls["vertexPolicyNFT_revokeExpiredPermission"]);
        console2.log("vertexPolicyNFT_setBaseURI       ", calls["vertexPolicyNFT_setBaseURI"]);
        console2.log("-----------------------------------------------");
        console2.log("policyholdersHadBalanceOf_0      ", calls["policyholdersHadBalanceOf_0"]);
        console2.log("policyholdersHadBalanceOf_1      ", calls["policyholdersHadBalanceOf_1"]);
    }

    // =====================================
    // ======== Methods for Fuzzer =========
    // =====================================

    function vertexPolicyNFT_batchGrantPolicies() public recordCall("vertexPolicyNFT_batchGrantPolicies") {
        vm.prank(address(vertexFactory.rootVertex()));
        // TODO Implement this call.
    }

    function vertexPolicyNFT_batchUpdatePermissions() public recordCall("vertexPolicyNFT_batchUpdatePermissions") {
        vm.prank(address(vertexFactory.rootVertex()));
        // TODO Implement this call.
    }

    function vertexPolicyNFT_batchRevokePolicies() public recordCall("vertexPolicyNFT_batchRevokePolicies") {
        vm.prank(address(vertexFactory.rootVertex()));
        // TODO Implement this call.
    }

    function vertexPolicyNFT_revokeExpiredPermission() public recordCall("vertexPolicyNFT_revokeExpiredPermission") {
        // TODO Is revokeExpiredPermission actually needed?
    }

    function vertexPolicyNFT_setBaseURI(string calldata baseURI) public recordCall("vertexPolicyNFT_setBaseURI") {
        vm.prank(address(vertexFactory.rootVertex()));
        vertexPolicyNFT.setBaseURI(baseURI);
    }
}

contract VertexFactoryInvariants is VertexCoreTest {
    // TODO Remove inheritance on VertexCoreTest once https://github.com/llama-community/vertex-v1/issues/38 is
    // completed. Inheriting from it now just to simplify the test setup, but ideally our invariant
    // tests would not be coupled to our unit tests in this way.

    VertexPolicyNFTHandler public handler;

    function setUp() public override {
        VertexCoreTest.setUp();
        handler = new VertexPolicyNFTHandler(vertexFactory, policy);

        // TODO Set this up and write tests.
        targetSender(makeAddr("invariantSender")); // TODO why does removing this result in failure due to clone being deployed to a sender's address?
        targetContract(address(handler));
    }

    // ======================================
    // ======== Invariant Assertions ========
    // ======================================

    // For a given permission ID and timestamp, the sum of that permission's quantity over all users
    // with that permission should equal the total supply of that permission ID.
    function assertInvariant_ForEachPermissionId_SumOfPermissionsOverAllUsersEqualsTotalSupply() public {
        // TODO Implement this assertion.
    }

    // For a given user and permission ID,their tokenPermissionCheckpoints array should always be
    // sorted by timestamp in ascending order.
    function assertInvariant_TokenPermissionUserCheckpointsAreAlwaysSortedByTimestamp() public {
        // TODO Implement this assertion.
    }

    // For a given user and permission ID, their tokenPermissionCheckpoints array should always have
    // unique timestamp values, i.e. a timestamp should not be duplicated.
    function assertInvariant_TokenPermissionUserCheckpointsAreAlwaysUniqueByTimestamp() public {
        // TODO Implement this assertion.
    }

    // For a given permission ID,the tokenPermissionCheckpoints array should always be sorted by
    // timestamp in ascending order.
    function assertInvariant_TokenPermissionSupplyCheckpointsAreAlwaysSortedByTimestamp() public {
        // TODO Implement this assertion.
    }

    // For a given permission ID, the tokenPermissionCheckpoints array should always have unique
    // timestamp values, i.e. a timestamp should not be duplicated.
    function assertInvariant_TokenPermissionSupplyCheckpointsAreAlwaysUniqueByTimestamp() public {
        // TODO Implement this assertion.
    }

    // The policyId, i.e. the token ID, held by a given user should always match that user's address.
    function assertInvariant_DeterministicPolicyIds() public view {
        address[] memory policyholders = handler.getActors();
        for (uint256 i = 0; i < policyholders.length; i++) {
            if (policy.balanceOf(policyholders[i]) == 0) continue;
            uint256 expectedTokenId = uint256(uint160(policyholders[i]));
            require(policy.ownerOf(expectedTokenId) == policyholders[i], "policyId should match user address");
        }
    }

    // A user should never have more than one policy NFT.
    function assertInvariant_PolicyholdersShouldNeverHaveMoreThanOneNFT() public view {
        address[] memory policyholders = handler.getActors();
        for (uint256 i = 0; i < policyholders.length; i++) {
            require(policy.balanceOf(policyholders[i]) <= 1, "policyholders should never have more than one NFT");
        }
    }

    // =================================
    // ======== Invariant Tests ========
    // =================================

    function invariant_AllInvariants() public view {
        assertInvariant_DeterministicPolicyIds();
        assertInvariant_PolicyholdersShouldNeverHaveMoreThanOneNFT();
    }

    function invariant_CallSummary() public {
        address[] memory policyholders = handler.getActors();
        for (uint256 i = 0; i < policyholders.length; i++) {
            uint256 balance = policy.balanceOf(policyholders[i]);
            if (balance == 0) handler.recordMetric("policyholdersHadBalanceOf_0");
            else if (balance == 1) handler.recordMetric("policyholdersHadBalanceOf_1");
            else handler.recordMetric("policyholdersHadBalanceOf_2+");
        }

        handler.callSummary();
    }
}
