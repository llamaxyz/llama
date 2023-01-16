// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IActionValidator {
    /**
     * @dev Get voting duration constant value
     * @return the voting duration value in seconds
     **/
    function getVotingDuration() external view returns (uint256);
}
