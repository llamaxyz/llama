// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

import {LlamaRelativeStrategyBase} from "src/strategies/LlamaRelativeStrategyBase.sol";

/// @title Llama Relative Unique Holder Quorum Strategy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is a Llama strategy which has the following properties:
///   - Approval/disapproval thresholds are specified as percentages of total supply.
///   - Action creators are allowed to cast approvals or disapprovals on their own actions within this strategy.
///   - The approval and disapproval role holder supplies are saved at action creation time and used to calculate that
///     action's quorum.
///   - Policyholders with the corresponding approval or disapproval role have a cast weight of 1.
contract LlamaRelativeUniqueHolderQuorum is LlamaRelativeStrategyBase {
  /// @inheritdoc ILlamaStrategy
  function validateActionCreation(ActionInfo calldata actionInfo) external override {
    if (msg.sender != address(llamaCore)) revert OnlyLlamaCore();

    LlamaPolicy llamaPolicy = policy; // Reduce SLOADs.
    uint256 approvalPolicySupply = llamaPolicy.getPastRoleSupplyAsNumberOfHolders(approvalRole, block.timestamp - 1);
    if (approvalPolicySupply == 0) revert RoleHasZeroSupply(approvalRole);

    uint256 disapprovalPolicySupply = llamaPolicy.getRoleSupplyAsNumberOfHolders(disapprovalRole);
    if (disapprovalPolicySupply == 0) revert RoleHasZeroSupply(disapprovalRole);

    // Save off the supplies to use for checking quorum.
    actionApprovalSupply[actionInfo.id] = approvalPolicySupply;
    actionDisapprovalSupply[actionInfo.id] = disapprovalPolicySupply;
  }

  function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp)
    external
    view
    override
    returns (uint96)
  {
    if (role != approvalRole && !forceApprovalRole[role]) return 0;
    uint96 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    if (forceApprovalRole[role]) return type(uint96).max;
    return quantity > 0 ? 1 : 0;
  }

  /// @inheritdoc ILlamaStrategy
  function getDisapprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp)
    external
    view
    override
    returns (uint96)
  {
    if (role != disapprovalRole && !forceDisapprovalRole[role]) return 0;
    uint96 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    if (forceDisapprovalRole[role]) return type(uint96).max;
    return quantity > 0 ? 1 : 0;
  }
}
