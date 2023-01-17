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

    struct Vote {
        bool support;
        uint248 votingPower;
    }

    struct Veto {
        bool support;
        uint248 votingPower;
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

    /**
     * @dev emitted when a new action is created
     * @param id Id of the action
     * @param creator address of the action creator
     * @param strategy The Strategy contract that will determine how the action is executed
     * @param target The contract called by action's associated transaction
     * @param value The value in wei of the action's associated transaction
     * @param signature The function signature that will be called by the action's associated transaction
     * @param data The arguments passed to the function that is called by the action's associated transaction
     **/
    event ActionCreated(uint256 id, address indexed creator, IVertexStrategy indexed strategy, address target, uint256 value, string signature, bytes data);

    /**
     * @dev emitted when an action is canceled
     * @param id Id of the action
     **/
    event ActionCanceled(uint256 id);

    /**
     * @dev emitted when a action is queued
     * @param id Id of the action
     * @param caller address of the initiator of the queuing transaction
     * @param strategy The Strategy contract that will determine how the action is executed
     * @param creator address of the action creator
     * @param executionTime time when action underlying transactions can be executed
     **/
    event ActionQueued(uint256 id, address indexed caller, address indexed strategy, address indexed creator, uint256 executionTime);

    /**
     * @dev emitted when an action is executed
     * @param id Id of the action
     * @param caller address of the initiator of the executing transaction
     * @param strategy The Strategy contract that will determine how the action is executed
     * @param creator address of the action creator
     **/
    event ActionExecuted(uint256 id, address indexed caller, address indexed strategy, address indexed creator);

    /**
     * @dev emitted when a vote is registered
     * @param id Id of the action
     * @param voter address of the voter
     * @param support boolean, true = vote for, false = vote against
     * @param votingPower Power of the voter/vote
     **/
    event VoteEmitted(uint256 id, address indexed voter, bool support, uint256 votingPower);

    /**
     * @dev emitted when a vote is registered
     * @param id Id of the action
     * @param vetoer address of the vetoer
     * @param votingVetoPower Power of the vetoer
     **/
    event VetoEmitted(uint256 id, address indexed vetoer, uint256 votingVetoPower);

    event VertexStrategyAuthorized(address indexed strategy, address indexed creator);

    event VertexStrategyUnauthorized(address indexed strategy, address indexed creator);

    function name() external view returns (string memory);

    /**
     * @dev Creates an action (Creator needs to hold a policy with the permissionSignature of the associated strategy, target, signature)
     * @param strategy The Strategy contract that will determine how the action is executed
     * @param target The contract called by action's associated transaction
     * @param value The value in wei of the action's associated transaction
     * @param signature The function signature that will be called by the action's associated transaction
     * @param data The arguments passed to the function that is called by the action's associated transaction
     * @return Id of the action
     **/
    function createAction(IVertexStrategy strategy, address target, uint256 value, string calldata signature, bytes calldata data) external returns (uint256);

    /**
     * @dev Cancels an action,
     * either at anytime by creator
     * or when strategy-defined rules are met
     * or when creator no longer has correct policy at execution time
     * @param actionId id of the action
     **/
    function cancelAction(uint256 actionId) external;

    /**
     * @dev Queue the action (If Action Succeeded)
     * @param actionId id of the action to queue
     **/
    function queueAction(uint256 actionId) external;

    /**
     * @dev Execute the action (If Action Queued)
     * @param actionId id of the action to execute
     **/
    function executeAction(uint256 actionId) external payable;

    /**
     * @dev Function allowing msg.sender to vote for/against a action
     * @param actionId id of the action
     * @param support boolean, true = vote for, false = vote against
     **/
    function submitVote(uint256 actionId, bool support) external;

    /**
     * @dev Function to register the vote of user that has voted offchain via signature
     * @param actionId id of the action
     * @param support boolean, true = vote for, false = vote against
     * @param v v part of the voter signature
     * @param r r part of the voter signature
     * @param s s part of the voter signature
     **/
    function submitVoteBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @dev Function allowing msg.sender to veto an action
     * only eligible when action is Queued
     * @param actionId id of the action
     **/
    function submitVeto(uint256 actionId) external;

    /**
     * @dev Function to register the veto of user that has vetoed offchain via signature
     * @param actionId id of the action
     * @param v v part of the voter signature
     * @param r r part of the voter signature
     * @param s s part of the voter signature
     **/
    function submitVetoBySignature(uint256 actionId, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @dev Create new strategies and add them to the list of authorized strategies
     * @param strategies list of new addresses to be authorized strategies
     **/
    function createAndAuthorizeStrategies(address[] memory strategies) external;

    /**
     * @dev Remove addresses to the list of authorized strategies
     * @param strategies list of addresses to be removed as authorized strategies
     **/
    function unauthorizeStrategies(address[] memory strategies) external;

    /**
     * @dev Getter of the Vote of a voter about an action
     * Note: Vote is a struct: ({bool support, uint248 votingPower})
     * @param actionId id of the action
     * @param voter address of the voter
     * @return The associated Vote memory object
     **/
    function getVoteOnAction(uint256 actionId, address voter) external view returns (Vote memory);

    /**
     * @dev Getter of the Veto of a vetoer about an action
     * Note: Veto is a struct: ({bool support, uint248 votingPower})
     * @param actionId id of the action
     * @param vetoer address of the vetoer
     * @return The associated Veto memory object
     **/
    function getVetoOnAction(uint256 actionId, address vetoer) external view returns (Veto memory);

    /**
     * @dev Get the current state of a action
     * @param actionId id of the action
     * @return The current state if the action
     **/
    function getActionState(uint256 actionId) external view returns (ActionState);
}
