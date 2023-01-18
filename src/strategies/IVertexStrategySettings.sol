// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";

interface IVertexStrategySettings {
    struct VotePowerByPermission {
        bytes32 permissionSignature;
        uint248 votingPower;
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
     * @dev Check whether an action has enough extra FOR-votes than AGAINST-votes
     * FOR VOTES - AGAINST VOTES > voteDifferential * voting supply
     * @param actionId Id of the action to verify
     * @return true if enough For-Votes
     **/
    function isVoteDifferentialValid(uint256 actionId) external view returns (bool);

    /**
     * @dev Check whether an action has enough extra FOR-vetoes than AGAINST-vetoes
     * FOR VETOVOTES - AGAINST VETOVOTES > vetoVoteDifferential * voting supply
     * @param actionId Id of the action to verify
     * @return true if enough For-vetoes
     **/
    function isVetoDifferentialValid(uint256 actionId) external view returns (bool);

    /**
     * @dev Calculates the minimum amount of Voting Power needed for a proposal to Pass
     * @param votingSupply Total number of oustanding vote tokens
     * @return voting power needed for a proposal to pass
     **/
    function getMinimumVotePowerNeeded(uint256 votingSupply) external view returns (uint256);

    /**
     * @dev Calculates the minimum amount of Vetoing Power needed for a proposal to be vetoed
     * @param votingSupply Total number of oustanding veto tokens
     * @return vetoing power needed for a proposal to pass
     **/
    function getMinimumVetoPowerNeeded(uint256 votingSupply) external view returns (uint256);

    /**
     * @dev Get the vote differential threshold constant value
     * to compare with % of for votes/total supply - % of against votes/total supply
     * @return the vote differential threshold value (100 <=> 1%)
     **/
    function voteDifferential()
        external
        view
        returns (
            uint256
        ); /**
    
     * @dev Get the veto differential threshold constant value
     * to compare with % of for vetoes/total supply - % of against vetoes/total supply
     * @return the veto differential threshold value (100 <=> 1%)
     **/

    function vetoVoteDifferential() external view returns (uint256);

    /**
     * @dev Get quorum threshold constant value for voting
     * to compare with % of for votes/total supply
     * @return the quorum threshold value (100 <=> 1%)
     **/
    function minimumVoteQuorum() external view returns (uint256);

    /**
     * @dev Get quorum threshold constant value for vetoing
     * to compare with % of for vetoes/total supply
     * @return the quorum threshold value (100 <=> 1%)
     **/
    function minimumVetoQuorum() external view returns (uint256);
}
