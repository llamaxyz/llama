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
///   - Action creators are allowed to vote on their own actions, assuming they hold the appropriate role.
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

  // -------- Interface Requirements --------

  /// @inheritdoc IVertexStrategy
  uint256 public queuingPeriod;

  /// @inheritdoc IVertexStrategy
  uint256 public approvalPeriod;

  /// @inheritdoc IVertexStrategy
  bool public isFixedLengthApprovalPeriod;

  // -------- Specific to this Strategy --------

  /// @notice The strategy's Vertex system.
  VertexCore public vertex;

  /// @notice Policy NFT for this Vertex system.
  VertexPolicy public policy;

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
  function isActionPassed(uint256 actionId) external view returns (bool) {
    Action memory action = vertex.getAction(actionId);
    return action.totalApprovals >= getMinimumAmountNeeded(action.approvalPolicySupply, minApprovalPct);
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
    return action.totalDisapprovals >= getMinimumAmountNeeded(action.disapprovalPolicySupply, minDisapprovalPct);
  }

  /// @inheritdoc IVertexStrategy
  function isDisapprovalEnabled() external view returns (bool) {
    return minDisapprovalPct <= ONE_HUNDRED_IN_BPS;
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

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Determine the minimum weight needed for an action to reach quorum.
  /// @param supply Total number of policyholders eligible for participation.
  /// @param minPct Minimum percentage needed to reach quorum.
  /// @return The total weight needed to reach quorum.
  function getMinimumAmountNeeded(uint256 supply, uint256 minPct) internal pure returns (uint256) {
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
