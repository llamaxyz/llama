// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {IVertexExecutor} from "src/executor/IVertexExecutor.sol";
import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";
import {VertexStrategySettings} from "src/strategies/VertexStrategySettings.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";

// Errors
error ActionNotQueued();
error TimelockNotFinished();
error ActionHasExpired();
error FailedActionExecution();

contract VertexStrategy is IVertexStrategy, VertexStrategySettings {
    /// @notice Name of the strategy.
    string public name;

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
        string memory _name,
        IVertexExecutor _executor,
        uint256 _delay,
        uint256 _expirationDelay,
        bool _isFixedVotingPeriod,
        uint256 _votingDuration,
        VertexPolicyNFT _policy,
        IVertexRouter _router,
        uint256 _voteDifferential,
        uint256 _vetoVoteDifferential,
        uint256 _minimumVoteQuorum,
        uint256 _minimumVetoQuorum,
        VotePowerByPermission[] memory _votePowerByPermission,
        VetoPowerByPermission[] memory _vetoPowerByPermission
    )
        VertexStrategySettings(
            _votingDuration,
            _policy,
            _router,
            _voteDifferential,
            _vetoVoteDifferential,
            _minimumVoteQuorum,
            _minimumVetoQuorum,
            _votePowerByPermission,
            _vetoPowerByPermission
        )
    {
        name = _name;
        executor = _executor;
        delay = _delay;
        expirationDelay = _expirationDelay;
        isFixedVotingPeriod = _isFixedVotingPeriod;

        emit NewStrategyCreated(name);
    }

    /// @inheritdoc IVertexStrategy
    function queueAction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 executionTime
    ) public override onlyVertexRouter returns (bytes32) {
        // TODO: should the router just handle the hashing?
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
    ) public override onlyVertexRouter returns (bytes32) {
        bytes32 actionHash = keccak256(abi.encode(target, value, signature, data, executionTime));
        queuedActions[actionHash] = false;

        emit CanceledAction(actionHash, target, value, signature, data);
        return actionHash;
    }

    /// @inheritdoc IVertexStrategy
    function executeAction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 executionTime
    ) public payable override onlyVertexRouter returns (bytes memory) {
        bytes32 actionHash = keccak256(abi.encode(target, value, signature, data, executionTime));
        if (!queuedActions[actionHash]) revert ActionNotQueued();
        if (block.timestamp < executionTime) revert TimelockNotFinished();
        if (block.timestamp > executionTime + expirationDelay) revert ActionHasExpired();

        queuedActions[actionHash] = false;

        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory result) = address(executor).delegatecall(
            abi.encodeWithSelector(IVertexExecutor.execute.selector, target, value, signature, data)
        );

        if (!success) revert FailedActionExecution();

        emit ExecutedAction(actionHash, target, value, signature, data, result);

        return result;
    }

    function isActionExpired(uint256 actionId) external view override returns (bool) {
        IVertexRouter.ActionWithoutVotes memory action = router.getActionWithoutVotes(actionId);

        return (block.timestamp > (action.executionTime + votingDuration));
    }
}
