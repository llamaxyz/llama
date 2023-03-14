// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCore} from "src/interfaces/IVertexCore.sol";
import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {Action, Strategy} from "src/lib/Structs.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

/// @title A strategy definition of a Vertex system.
/// @author Llama (vertex@llama.xyz)
/// @notice This is the template for Vertex strategies which determine the rules of an action's process.
contract VertexStrategy is IVertexStrategy {
  /// @notice Equivalent to 100%, but in basis points.
  uint256 internal constant ONE_HUNDRED_IN_BPS = 10_000;

  /// @notice Permission signature value that determines weight of all unspecified policyholders.
  bytes8 public constant DEFAULT_OPERATOR = 0xffffffffffffffff;

  /// @notice Can action be queued before approvalEndTime.
  bool public immutable isFixedLengthApprovalPeriod;

  /// @notice The strategy's Vertex system.
  IVertexCore public immutable vertex;

  /// @notice Policy NFT for this Vertex system.
  VertexPolicy public immutable policy;

  /// @notice Minimum time between queueing and execution of action.
  uint256 public immutable queuingPeriod;

  /// @notice Time after executionTime that action can be executed before permanently expiring.
  uint256 public immutable expirationPeriod;

  /// @notice Length of approval period in blocks.
  uint256 public immutable approvalPeriod;

  /// @notice Minimum percentage of total approval weight / total approval supply at creationTime of the action for it
  /// to be queued. In bps, where
  /// 100_00 == 100%.
  uint256 public immutable minApprovalPct;

  /// @notice Minimum percentage of total disapproval weight / total disapproval supply at creationTime of the action
  /// for it to be canceled. In bps,
  /// where 100_00
  /// == 100%.
  uint256 public immutable minDisapprovalPct;

  bytes32 public immutable approvalRole;
  bytes32 public immutable disapprovalRole;
  mapping(bytes32 => bool) public forceApprovalRole;
  mapping(bytes32 => bool) public forceDisapprovalRole;

  /// @notice Order is of WeightByPermissions is critical. Weight is determined by the first specific permission match.
  constructor(Strategy memory strategyConfig, VertexPolicy _policy, IVertexCore _vertex) {
    queuingPeriod = strategyConfig.queuingPeriod;
    expirationPeriod = strategyConfig.expirationPeriod;
    isFixedLengthApprovalPeriod = strategyConfig.isFixedLengthApprovalPeriod;
    approvalPeriod = strategyConfig.approvalPeriod;
    policy = _policy;
    vertex = _vertex;
    minApprovalPct = strategyConfig.minApprovalPct;
    minDisapprovalPct = strategyConfig.minDisapprovalPct;

    approvalRole = strategyConfig.approvalRole;
    disapprovalRole = strategyConfig.disapprovalRole;

    for (uint256 i; i < strategyConfig.forceApprovalRoles.length; i++) {
      bytes32 role = strategyConfig.forceApprovalRoles[i];
      forceApprovalRole[role] = true;
      emit ForceApprovalRoleAdded(role);
    }

    for (uint256 i; i < strategyConfig.forceDisapprovalRoles.length; i++) {
      bytes32 role = strategyConfig.forceDisapprovalRoles[i];
      forceDisapprovalRole[role] = true;
      emit ForceDisapprovalRoleAdded(role);
    }

    emit NewStrategyCreated(_vertex, _policy);
  }

  /// @inheritdoc IVertexStrategy
  function isActionPassed(uint256 actionId) external view override returns (bool) {
    Action memory action = vertex.getAction(actionId);
    return action.totalApprovals >= getMinimumAmountNeeded(action.approvalPolicySupply, minApprovalPct);
  }

  /// @inheritdoc IVertexStrategy
  function isActionCancelationValid(uint256 actionId) external view override returns (bool) {
    Action memory action = vertex.getAction(actionId);
    return action.totalDisapprovals >= getMinimumAmountNeeded(action.disapprovalPolicySupply, minDisapprovalPct);
  }

  /// @inheritdoc IVertexStrategy
  function getApprovalWeightAt(address policyholder, bytes32 role, uint256 timestamp) external view returns (uint256) {
    if (forceApprovalRole[role]) return type(uint256).max;
    return policy.holderWeightAt(policyholder, role, timestamp);
  }

  /// @inheritdoc IVertexStrategy
  function getDisapprovalWeightAt(address policyholder, bytes32 role, uint256 timestamp)
    external
    view
    returns (uint256)
  {
    if (forceDisapprovalRole[role]) return type(uint256).max;
    return policy.holderWeightAt(policyholder, role, timestamp);
  }

  /// @inheritdoc IVertexStrategy
  function getMinimumAmountNeeded(uint256 supply, uint256 minPct) public pure override returns (uint256) {
    // Rounding Up
    return FixedPointMathLib.mulDivUp(supply, minPct, ONE_HUNDRED_IN_BPS);
  }
}
