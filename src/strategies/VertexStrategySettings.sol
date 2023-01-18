// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexStrategySettings} from "src/strategies/IVertexStrategySettings.sol";
import {VotePowerByPermission} from "src/strategies/VertexStrategy.sol";
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
    IVertexRouter public immutable router;

    uint256 public immutable votingDuration;
    VertexPolicyNFT public immutable policy;
    uint256 public immutable override voteDifferential;
    uint256 public immutable override vetoVoteDifferential;
    uint256 public immutable override minimumVoteQuorum;
    uint256 public immutable override minimumVetoQuorum;

    mapping(bytes32 => uint248) public votePowerByPermissionSig;

    mapping(bytes32 => uint248) public vetoPowerByPermissionSig;

    constructor(
        uint256 _votingDuration,
        VertexPolicyNFT _policy,
        IVertexRouter _router,
        uint256 _voteDifferential,
        uint256 _vetoVoteDifferential,
        uint256 _minimumVoteQuorum,
        uint256 _minimumVetoQuorum,
        VotePowerByPermission[] memory _votePowerByPermission,
        VetoPowerByPermission[] memory _vetoPowerByPermission
    ) {
        votingDuration = _votingDuration;
        policy = _policy;
        router = _router;
        voteDifferential = _voteDifferential;
        vetoVoteDifferential = _vetoVoteDifferential;
        minimumVoteQuorum = _minimumVoteQuorum;
        minimumVetoQuorum = _minimumVetoQuorum;

        // TODO: Need to add validation to ensure you can't brick your contract (eg. permission signatures should be valid, 1 token 1 vote should be default)
        uint256 voteLength = _votePowerByPermission.length;
        unchecked {
            for (uint256 i; i < voteLength; ++i) {
                votePowerByPermissionSig[_votePowerByPermission[i].permissionSignature] = _votePowerByPermission[i].votingPower;
            }
        }

        uint256 vetoLength = _vetoPowerByPermission.length;
        unchecked {
            for (uint256 i; i < vetoLength; ++i) {
                vetoPowerByPermissionSig[_vetoPowerByPermission[i].permissionSignature] = _vetoPowerByPermission[i].votingPower;
            }
        }
    }

    modifier onlyVertexRouter() {
        if (msg.sender != address(router)) revert OnlyVertexRouter();
        _;
    }

    /// @inheritdoc IVertexStrategySettings
    function isActionPassed(uint256 actionId) external view override returns (bool) {
        IVertexRouter.ActionWithoutVotes memory action = router.getActionWithoutVotes(actionId);
        // TODO: Needs to account for votingEndTime = 0 (strategies that do not require votes)
        // TODO: Needs to account for both fixedVotingPeriod's
        //       if true then action cannot pass before voting period ends
        //       if false then action can pass before voting period ends
        // But handle all the math to determine if the vote has passed based on this strategies quorum settings.
    }

    /// @inheritdoc IVertexStrategySettings
    function isActionCanceletionValid(uint256 actionId) external view override returns (bool) {
        IVertexRouter.ActionWithoutVotes memory action = router.getActionWithoutVotes(actionId);
        // TODO: Use this action's properties to determine if it is eligible for cancelation
        // TODO: Needs to account for strategies that do not allow vetoes
        // Handle all the math to determine if the veto has passed based on this strategies quorum settings.
    }

    /// @inheritdoc IVertexStrategySettings
    function getVotePowerAt(address policyHolder, uint256 blockNumber) external view returns (uint256) {
        // TODO: This function needs to define the logic that calculates a policyHolder's veto power
        // based on their policy at a specific blockNumber. It requires VertexPolicyNFT to implement
        // ERC721Votes. votePowerByPermissionSig[0xfff...] sets the base voting power. Just set this to indicate
        // this strategy uses 1 token 1 vote, set it 0 and set votingPower of individual permissionSignatures to implement more custom strategies.
    }

    /// @inheritdoc IVertexStrategySettings
    function getVetoPowerAt(address policyHolder, uint256 blockNumber) external view returns (uint256) {
        // TODO: This function needs to define the logic that calculates a policyHolder's veto power
        // based on their policy at a specific blockNumber. It requires VertexPolicyNFT to implement
        // ERC721Votes. votePowerByPermissionSig[0xfff...] sets the base voting power. Just set this to indicate
        // this strategy uses 1 token 1 vote, set it 0 and set votingPower of individual permissionSignatures to implement more custom strategies.
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
