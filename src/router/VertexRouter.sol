// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Governor, IGovernor} from "@openzeppelin/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes, IVotes} from "@openzeppelin/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/governance/extensions/GovernorVotesQuorumFraction.sol";
import {VertexVotingStrategy} from "src/strategies/VertexVotingStrategy.sol";
import {VertexStrategyControl} from "src/router/VertexStrategyControl.sol";
import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";
import {IVertexRouter} from "src/router/IVertexRouter.sol";

error OnlyCancelBeforeExecuted();
error OnlyCreaterCanCancel();
error InvalidActionId();
error OnlyQueuedActions();

contract VertexRouter is IVertexRouter {
    uint256 private _actionsCount;
    mapping(uint256 => Action) private _actions;
    mapping(address => bool) private _authorizedStrategies;

    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    string public immutable name;

    constructor(address[] memory strategies, string calldata _name) {
        name = _name;
        addStrategies(strategies);
    }

    function createAction(
        IVertexStrategy strategy,
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata callData
    ) external override returns (uint256) {
        if (isStrategyAuthorized(address(strategy))) {
            revert InvalidStrategy();
        }

        // TODO: Validate msg.sender's VertexPolicyNFT

        uint256 previousActionCount = _actionsCount;

        Action storage newAction = _actions[previousActionCount];
        newAction.id = previousActionCount;
        newAction.creator = msg.sender;
        newAction.strategy = strategy;
        newAction.target = target;
        newAction.value = value;
        newAction.signature = signature;
        newAction.callData = callData;

        _actionsCount++;

        strategy.createAction(target, value, signature, callData);

        emit ActionCreated(previousActionCount, msg.sender, strategy, target, value, signature, callData);

        return newAction.id;
    }

    function cancelAction(uint256 actionId) external override {
        ActionState state = getActionState(actionId);
        if (state == ProposalState.Executed || state == ProposalState.Canceled || state == ProposalState.Expired) {
            revert OnlyCancelBeforeExecuted();
        }

        Action storage action = _actions[actionId];

        if (msg.sender != action.creator) {
            revert OnlyCreaterCanCancel();
        }

        action.canceled = true;

        action.strategy.cancelAction(action.target, action.value, action.signature, action.callData);

        emit ActionCanceled(proposalId);
    }

    /**
     * @dev Execute the action (If Action Queued)
     * @param actionId id of the action to execute
     **/
    function execute(uint256 actionId) external payable override {
        if (getActionState(actionId) != ActionState.Queued) revert OnlyQueuedActions();
        Action storage action = _actions[actionId];
        action.executed = true;
        action.strategy.executeAction(action.target, action.value, action.signature, action.callData);
        emit ActionExecuted(actionId, msg.sender, actionId.strategy, actionId.creator);
    }

    function getActionState(uint256 actionId) public view override returns (ActionState) {
        if (actionId >= _actionsCount) revert InvalidActionId();
        Action storage action = _actions[actionId];
        if (action.canceled) {
            return ActionState.Canceled;
        }
        // TODO: Complete getActionState logic
        // else if (block.number <= action.endBlock) {
        //     return ActionState.Active;
        // } else if (!IProposalValidator(address(action.executor)).isProposalPassed(this, proposalId)) {
        //     return ActionState.Failed;
        // } else if (action.executionTime == 0) {
        //     return ActionState.Succeeded;
        // } else if (action.executed) {
        //     return ActionState.Executed;
        // } else if (action.executor.isProposalOverGracePeriod(this, proposalId)) {
        //     return ActionState.Expired;
        // }
        else {
            return ActionState.Queued;
        }
    }

    /**
     * @dev Add new addresses to the list of authorized executors
     * @param executors list of new addresses to be authorized executors
     **/
    function authorizeExecutors(address[] memory executors) public override onlyOwner {
        for (uint256 i = 0; i < executors.length; i++) {
            _authorizeExecutor(executors[i]);
        }
    }

    /**
     * @dev Remove addresses to the list of authorized executors
     * @param executors list of addresses to be removed as authorized executors
     **/
    function unauthorizeExecutors(address[] memory executors) public override onlyOwner {
        for (uint256 i = 0; i < executors.length; i++) {
            _unauthorizeExecutor(executors[i]);
        }
    }

    /**
     * @dev Let the guardian abdicate from its priviledged rights
     **/
    function __abdicate() external override onlyGuardian {
        _guardian = address(0);
    }

    /**
     * @dev Getter of the current GovernanceStrategy address
     * @return The address of the current GovernanceStrategy contracts
     **/
    function getGovernanceStrategy() external view override returns (address) {
        return _governanceStrategy;
    }

    /**
     * @dev Returns whether an address is an authorized executor
     * @param executor address to evaluate as authorized executor
     * @return true if authorized
     **/
    function isExecutorAuthorized(address executor) public view override returns (bool) {
        return _authorizedExecutors[executor];
    }

    /**
     * @dev Getter the address of the guardian, that can mainly cancel proposals
     * @return The address of the guardian
     **/
    function getGuardian() external view override returns (address) {
        return _guardian;
    }

    /**
     * @dev Getter of the proposal count (the current number of proposals ever created)
     * @return the proposal count
     **/
    function getProposalsCount() external view override returns (uint256) {
        return _proposalsCount;
    }

    /**
     * @dev Getter of a proposal by id
     * @param proposalId id of the proposal to get
     * @return the proposal as ProposalWithoutVotes memory object
     **/
    function getProposalById(uint256 proposalId) external view override returns (ProposalWithoutVotes memory) {
        Proposal storage proposal = _proposals[proposalId];
        ProposalWithoutVotes memory proposalWithoutVotes = ProposalWithoutVotes({
            id: proposal.id,
            creator: proposal.creator,
            executor: proposal.executor,
            targets: proposal.targets,
            values: proposal.values,
            signatures: proposal.signatures,
            calldatas: proposal.calldatas,
            withDelegatecalls: proposal.withDelegatecalls,
            startBlock: proposal.startBlock,
            endBlock: proposal.endBlock,
            executionTime: proposal.executionTime,
            forVotes: proposal.forVotes,
            againstVotes: proposal.againstVotes,
            executed: proposal.executed,
            canceled: proposal.canceled,
            strategy: proposal.strategy,
            ipfsHash: proposal.ipfsHash
        });

        return proposalWithoutVotes;
    }

    /**
     * @dev Getter of the Vote of a voter about a proposal
     * Note: Vote is a struct: ({bool support, uint248 votingPower})
     * @param proposalId id of the proposal
     * @param voter address of the voter
     * @return The associated Vote memory object
     **/
    function getVoteOnProposal(uint256 proposalId, address voter) external view override returns (Vote memory) {
        return _proposals[proposalId].votes[voter];
    }

    /**
     * @dev Get the current state of a proposal
     * @param proposalId id of the proposal
     * @return The current state if the proposal
     **/
    function getProposalState(uint256 proposalId) public view override returns (ProposalState) {
        require(_proposalsCount >= proposalId, "INVALID_PROPOSAL_ID");
        Proposal storage proposal = _proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (!IProposalValidator(address(proposal.executor)).isProposalPassed(this, proposalId)) {
            return ProposalState.Failed;
        } else if (proposal.executionTime == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (proposal.executor.isProposalOverGracePeriod(this, proposalId)) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function _queueOrRevert(
        IExecutorWithTimelock executor,
        address target,
        uint256 value,
        string memory signature,
        bytes memory callData,
        uint256 executionTime,
        bool withDelegatecall
    ) internal {
        require(!executor.isActionQueued(keccak256(abi.encode(target, value, signature, callData, executionTime, withDelegatecall))), "DUPLICATED_ACTION");
        executor.queueTransaction(target, value, signature, callData, executionTime, withDelegatecall);
    }

    function _submitVote(address voter, uint256 proposalId, bool support) internal {
        require(getProposalState(proposalId) == ProposalState.Active, "VOTING_CLOSED");
        Proposal storage proposal = _proposals[proposalId];
        Vote storage vote = proposal.votes[voter];

        require(vote.votingPower == 0, "VOTE_ALREADY_SUBMITTED");

        uint256 votingPower = IVotingStrategy(proposal.strategy).getVotingPowerAt(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = proposal.forVotes.add(votingPower);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(votingPower);
        }

        vote.support = support;
        vote.votingPower = uint248(votingPower);

        emit VoteEmitted(proposalId, voter, support, votingPower);
    }

    function _setGovernanceStrategy(address governanceStrategy) internal {
        _governanceStrategy = governanceStrategy;

        emit GovernanceStrategyChanged(governanceStrategy, msg.sender);
    }

    function _setVotingDelay(uint256 votingDelay) internal {
        _votingDelay = votingDelay;

        emit VotingDelayChanged(votingDelay, msg.sender);
    }

    function _authorizeExecutor(address executor) internal {
        _authorizedExecutors[executor] = true;
        emit ExecutorAuthorized(executor);
    }

    function _unauthorizeExecutor(address executor) internal {
        _authorizedExecutors[executor] = false;
        emit ExecutorUnauthorized(executor);
    }
}
