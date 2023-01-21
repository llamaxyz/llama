// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {ActionWithoutApprovals, Strategy} from "src/utils/Structs.sol";

interface IVertexCore {
    enum ActionState {
        Active,
        Canceled,
        Failed,
        Succeeded,
        Queued,
        Expired,
        Executed
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
     *
     */
    event ActionCreated(uint256 id, address indexed creator, VertexStrategy indexed strategy, address target, uint256 value, string signature, bytes data);

    /**
     * @dev emitted when an action is canceled
     * @param id Id of the action
     *
     */
    event ActionCanceled(uint256 id);

    /**
     * @dev emitted when a action is queued
     * @param id Id of the action
     * @param caller address of the initiator of the queuing transaction
     * @param strategy The Strategy contract that will determine how the action is executed
     * @param creator address of the action creator
     * @param executionTime time when action underlying transactions can be executed
     *
     */
    event ActionQueued(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator, uint256 executionTime);

    /**
     * @dev emitted when an action is executed
     * @param id Id of the action
     * @param caller address of the initiator of the executing transaction
     * @param strategy The Strategy contract that will determine how the action is executed
     * @param creator address of the action creator
     *
     */
    event ActionExecuted(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator);

    /**
     * @dev emitted when a approval is registered
     * @param id Id of the action
     * @param policyHolder address of the policyHolder
     * @param support boolean, true = supported
     * @param weight Power of the policyHolder/approval
     *
     */
    event ApprovalEmitted(uint256 id, address indexed policyHolder, bool support, uint256 weight);

    /**
     * @dev emitted when a approval is registered
     * @param id Id of the action
     * @param policyHolder address of the policyHolder
     * @param weight Weight of the policyHolder
     *
     */
    event DisapprovalEmitted(uint256 id, address indexed policyHolder, uint256 weight);

    event VertexStrategiesAuthorized(Strategy[] strategies);

    event VertexStrategiesUnauthorized(VertexStrategy[] strategies);

    function name() external view returns (string memory);

    /**
     * @dev Creates an action (Creator needs to hold a policy with the permissionSignature of the associated strategy, target, signature)
     * @param strategy The Strategy contract that will determine how the action is executed
     * @param target The contract called by action's associated transaction
     * @param value The value in wei of the action's associated transaction
     * @param signature The function signature that will be called by the action's associated transaction
     * @param data The arguments passed to the function that is called by the action's associated transaction
     * @return Id of the action
     *
     */
    function createAction(VertexStrategy strategy, address target, uint256 value, string calldata signature, bytes calldata data) external returns (uint256);

    /**
     * @dev Cancels an action,
     * either at anytime by creator
     * or when strategy-defined rules are met
     * or when creator no longer has correct policy at execution time
     * @param actionId id of the action
     *
     */
    function cancelAction(uint256 actionId) external;

    /**
     * @dev Queue the action (If Action Succeeded)
     * @param actionId id of the action to queue
     *
     */
    function queueAction(uint256 actionId) external;

    /**
     * @dev Execute the action (If Action Queued)
     * @param actionId id of the action to execute
     *  # @return the result from the delegatecall
     *
     */
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
     * @param v v part of the policyHolder signature
     * @param r r part of the policyHolder signature
     * @param s s part of the policyHolder signature
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
     * @param v v part of the policyHolder signature
     * @param r r part of the policyHolder signature
     * @param s s part of the policyHolder signature
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
     * @dev Get the current state of a action
     * @param actionId id of the action
     * @return The current state if the action
     *
     */
    function getActionState(uint256 actionId) external view returns (ActionState);

    /**
     * @dev Get Action object without approval data
     * @param actionId id of the action
     * @return Action object without approval data
     *
     */
    function getActionWithoutApprovals(uint256 actionId) external view returns (ActionWithoutApprovals memory);

    /**
     * @dev Checks whether a proposal is over its expiration delay
     * @param actionId Id of the action against which to test
     * @return true of proposal is over its expiration delay
     *
     */
    function isActionExpired(uint256 actionId) external view returns (bool);
}
