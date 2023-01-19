// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";

// Errors
error OnlyVertexRouter();
error InvalidPermissionSignature();
error InvalidVoteConfiguration();
error InvalidVetoConfiguration();

contract VertexStrategy is IVertexStrategy, {
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
    uint256 public immutable votingDuration;

    /// @notice Policy NFT for this Vertex Instance.
    VertexPolicyNFT public immutable policy;

    /// @notice Minimum percentage of FOR-voting-power supply / getTotalVoteSupplyAt at startBlockNumber of action to pass vote.
    uint256 public immutable override minVotes;

    /// @notice Minimum percentage of FOR-vetoing-power supply / getTotalVetoSupplyAt at startBlockNumber of action to pass veto.
    uint256 public immutable override minVetoVotes;

    /// @notice Mapping of permission signatures to their vote power. DEFAULT_OPERATOR is used as a catch all.
    mapping(bytes32 => uint248) public votePowerByPermissionSig;

    /// @notice Mapping of permission signatures to their veto power. DEFAULT_OPERATOR is used as a catch all.
    mapping(bytes32 => uint248) public vetoPowerByPermissionSig;

    /// @notice List of all permission signatures that are eligible for voting.
    bytes32[] public votePermissionSigs;

    /// @notice List of all permission signatures that are eligible for vetoing.
    bytes32[] public vetoPermissionSigs;

    constructor(
        uint256 _executionDelay,
        uint256 _expirationDelay,
        bool _isFixedLengthApprovalPeriod,
        uint256 _votingDuration,
        VertexPolicyNFT _policy,
        IVertexRouter _router,
        uint256 _minVotes,
        uint256 _minVetoVotes,
        // TODO: Order is critical here. Voting power short circuits at the first specific permission match.
        VotePowerByPermission[] memory _votePowerByPermission,
        VetoPowerByPermission[] memory _vetoPowerByPermission
    ) {
        _executionDelay = __executionDelay;
        expirationDelay = _expirationDelay;
        isFixedLengthApprovalPeriod = _isFixedLengthApprovalPeriod;
        votingDuration = _votingDuration;
        policy = _policy;
        router = _router;
        minVotes = _minVotes;
        minVetoVotes = _minVetoVotes;

        if (
            _votePowerByPermission[0].permissionSignature == DEFAULT_OPERATOR &&
            _votePowerByPermission[0].votingPower == 0 &&
            _votePowerByPermission.length == 1
        ) revert InvalidVoteConfiguration();

        if (
            _vetoPowerByPermission[0].permissionSignature == DEFAULT_OPERATOR &&
            _vetoPowerByPermission[0].votingPower == 0 &&
            _vetoPowerByPermission.length == 1
        ) revert InvalidVetoConfiguration();

        // Initialize to 1, could be overwritten below
        votePowerByPermissionSig[DEFAULT_OPERATOR] = 1;
        vetoPowerByPermissionSig[DEFAULT_OPERATOR] = 1;

        uint256 voteLength = _votePowerByPermission.length;
        unchecked {
            for (uint256 i; i < voteLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use?
                // This would return a bool
                if (!policy.isPermissionSignatureActive(_votePowerByPermission[i].permissionSignature)) revert InvalidPermissionSignature();
                if (_votePowerByPermission[i].votingPower > 0) {
                    votePermissionSigs.push(_votePowerByPermission[i].permissionSignature);
                }
                votePowerByPermissionSig[_votePowerByPermission[i].permissionSignature] = _votePowerByPermission[i].votingPower;
            }
        }

        uint256 vetoLength = _vetoPowerByPermission.length;
        unchecked {
            for (uint256 i; i < vetoLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use?
                // This would return a bool
                if (!policy.isPermissionSignatureActive(_vetoPowerByPermission[i].permissionSignature)) revert InvalidPermissionSignature();
                if (_vetoPowerByPermission[i].votingPower > 0) {
                    vetoPermissionSigs.push(_vetoPowerByPermission[i].permissionSignature);
                }
                vetoPowerByPermissionSig[_vetoPowerByPermission[i].permissionSignature] = _vetoPowerByPermission[i].votingPower;
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
        uint256 voteLength = votePermissionSigs.length;
        unchecked {
            for (uint256 i; i < voteLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use?
                // This would return a bool
                if (policy.holderHasPermission(policyHolder, votePermissionSigs[i], blockNumber)) {
                    return votePowerByPermissionSig[votePermissionSigs[i]];
                }
            }
        }

        return votePowerByPermissionSig[DEFAULT_OPERATOR];
    }

    /// @inheritdoc IVertexStrategy
    function getVetoPowerAt(address policyHolder, uint256 blockNumber) external view returns (uint256) {
        uint256 vetoLength = vetoPermissionSigs.length;
        unchecked {
            for (uint256 i; i < vetoLength; ++i) {
                // TODO: @theo is it possible to have a check to see if a permission signature is in use at a blockNumber?
                // This would return a bool
                if (policy.holderHasPermission(policyHolder, vetoPermissionSigs[i], blockNumber)) {
                    return vetoPowerByPermissionSig[vetoPermissionSigs[i]];
                }
            }
        }

        return vetoPowerByPermissionSig[DEFAULT_OPERATOR];
    }

    /// @inheritdoc IVertexStrategy
    function getTotalVoteSupplyAt(uint256 blockNumber) external view returns (uint256) {
        if (votePowerByPermissionSig[DEFAULT_OPERATOR] > 0) {
            return policy.totalSupply();
        }

        // TODO: @theo I'm simplifying things here. We can chat about the best way to actual implement this.
        // This would return a uint of all the policyholders that have these permissions at a certain block height
        policy.getSupplyByPermissions(votePermissionSigs, blockNumber);
    }

    /// @inheritdoc IVertexStrategy
    function getTotalVetoSupplyAt(uint256 blockNumber) external view returns (uint256) {
        if (vetoPowerByPermissionSig[DEFAULT_OPERATOR] > 0) {
            return policy.totalSupply();
        }

        // TODO: @theo I'm simplifying things here. We can chat about the best way to actual implement this.
        // This would return a uint of all the policyholders that have these permissions at a certain block height
        policy.getSupplyByPermissions(vetoPermissionSigs, blockNumber);
    }

    /// @inheritdoc IVertexStrategy
    function isVoteQuorumValid(uint256 blockNumber, uint256 forVotes) external view returns (bool) {
        uint256 votingSupply = getTotalVoteSupplyAt(blockNumber);
        return forVotes >= getMinimumPowerNeeded(votingSupply, minVotes);
    }

    /// @inheritdoc IVertexStrategy
    function isVetoQuorumValid(uint256 blockNumber, uint256 forVotes) external view returns (bool) {
        uint256 vetoSupply = getTotalVetoSupplyAt(blockNumber);
        return forVotes >= getMinimumPowerNeeded(vetoSupply, minVetoVotes);
    }

    /// @inheritdoc IVertexStrategy
    function getMinimumPowerNeeded(uint256 voteSupply, uint256 minPercentage) external view returns (uint256) {
        // NOTE: Need to actual implement proper floating point math here
        // minPercentage (will either be minVotes or minVetoVotes) is the percent quorum needed and so this returns the votes in number form
        // we should round this up to the nearest integer
        return voteSupply.mul(minPercentage).div(ONE_HUNDRED_WITH_PRECISION);
    }
}
