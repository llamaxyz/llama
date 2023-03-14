// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCore} from "src/interfaces/IVertexCore.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {Strategy} from "src/lib/Structs.sol";

interface IVertexStrategy {
  event ForceApprovalRoleAdded(bytes32 role);
  event ForceDisapprovalRoleAdded(bytes32 role);
  event NewStrategyCreated(IVertexCore vertex, VertexPolicy policy);

  error NoPolicy();

  /// @notice Initializes a new VertexStrategy clone.
  /// @param strategyConfig The strategy configuration.
  /// @param policy The policy contract.
  /// @param vertex The VertexCore contract.
  function initialize(Strategy memory strategyConfig, VertexPolicy policy, IVertexCore vertex) external;

  /// @notice Get whether an action has passed the approval process.
  /// @param actionId id of the action.
  /// @return Boolean value that is true if the action has passed the approval process.
  function isActionPassed(uint256 actionId) external view returns (bool);

  /// @notice Get whether an action has eligible to be canceled.
  /// @param actionId id of the action.
  /// @return Boolean value that is true if the action can be canceled.
  function isActionCancelationValid(uint256 actionId) external view returns (bool);

  /// @notice Get the weight of an approval of a policyholder at a specific timestamp.
  /// @param policyholder Address of the policyholder.
  /// @param policyholder The role to check weight for.
  /// @param timestamp The block number at which to get the approval weight.
  /// @return The weight of the policyholder's approval.
  function getApprovalWeightAt(address policyholder, bytes32 role, uint256 timestamp) external view returns (uint256);

  /// @notice Get the weight of a disapproval of a policyholder at a specific timestamp.
  /// @param policyholder Address of the policyholder.
  /// @param policyholder The role to check weight for.
  /// @param timestamp The block number at which to get the disapproval weight.
  /// @return The weight of the policyholder's disapproval.
  function getDisapprovalWeightAt(address policyholder, bytes32 role, uint256 timestamp)
    external
    view
    returns (uint256);

  /// @notice Determine the minimum weight needed for an action to reach quorum.
  /// @param supply Total number of policyholders eligible for participation.
  /// @param minPercentage Minimum percentage needed to reach quorum.
  /// @return The total weight needed to reach quorum.
  function getMinimumAmountNeeded(uint256 supply, uint256 minPercentage) external pure returns (uint256);
}
