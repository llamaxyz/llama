// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ProtocolXYZ {
    event Paused(address indexed executor, bool isPaused);

    error OnlyVertex();

    address public immutable vertex;

    constructor(address _vertex) {
        vertex = _vertex;
    }

    modifier onlyVertex() {
        if (msg.sender != address(this)) revert OnlyVertex();
        _;
    }

    function pause(bool isPaused) external onlyVertex {
        emit Paused(msg.sender, isPaused);
    }
}
