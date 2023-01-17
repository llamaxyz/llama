// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IStrategySettings {
    /**
     * @dev Get voting duration constant value
     * @return the voting duration value in seconds
     **/
    function votingDuration() external view returns (uint256);
}
