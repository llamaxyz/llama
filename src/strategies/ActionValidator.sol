// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IActionValidator} from "src/strategies/IActionValidator.sol";
import {IVertexRouter} from "src/router/IVertexRouter.sol";

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

    function isActionPassed(uint256 actionId) external view override returns (bool) {
        // TODO: Needs to account for votingEndTime = 0 (no vote strategies)
        // TODO: Needs to account for both fixedVotingPeriod's
    }

    function isActionExpired(uint256 actionId) external view override returns (bool) {}

    function isActionCanceletionValid(IVertexRouter.Action action, address msgSender) external view override returns (bool) {
        // TODO: do these functionsneed the whole Action or just the action id
        // TODO: Include check that allows cancelation if msgSender is action creator
    }
}
