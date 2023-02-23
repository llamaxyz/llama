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
    VertexFactory public immutable vertexFactory;
    VertexPolicyNFT public immutable vertexPolicyNFT;

    constructor(VertexFactory _vertexFactory, VertexPolicyNFT _vertexPolicyNFT) {
        vertexFactory = _vertexFactory;
        vertexPolicyNFT = _vertexPolicyNFT;
    }
}
