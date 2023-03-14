// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, Strategy} from "src/lib/Structs.sol";

interface IVertexCore {
  event ActionCreated(
    uint256 id,
    address indexed creator,
    VertexStrategy indexed strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes data
  );
  event ActionCanceled(uint256 id);
  event ActionQueued(
    uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator, uint256 executionTime
  );
  event ActionExecuted(uint256 id, address indexed caller, VertexStrategy indexed strategy, address indexed creator);
  event PolicyholderApproved(uint256 id, address indexed policyholder, uint256 weight);
  event PolicyholderDisapproved(uint256 id, address indexed policyholder, uint256 weight);
  event StrategyAuthorized(VertexStrategy indexed strategy, Strategy strategyData);
  event StrategyUnauthorized(VertexStrategy indexed strategy);
  event AccountAuthorized(VertexAccount indexed account, string name);

  /// @notice Initializes a new VertexCore clone.
  /// @param name The name of the VertexCore clone.
  /// @param policy This Vertex instance's policy contract.
  /// @param vertexStrategyLogic The Vertex Strategy implementation (logic) contract.
  /// @param vertexAccountLogic The Vertex Account implementation (logic) contract.
  /// @param initialStrategies The configuration of the initial strategies.
  /// @param initialAccounts The configuration of the initial strategies.
  function initialize(
    string memory name,
    VertexPolicy policy,
    VertexStrategy vertexStrategyLogic,
    VertexAccount vertexAccountLogic,
    Strategy[] memory initialStrategies,
    string[] memory initialAccounts
  ) external;

  /// @notice Creates an action. The creator needs to hold a policy with the permissionId of the provided
  /// strategy, target, selector.
  /// @param strategy The VertexStrategy contract that will determine how the action is executed.
  /// @param target The contract called when the action is executed.
  /// @param value The value in wei to be sent when the action is executed.
  /// @param selector The function selector that will be called when the action is executed.
  /// @param data The encoded arguments to be passed to the function that is called when the action is executed.
  /// @return actionId of the newly created action.
  function createAction(VertexStrategy strategy, address target, uint256 value, bytes4 selector, bytes calldata data)
    external
    returns (uint256);

  /// @notice Cancels an action. Can be called anytime by the creator or if action is disapproved.
  /// @param actionId Id of the action to cancel.
  function cancelAction(uint256 actionId) external;

  /// @notice Queue an action by actionId if it's in Approved state.
  /// @param actionId Id of the action to queue.
  function queueAction(uint256 actionId) external;

  /// @notice Execute an action by actionId if it's in Queued state and executionTime has passed.
  /// @param actionId Id of the action to execute.
  /// @return The result returned from the call to the target contract.
  function executeAction(uint256 actionId) external payable returns (bytes memory);

  /// @notice How policyholders add their support of the approval of an action.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to submit their approval.
  function submitApproval(uint256 actionId, bytes32 role) external;

  /// @notice How policyholders add their support of the approval of an action via an off-chain signature.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to submit their approval.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  function submitApprovalBySignature(uint256 actionId, bytes32 role, uint8 v, bytes32 r, bytes32 s) external;

  /// @notice How policyholders add their support of the disapproval of an action.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to submit their disapproval.
  function submitDisapproval(uint256 actionId, bytes32 role) external;

  /// @notice How policyholders add their support of the disapproval of an action via an off-chain signature.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to submit their disapproval.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  function submitDisapprovalBySignature(uint256 actionId, bytes32 role, uint8 v, bytes32 r, bytes32 s) external;

  /// @notice Deploy new strategies and add them to the mapping of authorized strategies.
  /// @param strategies list of new Strategys to be authorized.
  function createAndAuthorizeStrategies(Strategy[] memory strategies) external;

  /// @notice Remove strategies from the mapping of authorized strategies.
  /// @param strategies list of Strategys to be removed from the mapping of authorized strategies.
  function unauthorizeStrategies(VertexStrategy[] memory strategies) external;

  /// @notice Deploy new accounts and add them to the mapping of authorized accounts.
  /// @param accounts list of new accounts to be authorized.
  function createAndAuthorizeAccounts(string[] memory accounts) external;

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
