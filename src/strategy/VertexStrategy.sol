// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCore} from "src/core/IVertexCore.sol";
import {IVertexStrategy} from "src/strategy/IVertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {Action, ActionWithoutApprovals, WeightByPermission, Strategy} from "src/utils/Structs.sol";

// Errors
error InvalidPermissionSignature();
error InvalidWeightConfiguration();

contract VertexStrategy is IVertexStrategy {
    /// @notice Equivalent to 100%, but scaled for precision
    uint256 public constant ONE_HUNDRED_WITH_PRECISION = 10000;

    /// @notice Permission signature value that determines weight for all unspecified policyholders.
    bytes32 public constant DEFAULT_OPERATOR = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @notice Minimum time between queueing and execution of action.
    uint256 public immutable executionDelay;

    /// @notice Time after delay that action can be executed before permanently expiring.
    uint256 public immutable expirationDelay;

    /// @notice Can action be queued before endBlockNumber.
    bool public immutable isFixedLengthApprovalPeriod;

    /// @notice The strategy's Vertex instance.
    IVertexCore public immutable vertex;

    /// @notice Length of approval period in blocks.
    uint256 public immutable approvalDuration;

    /// @notice Policy NFT for this Vertex Instance.
    VertexPolicyNFT public immutable policy;

    /// @notice Minimum percentage of total approval weight / total approval supply at startBlockNumber of action to be queued.
    uint256 public immutable minApprovalPct;

    /// @notice Minimum percentage of total disapproval weight / total disapproval supply at startBlockNumber of action to be canceled.
    uint256 public immutable minDisapprovalPct;

    /// @notice Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.
    mapping(bytes32 => uint248) public approvalWeightByPermission;

    /// @notice Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.
    mapping(bytes32 => uint248) public disapprovalWeightByPermission;

    /// @notice List of all permission signatures that are eligible for approvals.
    bytes32[] public approvalPermissions;

    /// @notice List of all permission signatures that are eligible for disapprovals.
    bytes32[] public disapprovalPermissions;

    /// @notice Order is of WeightByPermissions is critical. Weight is determined by the first specific permission match.
    constructor(Strategy memory strategyConfig, VertexPolicyNFT _policy, IVertexCore _vertex) {
        executionDelay = strategyConfig.executionDelay;
        expirationDelay = strategyConfig.expirationDelay;
        isFixedLengthApprovalPeriod = strategyConfig.isFixedLengthApprovalPeriod;
        approvalDuration = strategyConfig.approvalDuration;
        policy = _policy;
        vertex = _vertex;
        minApprovalPct = strategyConfig.minApprovalPct;
        minDisapprovalPct = strategyConfig.minDisapprovalPct;

        uint256 approvalPermissionsLength = strategyConfig.approvalWeightByPermission.length;
        uint256 disapprovalPermissionsLength = strategyConfig.disapprovalWeightByPermission.length;

        // Initialize to 1, could be overwritten below
        approvalWeightByPermission[DEFAULT_OPERATOR] = 1;
        disapprovalWeightByPermission[DEFAULT_OPERATOR] = 1;

        if (
            strategyConfig.approvalWeightByPermission[0].permissionSignature == DEFAULT_OPERATOR &&
            strategyConfig.approvalWeightByPermission[0].weight == 0 &&
            approvalPermissionsLength == 1
        ) revert InvalidWeightConfiguration();

        if (
            strategyConfig.disapprovalWeightByPermission[0].permissionSignature == DEFAULT_OPERATOR &&
            strategyConfig.disapprovalWeightByPermission[0].weight == 0 &&
            disapprovalPermissionsLength == 1
        ) revert InvalidWeightConfiguration();

        unchecked {
            for (uint256 i; i < approvalPermissionsLength; ++i) {
                // TODO: see if this saves gas
                WeightByPermission memory weightByPermission = strategyConfig.approvalWeightByPermission[i];

                if (weightByPermission.weight > 0) {
                    approvalPermissions.push(weightByPermission.permissionSignature);
                }
                approvalWeightByPermission[weightByPermission.permissionSignature] = weightByPermission.weight;
            }
        }

        unchecked {
            for (uint256 i; i < disapprovalPermissionsLength; ++i) {
                // TODO: see if this saves gas
                WeightByPermission memory weightByPermission = strategyConfig.disapprovalWeightByPermission[i];

                if (weightByPermission.weight > 0) {
                    disapprovalPermissions.push(weightByPermission.permissionSignature);
                }
                disapprovalWeightByPermission[weightByPermission.permissionSignature] = weightByPermission.weight;
            }
        }

        emit NewStrategyCreated();
    }

    /// @inheritdoc IVertexStrategy
    function isActionPassed(uint256 actionId) external view override returns (bool) {
        ActionWithoutApprovals memory action = vertex.getActionWithoutApprovals(actionId);
        // TODO: Needs to account for endBlockNumber = 0 (strategies that do not require an approval period)
        // TODO: Needs to account for both isFixedLengthApprovalPeriod's
        //       if true then action cannot pass before approval period ends
        //       if false then action can pass before approval period ends
        // Handle all the math to determine if the approval has passed based on this strategies quorum settings.
        return isApprovalQuorumValid(action.startBlockNumber, action.totalApprovals);
    }

    /// @inheritdoc IVertexStrategy
    function isActionCanceletionValid(uint256 actionId) external view override returns (bool) {
        ActionWithoutApprovals memory action = vertex.getActionWithoutApprovals(actionId);
        // TODO: Use this action's properties to determine if it is eligible for cancelation
        // TODO: Needs to account for strategies that do not allow disapprovals
        // Handle all the math to determine if the disapproval has passed based on this strategies quorum settings.
        return isDisapprovalQuorumValid(action.startBlockNumber, action.totalDisapprovals);
    }

    /// @inheritdoc IVertexStrategy
    function getApprovalWeightAt(address policyHolder, uint256 blockNumber) external view returns (uint256) {
        uint256 permissionsLength = approvalPermissions.length;
        unchecked {
            for (uint256 i; i < permissionsLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use?
                // We could also get the policyholder's permissions, loop through that and check against the approvalWeightByPermission mapping
                // This would return a bool
                if (policy.holderHasPermissionAt(policyHolder, approvalPermissions[i], blockNumber)) {
                    return approvalWeightByPermission[approvalPermissions[i]];
                }
            }
        }

        return approvalWeightByPermission[DEFAULT_OPERATOR];
    }

    /// @inheritdoc IVertexStrategy
    function getDisapprovalWeightAt(address policyHolder, uint256 blockNumber) external view returns (uint256) {
        uint256 permissionsLength = disapprovalPermissions.length;
        unchecked {
            for (uint256 i; i < permissionsLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use at a blockNumber?
                // We could also get the policyholder's permissions, loop through that and check against the disapprovalWeightByPermission mapping
                // This would return a bool
                if (policy.holderHasPermissionAt(policyHolder, disapprovalPermissions[i], blockNumber)) {
                    return disapprovalWeightByPermission[disapprovalPermissions[i]];
                }
            }
        }

        return disapprovalWeightByPermission[DEFAULT_OPERATOR];
    }

    /// @inheritdoc IVertexStrategy
    function isApprovalQuorumValid(uint256 actionId, uint256 approvals) public view override returns (bool) {
        ActionWithoutApprovals memory action = vertex.getActionWithoutApprovals(actionId);
        return approvals >= getMinimumAmountNeeded(action.approvalPolicySupply, minApprovalPct);
    }

    /// @inheritdoc IVertexStrategy
    function isDisapprovalQuorumValid(uint256 actionId, uint256 disapprovals) public view override returns (bool) {
        ActionWithoutApprovals memory action = vertex.getActionWithoutApprovals(actionId);
        return disapprovals >= getMinimumAmountNeeded(action.disapprovalPolicySupply, minDisapprovalPct);
    }

    /// @inheritdoc IVertexStrategy
    function getMinimumAmountNeeded(uint256 supply, uint256 minPct) public pure override returns (uint256) {
        // NOTE: Need to actual implement proper floating point math here
        // minPct (will either be minApprovalPct or minDisapprovalPct) is the percent quorum needed and so this returns the amount in number form
        // we should round this up to the nearest integer
        return (supply * minPct) / ONE_HUNDRED_WITH_PRECISION;
    }

    function getApprovalPermissions() public view override returns (bytes32[] memory) {
        return approvalPermissions;
    }

    function getDisapprovalPermissions() public view override returns (bytes32[] memory) {
        return disapprovalPermissions;
    }
}
