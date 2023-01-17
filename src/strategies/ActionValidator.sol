// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IActionValidator} from "src/strategies/IActionValidator.sol";

/**
 * @title Action Validator abstract Contract, inherited by  Vertex strategies
 * @dev Validates/Invalidates action state transitions.
 * Voting Power functions: Validates success of actions.
 * Veto Power functions: Validates whether an action can be vetoed
 * @author Llama
 **/
abstract contract ActionValidator is IActionValidator {
    uint256 private immutable votingDuration;

    constructor(uint256 _votingDuration) {
        votingDuration = _votingDuration;
    }

    function getVotingDuration() external view override returns (uint256) {
        return votingDuration;
    }
}
