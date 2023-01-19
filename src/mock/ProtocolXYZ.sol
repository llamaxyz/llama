// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {VertexExecutor} from "src/executor/VertexExecutor.sol";

contract ProtocolXYZ is AccessControl {
    event Executed(address indexed executor, uint256 number);
    event Paused(address indexed executor, bool isPaused);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(VertexExecutor executor) {
        _grantRole(ADMIN_ROLE, address(executor));
    }

    function create(uint256 number) external onlyRole(ADMIN_ROLE) {
        emit Executed(msg.sender, number);
    }

    function pause(bool isPaused) external onlyRole(ADMIN_ROLE) {
        emit Paused(msg.sender, isPaused);
    }
}
