// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {IVotes} from "@openzeppelin/governance/utils/IVotes.sol";
import {VertexRouter} from "src/router/VertexRouter.sol";
import {VertexExecutor} from "src/executor/VertexExecutor.sol";
import {ProtocolXYZ} from "src/mock/ProtocolXYZ.sol";
import {ProtocolVotingNFT} from "src/mock/ProtocolVotingNFT.sol";

contract VertexTest is Test {
    VertexRouter public vertexRouter;
    VertexExecutor public vertexExecutor;
    ProtocolXYZ public protocolXYZ;
    ProtocolVotingNFT public protocolVotingNFT;

    function setUp() public {
        protocolVotingNFT = new ProtocolVotingNFT("ProtocolVotingNFT", "XYZ");

        address alice = address(0x1337);
        address bob = address(0x1338);
        address charlie = address(0x1339);
        address diane = address(0x1340);

        protocolVotingNFT.mint(alice, 1);
        protocolVotingNFT.mint(bob, 2);
        protocolVotingNFT.mint(charlie, 3);
        protocolVotingNFT.mint(diane, 4);

        address[] memory proposers = new address[](1);
        proposers[0] = address(0);

        address[] memory executors = new address[](1);
        executors[0] = address(0);

        vertexExecutor = new VertexExecutor(0, proposers, executors, address(this));

        vertexRouter = new VertexRouter(IVotes(protocolVotingNFT), vertexExecutor);

        vertexExecutor.grantRole(keccak256("PROPOSER_ROLE"), address(vertexRouter));
        vertexExecutor.revokeRole(keccak256("TIMELOCK_ADMIN_ROLE"), address(this));
        protocolXYZ = new ProtocolXYZ(vertexExecutor);
    }

    function testPropose() public {
        uint256 x = 1;
        assertEq(x, 1);
    }
}
