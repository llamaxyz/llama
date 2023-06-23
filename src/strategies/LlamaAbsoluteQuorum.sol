// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaAbsoluteStrategyBase} from "src/strategies/LlamaAbsoluteStrategyBase.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Llama Absolute Quorum Strategy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is a Llama strategy which has the following properties:
///   - Approval/disapproval thresholds are specified as absolute numbers.
///   - Action creators are allowed to cast approvals or disapprovals on their own actions within this strategy.
contract LlamaAbsoluteQuorum is LlamaAbsoluteStrategyBase {
  // ==========================================
  // ======== Interface Implementation ========
  // ==========================================

  /// @inheritdoc ILlamaStrategy
  function validateActionCreation(ActionInfo calldata /* actionInfo */ ) external view override {
    LlamaPolicy llamaPolicy = policy; // Reduce SLOADs.
    uint256 approvalPolicySupply = llamaPolicy.getRoleSupplyAsQuantitySum(approvalRole);
    if (approvalPolicySupply == 0) revert RoleHasZeroSupply(approvalRole);

    uint256 disapprovalPolicySupply = llamaPolicy.getRoleSupplyAsQuantitySum(disapprovalRole);
    if (disapprovalPolicySupply == 0) revert RoleHasZeroSupply(disapprovalRole);

    if (minApprovals > approvalPolicySupply) revert InsufficientApprovalQuantity();
    if (minDisapprovals != type(uint128).max && minDisapprovals > disapprovalPolicySupply) {
      revert InsufficientDisapprovalQuantity();
    }
  }

  // -------- When Casting Approval --------

  /// @inheritdoc ILlamaStrategy
  function checkIfApprovalEnabled(ActionInfo calldata, /* actionInfo */ address, /* policyholder */ uint8 role)
    external
    view
    override
  {
    if (role != approvalRole && !forceApprovalRole[role]) revert InvalidRole(approvalRole);
  }

  // -------- When Casting Disapproval --------

  /// @inheritdoc ILlamaStrategy
  function checkIfDisapprovalEnabled(ActionInfo calldata, /* actionInfo */ address, /* policyholder */ uint8 role)
    external
    view
    override
  {
    if (minDisapprovals == type(uint128).max) revert DisapprovalDisabled();
    if (role != disapprovalRole && !forceDisapprovalRole[role]) revert InvalidRole(disapprovalRole);
  }
}
