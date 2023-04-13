// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ActionState} from "src/lib/Enums.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {Action, Strategy} from "src/lib/Structs.sol";

/// @title A strategy definition of a Vertex system.
/// @author Llama (vertex@llama.xyz)
/// @notice This is the template for Vertex strategies which determine the rules of an action's process.
contract VertexStrategy is Initializable {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error InvalidMinApprovalPct(uint256 minApprovalPct);
  error InvalidPermissionId();
  error NoPolicy();
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

  /// @notice Can action be queued before approvalEndTime.
  bool public isFixedLengthApprovalPeriod;

  /// @notice The strategy's Vertex system.
  VertexCore public vertex;

  /// @notice Policy NFT for this Vertex system.
  VertexPolicy public policy;

  /// @notice Minimum time, in seconds, between queueing and execution of action.
  uint256 public queuingPeriod;

  /// @notice Time, in seconds,  after executionTime that action can be executed before permanently expiring.
  uint256 public expirationPeriod;

  /// @notice Length of approval period in seconds.
  uint256 public approvalPeriod;

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

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor() initializer {}

  /// @notice Initializes a new VertexStrategy clone.
  /// @dev Order is of WeightByPermissions is critical. Weight is determined by the first specific permission match.
  /// @param strategyConfig The strategy configuration.
  function initialize(Strategy memory strategyConfig) external initializer {
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

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Get whether an action has passed the approval process.
  /// @param actionId id of the action.
  /// @return Boolean value that is true if the action has passed the approval process.
  function isActionPassed(uint256 actionId) external view returns (bool) {
    Action memory action = vertex.getAction(actionId);
    return action.totalApprovals >= getMinimumAmountNeeded(action.approvalPolicySupply, minApprovalPct);
  }

  /// @notice Returns `true` if the action is expired, false otherwise.
  /// @param actionId id of the action.
  /// @return Boolean value that is true if the action is expired.
  function isActionExpired(uint256 actionId) external view returns (bool) {
    Action memory action = vertex.getAction(actionId);
    return action.minExecutionTime + expirationPeriod < block.timestamp;
  }

  /// @notice Get whether an action has eligible to be canceled.
  /// @param actionId id of the action.
  /// @param caller User initiating the cancelation.
  /// @return Boolean value that is true if the action can be canceled.
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
    return action.totalDisapprovals >= getMinimumAmountNeeded(action.disapprovalPolicySupply, minDisapprovalPct);
  }

  /// @notice Returns `true` if the approvals are allowed with this strategy, `false` otherwise.
  function isApprovalEnabled() external view returns (bool) {
    return minApprovalPct != 0;
  }

  /// @notice Returns `true` if the disapprovals are allowed with this strategy, `false` otherwise.
  function isDisapprovalEnabled() external view returns (bool) {
    return minDisapprovalPct <= ONE_HUNDRED_IN_BPS;
  }

  /// @notice Get the weight of an approval of a policyholder at a specific timestamp.
  /// @param policyholder Address of the policyholder.
  /// @param policyholder The role to check weight for.
  /// @param timestamp The block number at which to get the approval weight.
  /// @return The weight of the policyholder's approval.
  function getApprovalWeightAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint256) {
    uint256 weight = policy.getPastWeight(policyholder, role, timestamp);
    return weight > 0 && forceApprovalRole[role] ? type(uint256).max : weight;
  }

  /// @notice Get the weight of a disapproval of a policyholder at a specific timestamp.
  /// @param policyholder Address of the policyholder.
  /// @param policyholder The role to check weight for.
  /// @param timestamp The block number at which to get the disapproval weight.
  /// @return The weight of the policyholder's disapproval.
  function getDisapprovalWeightAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint256) {
    uint256 weight = policy.getPastWeight(policyholder, role, timestamp);
    return weight > 0 && forceDisapprovalRole[role] ? type(uint256).max : weight;
  }

  /// @notice Determine the minimum weight needed for an action to reach quorum.
  /// @param supply Total number of policyholders eligible for participation.
  /// @param minPct Minimum percentage needed to reach quorum.
  /// @return The total weight needed to reach quorum.
  function getMinimumAmountNeeded(uint256 supply, uint256 minPct) public pure returns (uint256) {
    // Rounding Up
    return FixedPointMathLib.mulDivUp(supply, minPct, ONE_HUNDRED_IN_BPS);
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Reverts if the given `role` is greater than `numRoles`.
  function _assertValidRole(uint8 role, uint8 numRoles) internal pure {
    if (role > numRoles) revert RoleNotInitialized(role);
  }

  function _uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }
}
