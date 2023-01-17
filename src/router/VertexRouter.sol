// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";
import {IActionValidator} from "src/strategies/IActionValidator.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {VertexExecutor} from "src/executor/VertexExecutor.sol";

// Errors
error OnlyCancelBeforeExecuted();
error OnlyCreaterCanCancel();
error InvalidActionId();
error OnlyQueuedActions();
error InvalidStateForQueue();
error DuplicateAction();
error ActionCannotBeCanceled();
error OnlyExecutor();

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

    constructor(string calldata _name, address[] memory strategies) {
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
        if (!isStrategyAuthorized(strategy)) revert InvalidStrategy();

        // TODO: @theo insert validation logic here
        // Eg. is msg.sender a VertexPolicyNFT holder and does
        //     their policy allow them create an action with this
        //     strategy, target, signature hash

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
        newAction.votingEndTime = block.timestamp + IActionValidator(strategy).getVotingDuration();

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

        // TODO: clean up cancellation detection logic
        if (msg.sender == action.creator) {
            action.canceled = true;
        } else {
            if (!IActionValidator(action.strategy).isActionCanceletionValid(action)) revert ActionCannotBeCanceled();
            action.canceled = true;
            action.strategy.cancelAction(msg.sender, actionId);
        }

        emit ActionCanceled(actionId);
    }

    /// @inheritdoc IVertexRouter
    function queueAction(uint256 actionId) external override {
        if (getActionState(actionId) != ActionState.Succeeded) revert InvalidStateForQueue();
        Action storage action = actions[actionId];
        uint256 executionTime = block.timestamp + action.strategy.getDelay();

        if (action.strategy.isActionQueued(keccak256(abi.encode(action.target, action.value, action.signature, action.data)))) revert DuplicateAction();
        action.strategy.queueTransaction(target, value, signature, data, executionTime);

        action.executionTime = executionTime;

        emit ActionQueued(actionId, msg.sender, action.strategy, action.creator, executionTime);
    }

    /**
     * @dev Execute the action (If Action Queued)
     * @param actionId id of the action to execute
     **/
    function executeAction(uint256 actionId) external payable override {
        if (getActionState(actionId) != ActionState.Queued) revert OnlyQueuedActions();
        Action storage action = actions[actionId];
        action.executed = true;
        action.strategy.executeAction(action.target, action.value, action.signature, action.data);
        emit ActionExecuted(actionId, msg.sender, actionId.strategy, actionId.creator);
    }

    function getActionState(uint256 actionId) public view override returns (ActionState) {
        if (actionId >= actionsCount) revert InvalidActionId();
        Action storage action = actions[actionId];
        if (action.canceled) {
            return ActionState.Canceled;
        }
        // TODO: Complete getActionState logic
        // else if (block.number <= action.endBlock) {
        //     return ActionState.Active;
        // } else if (!IActionValidator(address(action.strategy)).isActionPassed(this, actionId)) {
        //     return ActionState.Failed;
        // } else if (action.executionTime == 0) {
        //     return ActionState.Succeeded;
        // } else if (action.executed) {
        //     return ActionState.Executed;
        // } else if (action.strategy.isActionOverGracePeriod(this, actionId)) {
        //     return ActionState.Expired;
        // }
        else {
            return ActionState.Queued;
        }
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

    /**
     * @dev Returns whether an address is an authorized strategy
     * @param strategy address to evaluate as authorized strategy
     * @return true if authorized
     **/
    function isStrategyAuthorized(IVertexStrategy strategy) public view override returns (bool) {
        return authorizedStrategies[strategy];
    }

    function _authorizeStrategy(IVertexStrategy strategy) internal {
        authorizedStrategies[strategy] = true;
        emit StrategyAuthorized(strategy);
    }

    function _unauthorizeStrategy(IVertexStrategy strategy) internal {
        authorizedStrategies[strategy] = false;
        emit StrategyUnauthorized(strategy);
    }
}
