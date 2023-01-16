// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";
import {IActionValidator} from "src/strategies/IActionValidator.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";

// Errors
error OnlyCancelBeforeExecuted();
error OnlyCreaterCanCancel();
error InvalidActionId();
error OnlyQueuedActions();
error InvalidStateForQueue();
error DuplicateAction();

/// @title VertexRouter
/// @author Llama (vertex@llama.xyz)
/// @notice Main point of interaction with a Vertex instance.
contract VertexRouter is IVertexRouter {
    /// @notice Name of this Vertex instance.
    string public immutable name;

    /// @notice The NFT contract that defines the policies for this Vertex instance.
    VertexPolicyNFT private _policies;

    /// @notice The current number of actions ever created.
    uint256 private _actionsCount;

    /// @notice Mapping of action ids to Action structs.
    mapping(uint256 => Action) private _actions;

    /// @notice Mapping of all authorized strategies.
    mapping(IVertexStrategy => bool) private _authorizedStrategies;

    /// @notice EIP-712 typehashes.
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant VOTE_EMITTED_TYPEHASH = keccak256("VoteEmitted(uint256 id,bool support)");
    bytes32 public constant VETO_EMITTED_TYPEHASH = keccak256("VetoEmitted(uint256 id,bool support)");

    constructor(string calldata _name, address[] memory strategies) {
        name = _name;

        // TODO: this assumes strategies have already been deployed.
        // not sure if this is optimal or the router deploys strategies.
        addStrategies(strategies);
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

        uint256 previousActionCount = _actionsCount;
        Action storage newAction = _actions[previousActionCount];
        newAction.id = previousActionCount;
        newAction.creator = msg.sender;
        newAction.strategy = strategy;
        newAction.target = target;
        newAction.value = value;
        newAction.signature = signature;
        newAction.data = data;
        newAction.votingStartTime = block.timestamp;
        newAction.votingEndTime = block.timestamp + IActionValidator(strategy).getVotingDuration();

        _actionsCount++;

        strategy.createAction(target, value, signature, data);

        emit ActionCreated(previousActionCount, msg.sender, strategy, target, value, signature, data);

        return newAction.id;
    }

    /// @inheritdoc IVertexRouter
    function cancelAction(uint256 actionId) external override {
        ActionState state = getActionState(actionId);
        if (state == ActionState.Executed || state == ActionState.Canceled || state == ActionState.Expired) {
            revert OnlyCancelBeforeExecuted();
        }

        Action storage action = _actions[actionId];

        // TODO: clean up cancellation detection logic
        if (msg.sender == action.creator) {
            action.canceled = true;
        } else {
            bool isCanceled = action.strategy.cancelAction(msg.sender, actionId);
            action.canceled = isCanceled;
        }

        emit ActionCanceled(actionId);
    }

    /// @inheritdoc IVertexRouter
    function queueAction(uint256 actionId) external override {
        if (getActionState(actionId) != ActionState.Succeeded) revert InvalidStateForQueue();
        Action storage action = _actions[actionId];
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
    function execute(uint256 actionId) external payable override {
        if (getActionState(actionId) != ActionState.Queued) revert OnlyQueuedActions();
        Action storage action = _actions[actionId];
        action.executed = true;
        action.strategy.executeAction(action.target, action.value, action.signature, action.data);
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
    function authorizeStrategies(address[] memory strategies) public override onlyOwner {
        for (uint256 i = 0; i < strategies.length; i++) {
            _authorizeStrategy(strategies[i]);
        }
    }

    /**
     * @dev Remove addresses to the list of authorized strategies
     * @param strategies list of addresses to be removed as authorized strategies
     **/
    function unauthorizeStrategies(address[] memory strategies) public override onlyOwner {
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
        return _authorizedStrategies[strategy];
    }

    /**
     * @dev Getter of the action count (the current number of actions ever created)
     * @return the action count
     **/
    function getActionsCount() external view override returns (uint256) {
        return _actionsCount;
    }

    /**
     * @dev Getter of a action by id
     * @param actionId id of the action to get
     * @return the action as Action memory object
     **/
    function getActionById(uint256 actionId) external view override returns (Action memory) {
        return _actions[actionId];
    }

    function _authorizeStrategy(IVertexStrategy strategy) internal {
        _authorizedStrategies[strategy] = true;
        emit StrategyAuthorized(strategy);
    }

    function _unauthorizeStrategy(IVertexStrategy strategy) internal {
        _authorizedStrategies[strategy] = false;
        emit StrategyUnauthorized(strategy);
    }
}
