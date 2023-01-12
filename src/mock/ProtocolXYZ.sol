// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AccessControl} from "@openzeppelin/access/AccessControl.sol";

contract ProtocolXYZ is AccessControl {
    event Executed(address indexed executor, uint256 number);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(address admin) {
        _grantRole(ADMIN_ROLE, admin);
    }

    function create(uint256 number) external onlyRole(ADMIN_ROLE) {
        emit Executed(msg.sender, number);
    }
}
