// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";
import {IStrategySettings} from "src/strategies/IStrategySettings.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {VertexExecutor} from "src/executor/VertexExecutor.sol";
import {getChainId} from "src/utils/Helpers.sol";

// Errors
error OnlyCancelBeforeExecuted();
error InvalidActionId();
error OnlyQueuedActions();
error InvalidStateForQueue();
error DuplicateAction();
error ActionCannotBeCanceled();
error OnlyExecutor();
error VotingClosed();
error VoteAlreadySubmitted();
error InvalidSignature();
error VetoAlreadySubmitted();

/// @title VertexRouter
/// @author Llama (vertex@llama.xyz)
/// @notice Main point of interaction with a Vertex instance.
contract VertexRouter is IVertexRouter {
    /// @notice Name of this Vertex instance.
    string public immutable name;

    /// @notice The current number of actions created.
    uint256 public actionsCount;

    /// @notice Mapping of action ids to Actions.
    mapping(uint256 => Action) public actions;

    /// @notice The NFT contract that defines the policies for this Vertex instance.
    VertexPolicyNFT public immutable policy;

    /// @notice The NFT contract that defines the policies for this Vertex instance.
    VertexExecutor public immutable executor;

    /// @notice Mapping of all authorized strategies.
    mapping(IVertexStrategy => bool) public authorizedStrategies;

    // TODO: Do we need an onchain way to access all strategies? Ideally not but will keep this as a placeholder.
    /// @notice Array of authorized strategies.
    // IVertexStrategy[] public strategies;

    /// @notice EIP-712 typehashes.
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant VOTE_EMITTED_TYPEHASH = keccak256("VoteEmitted(uint256 id,bool support)");
    bytes32 public constant VETO_EMITTED_TYPEHASH = keccak256("VetoEmitted(uint256 id,bool support)");

    constructor(string calldata _name) {
        name = _name;

        // TODO: We will use CREATE2 to deterministically deploy the VertexPolicyNFT,
        // all initial strategies, and the executor. These contracts can be fully confgiured
        // from their constructors. We will then use these addresses to set the policy,
        // authorizedStrategies, and executor.
    }

    modifier onlyVertexExecutor() {
        if (msg.sender != executor) revert OnlyExecutor();
        _;
    }

    /// @inheritdoc IVertexRouter
    function createAction(
        IVertexStrategy strategy,
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data
    ) external override returns (uint256) {
        if (!authorizedStrategies[strategy]) revert InvalidStrategy();

        // TODO: @theo insert validation logic here
        // Eg. is msg.sender a VertexPolicyNFT holder and does
        //     their policy allow them create an action with this
        //     strategy, target, signature hash. You also probably
        //     want to validate their policy at the previous block number

        uint256 previousActionCount = actionsCount;
        Action storage newAction = actions[previousActionCount];
        newAction.id = previousActionCount;
        newAction.creator = msg.sender;
        newAction.strategy = strategy;
        newAction.target = target;
        newAction.value = value;
        newAction.signature = signature;
        newAction.data = data;
        newAction.votingStartTime = block.timestamp;
        newAction.votingEndTime = block.timestamp + IStrategySettings(strategy).votingDuration();

        actionsCount++;

        emit ActionCreated(previousActionCount, msg.sender, strategy, target, value, signature, data);

        return newAction.id;
    }

    /// @inheritdoc IVertexRouter
    function cancelAction(uint256 actionId) external override {
        ActionState state = getActionState(actionId);
        if (state == ActionState.Executed || state == ActionState.Canceled || state == ActionState.Expired) {
            revert OnlyCancelBeforeExecuted();
        }

        Action storage action = actions[actionId];
        if (!(msg.sender == action.creator || IStrategySettings(action.strategy).isActionCanceletionValid(action))) revert ActionCannotBeCanceled();

        action.canceled = true;
        action.strategy.cancelAction(actionId);

        emit ActionCanceled(actionId);
    }

    /// @inheritdoc IVertexRouter
    function queueAction(uint256 actionId) external override {
        if (getActionState(actionId) != ActionState.Succeeded) revert InvalidStateForQueue();
        Action storage action = actions[actionId];
        uint256 executionTime = block.timestamp + action.strategy.delay();

        if (action.strategy.queuedActions(keccak256(abi.encode(action.target, action.value, action.signature, action.data)))) revert DuplicateAction();
        action.strategy.queueAction(action.target, action.value, action.signature, action.data, executionTime);

        action.executionTime = executionTime;

        emit ActionQueued(actionId, msg.sender, action.strategy, action.creator, executionTime);
    }

    /// @inheritdoc IVertexRouter
    function executeAction(uint256 actionId) external payable override {
        if (getActionState(actionId) != ActionState.Queued) revert OnlyQueuedActions();
        Action storage action = actions[actionId];
        action.executed = true;
        action.strategy.executeAction(action.target, action.value, action.signature, action.data, action.executionTime);
        emit ActionExecuted(actionId, msg.sender, actionId.strategy, actionId.creator);
    }

    /// @inheritdoc IVertexRouter
    function submitVote(uint256 actionId, bool support) external override {
        return _submitVote(msg.sender, actionId, support);
    }

    /// @inheritdoc IVertexRouter
    function submitVoteBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external override {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), getChainId(), address(this))),
                keccak256(abi.encode(VOTE_EMITTED_TYPEHASH, actionId, support))
            )
        );
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        return _submitVote(signer, actionId, support);
    }

    /// @inheritdoc IVertexRouter
    function submitVeto(uint256 actionId, bool support) external override {
        return _submitVeto(msg.sender, actionId, support);
    }

    /// @inheritdoc IVertexRouter
    function submitVetoBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external override {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), getChainId(), address(this))),
                keccak256(abi.encode(VETO_EMITTED_TYPEHASH, actionId, support))
            )
        );
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        return _submitVeto(signer, actionId, support);
    }

    function getActionWithoutVotes(uint256 actionId) external view override returns (ActionWithoutVotes memory) {
        Action storage action = actions[actionId];
        ActionWithoutVotes memory actionWithoutVotes = ActionWithoutVotes({
            id: action.id,
            creator: action.creator,
            strategy: action.strategy,
            target: action.target,
            value: action.value,
            signature: action.signature,
            data: action.data,
            votingStartTime: action.votingStartTime,
            votingEndTime: action.votingEndTime,
            executionTime: action.executionTime,
            queueTime: action.queueTime,
            forVotes: action.forVotes,
            againstVotes: action.againstVotes,
            forVetoVotes: action.forVetoVotes,
            againstVetoVotes: action.againstVetoVotes,
            executed: action.executed,
            canceled: action.canceled
        });

        return actionWithoutVotes;
    }

    function getActionState(uint256 actionId) public view override returns (ActionState) {
        if (actionId >= actionsCount) revert InvalidActionId();
        Action storage action = actions[actionId];
        if (action.canceled) {
            return ActionState.Canceled;
        }

        if (
            block.timestamp <= action.votingEndTime && (action.strategy.isFixedVotingPeriod() || !IStrategySettings(action.strategy).isActionPassed(actionId))
        ) {
            return ActionState.Active;
        }

        // TODO: do we need to pass the full action object here?
        if (!IStrategySettings(action.strategy).isActionPassed(actionId)) {
            return ActionState.Failed;
        }

        if (action.executionTime == 0) {
            return ActionState.Succeeded;
        }

        if (action.executed) {
            return ActionState.Executed;
        }

        if (action.strategy.isActionExpired(actionId)) {
            return ActionState.Expired;
        }

        return ActionState.Queued;
    }

    /**
     * @dev Add new addresses to the list of authorized strategies
     * @param strategies list of new addresses to be authorized strategies
     **/
    function createAndAuthorizeStrategies(address[] memory strategies) public override onlyVertexExecutor {
        //  TODO: this function needs to accept Strategy[]. Strategy should include all the arguments to deploy a new strategy
        //  It should use create2 to deploy and get all the addresses in an array, loop through them, and authorize them all
        for (uint256 i = 0; i < strategies.length; i++) {
            _authorizeStrategy(strategies[i]);
        }
    }

    /**
     * @dev Remove addresses to the list of authorized strategies
     * @param strategies list of addresses to be removed as authorized strategies
     **/
    function unauthorizeStrategies(address[] memory strategies) public override onlyVertexExecutor {
        for (uint256 i = 0; i < strategies.length; i++) {
            _unauthorizeStrategy(strategies[i]);
        }
    }

    function _authorizeStrategy(IVertexStrategy strategy) internal {
        authorizedStrategies[strategy] = true;
        emit VertexStrategyAuthorized(strategy);
    }

    function _unauthorizeStrategy(IVertexStrategy strategy) internal {
        authorizedStrategies[strategy] = false;
        emit VertexStrategyUnauthorized(strategy);
    }

    function _submitVote(address voter, uint256 actionId, bool support) internal {
        if (getActionState(actionId) != ActionState.Active) revert VotingClosed();
        Action storage action = actions[actionId];
        Vote storage vote = action.votes[voter];

        if (vote.votingPower != 0) revert VoteAlreadySubmitted();

        // TODO: StrategySettings needs to define voting rules by querying policy NFT
        uint256 votingPower = IStrategySettings(action.strategy).getVotingPowerAt(voter, action.votingStartTime);

        if (support) {
            action.forVotes += votingPower;
        } else {
            action.againstVotes += votingPower;
        }

        vote.support = support;
        vote.votingPower = uint248(votingPower);

        emit VoteEmitted(actionId, voter, support, votingPower);
    }

    function _submitVeto(address vetoer, uint256 actionId, bool support) internal {
        if (getActionState(actionId) != ActionState.Queued) revert VotingClosed();
        Action storage action = actions[actionId];
        // TODO: add check here to see if the action's strategy allows for veto
        Veto storage veto = action.vetoes[vetoer];

        if (veto.votingPower != 0) revert VetoAlreadySubmitted();

        // TODO: StrategySettings needs to define voting rules by querying policy NFT
        uint256 vetoPower = IStrategySettings(action.strategy).getVetoPowerAt(vetoer, action.votingStartTime);

        if (support) {
            action.forVetoVotes += vetoPower;
        } else {
            action.againstVetoVotes += vetoPower;
        }

        veto.support = support;
        veto.votingPower = uint248(vetoPower);

        emit VoteEmitted(actionId, vetoer, support, vetoPower);
    }
}
