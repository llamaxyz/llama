// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ProtocolVotingNFT} from "src/mock/ProtocolVotingNFT.sol";

contract VertexTest is Test {
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
    }

    function testPropose() public {
        uint256 x = 1;
        assertEq(x, 1);
    }
}
