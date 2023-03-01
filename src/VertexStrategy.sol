// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCore} from "src/interfaces/IVertexCore.sol";
import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {Action, WeightByPermission, Strategy} from "src/lib/Structs.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

/// @title A strategy definition of a Vertex system.
/// @author Llama (vertex@llama.xyz)
/// @notice This is the template for Vertex strategies which determine the rules of an action's process.
contract VertexStrategy is IVertexStrategy {
  error InvalidPermissionSignature();

  /// @notice Equivalent to 100%, but in basis points.
  uint256 private constant ONE_HUNDRED_IN_BPS = 10_000;

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

  /// @notice List of all permission signatures that are eligible for approvals.
  bytes8[] public approvalPermissions;

  /// @notice List of all permission signatures that are eligible for disapprovals.
  bytes8[] public disapprovalPermissions;

  /// @notice Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.
  mapping(bytes8 => uint256) public approvalWeightByPermission;

  /// @notice Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.
  mapping(bytes8 => uint256) public disapprovalWeightByPermission;

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

    uint256 approvalPermissionsLength = strategyConfig.approvalWeightByPermission.length;
    uint256 disapprovalPermissionsLength = strategyConfig.disapprovalWeightByPermission.length;

    // Initialize to 1, could be overwritten below
    approvalWeightByPermission[DEFAULT_OPERATOR] = 1;
    disapprovalWeightByPermission[DEFAULT_OPERATOR] = 1;

    if (approvalPermissionsLength > 0) {
      unchecked {
        for (uint256 i; i < approvalPermissionsLength; ++i) {
          WeightByPermission memory weightByPermission = strategyConfig.approvalWeightByPermission[i];

          if (weightByPermission.weight > 0) approvalPermissions.push(weightByPermission.permissionSignature);
          approvalWeightByPermission[weightByPermission.permissionSignature] = weightByPermission.weight;
        }
      }
    }

    if (disapprovalPermissionsLength > 0) {
      unchecked {
        for (uint256 i; i < disapprovalPermissionsLength; ++i) {
          WeightByPermission memory weightByPermission = strategyConfig.disapprovalWeightByPermission[i];

          if (weightByPermission.weight > 0) disapprovalPermissions.push(weightByPermission.permissionSignature);
          disapprovalWeightByPermission[weightByPermission.permissionSignature] = weightByPermission.weight;
        }
      }
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
  function getApprovalWeightAt(address policyholder, uint256 timestamp) external view returns (uint256) {
    if (policy.balanceOf(policyholder) == 0) revert NoPolicy();
    uint256 permissionsLength = approvalPermissions.length;
    unchecked {
      for (uint256 i; i < permissionsLength; ++i) {
        if (policy.holderHasPermissionAt(policyholder, approvalPermissions[i], timestamp)) {
          return approvalWeightByPermission[approvalPermissions[i]];
        }
      }
    }

    return approvalWeightByPermission[DEFAULT_OPERATOR];
  }

  /// @inheritdoc IVertexStrategy
  function getDisapprovalWeightAt(address policyholder, uint256 timestamp) external view returns (uint256) {
    if (policy.balanceOf(policyholder) == 0) revert NoPolicy();
    uint256 permissionsLength = disapprovalPermissions.length;
    unchecked {
      for (uint256 i; i < permissionsLength; ++i) {
        if (policy.holderHasPermissionAt(policyholder, disapprovalPermissions[i], timestamp)) {
          return disapprovalWeightByPermission[disapprovalPermissions[i]];
        }
      }
    }

    return disapprovalWeightByPermission[DEFAULT_OPERATOR];
  }

  /// @inheritdoc IVertexStrategy
  function getMinimumAmountNeeded(uint256 supply, uint256 minPct) public pure override returns (uint256) {
    // Rounding Up
    return FixedPointMathLib.mulDivUp(supply, minPct, ONE_HUNDRED_IN_BPS);
  }

  /// @inheritdoc IVertexStrategy
  function getApprovalPermissions() public view override returns (bytes8[] memory) {
    return approvalPermissions;
  }

  /// @inheritdoc IVertexStrategy
  function getDisapprovalPermissions() public view override returns (bytes8[] memory) {
    return disapprovalPermissions;
  }
}
