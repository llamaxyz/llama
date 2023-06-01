// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/LlamaAbsoluteStrategyBase.sol";
import {ActionState} from "src/lib/Enums.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {Action, ActionInfo} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Llama Peer Review Strategy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is a llama strategy which has the following properties:
///   - Approval/disapproval thresholds are specified as absolute numbers.
///   - Action creators are not allowed to cast approvals or disapprovals on their own actions,
///     regardless of the roles they hold.
///   - By not allowing action creators to cast approvals or disapprovals on their own actions,
///     this strategy is useful for when a group of policyholders have permission to both create
///     and approve an action. You can design a strategy where anyone in this group can propose
///     but they need N number of approvals from their peers in this group for the action to be
///     approved.
contract LlamaPeerReview is LlamaAbsoluteStrategyBase {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  /// @dev The action creator cannot approve or disapprove an action.
  error ActionCreatorCannotCast();

  // ==========================================
  // ======== Interface Implementation ========
  // ==========================================

  /// @inheritdoc ILlamaStrategy
  function validateActionCreation(ActionInfo calldata actionInfo) external view override {
    LlamaPolicy llamaPolicy = policy; // Reduce SLOADs.
    uint256 approvalPolicySupply = llamaPolicy.getRoleSupplyAsQuantitySum(approvalRole);
    if (approvalPolicySupply == 0) revert RoleHasZeroSupply(approvalRole);

    uint256 disapprovalPolicySupply = llamaPolicy.getRoleSupplyAsQuantitySum(disapprovalRole);
    if (disapprovalPolicySupply == 0) revert RoleHasZeroSupply(disapprovalRole);
    unchecked {
      // Safety: We check the supply of the role above, and this supply is inclusive of the quantity
      // held by the action creator. Therefore we can reduce the total supply by the quantity held by
      // the action creator without overflow, since a policyholder can never have a quantity greater than
      // the total supply.
      uint256 actionCreatorApprovalRoleQty = llamaPolicy.getQuantity(actionInfo.creator, approvalRole);
      if (minApprovals > approvalPolicySupply - actionCreatorApprovalRoleQty) revert InsufficientApprovalQuantity();

      uint256 actionCreatorDisapprovalRoleQty = llamaPolicy.getQuantity(actionInfo.creator, disapprovalRole);
      if (
        minDisapprovals != type(uint128).max
          && minDisapprovals > disapprovalPolicySupply - actionCreatorDisapprovalRoleQty
      ) revert InsufficientDisapprovalQuantity();
    }
  }

  // -------- When Casting Approval --------

  /// @inheritdoc ILlamaStrategy
  function isApprovalEnabled(ActionInfo calldata actionInfo, address policyholder, uint8 role) external view override {
    if (actionInfo.creator == policyholder) revert ActionCreatorCannotCast();
    if (role != approvalRole && !forceApprovalRole[role]) revert InvalidRole(approvalRole);
  }

  // -------- When Casting Disapproval --------

  /// @inheritdoc ILlamaStrategy
  function isDisapprovalEnabled(ActionInfo calldata actionInfo, address policyholder, uint8 role)
    external
    view
    override
  {
    if (minDisapprovals == type(uint128).max) revert DisapprovalDisabled();
    if (actionInfo.creator == policyholder) revert ActionCreatorCannotCast();
    if (role != disapprovalRole && !forceDisapprovalRole[role]) revert InvalidRole(disapprovalRole);
  }
}
