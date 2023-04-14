// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {Action, Strategy} from "src/lib/Structs.sol";

/// @title Vertex Strategy
/// @author Llama (vertex@llama.xyz)
/// @notice This is the default vertex strategy which has the following properties:
///   - Approval/disapproval thresholds are specified as percentages of total supply.
///   - Action creators are not allowed to vote on their own actions, regardless of the roles they hold.
contract VertexStrategy is IVertexStrategy, Initializable {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error InvalidMinApprovalPct(uint256 minApprovalPct);
  error RoleNotInitialized(uint8 role);

  // ========================
  // ======== Events ========
  // ========================

  event ForceApprovalRoleAdded(uint8 role);
  event ForceDisapprovalRoleAdded(uint8 role);
  event NewStrategyCreated(VertexCore vertex, VertexPolicy policy);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================
  /// @notice Equivalent to 100%, but in basis points.
  uint256 internal constant ONE_HUNDRED_IN_BPS = 10_000;

  /// @notice If false, action be queued before approvalEndTime.
  bool public isFixedLengthApprovalPeriod;

  /// @notice The strategy's Vertex system.
  VertexCore public vertex;

  /// @notice Policy NFT for this Vertex system.
  VertexPolicy public policy;

  /// @notice Length of approval period in seconds.
  uint256 public approvalPeriod;

  /// @notice Minimum time, in seconds, between queueing and execution of action.
  uint256 public queuingPeriod;

  /// @notice Time, in seconds, after executionTime that action can be executed before permanently expiring.
  uint256 public expirationPeriod;

  /// @notice Minimum percentage of `totalApprovalWeight / totalApprovalSupplyAtCreationTime` required for the
  /// action to be queued. In bps, where 100_00 == 100%.
  uint256 public minApprovalPct;

  /// @notice Minimum percentage of `totalDisapprovalWeight / totalDisapprovalSupplyAtCreationTime` required of the
  /// action for it to be canceled. In bps, 100_00 == 100%.
  uint256 public minDisapprovalPct;

  /// @notice The role that can approve an action.
  uint8 public approvalRole;

  /// @notice The role that can disapprove an action.
  uint8 public disapprovalRole;

  /// @notice Mapping of roles that can force an action to be approved.
  mapping(uint8 => bool) public forceApprovalRole;

  /// @notice Mapping of roles that can force an action to be disapproved.
  mapping(uint8 => bool) public forceDisapprovalRole;

  /// @notice Mapping of action ID to the supply of the approval role at the time the action was created.
  mapping(uint256 => uint256) public actionApprovalSupply;

  /// @notice Mapping of action ID to the supply of the disapproval role at the time the action was created.
  mapping(uint256 => uint256) public actionDisapprovalSupply;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor() initializer {}

  /// @inheritdoc IVertexStrategy
  function initialize(bytes memory config) external initializer {
    Strategy memory strategyConfig = abi.decode(config, (Strategy));
    vertex = VertexCore(msg.sender);
    policy = vertex.policy();
    queuingPeriod = strategyConfig.queuingPeriod;
    expirationPeriod = strategyConfig.expirationPeriod;
    isFixedLengthApprovalPeriod = strategyConfig.isFixedLengthApprovalPeriod;
    approvalPeriod = strategyConfig.approvalPeriod;

    if (strategyConfig.minApprovalPct > ONE_HUNDRED_IN_BPS) revert InvalidMinApprovalPct(minApprovalPct);
    minApprovalPct = strategyConfig.minApprovalPct;
    minDisapprovalPct = strategyConfig.minDisapprovalPct;

    uint8 numRoles = policy.numRoles();

    approvalRole = strategyConfig.approvalRole;
    _assertValidRole(approvalRole, numRoles);

    disapprovalRole = strategyConfig.disapprovalRole;
    _assertValidRole(disapprovalRole, numRoles);

    for (uint256 i; i < strategyConfig.forceApprovalRoles.length; i = _uncheckedIncrement(i)) {
      uint8 role = strategyConfig.forceApprovalRoles[i];
      _assertValidRole(role, numRoles);
      forceApprovalRole[role] = true;
      emit ForceApprovalRoleAdded(role);
    }

    for (uint256 i; i < strategyConfig.forceDisapprovalRoles.length; i = _uncheckedIncrement(i)) {
      uint8 role = strategyConfig.forceDisapprovalRoles[i];
      _assertValidRole(role, numRoles);
      forceDisapprovalRole[role] = true;
      emit ForceDisapprovalRoleAdded(role);
    }

    emit NewStrategyCreated(vertex, policy);
  }

  // ==========================================
  // ======== Interface Implementation ========
  // ==========================================

  /// @inheritdoc IVertexStrategy
  function validateActionCreation(uint256 actionId) external returns (bool, bytes32) {
    uint256 approvalPolicySupply = policy.getSupply(approvalRole);
    if (approvalPolicySupply == 0) return (false, "No approval supply");
    uint256 disapprovalPolicySupply = policy.getSupply(disapprovalRole);
    if (disapprovalPolicySupply == 0) return (false, "No disapproval supply");

    // If the action creator has the approval or disapproval role, reduce the total supply by 1.
    Action memory action = vertex.getAction(actionId);
    unchecked {
      // Safety: If either supply was zero, we would have returned early above. Therefore we know
      // both of the supply values are at least 1, and therefore we can safely subtract 1 without
      // worrying about overflow.
      if (policy.hasRole(action.creator, approvalRole)) approvalPolicySupply -= 1;
      if (policy.hasRole(action.creator, disapprovalRole)) disapprovalPolicySupply -= 1;
    }

    // Save off the supplies to use for checking quorum.
    actionApprovalSupply[actionId] = approvalPolicySupply;
    actionDisapprovalSupply[actionId] = disapprovalPolicySupply;
    return (true, "");
  }

  /// @inheritdoc IVertexStrategy
  function minExecutionTime(uint256) external view returns (uint256) {
    return block.timestamp + queuingPeriod;
  }

  /// @inheritdoc IVertexStrategy
  function isActive(uint256 actionId) external view returns (bool) {
    return block.timestamp < approvalEndTime(actionId) && (isFixedLengthApprovalPeriod || !isActionPassed(actionId));
  }

  /// @inheritdoc IVertexStrategy
  function isActionPassed(uint256 actionId) public view returns (bool) {
    Action memory action = vertex.getAction(actionId);
    return action.totalApprovals >= _getMinimumAmountNeeded(actionApprovalSupply[actionId], minApprovalPct);
  }

  /// @inheritdoc IVertexStrategy
  function isActionExpired(uint256 actionId) external view returns (bool) {
    Action memory action = vertex.getAction(actionId);
    return action.minExecutionTime + expirationPeriod < block.timestamp;
  }

  /// @inheritdoc IVertexStrategy
  function isActionCancelationValid(uint256 actionId, address caller) external view returns (bool) {
    // The rules for cancelation are:
    //   1. The action cannot be canceled if it's state is any of the following: Executed, Canceled, Expired, Failed.
    //   2. For all other states (Active, Approved, Queued) the action can be canceled if:
    //        a. The caller is the action creator.
    //        b. The action is Queued, but the number of disapprovals is >= the disapproval threshold.

    // Check 1.
    ActionState state = vertex.getActionState(actionId);
    if (
      state == ActionState.Executed || state == ActionState.Canceled || state == ActionState.Expired
        || state == ActionState.Failed
    ) return false;

    // Check 2a.
    Action memory action = vertex.getAction(actionId);
    if (caller == action.creator) return true;

    // Check 2b.
    return action.totalDisapprovals >= _getMinimumAmountNeeded(actionDisapprovalSupply[actionId], minDisapprovalPct);
  }

  /// @inheritdoc IVertexStrategy
  function isApprovalEnabled(uint256 actionId, address policyholder) external view returns (bool, bytes32) {
    Action memory action = vertex.getAction(actionId);
    if (action.creator == policyholder) return (false, "Action creator cannot approve");
    return (true, "");
  }

  /// @inheritdoc IVertexStrategy
  function isDisapprovalEnabled(uint256 actionId, address policyholder) external view returns (bool, bytes32) {
    Action memory action = vertex.getAction(actionId);
    if (action.creator == policyholder) return (false, "Action creator cannot disapprove");
    if (minDisapprovalPct > ONE_HUNDRED_IN_BPS) return (false, "Disapproval disabled");
    return (true, "");
  }

  /// @inheritdoc IVertexStrategy
  function getApprovalWeightAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint256) {
    uint256 weight = policy.getPastWeight(policyholder, role, timestamp);
    return weight > 0 && forceApprovalRole[role] ? type(uint256).max : weight;
  }

  /// @inheritdoc IVertexStrategy
  function getDisapprovalWeightAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint256) {
    uint256 weight = policy.getPastWeight(policyholder, role, timestamp);
    return weight > 0 && forceDisapprovalRole[role] ? type(uint256).max : weight;
  }

  // ========================================
  // ======== Other Public Functions ========
  // ========================================

  /// @notice Returns the timestamp at which the approval period ends.
  function approvalEndTime(uint256 actionId) public view returns (uint256) {
    Action memory action = vertex.getAction(actionId);
    return action.creationTime + approvalPeriod;
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Determine the minimum weight needed for an action to reach quorum.
  /// @param supply Total number of policyholders eligible for participation.
  /// @param minPct Minimum percentage needed to reach quorum.
  /// @return The total weight needed to reach quorum.
  function _getMinimumAmountNeeded(uint256 supply, uint256 minPct) internal pure returns (uint256) {
    // Rounding Up
    return FixedPointMathLib.mulDivUp(supply, minPct, ONE_HUNDRED_IN_BPS);
  }

  /// @dev Reverts if the given `role` is greater than `numRoles`.
  function _assertValidRole(uint8 role, uint8 numRoles) internal pure {
    if (role > numRoles) revert RoleNotInitialized(role);
  }

  /// @dev Increments `i` by 1, but does not check for overflow.
  function _uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }
}
