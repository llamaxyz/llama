// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Llama Strategy Interface
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the interface for Llama strategies which determine the rules of an action's process.
/// @dev The interface is sorted by the stage of the action's lifecycle in which the method's are used.
interface ILlamaStrategy {
  // -------- For Inspection --------
  // These are not strictly required by the core, but are useful for inspecting a strategy contract.

  /// @notice Returns the address of the Ll contract that this strategy is registered to.
  function llamaCore() external view returns (LlamaCore);

  /// @notice Returns the name of the policy contract that this strategy is registered to.
  function policy() external view returns (LlamaPolicy);

  // -------- At Strategy Creation --------

  /// @notice Initializes a new clone of the strategy.
  /// @dev Order is of QuantityByPermissions is critical. Quantity is determined by the first specific permission match.
  /// @param config The strategy configuration, encoded as bytes to support differing constructor arguments in
  /// different strategies.
  function initialize(bytes memory config) external;

  // -------- At Action Creation --------

  /// @notice Returns `true` if the action is allowed to be created, false otherwise.  May also
  /// return a reason string for why the action is not allowed.
  /// @dev Reason string is limited to `bytes32` to reduce the risk of a revert due to a large
  /// string that consumes too much gas when copied to memory.
  /// @dev This method is not view because the strategy may want to save off some data at the time of creation.
  function validateActionCreation(uint256 actionId) external returns (bool, bytes32);

  // -------- When Casting Approval --------

  /// @notice Returns true if approvals are allowed with this strategy for the given policyholder, false
  /// otherwise.  May also return a reason string for why the action is not allowed.
  /// @dev Reason string is limited to `bytes32` to reduce the risk of a revert due to a large
  /// string that consumes too much gas when copied to memory.
  function isApprovalEnabled(uint256 actionId, address policyholder) external view returns (bool, bytes32);

  /// @notice Get the quantity of an approval of a policyholder at a specific timestamp.
  /// @param policyholder Address of the policyholder.
  /// @param policyholder The role to check quantity for.
  /// @param timestamp The block number at which to get the approval quantity.
  /// @return The quantity of the policyholder's approval.
  function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint256);

  // -------- When Casting Disapproval --------

  /// @notice Returns true if disapprovals are allowed with this strategy for the given policyholder, false
  /// otherwise. May also return a reason string for why the action is not allowed.
  /// @dev Reason string is limited to `bytes32` to reduce the risk of a revert due to a large
  /// string that consumes too much gas when copied to memory.
  function isDisapprovalEnabled(uint256 actionId, address policyholder) external view returns (bool, bytes32);

  /// @notice Get the quantity of a disapproval of a policyholder at a specific timestamp.
  /// @param policyholder Address of the policyholder.
  /// @param policyholder The role to check quantity for.
  /// @param timestamp The block number at which to get the disapproval quantity.
  /// @return The quantity of the policyholder's disapproval.
  function getDisapprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp)
    external
    view
    returns (uint256);

  // -------- When Queueing --------

  /// @notice Returns the earliest timestamp, in seconds, at which an action can be executed.
  function minExecutionTime(uint256 actionId) external view returns (uint256);

  // -------- When Canceling --------

  /// @notice Get whether an action has eligible to be canceled.
  /// @param actionId id of the action.
  /// @param caller Policyholder initiating the cancelation.
  /// @return Boolean value that is true if the action can be canceled.
  function isActionCancelationValid(uint256 actionId, address caller) external view returns (bool);

  // -------- When Determining Action State --------
  // These are used during casting of approvals and disapprovals, when queueing, and when executing.

  /// @notice Returns true if an action is currently active, false otherwise.
  function isActive(uint256 actionId) external view returns (bool);

  /// @notice Get whether an action has passed the approval process.
  /// @param actionId id of the action.
  /// @return Boolean value that is true if the action has passed the approval process.
  function isActionPassed(uint256 actionId) external view returns (bool);

  /// @notice Get whether an action has been vetoed during the disapproval process.
  /// @param actionId id of the action.
  /// @return Boolean value that is true if the action has been vetoed during the disapproval process.
  function isActionVetoed(uint256 actionId) external view returns (bool);

  /// @notice Returns `true` if the action is expired, false otherwise.
  /// @param actionId id of the action.
  /// @return Boolean value that is true if the action is expired.
  function isActionExpired(uint256 actionId) external view returns (bool);
}
