// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCore} from "src/core/IVertexCore.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";

///@dev Struct to define a permission
struct Permission {
    address target;
    bytes4 selector;
    address executor;
}

struct Approval {
    bool support; // is policyholder supporting this approval.
    uint248 weight; // weight of policyholder's support.
}

struct Disapproval {
    bool support; // is policyholder supporting this disapproval.
    uint248 weight; // weight of policyholder's support.
}

struct Action {
    address creator; // msg.sender of createAction.
    bool executed; // has action executed.
    bool canceled; // is action canceled.
    VertexStrategy strategy; // strategy that determines the validation process of this action.
    address target; // The contract called when the action is executed
    uint256 value; // The value in wei to be sent when the action is executed.
    bytes4 selector; // The function selector that will be called when the action is executed.
    bytes data; //  The encoded arguments to be passed to the function that is called when the action is executed.
    uint256 createdBlockNumber; // The block number of action creation (used for policy snapshots).
    uint256 executionTime; // Only set when an action is queued. The timestamp when action exection can begin.
    uint256 totalApprovals; // The total weight of policyholder approvals.
    uint256 totalDisapprovals; // The total weight of policyholder disapprovals.
    uint256 approvalPolicySupply; // The total amount of policyholders eligible to approve.
    uint256 disapprovalPolicySupply; // The total amount of policyholders eligible to disapprove.
}

struct WeightByPermission {
    bytes32 permissionSignature; // Policyholder's permission signature.
    uint248 weight; // Approval or disapproval weight of policyholder.
}

struct Strategy {
    uint256 approvalPeriod; // The length of time of the approval period.
    uint256 queuingDuration; // The length of time of the queuing period. The disapproval period is the queuing period when enabled.
    uint256 expirationDelay; // The length of time an action can be executed before it expires.
    bool isFixedLengthApprovalPeriod; // Determines if an action be queued before approvalEndTime.
    uint256 minApprovalPct; // Minimum percentage of total approval weight / total approval supply.
    uint256 minDisapprovalPct; // Minimum percentage of total disapproval weight / total disapproval supply.
    WeightByPermission[] approvalWeightByPermission; // List of permissionSignatures and weights that define the validation process for approval.
    WeightByPermission[] disapprovalWeightByPermission; // List of permissionSignatures and weights that define the validation process for disapproval.
}
