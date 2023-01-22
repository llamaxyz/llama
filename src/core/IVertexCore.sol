// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {Action, Strategy} from "src/utils/Structs.sol";

interface IVertexCore {
    enum ActionState {
        Active, // Action created and approval period begins.
        Canceled, // Action canceled by creator or disapproved.
        Failed, // Action approval failed.
        Succeeded, // Action approval succeeded and ready to be queued.
        Queued, // Action queued for queueing duration and disapproval period begins.
        Expired, // block.timestamp is greater than Action's executionTime + expirationDelay.
        Executed // Action has executed succesfully.
    }

    event ActionCreated(uint256 id, address indexed creator, VertexStrategy indexed strategy, address target, uint256 value, string signature, bytes data);
    event ActionCanceled(uint256 id);
    event ActionQueued(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator, uint256 executionTime);
    event ActionExecuted(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator);
    event PolicyholderApproved(uint256 id, address indexed policyholder, bool support, uint256 weight);
    event PolicyholderDisapproved(uint256 id, address indexed policyholder, bool support, uint256 weight);
    event StrategiesAuthorized(Strategy[] strategies);
    event StrategiesUnauthorized(VertexStrategy[] strategies);

    /// @notice Creates an action. The creator needs to hold a policy with the permissionSignature of the provided strategy, target, signature.
    /// @param strategy The VertexStrategy contract that will determine how the action is executed.
    /// @param target The contract called when the action is executed.
    /// @param value The value in wei to be sent when the action is executed.
    /// @param signature The function signature that will be called when the action is executed.
    /// @param data The encoded arguments to be passed to the function that is called when the action is executed.
    /// @return actionId of the newly created action.
    function createAction(VertexStrategy strategy, address target, uint256 value, string calldata signature, bytes calldata data) external returns (uint256);

    /// @notice Cancels an action. Can be called anytime by the creator or if action is disapproved.
    /// @param actionId Id of the action to cancel.
    function cancelAction(uint256 actionId) external;

    /// @notice Queue an action by actionId if it's in Succeeded state.
    /// @param actionId Id of the action to queue.
    function queueAction(uint256 actionId) external;

    /// @notice Execute an action by actionId if it's in Queued state and executionTime has passed.
    /// @param actionId Id of the action to execute.
    /// @return The result returned from the call to the target contract.
    function executeAction(uint256 actionId) external payable returns (bytes memory);

    /**
     * @dev Function allowing msg.sender to approval for/against an action
     * @param actionId id of the action
     * @param support boolean, true = approval for, false = approval against
     *
     */
    function submitApproval(uint256 actionId, bool support) external;

    /**
     * @dev Function to register the approval of user that has approvald offchain via signature
     * @param actionId id of the action
     * @param support boolean, true = approval for, false = approval against
     * @param v v part of the policyholder signature
     * @param r r part of the policyholder signature
     * @param s s part of the policyholder signature
     *
     */
    function submitApprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @dev Function allowing msg.sender to disapprove an action
     * only eligible when action is Queued
     * @param actionId id of the action
     *
     */
    function submitDisapproval(uint256 actionId, bool support) external;

    /**
     * @dev Function to register the disapprove of user that has been disapproved offchain via signature
     * @param actionId id of the action
     * @param v v part of the policyholder signature
     * @param r r part of the policyholder signature
     * @param s s part of the policyholder signature
     *
     */
    function submitDisapprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @dev Create new strategies and add them to the list of authorized strategies
     * @param strategies list of new addresses to be authorized strategies
     *
     */
    function createAndAuthorizeStrategies(Strategy[] memory strategies) external;

    /**
     * @dev Remove addresses to the list of authorized strategies
     * @param strategies list of addresses to be removed as authorized strategies
     *
     */
    function unauthorizeStrategies(VertexStrategy[] memory strategies) external;

    /**
     * @dev Get Action object without approval data
     * @param actionId id of the action
     * @return Action object without approval data
     *
     */
    function getAction(uint256 actionId) external view returns (Action memory);

    /**
     * @dev Get the current state of a action
     * @param actionId id of the action
     * @return The current state if the action
     *
     */
    function getActionState(uint256 actionId) external view returns (ActionState);

    /**
     * @dev Checks whether a proposal is over its expiration delay
     * @param actionId Id of the action against which to test
     * @return true of proposal is over its expiration delay
     *
     */
    function isActionExpired(uint256 actionId) external view returns (bool);
}
