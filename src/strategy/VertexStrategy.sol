// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCore} from "src/core/IVertexCore.sol";
import {IVertexStrategy} from "src/strategy/IVertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {Action, WeightByPermission, Strategy} from "src/utils/Structs.sol";

/// @title A strategy definition of a Vertex system.
/// @author Llama (vertex@llama.xyz)
/// @notice This is the template for Vertex strategies which determine the rules of an action's process.
contract VertexStrategy is IVertexStrategy {
    /// @notice Equivalent to 100%, but in basis points.
    uint256 public constant ONE_HUNDRED_IN_BPS = 100_00;

    /// @notice Permission signature value that determines weight of all unspecified policyholders.
    bytes32 public constant DEFAULT_OPERATOR = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @notice Minimum time between queueing and execution of action.
    uint256 public immutable queuingDuration;

    /// @notice Time after executionTime that action can be executed before permanently expiring.
    uint256 public immutable expirationDelay;

    /// @notice Can action be queued before approvalEndTime.
    bool public immutable isFixedLengthApprovalPeriod;

    /// @notice The strategy's Vertex system.
    IVertexCore public immutable vertex;

    /// @notice Length of approval period in blocks.
    uint256 public immutable approvalPeriod;

    /// @notice Policy NFT for this Vertex system.
    VertexPolicyNFT public immutable policy;

    /// @notice Minimum percentage of total approval weight / total approval supply at createdBlockNumber of the action for it to be queued. In bps, where
    /// 100_00 == 100%.
    uint256 public immutable minApprovalPct;

    /// @notice Minimum percentage of total disapproval weight / total disapproval supply at createdBlockNumber of the action for it to be canceled. In bps,
    /// where 100_00
    /// == 100%.
    uint256 public immutable minDisapprovalPct;

    /// @notice Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.
    mapping(bytes32 => uint248) public approvalWeightByPermission;

    /// @notice Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.
    mapping(bytes32 => uint248) public disapprovalWeightByPermission;

    /// @notice List of all permission signatures that are eligible for approvals.
    bytes32[] public approvalPermissions;

    /// @notice List of all permission signatures that are eligible for disapprovals.
    bytes32[] public disapprovalPermissions;

    error InvalidPermissionSignature();
    error InvalidWeightConfiguration();

    /// @notice Order is of WeightByPermissions is critical. Weight is determined by the first specific permission match.
    constructor(Strategy memory strategyConfig, VertexPolicyNFT _policy, IVertexCore _vertex) {
        queuingDuration = strategyConfig.queuingDuration;
        expirationDelay = strategyConfig.expirationDelay;
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
            if (
                strategyConfig.approvalWeightByPermission[0].permissionSignature == DEFAULT_OPERATOR && strategyConfig.approvalWeightByPermission[0].weight == 0
                    && approvalPermissionsLength == 1
            ) revert InvalidWeightConfiguration();

            unchecked {
                for (uint256 i; i < approvalPermissionsLength; ++i) {
                    WeightByPermission memory weightByPermission = strategyConfig.approvalWeightByPermission[i];

                    if (weightByPermission.weight > 0) {
                        approvalPermissions.push(weightByPermission.permissionSignature);
                    }
                    approvalWeightByPermission[weightByPermission.permissionSignature] = weightByPermission.weight;
                }
            }
        }

        if (disapprovalPermissionsLength > 0) {
            if (
                strategyConfig.disapprovalWeightByPermission[0].permissionSignature == DEFAULT_OPERATOR
                    && strategyConfig.disapprovalWeightByPermission[0].weight == 0 && disapprovalPermissionsLength == 1
            ) revert InvalidWeightConfiguration();

            unchecked {
                for (uint256 i; i < disapprovalPermissionsLength; ++i) {
                    WeightByPermission memory weightByPermission = strategyConfig.disapprovalWeightByPermission[i];

                    if (weightByPermission.weight > 0) {
                        disapprovalPermissions.push(weightByPermission.permissionSignature);
                    }
                    disapprovalWeightByPermission[weightByPermission.permissionSignature] = weightByPermission.weight;
                }
            }
        }

        emit NewStrategyCreated();
    }

    /// @inheritdoc IVertexStrategy
    function isActionPassed(uint256 actionId) external view override returns (bool) {
        Action memory action = vertex.getAction(actionId);
        return isApprovalQuorumValid(action.createdBlockNumber, action.totalApprovals);
    }

    /// @inheritdoc IVertexStrategy
    function isActionCanceletionValid(uint256 actionId) external view override returns (bool) {
        Action memory action = vertex.getAction(actionId);
        return isDisapprovalQuorumValid(action.createdBlockNumber, action.totalDisapprovals);
    }

    /// @inheritdoc IVertexStrategy
    function getApprovalWeightAt(address policyholder, uint256 blockNumber) external view returns (uint256) {
        uint256 permissionsLength = approvalPermissions.length;
        unchecked {
            for (uint256 i; i < permissionsLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use?
                // We could also get the policyholder's permissions, loop through that and check against the approvalWeightByPermission mapping
                // This would return a bool
                if (policy.holderHasPermissionAt(policyholder, approvalPermissions[i], blockNumber)) {
                    return approvalWeightByPermission[approvalPermissions[i]];
                }
            }
        }

        return approvalWeightByPermission[DEFAULT_OPERATOR];
    }

    /// @inheritdoc IVertexStrategy
    function getDisapprovalWeightAt(address policyholder, uint256 blockNumber) external view returns (uint256) {
        uint256 permissionsLength = disapprovalPermissions.length;
        unchecked {
            for (uint256 i; i < permissionsLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use at a blockNumber?
                // We could also get the policyholder's permissions, loop through that and check against the disapprovalWeightByPermission mapping
                // This would return a bool
                if (policy.holderHasPermissionAt(policyholder, disapprovalPermissions[i], blockNumber)) {
                    return disapprovalWeightByPermission[disapprovalPermissions[i]];
                }
            }
        }

        return disapprovalWeightByPermission[DEFAULT_OPERATOR];
    }

    /// @inheritdoc IVertexStrategy
    function isApprovalQuorumValid(uint256 actionId, uint256 approvals) public view override returns (bool) {
        Action memory action = vertex.getAction(actionId);
        return approvals >= getMinimumAmountNeeded(action.approvalPolicySupply, minApprovalPct);
    }

    /// @inheritdoc IVertexStrategy
    function isDisapprovalQuorumValid(uint256 actionId, uint256 disapprovals) public view override returns (bool) {
        Action memory action = vertex.getAction(actionId);
        return disapprovals >= getMinimumAmountNeeded(action.disapprovalPolicySupply, minDisapprovalPct);
    }

    /// @inheritdoc IVertexStrategy
    function getMinimumAmountNeeded(uint256 supply, uint256 minPct) public pure override returns (uint256) {
        return supply * minPct / ONE_HUNDRED_IN_BPS;
    }

    /// @inheritdoc IVertexStrategy
    function getApprovalPermissions() public view override returns (bytes32[] memory) {
        return approvalPermissions;
    }

    /// @inheritdoc IVertexStrategy
    function getDisapprovalPermissions() public view override returns (bytes32[] memory) {
        return disapprovalPermissions;
    }
}
