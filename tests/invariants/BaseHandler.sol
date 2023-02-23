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

contract BaseHandler is CommonBase, StdCheats, StdUtils {
    // Protocol contracts.
    VertexFactory public immutable vertexFactory;
    VertexPolicyNFT public immutable vertexPolicyNFT;

    // Handler state.
    address[] internal actors;
    uint256[] internal timestamps;
    uint256 currentTimestamp;

    constructor(VertexFactory _vertexFactory, VertexPolicyNFT _vertexPolicyNFT) {
        vertexFactory = _vertexFactory;
        vertexPolicyNFT = _vertexPolicyNFT;
    }

    // --- Actor Management ---
    function addActor() public {
        string memory actorName = string(abi.encodePacked("actor", vm.toString(actors.length)));
        actors.push(makeAddr(actorName));
    }

    modifier useActor(uint256 seed) {
        if (actors.length == 0) addActor();
        vm.startPrank(actors[seed % actors.length]);
        _;
        vm.stopPrank();
    }

    // --- Timestamp Management ---
    function increaseTimestampBy(uint256 timeToIncrease) public {
        timeToIncrease = bound(timeToIncrease, 0, 8 weeks);
        uint256 newTimestamp = currentTimestamp + timeToIncrease;
        timestamps.push(newTimestamp);
        currentTimestamp = newTimestamp;
    }

    modifier useCurrentTimestamp() {
        vm.warp(currentTimestamp);
        _;
    }

    modifier useCurrentTimestampThenIncreaseTimestampBy(uint256 timeToIncrease) {
        vm.warp(currentTimestamp);
        _;
        increaseTimestampBy(timeToIncrease);
    }
}
