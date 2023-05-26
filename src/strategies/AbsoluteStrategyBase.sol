// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {Action, ActionInfo} from "src/lib/Structs.sol";
import {AbsolutePeerReview} from "src/strategies/AbsolutePeerReview.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Absolute Strategy Base Llama Strategy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is a base contract for llama strategies to inherit which has the following properties:
///   - Approval/disapproval thresholds are specified as absolute numbers.
abstract contract AbsoluteStrategyBase is ILlamaStrategy, Initializable {
  // ======================================
  // ============== Structs ===============
  // ======================================

  struct Config {
    uint64 approvalPeriod; // The length of time of the approval period.
    uint64 queuingPeriod; // The length of time of the queuing period. The disapproval period is the queuing period when
      // enabled.
    uint64 expirationPeriod; // The length of time an action can be executed before it expires.
    uint128 minApprovals; // Minimum number of total approval quantity.
    uint128 minDisapprovals; // Minimum number of total disapproval quantity.
    bool isFixedLengthApprovalPeriod; // Determines if an action be queued before approvalEndTime.
    uint8 approvalRole; // Anyone with this role can cast approval of an action.
    uint8 disapprovalRole; // Anyone with this role can cast disapproval of an action.
    uint8[] forceApprovalRoles; // Anyone with this role can single-handedly approve an action.
    uint8[] forceDisapprovalRoles; // Anyone with this role can single-handedly disapprove an action.
  }
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  /// @dev The action cannot be canceled if it's already in a terminal state.
  /// @param currentState The current state of the action.
  error CannotCancelInState(ActionState currentState);

  /// @dev The strategy has disabled disapprovals.
  error DisapprovalDisabled();

  /// @dev The action cannot be created because approval quorum is not possible.
  error InsufficientApprovalQuantity();

  /// @dev The action cannot be created because disapproval quorum is not possible.
  error InsufficientDisapprovalQuantity();

  /// @dev The action cannot be created because the quantity of approvals required are greater than the role supply.
  error InvalidMinApprovals(uint256 minApprovals);

  /// @dev The role is not eligible to participate in this strategy in the specified way.
  /// @param role The role being used.
  error InvalidRole(uint8 role);

  /// @dev Only the action creator can cancel an action.
  error OnlyActionCreator();

  /// @dev The action cannot be created if the approval or disapproval supply is 0.
  /// @param role The role being used.
  error RoleHasZeroSupply(uint8 role);

  /// @dev The provided `role` is not initialized by the `LlamaPolicy`.
  /// @param role The role being used.
  error RoleNotInitialized(uint8 role);

  // ========================
  // ======== Events ========
  // ========================

  event ForceApprovalRoleAdded(uint8 role);
  event ForceDisapprovalRoleAdded(uint8 role);
  event StrategyCreated(LlamaCore llamaCore, LlamaPolicy policy);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  // -------- Interface Requirements --------

  /// @inheritdoc ILlamaStrategy
  LlamaCore public llamaCore;

  /// @inheritdoc ILlamaStrategy
  LlamaPolicy public policy;

  // -------- Strategy Configuration --------

  /// @notice Equivalent to 100%, but in basis points.
  uint256 internal constant ONE_HUNDRED_IN_BPS = 10_000;

  /// @notice If false, action be queued before approvalEndTime.
  bool public isFixedLengthApprovalPeriod;

  /// @notice Length of approval period in seconds.
  uint64 public approvalPeriod;

  /// @notice Minimum time, in seconds, between queueing and execution of action.
  uint64 public queuingPeriod;

  /// @notice Time, in seconds, after executionTime that action can be executed before permanently expiring.
  uint64 public expirationPeriod;

  /// @notice Minimum total quantity of approvals for the action to be queued.
  /// @dev We use a `uint128` here since quantities are stored as `uint128` in the policy.
  uint128 public minApprovals;

  /// @notice Minimum total quantity of disapprovals for the action to be canceled.
  /// @dev We use a `uint128` here since quantities are stored as `uint128` in the policy.
  uint128 public minDisapprovals;

  /// @notice The role that can approve an action.
  uint8 public approvalRole;

  /// @notice The role that can disapprove an action.
  uint8 public disapprovalRole;

  /// @notice Mapping of roles that can force an action to be approved.
  mapping(uint8 => bool) public forceApprovalRole;

  /// @notice Mapping of roles that can force an action to be disapproved.
  mapping(uint8 => bool) public forceDisapprovalRole;

  // =============================
  // ======== Constructor ========
  // =============================

  constructor() {
    _disableInitializers();
  }

  // ==========================================
  // ======== Interface Implementation ========
  // ==========================================

  // -------- At Strategy Creation --------

  /// @inheritdoc ILlamaStrategy
  function initialize(bytes memory config) external initializer {
    AbsolutePeerReview.Config memory strategyConfig = abi.decode(config, (AbsolutePeerReview.Config));
    llamaCore = LlamaCore(msg.sender);
    policy = llamaCore.policy();
    queuingPeriod = strategyConfig.queuingPeriod;
    expirationPeriod = strategyConfig.expirationPeriod;
    isFixedLengthApprovalPeriod = strategyConfig.isFixedLengthApprovalPeriod;
    approvalPeriod = strategyConfig.approvalPeriod;

    if (strategyConfig.minApprovals > policy.getRoleSupplyAsQuantitySum(strategyConfig.approvalRole)) {
      revert InvalidMinApprovals(strategyConfig.minApprovals);
    }

    minApprovals = strategyConfig.minApprovals;
    minDisapprovals = strategyConfig.minDisapprovals;

    uint8 numRoles = policy.numRoles();

    approvalRole = strategyConfig.approvalRole;
    _assertValidRole(strategyConfig.approvalRole, numRoles);

    disapprovalRole = strategyConfig.disapprovalRole;
    _assertValidRole(strategyConfig.disapprovalRole, numRoles);

    for (uint256 i = 0; i < strategyConfig.forceApprovalRoles.length; i = LlamaUtils.uncheckedIncrement(i)) {
      uint8 role = strategyConfig.forceApprovalRoles[i];
      if (role == 0) revert InvalidRole(0);
      _assertValidRole(role, numRoles);
      forceApprovalRole[role] = true;
      emit ForceApprovalRoleAdded(role);
    }

    for (uint256 i = 0; i < strategyConfig.forceDisapprovalRoles.length; i = LlamaUtils.uncheckedIncrement(i)) {
      uint8 role = strategyConfig.forceDisapprovalRoles[i];
      if (role == 0) revert InvalidRole(0);
      _assertValidRole(role, numRoles);
      forceDisapprovalRole[role] = true;
      emit ForceDisapprovalRoleAdded(role);
    }

    emit StrategyCreated(llamaCore, policy);
  }

  // -------- At Action Creation --------

  /// @inheritdoc ILlamaStrategy
  function validateActionCreation(ActionInfo calldata actionInfo) external view virtual;

  // -------- When Casting Approval --------

  /// @inheritdoc ILlamaStrategy
  function isApprovalEnabled(ActionInfo calldata actionInfo, address policyholder, uint8 role) external view virtual;

  /// @inheritdoc ILlamaStrategy
  function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint128) {
    if (role != approvalRole && !forceApprovalRole[role]) return 0;
    uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    return quantity > 0 && forceApprovalRole[role] ? type(uint128).max : quantity;
  }

  // -------- When Casting Disapproval --------

  /// @inheritdoc ILlamaStrategy
  function isDisapprovalEnabled(ActionInfo calldata actionInfo, address policyholder, uint8 role) external view virtual;

  /// @inheritdoc ILlamaStrategy
  function getDisapprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp)
    external
    view
    returns (uint128)
  {
    if (role != disapprovalRole && !forceDisapprovalRole[role]) return 0;
    uint128 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    return quantity > 0 && forceDisapprovalRole[role] ? type(uint128).max : quantity;
  }

  // -------- When Queueing --------

  /// @inheritdoc ILlamaStrategy
  function minExecutionTime(ActionInfo calldata) external view returns (uint64) {
    return LlamaUtils.toUint64(block.timestamp + queuingPeriod);
  }

  // -------- When Canceling --------

  /// @inheritdoc ILlamaStrategy
  function validateActionCancelation(ActionInfo calldata actionInfo, address caller) external view {
    // The rules for cancelation are:
    //   1. The action cannot be canceled if it's state is any of the following: Executed, Canceled,
    //      Expired, Failed.
    //   2. For all other states (Active, Approved, Queued) the action can be canceled if the caller
    //      is the action creator.

    // Check 1.
    ActionState state = llamaCore.getActionState(actionInfo);
    if (
      state == ActionState.Executed || state == ActionState.Canceled || state == ActionState.Expired
        || state == ActionState.Failed
    ) revert CannotCancelInState(state);

    // Check 2.
    if (caller != actionInfo.creator) revert OnlyActionCreator();
  }

  // -------- When Determining Action State --------

  /// @inheritdoc ILlamaStrategy
  function isActive(ActionInfo calldata actionInfo) external view returns (bool) {
    return
      block.timestamp <= approvalEndTime(actionInfo) && (isFixedLengthApprovalPeriod || !isActionApproved(actionInfo));
  }

  /// @inheritdoc ILlamaStrategy
  function isActionApproved(ActionInfo calldata actionInfo) public view returns (bool) {
    Action memory action = llamaCore.getAction(actionInfo.id);
    return action.totalApprovals >= minApprovals;
  }

  /// @inheritdoc ILlamaStrategy
  function isActionDisapproved(ActionInfo calldata actionInfo) public view returns (bool) {
    Action memory action = llamaCore.getAction(actionInfo.id);
    return action.totalDisapprovals >= minDisapprovals;
  }

  /// @inheritdoc ILlamaStrategy
  function isActionExpired(ActionInfo calldata actionInfo) external view returns (bool) {
    Action memory action = llamaCore.getAction(actionInfo.id);
    return block.timestamp > action.minExecutionTime + expirationPeriod;
  }

  // ========================================
  // ======== Other Public Functions ========
  // ========================================

  /// @notice Returns the timestamp at which the approval period ends.
  function approvalEndTime(ActionInfo calldata actionInfo) public view returns (uint256) {
    Action memory action = llamaCore.getAction(actionInfo.id);
    return action.creationTime + approvalPeriod;
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Reverts if the given `role` is greater than `numRoles`.
  function _assertValidRole(uint8 role, uint8 numRoles) internal pure {
    if (role > numRoles) revert RoleNotInitialized(role);
  }
}
