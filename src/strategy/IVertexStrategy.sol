// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCore} from "src/core/IVertexCore.sol";

interface IVertexStrategy {
    /**
     * @dev emitted when a new strategy is deployed.
     *
     */
    event NewStrategyCreated();

    /**
     * @dev Returns the approval power of a policyHolder at a specific block number.
     * @param policyHolder Address of the policyHolder
     * @param blockNumber block number at which to fetch approval power
     * @return approval power number
     *
     */
    function getApprovalWeightAt(address policyHolder, uint256 blockNumber) external view returns (uint256);

    /**
     * @dev Returns the disapproving power of a policyHolder at a specific block number.
     * @param policyHolder Address of the policyHolder
     * @param blockNumber block number at which to fetch disapproving power
     * @return disapproving power number
     *
     */
    function getDisapprovalWeightAt(address policyHolder, uint256 blockNumber) external view returns (uint256);

    /**
     * @dev Determine if an action is eligible for cancelation based on its id
     * @param actionId id of action
     * @return true if cancelation is valid
     *
     */
    function isActionCanceletionValid(uint256 actionId) external view returns (bool);

    /**
     * @dev Determine if the approval for this action passed
     * @param actionId id of action
     * @return true if action's approval passed
     *
     */
    function isActionPassed(uint256 actionId) external view returns (bool);

    /**
     * @dev Check whether an action has reached quorum, ie has enough approvals
     * @param approvals total weight of approvals
     * @param blockNumber action's startBlockNumber
     * @return true if has approval weight needed for action to be queued
     *
     */
    function isApprovalQuorumValid(uint256 approvals, uint256 blockNumber) external view returns (bool);

    /**
     * @dev Check whether an action has reached quorum, ie has enough disapprovals
     * @param disapprovals total weight of disapprovals
     * @param blockNumber action's startBlockNumber
     * @return true if has disapproval weight needed for action to pass
     *
     */
    function isDisapprovalQuorumValid(uint256 disapprovals, uint256 blockNumber) external view returns (bool);

    /**
     * @dev Calculates the minimum amount needed for an action to be queued or executed
     * @param supply Total number of NFTs eligible
     * @param minPercentage Min. percentage needed to pass
     * @return number needed for a proposal to pass
     *
     */
    function getMinimumAmountNeeded(uint256 supply, uint256 minPercentage) external pure returns (uint256);

    function getApprovalPermissions() external view returns (bytes32[] memory);

    function getDisapprovalPermissions() external view returns (bytes32[] memory);
}
