// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {IVertexStrategy} from "src/strategy/IVertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";

// Errors
error OnlyVertexRouter();
error InvalidPermissionSignature();
error InvalidWeightConfiguration();

contract VertexStrategy is IVertexStrategy {
    /// @notice Equivalent to 100%, but scaled for precision
    uint256 public constant ONE_HUNDRED_WITH_PRECISION = 10000;

    /// @notice Permission signature value that determines power for all undefined voters.
    bytes32 public constant DEFAULT_OPERATOR = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @notice Minimum time between queueing and execution of action.
    uint256 public immutable executionDelay;

    /// @notice Time after delay that action can be executed before permanently expiring.
    uint256 public immutable expirationDelay;

    /// @notice Can action be queued before endBlockNumber.
    bool public immutable isFixedLengthApprovalPeriod;

    /// @notice Router of this Vertex instance.
    IVertexRouter public immutable router;

    /// @notice Length of voting period.
    uint256 public immutable approvalDuration;

    /// @notice Policy NFT for this Vertex Instance.
    VertexPolicyNFT public immutable policy;

    /// @notice Minimum percentage of total approval weight / total approval supply at startBlockNumber of action to pass vote.
    uint256 public immutable override minApprovalPct;

    /// @notice Minimum percentage of total disapproval weight / total disapproval supply at startBlockNumber of action to pass veto.
    uint256 public immutable override minDisapprovalPct;

    /// @notice Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.
    mapping(bytes32 => uint248) public approvalWeightByPermission;

    /// @notice Mapping of permission signatures to their weight. DEFAULT_OPERATOR is used as a catch all.
    mapping(bytes32 => uint248) public disapprovalWeightByPermission;

    /// @notice List of all permission signatures that are eligible for approvals.
    bytes32[] public approvalPermissions;

    /// @notice List of all permission signatures that are eligible for disapprovals.
    bytes32[] public disapprovalPermissions;

    /// @notice Order is of WeightByPermissions is critical. Weight is determined by the first specific permission match.
    constructor(
        uint256 _executionDelay,
        uint256 _expirationDelay,
        bool _isFixedLengthApprovalPeriod,
        uint256 _approvalDuration,
        VertexPolicyNFT _policy,
        IVertexRouter _router,
        uint256 _minApprovalPct,
        uint256 _minDisapprovalPct,
        WeightByPermission[] memory _approvalWeightByPermission,
        WeightByPermission[] memory _disapprovalWeightByPermission
    ) {
        executionDelay = _executionDelay;
        expirationDelay = _expirationDelay;
        isFixedLengthApprovalPeriod = _isFixedLengthApprovalPeriod;
        approvalDuration = _approvalDuration;
        policy = _policy;
        router = _router;
        minApprovalPct = _minApprovalPct;
        minDisapprovalPct = _minDisapprovalPct;

        uint256 approvalPermissionsLength = _approvalWeightByPermission.length;
        uint256 disapprovalPermissionsLength = _disapprovalWeightByPermission.length;

        // Initialize to 1, could be overwritten below
        approvalWeightByPermission[DEFAULT_OPERATOR] = 1;
        disapprovalWeightByPermission[DEFAULT_OPERATOR] = 1;

        if (
            _approvalWeightByPermission[0].permissionSignature == DEFAULT_OPERATOR &&
            _approvalWeightByPermission[0].weight == 0 &&
            approvalPermissionsLength == 1
        ) revert InvalidWeightConfiguration();

        if (
            _disapprovalWeightByPermission[0].permissionSignature == DEFAULT_OPERATOR &&
            _disapprovalWeightByPermission[0].weight == 0 &&
            disapprovalPermissionsLength == 1
        ) revert InvalidWeightConfiguration();

        unchecked {
            for (uint256 i; i < approvalPermissionsLength; ++i) {
                // TODO: see if this saves gas
                WeightByPermission memory weightByPermission = _approvalWeightByPermission[i];

                // TODO: @theo is it possible to have a check to see if a permission signature is in use?
                // This would return a bool
                if (!policy.isPermissionSignatureActive(weightByPermission.permissionSignature)) revert InvalidPermissionSignature();

                if (weightByPermission.weight > 0) {
                    approvalPermissions.push(weightByPermission.permissionSignature);
                }
                approvalWeightByPermission[weightByPermission.permissionSignature] = weightByPermission.weight;
            }
        }

        unchecked {
            for (uint256 i; i < disapprovalPermissionsLength; ++i) {
                // TODO: see if this saves gas
                WeightByPermission memory weightByPermission = _disapprovalWeightByPermission[i];

                // TODO: @theo is it possible to have a check to see if a permission signature is in use?
                // This would return a bool
                if (!policy.isPermissionSignatureActive(weightByPermission.permissionSignature)) revert InvalidPermissionSignature();

                if (weightByPermission.weight > 0) {
                    disapprovalPermissions.push(weightByPermission.permissionSignature);
                }
                disapprovalWeightByPermission[weightByPermission.permissionSignature] = weightByPermission.weight;
            }
        }

        emit NewStrategyCreated();
    }

    modifier onlyVertexRouter() {
        if (msg.sender != address(router)) revert OnlyVertexRouter();
        _;
    }

    /// @inheritdoc IVertexStrategy
    function isActionPassed(uint256 actionId) external view override returns (bool) {
        IVertexRouter.ActionWithoutVotes memory action = router.getActionWithoutVotes(actionId);
        // TODO: Needs to account for endBlockNumber = 0 (strategies that do not require votes)
        // TODO: Needs to account for both fixedVotingPeriod's
        //       if true then action cannot pass before voting period ends
        //       if false then action can pass before voting period ends
        // Handle all the math to determine if the vote has passed based on this strategies quorum settings.
        return isVoteQuorumValid(action.startBlockNumber, action.forVotes);
    }

    /// @inheritdoc IVertexStrategy
    function isActionCanceletionValid(uint256 actionId) external view override returns (bool) {
        IVertexRouter.ActionWithoutVotes memory action = router.getActionWithoutVotes(actionId);
        // TODO: Use this action's properties to determine if it is eligible for cancelation
        // TODO: Needs to account for strategies that do not allow vetoes
        // Handle all the math to determine if the veto has passed based on this strategies quorum settings.
        return isVetoQuorumValid(action.startBlockNumber, action.forVetoVotes);
    }

    /// @inheritdoc IVertexStrategy
    function getVotePowerAt(address policyHolder, uint256 blockNumber) external view returns (uint256) {
        uint256 voteLength = approvalPermissions.length;
        unchecked {
            for (uint256 i; i < voteLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use?
                // This would return a bool
                if (policy.holderHasPermission(policyHolder, approvalPermissions[i], blockNumber)) {
                    return approvalWeightByPermission[approvalPermissions[i]];
                }
            }
        }

        return approvalWeightByPermission[DEFAULT_OPERATOR];
    }

    /// @inheritdoc IVertexStrategy
    function getVetoPowerAt(address policyHolder, uint256 blockNumber) external view returns (uint256) {
        uint256 vetoLength = disapprovalPermissions.length;
        unchecked {
            for (uint256 i; i < vetoLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use at a blockNumber?
                // This would return a bool
                if (policy.holderHasPermission(policyHolder, disapprovalPermissions[i], blockNumber)) {
                    return disapprovalWeightByPermission[disapprovalPermissions[i]];
                }
            }
        }

        return disapprovalWeightByPermission[DEFAULT_OPERATOR];
    }

    /// @inheritdoc IVertexStrategy
    function getTotalVoteSupplyAt(uint256 blockNumber) public view returns (uint256) {
        if (approvalWeightByPermission[DEFAULT_OPERATOR] > 0) {
            return policy.totalSupply();
        }

        // TODO: @theo I'm simplifying things here. We can chat about the best way to actual implement this.
        // This would return a uint of all the policyholders that have these permissions at a certain block height
        policy.getSupplyByPermissions(approvalPermissions, blockNumber);
    }

    /// @inheritdoc IVertexStrategy
    function getTotalDisapprovalSupplyAt(uint256 blockNumber) public view returns (uint256) {
        if (disapprovalWeightByPermission[DEFAULT_OPERATOR] > 0) {
            return policy.totalSupply();
        }

        // TODO: @theo I'm simplifying things here. We can chat about the best way to actual implement this.
        // This would return a uint of all the policyholders that have these permissions at a certain block height
        policy.getSupplyByPermissions(disapprovalPermissions, blockNumber);
    }

    /// @inheritdoc IVertexStrategy
    function isVoteQuorumValid(uint256 blockNumber, uint256 forVotes) public view returns (bool) {
        uint256 votingSupply = getTotalVoteSupplyAt(blockNumber);
        return forVotes >= getMinimumWeightNeeded(votingSupply, minApprovalPct);
    }

    /// @inheritdoc IVertexStrategy
    function isVetoQuorumValid(uint256 blockNumber, uint256 forVotes) public view returns (bool) {
        uint256 vetoSupply = getTotalDisapprovalSupplyAt(blockNumber);
        return forVotes >= getMinimumWeightNeeded(vetoSupply, minDisapprovalPct);
    }

    /// @inheritdoc IVertexStrategy
    function getMinimumWeightNeeded(uint256 voteSupply, uint256 minPercentage) public view returns (uint256) {
        // NOTE: Need to actual implement proper floating point math here
        // minPercentage (will either be minApprovalPct or minDisapprovalPct) is the percent quorum needed and so this returns the votes in number form
        // we should round this up to the nearest integer
        return voteSupply.mul(minPercentage).div(ONE_HUNDRED_WITH_PRECISION);
    }
}
