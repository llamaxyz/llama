// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";
import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";

error OnlyCancelBeforeExecuted();
error OnlyCreaterCanCancel();
error InvalidActionId();
error OnlyQueuedActions();

contract VertexRouter is IVertexRouter {
    uint256 private _actionsCount;
    mapping(uint256 => Action) private _actions;
    mapping(IVertexStrategy => bool) private _authorizedStrategies;
    VertexPolicyNFT private _policies;

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

        _actionsCount++;

        strategy.createAction(target, value, signature, data);

        emit ActionCreated(previousActionCount, msg.sender, strategy, target, value, signature, data);

        return newAction.id;
    }

    function cancelAction(uint256 actionId) external override {
        ActionState state = getActionState(actionId);
        if (state == ActionState.Executed || state == ActionState.Canceled || state == ActionState.Expired) {
            revert OnlyCancelBeforeExecuted();
        }

        Action storage action = _actions[actionId];

        if (msg.sender != action.creator) {
            revert OnlyCreaterCanCancel();
        }

        action.canceled = true;

        action.strategy.cancelAction(action.target, action.value, action.signature, action.data);

        emit ActionCanceled(actionId);
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
