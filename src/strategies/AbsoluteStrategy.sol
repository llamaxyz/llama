// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, AbsoluteStrategyConfig} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Absolute Llama Strategy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is a llama strategy which has the following properties:
///   - Approval/disapproval thresholds are specified as absolute numbers.
///   - Action creators are not allowed to cast approvals or disapprovals on their own actions,
///     regardless of the roles they hold.
contract AbsoluteStrategy is ILlamaStrategy, Initializable {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error InvalidMinApprovals(uint256 minApprovals);
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
  uint256 public approvalPeriod;

  /// @notice Minimum time, in seconds, between queueing and execution of action.
  uint256 public queuingPeriod;

  /// @notice Time, in seconds, after executionTime that action can be executed before permanently expiring.
  uint256 public expirationPeriod;

  /// @notice Minimum total quantity of approvals for the action to be queued
  uint256 public minApprovals;

  /// @notice Minimum total quantity of disapprovals for the action to be canceled
  uint256 public minDisapprovals;

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

  // =============================
  // ======== Constructor ========
  // =============================

  constructor() initializer {}

  // ==========================================
  // ======== Interface Implementation ========
  // ==========================================

  // -------- At Strategy Creation --------

  /// @inheritdoc ILlamaStrategy
  function initialize(bytes memory config) external initializer {
    AbsoluteStrategyConfig memory strategyConfig = abi.decode(config, (AbsoluteStrategyConfig));
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

    emit StrategyCreated(llamaCore, policy);
  }

  // -------- At Action Creation --------

  /// @inheritdoc ILlamaStrategy
  function validateActionCreation(uint256 actionId) external returns (bool, bytes32) {
    uint256 approvalPolicySupply = policy.getRoleSupplyAsQuantitySum(approvalRole);
    if (approvalPolicySupply == 0) return (false, "No approval supply");
    uint256 disapprovalPolicySupply = policy.getRoleSupplyAsQuantitySum(disapprovalRole);
    if (disapprovalPolicySupply == 0) return (false, "No disapproval supply");

    // If the action creator has the approval or disapproval role, reduce the total supply by 1.
    Action memory action = llamaCore.getAction(actionId);
    unchecked {
      // Safety: We check the supply of the role above, and this supply is inclusive of the quantity
      // held by the action creator. Therefore we can reduce the total supply by the quantity held by
      // the action creator without overflow, since a policyholder can never have a quantity greater than
      // the total supply.
      uint256 actionCreatorApprovalRoleQty = policy.getQuantity(action.creator, approvalRole);
      approvalPolicySupply -= actionCreatorApprovalRoleQty;
      uint256 actionCreatorDisapprovalRoleQty = policy.getQuantity(action.creator, disapprovalRole);
      disapprovalPolicySupply -= actionCreatorDisapprovalRoleQty;
    }

    // Save off the supplies to use for checking quorum.
    actionApprovalSupply[actionId] = approvalPolicySupply;
    actionDisapprovalSupply[actionId] = disapprovalPolicySupply;
    return (true, "");
  }

  // -------- When Casting Approval --------

  /// @inheritdoc ILlamaStrategy
  function isApprovalEnabled(uint256 actionId, address policyholder) external view returns (bool, bytes32) {
    Action memory action = llamaCore.getAction(actionId);
    if (action.creator == policyholder) return (false, "Action creator cannot approve");
    return (true, "");
  }

  /// @inheritdoc ILlamaStrategy
  function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint256) {
    uint256 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    return quantity > 0 && forceApprovalRole[role] ? type(uint256).max : quantity;
  }

  // -------- When Casting Disapproval --------

  /// @inheritdoc ILlamaStrategy
  function isDisapprovalEnabled(uint256 actionId, address policyholder) external view returns (bool, bytes32) {
    Action memory action = llamaCore.getAction(actionId);
    if (action.creator == policyholder) return (false, "Action creator cannot disapprove");
    if (minDisapprovals > actionDisapprovalSupply[actionId]) return (false, "Disapproval disabled");
    return (true, "");
  }

  /// @inheritdoc ILlamaStrategy
  function getDisapprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp)
    external
    view
    returns (uint256)
  {
    uint256 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    return quantity > 0 && forceDisapprovalRole[role] ? type(uint256).max : quantity;
  }

  // -------- When Queueing --------

  /// @inheritdoc ILlamaStrategy
  function minExecutionTime(uint256) external view returns (uint256) {
    return block.timestamp + queuingPeriod;
  }

  // -------- When Canceling --------

  /// @inheritdoc ILlamaStrategy
  function isActionCancelationValid(uint256 actionId, address caller) external view returns (bool) {
    // The rules for cancelation are:
    //   1. The action cannot be canceled if it's state is any of the following: Executed, Canceled, Expired, Failed.
    //   2. For all other states (Active, Approved, Queued) the action can be canceled if:
    //        a. The caller is the action creator.
    //        b. The action is Queued, but the number of disapprovals is >= the disapproval threshold.

    // Check 1.
    ActionState state = llamaCore.getActionState(actionId);
    if (
      state == ActionState.Executed || state == ActionState.Canceled || state == ActionState.Expired
        || state == ActionState.Failed
    ) return false;

    // Check 2a.
    Action memory action = llamaCore.getAction(actionId);
    if (caller == action.creator) return true;

    // Check 2b.
    return action.totalDisapprovals >= minDisapprovals;
  }

  // -------- When Determining Action State --------

  /// @inheritdoc ILlamaStrategy
  function isActive(uint256 actionId) external view returns (bool) {
    return block.timestamp <= approvalEndTime(actionId) && (isFixedLengthApprovalPeriod || !isActionPassed(actionId));
  }

  /// @inheritdoc ILlamaStrategy
  function isActionPassed(uint256 actionId) public view returns (bool) {
    Action memory action = llamaCore.getAction(actionId);
    return action.totalApprovals >= minApprovals;
  }

  /// @inheritdoc ILlamaStrategy
  function isActionExpired(uint256 actionId) external view returns (bool) {
    Action memory action = llamaCore.getAction(actionId);
    return block.timestamp > action.minExecutionTime + expirationPeriod;
  }

  // ========================================
  // ======== Other Public Functions ========
  // ========================================

  /// @notice Returns the timestamp at which the approval period ends.
  function approvalEndTime(uint256 actionId) public view returns (uint256) {
    Action memory action = llamaCore.getAction(actionId);
    return action.creationTime + approvalPeriod;
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

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
