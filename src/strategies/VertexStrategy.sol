// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {IVertexExecutor} from "src/executor/IVertexExecutor.sol";
import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";
import {ActionValidator} from "src/strategies/ActionValidator.sol";

// Errors
error ActionNotQueued();
error TimelockNotFinished();
error ActionHasExpired();

contract VertexStrategy is IVertexStrategy, ActionValidator {
    /// @notice Name of the strategy.
    string public immutable name;

    /// @notice Router of this Vertex instance.
    IVertexRouter public immutable router;

    /// @notice Executor of this Vertex instance.
    IVertexExecutor public immutable executor;

    /// @notice Minimum time between queueing and execution of action.
    uint256 public immutable delay;

    /// @notice Time after delay that action can be executed before permanently expiring.
    uint256 public immutable expirationDelay;

    /// @notice Can action be queued before votingEndTime.
    bool public immutable isFixedVotingPeriod;

    /// @notice Mapping of action hashes and boolean that indicates if action is queued.
    mapping(bytes32 => bool) public queuedActions;

    constructor(
        string calldata _name,
        IVertexRouter _router,
        IVertexExecutor _executor,
        uint256 _delay,
        uint256 _expirationDelay,
        uint256 _votingDuration,
        bool _isFixedVotingPeriod
    ) ActionValidator(_votingDuration) {
        name = _name;
        router = _router;
        executor = _executor;
        delay = _delay;
        expirationDelay = _expirationDelay;
        isFixedVotingPeriod = _isFixedVotingPeriod;

        emit NewStrategyCreated(name);
    }

    modifier onlyVertexRouter() {
        if (msg.sender != router) revert OnlyRouter();
        _;
    }

    /// @inheritdoc IVertexStrategy
    function queueAction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 executionTime
    ) public override onlyRouter returns (bytes32) {
        bytes32 actionHash = keccak256(abi.encode(target, value, signature, data, executionTime));
        queuedActions[actionHash] = true;

        emit QueuedAction(actionHash, target, value, signature, data, executionTime);
        return actionHash;
    }

    /// @inheritdoc IVertexStrategy
    function cancelAction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 executionTime
    ) public override onlyRouter returns (bytes32) {
        bytes32 actionHash = keccak256(abi.encode(target, value, signature, data, executionTime));
        queuedActions[actionHash] = false;

        emit CanceledAction(actionHash, target, value, signature, data, executionTime);
        return actionHash;
    }

    /// @inheritdoc IVertexStrategy
    function executeAction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 executionTime
    ) public payable override onlyRouter returns (bytes memory) {
        bytes32 actionHash = keccak256(abi.encode(target, value, signature, data, executionTime));
        if (!queuedActions[actionHash]) revert ActionNotQueued();
        if (block.timestamp < executionTime) revert TimelockNotFinished();
        if (block.timestamp > executionTime + expirationDelay()) revert ActionHasExpired();

        queuedActions[actionHash] = false;

        (bool success, bytes memory result) = executor.delegatecall{value: value}(
            abi.encodeWithSelector(IVertexExecutor.execute.selector, target, value, signature, data)
        );

        if (!success) revert FailedActionExecution();

        emit ExecutedAction(actionHash, target, value, signature, data, executionTime, result);

        return result;
    }
}
