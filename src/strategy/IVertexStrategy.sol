// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";

interface IVertexStrategy {
    /**
     * @dev emitted when a new strategy is deployed.
     **/
    event NewStrategyCreated();

    struct WeightByPermission {
        bytes32 permissionSignature;
        uint248 weight;
    }

    /**
     * @dev Returns the voting power of a policyHolder at a specific block number.
     * @param policyHolder Address of the policyHolder
     * @param blockNumber block number at which to fetch voting power
     * @return Voting power number
     **/
    function getVotePowerAt(address policyHolder, uint256 blockNumber) external view returns (uint256);

    /**
     * @dev Returns the vetoing power of a policyHolder at a specific block number.
     * @param policyHolder Address of the policyHolder
     * @param blockNumber block number at which to fetch vetoing power
     * @return Vetoing power number
     **/
    function getVetoPowerAt(address policyHolder, uint256 blockNumber) external view returns (uint256);

    /**
     * @dev Determine if an action is eligible for cancelation based on its id
     * @param actionId id of action
     * @return true if cancelation is valid
     **/
    function isActionCanceletionValid(uint256 actionId) external view returns (bool);

    /**
     * @dev Determine if the vote for this action passed
     * @param actionId id of action
     * @return true if action's vote passed
     **/
    function isActionPassed(uint256 actionId) external view returns (bool);

    /**
     * @dev Returns the total supply of policy NFTs at block number
     * @param blockNumber Blocknumber at which to evaluate
     * @return total supply at blockNumber
     **/
    function getTotalVoteSupplyAt(uint256 blockNumber) external view returns (uint256);

    /**
     * @dev Returns the total supply of policy NFTs at block number
     * @param blockNumber Blocknumber at which to evaluate
     * @return total supply at blockNumber
     **/
    function getTotalVetoSupplyAt(uint256 blockNumber) external view returns (uint256);

    /**
     * @dev Check whether an action has reached quorum, ie has enough FOR-voting-power
     * Here quorum is not to understand as number of votes reached, but number of for-votes reached
     * @param actionId Id of the action to verify
     * @return true if has voting power needed for action to pass
     **/
    function isVoteQuorumValid(uint256 actionId) external view returns (bool);

    /**
     * @dev Check whether an action has reached quorum, ie has enough FOR-vetoing-power
     * Here quorum is not to understand as number of vetoes reached, but number of for-vetoes reached
     * @param actionId Id of the action to verify
     * @return true if has veoting power needed for action to be vetoed
     **/
    function isVetoQuorumValid(uint256 actionId) external view returns (bool);

    /**
     * @dev Calculates the minimum amount of Voting Power needed for a proposal to Pass
     * @param votingSupply Total number of oustanding vote tokens
     * @param minPercentage Min. percentage needed to pass
     * @return voting power needed for a proposal to pass
     **/
    function getMinimumPowerNeeded(uint256 votingSupply, uint256 minPercentage) external view returns (uint256);
}
