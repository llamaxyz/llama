// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexStrategySettings} from "src/strategies/IVertexStrategySettings.sol";
import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";

// Errors
error OnlyVertexRouter();

/**
 * @title Action Validator abstract Contract, inherited by  Vertex strategies
 * @dev Validates/Invalidates action state transitions.
 * Voting Power functions: Validates success of actions.
 * Veto Power functions: Validates whether an action can be vetoed
 * @author Llama
 **/
abstract contract VertexStrategySettings is IVertexStrategySettings {
    /// @notice Router of this Vertex instance.
    address public immutable router;

    uint256 public immutable votingDuration;
    VertexPolicyNFT public immutable policy;
    uint256 public immutable override voteDifferential;
    uint256 public immutable override vetoVoteDifferential;
    uint256 public immutable override minimumVoteQuorum;
    uint256 public immutable override minimumVetoQuorum;

    constructor(
        uint256 _votingDuration,
        VertexPolicyNFT _policy,
        address _router,
        uint256 _voteDifferential,
        uint256 _vetoVoteDifferential,
        uint256 _minimumVoteQuorum,
        uint256 _minimumVetoQuorum
    ) {
        votingDuration = _votingDuration;
        policy = _policy;
        router = _router;
        voteDifferential = _voteDifferential;
        vetoVoteDifferential = _vetoVoteDifferential;
        minimumVoteQuorum = _minimumVoteQuorum;
        minimumVetoQuorum = _minimumVetoQuorum;
    }

    modifier onlyVertexRouter() {
        if (msg.sender != router) revert OnlyVertexRouter();
        _;
    }

    /// @inheritdoc IVertexStrategySettings
    function isActionPassed(uint256 actionId) external view override returns (bool) {
        // TODO: Needs to account for votingEndTime = 0 (strategies that do not require votes)
        // TODO: Needs to account for both fixedVotingPeriod's
        //       if true then action cannot pass before voting period ends
        //       if false then action can pass before voting period ends
    }

    /// @inheritdoc IVertexStrategySettings
    function isActionCanceletionValid(uint256 actionId) external view override returns (bool) {
        IVertexRouter.ActionWithoutVotes memory action = router.getActionWithoutVotes(actionId);
        // TODO: Use this action's properties to determine if it is eligible for cancelation
    }

    /// @inheritdoc IVertexStrategySettings
    function getVotePowerAt(address policyHolder, uint256 blockNumber) external view returns (uint256) {
        // TODO: This function needs to define the logic that calculates a policyHolder's vote power
        // based on their policy at a specific blockNumber. It requires VertexPolicyNFT to implement
        // ERC721Votes.
    }

    /// @inheritdoc IVertexStrategySettings
    function getVetoPowerAt(address policyHolder, uint256 blockNumber) external view returns (uint256) {
        // TODO: This function needs to define the logic that calculates a policyHolder's veto power
        // based on their policy at a specific blockNumber. It requires VertexPolicyNFT to implement
        // ERC721Votes.
    }

    /// @inheritdoc IVertexStrategySettings
    function getTotalVoteSupplyAt(uint256 blockNumber) external view returns (uint256) {
        // TODO: Not sure if we even needs to define a getter here. We can just query
        // the NFT contract directly to get totalSupply at different blockNumbers.
    }

    /// @inheritdoc IVertexStrategySettings
    function getTotalVetoSupplyAt(uint256 blockNumber) external view returns (uint256) {
        // TODO: Not sure if we need a separate getter for veto supply. We should allow customers to use
        // different rules for voting and vetoing but I'm sure we can share a lot of the same logic.
    }

    /// @inheritdoc IVertexStrategySettings
    function isVoteQuorumValid(uint256 actionId) external view returns (bool) {
        // TODO: Need to implement rules for determining a valid quorum.
        // All of these view functions should be fully configurable. Meaning they
        // contain the same logic but are dictated solely by the constructor arguments.
    }

    /// @inheritdoc IVertexStrategySettings
    function isVetoQuorumValid(uint256 actionId) external view returns (bool) {
        // TODO: Need to implement rules for determining a valid veto quorum.
        // All of these view functions should be fully configurable. Meaning they
        // contain the same logic but are dictated solely by the constructor arguments.
    }

    /// @inheritdoc IVertexStrategySettings
    function isVoteDifferentialValid(uint256 actionId) external view returns (bool) {
        // TODO: Need to implement rules for determining a valid vote differential.
        // All of these view functions should be fully configurable. Meaning they
        // contain the same logic but are dictated solely by the constructor arguments.
    }

    /// @inheritdoc IVertexStrategySettings
    function isVetoDifferentialValid(uint256 actionId) external view returns (bool) {
        // TODO: Need to implement rules for determining a valid veto differential.
        // All of these view functions should be fully configurable. Meaning they
        // contain the same logic but are dictated solely by the constructor arguments.
    }

    /// @inheritdoc IVertexStrategySettings
    function getMinimumVotePowerNeeded(uint256 votingSupply) external view returns (uint256) {
        // NOTE: Unsure if we need this one for both voting and vetoing. My guess is that we can simplify voting
        // and vetoing a lot.
    }

    /// @inheritdoc IVertexStrategySettings
    function getMinimumVetoPowerNeeded(uint256 votingSupply) external view returns (uint256) {
        // NOTE: Unsure if we need this one for both voting and vetoing. My guess is that we can simplify voting
        // and vetoing a lot.
    }
}
