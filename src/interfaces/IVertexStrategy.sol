// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Vertex Strategy Interface
/// @author Llama (vertex@llama.xyz)
/// @notice This is the interface for Vertex strategies which determine the rules of an action's process.
interface IVertexStrategy {
  /// @notice Initializes a new clone of the strategy.
  /// @dev Order is of WeightByPermissions is critical. Weight is determined by the first specific permission match.
  /// @param config The strategy configuration, encoded as bytes to support differing constructor arguments in
  /// different strategies.
  function initialize(bytes memory config) external;

  /// @notice Returns the approver role.
  function approvalRole() external view returns (uint8);

  /// @notice Returns the disapprover role.
  function disapprovalRole() external view returns (uint8);

  /// @notice Minimum time, in seconds, between queueing and execution of action.
  function queuingPeriod() external view returns (uint256);

  /// @notice Length of approval period in seconds.
  function approvalPeriod() external view returns (uint256);

  /// @notice If false, action be queued before approvalEndTime.
  function isFixedLengthApprovalPeriod() external view returns (bool);

  /// @notice Get whether an action has passed the approval process.
  /// @param actionId id of the action.
  /// @return Boolean value that is true if the action has passed the approval process.
  function isActionPassed(uint256 actionId) external view returns (bool);

  /// @notice Returns `true` if the action is expired, false otherwise.
  /// @param actionId id of the action.
  /// @return Boolean value that is true if the action is expired.
  function isActionExpired(uint256 actionId) external view returns (bool);

  /// @notice Get whether an action has eligible to be canceled.
  /// @param actionId id of the action.
  /// @param caller User initiating the cancelation.
  /// @return Boolean value that is true if the action can be canceled.
  function isActionCancelationValid(uint256 actionId, address caller) external view returns (bool);

  /// @notice Returns `true` if the disapprovals are allowed with this strategy, `false` otherwise.
  function isDisapprovalEnabled() external view returns (bool);

  /// @notice Get the weight of an approval of a policyholder at a specific timestamp.
  /// @param policyholder Address of the policyholder.
  /// @param policyholder The role to check weight for.
  /// @param timestamp The block number at which to get the approval weight.
  /// @return The weight of the policyholder's approval.
  function getApprovalWeightAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint256);

  /// @notice Get the weight of a disapproval of a policyholder at a specific timestamp.
  /// @param policyholder Address of the policyholder.
  /// @param policyholder The role to check weight for.
  /// @param timestamp The block number at which to get the disapproval weight.
  /// @return The weight of the policyholder's disapproval.
  function getDisapprovalWeightAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint256);
}
