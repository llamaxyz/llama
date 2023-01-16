// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";

interface IVertexRouter {
    enum ActionState {
        Active,
        Canceled,
        Failed,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    struct Action {
        uint256 id;
        address creator;
        IVertexStrategy strategy;
        address target;
        uint256 value;
        string signature;
        bytes data;
        bool canceled;
        bool executed;
        // Properties for initial voting
        uint256 votingStartTime;
        uint256 votingEndTime;
        uint256 forVotes;
        uint256 againstVotes;
        mapping(address => Vote) votes;
        // Properties for veto voting
        uint256 queueTime;
        uint256 executionTime; // Not set until action is queued
        uint256 forVetoVotes;
        uint256 againstVetoVotes;
        mapping(address => Veto) vetoVotes;
    }

    struct ActionWithoutVotes {
        uint256 id;
        address creator;
        IVertexStrategy strategy;
        address target;
        uint256 value;
        string signature;
        bytes data;
        bool executed;
        bool canceled;
        uint256 votingStartTime;
        uint256 votingEndTime;
        uint256 queueTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 forVetoVotes;
        uint256 againstVetoVotes;
    }

    event ActionCreated(uint256 id, address indexed creator, IVertexStrategy indexed strategy, address target, uint256 value, string signature, bytes data);

    event ActionCanceled(uint256 id);

    event ActionExecuted(uint256 id, address indexed caller, address indexed strategy, address indexed creator);

    event VertexStrategyAuthorized(address indexed strategy, address indexed creator);

    event VertexStrategyUnauthorized(address indexed strategy, address indexed creator);

    function name() external view returns (string memory);

    function createAction(IVertexStrategy strategy, address target, uint256 value, string calldata signature, bytes calldata data) external returns (uint256);

    function cancel(uint256 actionId) external;

    function execute(uint256 actionId) external payable;

    function getStrategies() external view returns (IVertexStrategy[] memory);

    function isStrategyAuthorized(IVertexStrategy strategy) external view returns (bool);

    function getActionsCount() external view returns (uint256);

    function getActionsById(uint256 actionId) external view returns (Action memory);

    function getActionState(uint256 actionId) external view returns (ActionState);
}
