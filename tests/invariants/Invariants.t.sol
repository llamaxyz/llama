// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import {VertexFactory} from "src/factory/VertexFactory.sol";
import {Strategy} from "src/utils/Structs.sol";
import {VertexCoreTest} from "tests/VertexCore.t.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    VertexFactory public immutable vertexFactory;

    // Used to track the last seen `vertexCount` value.
    uint256 public lastVertexCount;

    // The salt is a function of name and symbol. To ensure we get a different contract address each
    // time we deterministically update this value to track what the next name and symbol will be.
    uint256 nextNameCounter = 0;

    constructor(VertexFactory _vertexFactory) {
        vertexFactory = _vertexFactory;
        lastVertexCount = vertexFactory.vertexCount();
    }

    function name() private returns (string memory currentName) {
        currentName = string.concat("NAME_", vm.toString(nextNameCounter++));
    }

    // The vertexCount state variable should only increase, and be incremented by 1 with each
    // successful deploy.
    modifier assertInvariant_VertexCountMonotonicallyIncreases() {
        uint256 initVertexCount1 = vertexFactory.vertexCount();
        uint256 initVertexCount2 = lastVertexCount;
        require(initVertexCount1 == initVertexCount2, "pre-deploy vertexCount mismatch");

        _;

        uint256 newVertexCount = vertexFactory.vertexCount();
        require(newVertexCount == initVertexCount1 + 1, "post-deploy vertexCount mismatch");
        lastVertexCount = newVertexCount;
    }

    function vertexFactory_deploy() public assertInvariant_VertexCountMonotonicallyIncreases {
        // We don't care about the parameters, we just need it to execute successfully.
        vm.prank(address(vertexFactory.rootVertex()));
        vertexFactory.deploy(name(), name(), new Strategy[](0), new string[](0), new address[](0), new bytes8[][](0), new uint256[][](0));
    }
}

contract VertexInvariants is VertexCoreTest {
    // TODO Remove inheritance on VertexCoreTest once https://github.com/llama-community/vertex-v1/issues/38 is
    // completed. Inheriting from it now just to simplify the test setup, but ideally our invariant
    // tests would not be coupled to our unit tests in this way.

    Handler public handler;

    function setUp() public override {
        VertexCoreTest.setUp();
        handler = new Handler(vertexFactory);

        // Target the handler contract, and use `excludeArtifact` to prevent contracts deployed by
        // the factory from automatically being added to the target contracts list (by default,
        // deployed contracts are automatically added to the target contracts list).
        targetSender(makeAddr("invariantSender")); // TODO why does removing this result in failure due to clone being deployed to a sender's address?
        targetContract(address(handler));
        excludeArtifact("VertexCore");
        excludeArtifact("VertexPolicyNFT");
        excludeArtifact("VertexStrategy");
        excludeArtifact("VertexAccount");
    }

    function invariant_VertexCountMonotonicallyIncreases() public {
        // No logic is needed here since checks are done in the `Handler` contract.
    }
}
