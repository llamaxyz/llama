// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable2Step} from "@openzeppelin/access/Ownable2Step.sol";

contract ProtocolXYZ is Ownable2Step {
    bool public paused;

    function pause(bool isPaused) external onlyOwner {
        paused = isPaused;
    }
}
