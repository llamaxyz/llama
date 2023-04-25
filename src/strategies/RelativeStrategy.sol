// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, ActionInfo, RelativeStrategyConfig} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Relative Llama Strategy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the default llama strategy which has the following properties:
///   - Approval/disapproval thresholds are specified as percentages of total supply.
///   - Action creators are not allowed to cast approvals or disapprovals on their own actions,
///     regardless of the roles they hold.
contract RelativeStrategy is ILlamaStrategy, Initializable {
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

  /// @notice Minimum percentage of `totalApprovalQuantity / totalApprovalSupplyAtCreationTime` required for the
  /// action to be queued. In bps, where 10,000 == 100%.
  /// @dev We use `uint16` because it's the smallest integer type that can hold 10,000.
  uint16 public minApprovalPct;

  /// @notice Minimum percentage of `totalDisapprovalQuantity / totalDisapprovalSupplyAtCreationTime` required of the
  /// action for it to be canceled. In bps, 10,000 == 100%.
  /// @dev We use `uint16` because it's the smallest integer type that can hold 10,000.
  uint16 public minDisapprovalPct;

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
    RelativeStrategyConfig memory strategyConfig = abi.decode(config, (RelativeStrategyConfig));
    llamaCore = LlamaCore(msg.sender);
    policy = llamaCore.policy();
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

    for (uint256 i = 0; i < strategyConfig.forceApprovalRoles.length; i = _uncheckedIncrement(i)) {
      uint8 role = strategyConfig.forceApprovalRoles[i];
      _assertValidRole(role, numRoles);
      forceApprovalRole[role] = true;
      emit ForceApprovalRoleAdded(role);
    }

    for (uint256 i = 0; i < strategyConfig.forceDisapprovalRoles.length; i = _uncheckedIncrement(i)) {
      uint8 role = strategyConfig.forceDisapprovalRoles[i];
      _assertValidRole(role, numRoles);
      forceDisapprovalRole[role] = true;
      emit ForceDisapprovalRoleAdded(role);
    }

    emit StrategyCreated(llamaCore, policy);
  }

  // -------- At Action Creation --------

  /// @inheritdoc ILlamaStrategy
  function validateActionCreation(ActionInfo calldata actionInfo) external returns (bool, bytes32) {
    uint256 approvalPolicySupply = policy.getRoleSupplyAsNumberOfHolders(approvalRole);
    if (approvalPolicySupply == 0) return (false, "No approval supply");
    uint256 disapprovalPolicySupply = policy.getRoleSupplyAsNumberOfHolders(disapprovalRole);
    if (disapprovalPolicySupply == 0) return (false, "No disapproval supply");

    // If the action creator has the approval or disapproval role, reduce the total supply by 1.
    unchecked {
      // Safety: We check the supply of the role above, and this supply is inclusive of the quantity
      // held by the action creator. Therefore we can reduce the total supply by the quantity held by
      // the action creator without overflow, since a policyholder can never have a quantity greater than
      // the total supply.
      uint256 actionCreatorApprovalRoleQty = policy.getQuantity(actionInfo.creator, approvalRole);
      approvalPolicySupply -= actionCreatorApprovalRoleQty;
      uint256 actionCreatorDisapprovalRoleQty = policy.getQuantity(actionInfo.creator, disapprovalRole);
      disapprovalPolicySupply -= actionCreatorDisapprovalRoleQty;
    }

    // Save off the supplies to use for checking quorum.
    actionApprovalSupply[actionInfo.id] = approvalPolicySupply;
    actionDisapprovalSupply[actionInfo.id] = disapprovalPolicySupply;
    return (true, "");
  }

  // -------- When Casting Approval --------

  /// @inheritdoc ILlamaStrategy
  function isApprovalEnabled(ActionInfo calldata actionInfo, address policyholder)
    external
    pure
    returns (bool, bytes32)
  {
    if (actionInfo.creator == policyholder) return (false, "Action creator cannot approve");
    return (true, "");
  }

  /// @inheritdoc ILlamaStrategy
  function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint256) {
    uint256 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    return quantity > 0 && forceApprovalRole[role] ? type(uint256).max : quantity;
  }

  // -------- When Casting Disapproval --------

  /// @inheritdoc ILlamaStrategy
  function isDisapprovalEnabled(ActionInfo calldata actionInfo, address policyholder)
    external
    view
    returns (bool, bytes32)
  {
    if (actionInfo.creator == policyholder) return (false, "Action creator cannot disapprove");
    if (minDisapprovalPct > ONE_HUNDRED_IN_BPS) return (false, "Disapproval disabled");
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
  function minExecutionTime(ActionInfo calldata) external view returns (uint256) {
    return block.timestamp + queuingPeriod;
  }

  // -------- When Canceling --------

  /// @inheritdoc ILlamaStrategy
  function isActionCancelationValid(ActionInfo calldata actionInfo, address caller) external view returns (bool) {
    // The rules for cancelation are:
    //   1. The action cannot be canceled if it's state is any of the following: Executed, Canceled, Expired, Failed.
    //   2. For all other states (Active, Approved, Queued) the action can be canceled if:
    //        a. The caller is the action creator.
    //        b. The action is Queued, but the number of disapprovals is >= the disapproval threshold.

    // Check 1.
    ActionState state = llamaCore.getActionState(actionInfo);
    if (
      state == ActionState.Executed || state == ActionState.Canceled || state == ActionState.Expired
        || state == ActionState.Failed
    ) return false;

    // Check 2a.
    Action memory action = llamaCore.getAction(actionInfo.id);
    if (caller == actionInfo.creator) return true;

    // Check 2b.
    return
      action.totalDisapprovals >= _getMinimumAmountNeeded(actionDisapprovalSupply[actionInfo.id], minDisapprovalPct);
  }

  // -------- When Determining Action State --------

  /// @inheritdoc ILlamaStrategy
  function isActive(ActionInfo calldata actionInfo) external view returns (bool) {
    return
      block.timestamp <= approvalEndTime(actionInfo) && (isFixedLengthApprovalPeriod || !isActionPassed(actionInfo));
  }

  /// @inheritdoc ILlamaStrategy
  function isActionPassed(ActionInfo calldata actionInfo) public view returns (bool) {
    Action memory action = llamaCore.getAction(actionInfo.id);
    return action.totalApprovals >= _getMinimumAmountNeeded(actionApprovalSupply[actionInfo.id], minApprovalPct);
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

  /// @dev Determine the minimum quantity needed for an action to reach quorum.
  /// @param supply Total number of policyholders eligible for participation.
  /// @param minPct Minimum percentage needed to reach quorum.
  /// @return The total quantity needed to reach quorum.
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
