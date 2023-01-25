// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCore} from "src/core/IVertexCore.sol";

interface IVertexStrategy {
    event NewStrategyCreated();

    /// @notice Get whether an action has passed the approval process.
    /// @param actionId id of the action.
    /// @return Boolean value that is true if the action has passed the approval process.
    function isActionPassed(uint256 actionId) external view returns (bool);

    /// @notice Get whether an action has eligible to be canceled.
    /// @param actionId id of the action.
    /// @return Boolean value that is true if the action can be canceled.
    function isActionCanceletionValid(uint256 actionId) external view returns (bool);

    /// @notice Get the weight of an approval of a policyholder at a specific block number.
    /// @param policyholder Address of the policyholder.
    /// @param blockNumber The block number at which to get the approval weight.
    /// @return The weight of the policyholder's approval.
    function getApprovalWeightAt(address policyholder, uint256 blockNumber) external view returns (uint256);

    /// @notice Get the weight of a disapproval of a policyholder at a specific block number.
    /// @param policyholder Address of the policyholder.
    /// @param blockNumber The block number at which to get the disapproval weight.
    /// @return The weight of the policyholder's disapproval.
    function getDisapprovalWeightAt(address policyholder, uint256 blockNumber) external view returns (uint256);

    /// @notice Determine if the total weight of policyholders in support of an approval has reached quorum.
    /// @param approvals total weight of approvals
    /// @param blockNumber The block number at which to determine policyholder's approval weight.
    /// @return Boolean value that is true if the approval of an action has reached quorum.
    function isApprovalQuorumValid(uint256 approvals, uint256 blockNumber) external view returns (bool);

    /// @notice Determine if the total weight of policyholders in support of a disapproval has reached quorum.
    /// @param disapprovals total weight of disapprovals
    /// @param blockNumber The block number at which to determine policyholder's disapproval weight.
    /// @return Boolean value that is true if the disapproval of an action has reached quorum.
    function isDisapprovalQuorumValid(uint256 disapprovals, uint256 blockNumber) external view returns (bool);

    /// @notice Determine the minimum weight needed for an action to reach quorum.
    /// @param supply Total number of policyholders eligible for participation.
    /// @param minPercentage Minimum percentage needed to reach quorum.
    /// @return The total weight needed to reach quorum.
    function getMinimumAmountNeeded(uint256 supply, uint256 minPercentage) external pure returns (uint256);

    /// @notice Get the list of all permission signatures that are eligible for approvals.
    /// @return The list of all permission signatures that are eligible for approvals.
    function getApprovalPermissions() external view returns (bytes8[] memory);

    /// @notice Get the list of all permission signatures that are eligible for disapprovals.
    /// @return The list of all permission signatures that are eligible for disapprovals.
    function getDisapprovalPermissions() external view returns (bytes8[] memory);
}
