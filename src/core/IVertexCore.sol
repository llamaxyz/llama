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

    event ActionCreated(uint256 id, address indexed creator, VertexStrategy indexed strategy, address target, uint256 value, bytes4 selector, bytes data);
    event ActionCanceled(uint256 id);
    event ActionQueued(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator, uint256 executionTime);
    event ActionExecuted(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator);
    event PolicyholderApproved(uint256 id, address indexed policyholder, bool support, uint256 weight);
    event PolicyholderDisapproved(uint256 id, address indexed policyholder, bool support, uint256 weight);
    event StrategiesAuthorized(Strategy[] strategies);
    event StrategiesUnauthorized(VertexStrategy[] strategies);

    /// @notice Creates an action. The creator needs to hold a policy with the permissionSignature of the provided strategy, target, selector.
    /// @param policyId The tokenId of the policy NFT owned by the policyholder.
    /// @param strategy The VertexStrategy contract that will determine how the action is executed.
    /// @param target The contract called when the action is executed.
    /// @param value The value in wei to be sent when the action is executed.
    /// @param selector The function selector that will be called when the action is executed.
    /// @param data The encoded arguments to be passed to the function that is called when the action is executed.
    /// @return actionId of the newly created action.
    function createAction(uint256 policyId, VertexStrategy strategy, address target, uint256 value, bytes4 selector, bytes calldata data)
        external
        returns (uint256);

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

    /// @notice How policyholders add or remove their support of the approval of an action.
    /// @param actionId The id of the action.
    /// @param support A boolean value that indicates whether the policyholder is adding or removing their support of the approval.
    function submitApproval(uint256 actionId, bool support) external;

    /// @notice How policyholders add or remove their support of the approval of an action via an offchain selector.
    /// @param actionId The id of the action.
    /// @param support A boolean value that indicates whether the policyholder is adding or removing their support of the approval.
    /// @param v v part of the policyholder selector
    /// @param r r part of the policyholder selector
    /// @param s s part of the policyholder selector
    function submitApprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external;

    /// @notice How policyholders add or remove their support of the disapproval of an action.
    /// @param actionId The id of the action.
    /// @param support A boolean value that indicates whether the policyholder is adding or removing their support of the disapproval.
    function submitDisapproval(uint256 actionId, bool support) external;

    /// @notice How policyholders add or remove their support of the disapproval of an action via an offchain selector.
    /// @param actionId The id of the action.
    /// @param support A boolean value that indicates whether the policyholder is adding or removing their support of the disapproval.
    /// @param v v part of the policyholder selector
    /// @param r r part of the policyholder selector
    /// @param s s part of the policyholder selector
    function submitDisapprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external;

    /// @notice Deploy new strategies and add them to the mapping of authorized strategies.
    /// @param strategies list of new Strategys to be authorized.
    function createAndAuthorizeStrategies(Strategy[] memory strategies) external;

    /// @notice Remove strategies from the mapping of authorized strategies.
    /// @param strategies list of Strategys to be removed from the mapping of authorized strategies.
    function unauthorizeStrategies(VertexStrategy[] memory strategies) external;

    /// @notice Get an Action struct by actionId.
    /// @param actionId id of the action.
    /// @return The Action struct.
    function getAction(uint256 actionId) external view returns (Action memory);

    /// @notice Get the current ActionState of an action by its actionId.
    /// @param actionId id of the action.
    /// @return The current ActionState of the action.
    function getActionState(uint256 actionId) external view returns (ActionState);

    /// @notice Get whether an action has expired and can no longer be executed.
    /// @param actionId id of the action.
    /// @return Boolean value that is true if the action has expired.
    function isActionExpired(uint256 actionId) external view returns (bool);
}
