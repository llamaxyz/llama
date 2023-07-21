// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionInfo} from "src/lib/Structs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

import {LlamaRelativeStrategyBase} from "src/strategies/relative/LlamaRelativeStrategyBase.sol";

/// @title Llama Relative Quantity Quorum Strategy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is a Llama strategy which has the following properties:
///   - Approval/disapproval thresholds are specified as percentages of total quantity.
///   - Action creators are allowed to cast approvals or disapprovals on their own actions within this strategy.
///   - The approval and disapproval role holder quantities are saved at action creation time and used to calculate that
///     action's quorum.
///   - Role quantity is used to determine the approval and disapproval weight of a policyholder's cast.
contract LlamaRelativeQuantityQuorum is LlamaRelativeStrategyBase {
  /// @inheritdoc ILlamaStrategy
  function getApprovalQuantityAt(address policyholder, uint8 role, uint256 timestamp)
    external
    view
    override
    returns (uint96)
  {
    if (role != approvalRole && !forceApprovalRole[role]) return 0;
    uint96 quantity = policy.getPastQuantity(policyholder, role, timestamp);
    return quantity > 0 && forceApprovalRole[role] ? type(uint96).max : quantity;
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
    return quantity > 0 && forceDisapprovalRole[role] ? type(uint96).max : quantity;
  }

  /// @inheritdoc LlamaRelativeStrategyBase
  function getApprovalSupply(ActionInfo calldata actionInfo) public view override returns (uint96) {
    uint256 creationTime = llamaCore.getAction(actionInfo.id).creationTime;
    if (creationTime == 0) revert InvalidActionInfo();
    return policy.getPastRoleSupplyAsQuantitySum(approvalRole, creationTime - 1);
  }

  /// @inheritdoc LlamaRelativeStrategyBase
  function getDisapprovalSupply(ActionInfo calldata actionInfo) public view override returns (uint96) {
    uint256 creationTime = llamaCore.getAction(actionInfo.id).creationTime;
    if (creationTime == 0) revert InvalidActionInfo();
    return policy.getPastRoleSupplyAsQuantitySum(disapprovalRole, creationTime - 1);
  }
}
