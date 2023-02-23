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
    constructor(VertexFactory _vertexFactory, VertexPolicyNFT _vertexPolicyNFT) BaseHandler(_vertexFactory, _vertexPolicyNFT) {}

    function vertexPolicyNFT_() public {
        //
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

    // For a given permission ID and timestamp, the sum of that permission's quantity over all users
    // with that permission should equal the total supply of that permission ID.
    function assertInvariant_ForEachPermissionId_SumOfPermissionsOverAllUsersEqualsTotalSupply() public {}

    // For a given user and permission ID,their tokenPermissionCheckpoints array should always be
    // sorted by timestamp in ascending order.
    function assertInvariant_TokenPermissionUserCheckpointsAreAlwaysSortedByTimestamp() public {}

    // For a given user and permission ID, their tokenPermissionCheckpoints array should always have
    // unique timestamp values, i.e. a timestamp should not be duplicated.
    function assertInvariant_TokenPermissionUserCheckpointsAreAlwaysUniqueByTimestamp() public {}

    // For a given permission ID,the tokenPermissionCheckpoints array should always be sorted by
    // timestamp in ascending order.
    function assertInvariant_TokenPermissionSupplyCheckpointsAreAlwaysSortedByTimestamp() public {}

    // For a given permission ID, the tokenPermissionCheckpoints array should always have unique
    // timestamp values, i.e. a timestamp should not be duplicated.
    function assertInvariant_TokenPermissionSupplyCheckpointsAreAlwaysUniqueByTimestamp() public {}

    // The policyId, i.e. the token ID, held by a given user should always match that user's address.
    function assertInvariant_DeterministicPolicyIds() public {}
}
