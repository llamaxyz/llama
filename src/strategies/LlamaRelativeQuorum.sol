// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {Action, ActionInfo} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Llama Relative Quorum Strategy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is a Llama strategy which has the following properties:
///   - Approval/disapproval thresholds are specified as percentages of total supply.
///   - Action creators are allowed to cast approvals or disapprovals on their own actions within this strategy.
///   - The approval and disapproval role holder supplies are saved at action creation time and used to calculate that
///     action's quorum.
///   - Role quantity is used to determine the approval and disapproval weight of a policyholder's cast.
contract LlamaRelativeQuorum is ILlamaStrategy, Initializable {
  // =========================
  // ======== Structs ========
  // =========================

  struct Config {
    uint64 approvalPeriod; // The length of time of the approval period.
    uint64 queuingPeriod; // The length of time of the queuing period. The disapproval period is the queuing period when
      // enabled.
    uint64 expirationPeriod; // The length of time an action can be executed before it expires.
    uint16 minApprovalPct; // Minimum percentage of total approval quantity / total approval supply.
    uint16 minDisapprovalPct; // Minimum percentage of total disapproval quantity / total disapproval supply.
    bool isFixedLengthApprovalPeriod; // Determines if an action be queued before approvalEndTime.
    uint8 approvalRole; // Anyone with this role can cast approval of an action.
    uint8 disapprovalRole; // Anyone with this role can cast disapproval of an action.
    uint8[] forceApprovalRoles; // Anyone with this role can single-handedly approve an action.
    uint8[] forceDisapprovalRoles; // Anyone with this role can single-handedly disapprove an action.
  }

  // ========================
  // ======== Errors ========
  // ========================

  /// @dev Only callable by a Llama instance's core contract.
  error OnlyLlamaCore();

  /// @dev The action cannot be canceled if it's already in a terminal state.
  /// @param currentState The current state of the action.
  error CannotCancelInState(ActionState currentState);

  /// @dev The strategy has disabled disapprovals.
  error DisapprovalDisabled();

  /// @dev The action cannot be created because the minimum approval percentage cannot be greater than 100%.
  /// @param minApprovalPct The provided minApprovalPct.
  error InvalidMinApprovalPct(uint256 minApprovalPct);

  /// @dev The role is not eligible to participate in this strategy in the specified way.
  /// @param role The role being used.
  error InvalidRole(uint8 role);

  /// @dev Only the action creator can cancel an action.
  error OnlyActionCreator();

  /// @dev The action cannot be created if the approval or disapproval supply is 0.
  /// @param role The role being used.
  error RoleHasZeroSupply(uint8 role);

  /// @dev The provided role is not initialized by the `LlamaPolicy`.
  /// @param role The role being used.
  error RoleNotInitialized(uint8 role);

  // =================================================
  // ======== Constants and Storage Variables ========
  // =================================================

  // -------- Interface Requirements --------

  /// @inheritdoc ILlamaStrategy
  LlamaCore public llamaCore;

  /// @inheritdoc ILlamaStrategy
  LlamaPolicy public policy;

  // -------- Strategy Configuration --------

  /// @dev Equivalent to 100%, but in basis points.
  uint256 internal constant ONE_HUNDRED_IN_BPS = 10_000;

  /// @notice If `false`, action be queued before approvalEndTime.
  bool public isFixedLengthApprovalPeriod;

  /// @notice Length of approval period in seconds.
  uint64 public approvalPeriod;

  /// @notice Minimum time, in seconds, between queueing and execution of action.
  uint64 public queuingPeriod;

  /// @notice Time, in seconds, after `minExecutionTime` that action can be executed before permanently expiring.
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
  mapping(uint8 role => bool isForceApproval) public forceApprovalRole;

  /// @notice Mapping of roles that can force an action to be disapproved.
  mapping(uint8 role => bool isForceDisapproval) public forceDisapprovalRole;

  /// @notice Mapping of action ID to the supply of the approval role at the time the action was created.
  mapping(uint256 actionId => uint256 approvalRolePolicySupply) public actionApprovalSupply;

  /// @notice Mapping of action ID to the supply of the disapproval role at the time the action was created.
  mapping(uint256 actionId => uint256 disapprovalRolePolicySupply) public actionDisapprovalSupply;

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
    Config memory strategyConfig = abi.decode(config, (Config));
    llamaCore = LlamaCore(msg.sender);
    policy = llamaCore.policy();
    queuingPeriod = strategyConfig.queuingPeriod;
    expirationPeriod = strategyConfig.expirationPeriod;
    isFixedLengthApprovalPeriod = strategyConfig.isFixedLengthApprovalPeriod;
    approvalPeriod = strategyConfig.approvalPeriod;

    if (strategyConfig.minApprovalPct > ONE_HUNDRED_IN_BPS) revert InvalidMinApprovalPct(strategyConfig.minApprovalPct);
    minApprovalPct = strategyConfig.minApprovalPct;
    minDisapprovalPct = strategyConfig.minDisapprovalPct;

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
    }

    for (uint256 i = 0; i < strategyConfig.forceDisapprovalRoles.length; i = LlamaUtils.uncheckedIncrement(i)) {
      uint8 role = strategyConfig.forceDisapprovalRoles[i];
      if (role == 0) revert InvalidRole(0);
      _assertValidRole(role, numRoles);
      forceDisapprovalRole[role] = true;
    }
  }

  // -------- At Action Creation --------

  /// @inheritdoc ILlamaStrategy
  function validateActionCreation(ActionInfo calldata actionInfo) external {
    if (msg.sender != address(llamaCore)) revert OnlyLlamaCore();

    LlamaPolicy llamaPolicy = policy; // Reduce SLOADs.
    uint256 approvalPolicySupply = llamaPolicy.getPastRoleSupplyAsNumberOfHolders(approvalRole, block.timestamp - 1);
    if (approvalPolicySupply == 0) revert RoleHasZeroSupply(approvalRole);

    uint256 disapprovalPolicySupply =
      llamaPolicy.getPastRoleSupplyAsNumberOfHolders(disapprovalRole, block.timestamp - 1);
    if (disapprovalPolicySupply == 0) revert RoleHasZeroSupply(disapprovalRole);

    // Save off the supplies to use for checking quorum.
    actionApprovalSupply[actionInfo.id] = approvalPolicySupply;
    actionDisapprovalSupply[actionInfo.id] = disapprovalPolicySupply;
  }

  // -------- When Casting Approval --------

  /// @inheritdoc ILlamaStrategy
  function checkIfApprovalEnabled(ActionInfo calldata, address, uint8 role) external view {
    if (role != approvalRole && !forceApprovalRole[role]) revert InvalidRole(approvalRole);
  }

  /// @inheritdoc ILlamaStrategy
  function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint96) {
    if (role != approvalRole && !forceApprovalRole[role]) return 0;
    uint96 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    return quantity > 0 && forceApprovalRole[role] ? type(uint96).max : quantity;
  }

  // -------- When Casting Disapproval --------

  /// @inheritdoc ILlamaStrategy
  function checkIfDisapprovalEnabled(ActionInfo calldata, address, uint8 role) external view {
    if (minDisapprovalPct > ONE_HUNDRED_IN_BPS) revert DisapprovalDisabled();
    if (role != disapprovalRole && !forceDisapprovalRole[role]) revert InvalidRole(disapprovalRole);
  }

  /// @inheritdoc ILlamaStrategy
  function getDisapprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp) external view returns (uint96) {
    if (role != disapprovalRole && !forceDisapprovalRole[role]) return 0;
    uint96 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    return quantity > 0 && forceDisapprovalRole[role] ? type(uint96).max : quantity;
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
  function isActionActive(ActionInfo calldata actionInfo) external view returns (bool) {
    return
      block.timestamp <= approvalEndTime(actionInfo) && (isFixedLengthApprovalPeriod || !isActionApproved(actionInfo));
  }

  /// @inheritdoc ILlamaStrategy
  function isActionApproved(ActionInfo calldata actionInfo) public view returns (bool) {
    Action memory action = llamaCore.getAction(actionInfo.id);
    return action.totalApprovals >= _getMinimumAmountNeeded(actionApprovalSupply[actionInfo.id], minApprovalPct);
  }

  /// @inheritdoc ILlamaStrategy
  function isActionDisapproved(ActionInfo calldata actionInfo) public view returns (bool) {
    Action memory action = llamaCore.getAction(actionInfo.id);
    return
      action.totalDisapprovals >= _getMinimumAmountNeeded(actionDisapprovalSupply[actionInfo.id], minDisapprovalPct);
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
}
