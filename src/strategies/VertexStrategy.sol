// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";
import {ActionValidator} from "src/strategies/ActionValidator.sol";

contract VertexStrategy is IVertexStrategy, ActionValidator {
    /// @notice Name of the strategy.
    string public immutable name;

    /// @notice Router of this Vertex instance.
    IVertexRouter public immutable router;

    /// @notice Minimum time between queueing and execution of action.
    uint256 public immutable delay;

    /// @notice Time after delay that action can be executed before permanently expiring.
    uint256 public immutable expirationDelay;

    /// @notice Can action be queued before votingEndTime.
    bool public immutable isFixedVotingPeriod;

    constructor(
        string calldata _name,
        IVertexRouter _router,
        uint256 _delay,
        uint256 _expirationDelay,
        uint256 votingDuration,
        bool _isFixedVotingPeriod
    ) ActionValidator(votingDuration) {
        name = _name;
        router = _router;
        delay = _delay;
        expirationDelay = _expirationDelay;
        isFixedVotingPeriod = _isFixedVotingPeriod;

        emit NewStrategyCreated(name);
    }
}
