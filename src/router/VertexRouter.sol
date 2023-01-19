// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {VertexExecutor} from "src/executor/VertexExecutor.sol";
import {getChainId} from "src/utils/Helpers.sol";

// Errors
error InvalidStrategy();
error OnlyCancelBeforeExecuted();
error InvalidActionId();
error OnlyQueuedActions();
error InvalidStateForQueue();
error DuplicateAction();
error ActionCannotBeCanceled();
error OnlyExecutor();
error SignalingClosed();
error ApprovalAlreadySubmitted();
error InvalidSignature();
error DisapprovalAlreadySubmitted();
error TimelockNotFinished();
error ActionHasExpired();
error FailedActionExecution();

/// @title VertexRouter
/// @author Llama (vertex@llama.xyz)
/// @notice Main point of interaction with a Vertex instance.
contract VertexRouter is IVertexRouter {
    /// @notice Name of this Vertex instance.
    string public name;

    /// @notice The current number of actions created.
    uint256 public actionsCount;

    /// @notice Mapping of action ids to Actions.
    mapping(uint256 => Action) public actions;

    /// @notice The NFT contract that defines the policies for this Vertex instance.
    VertexPolicyNFT public immutable policy;

    /// @notice The NFT contract that defines the policies for this Vertex instance.
    address public immutable executor;

    /// @notice Mapping of all authorized strategies.
    mapping(VertexStrategy => bool) public authorizedStrategies;

    /// @notice Mapping of action id's and bool that indicates if action is queued.
    mapping(uint256 => bool) public queuedActions;

    // TODO: Do we need an onchain way to access all strategies? Ideally not but will keep this as a placeholder.
    /// @notice Array of authorized strategies.
    // VertexStrategy[] public strategies;

    /// @notice EIP-712 typehashes.
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 public constant APPROVAL_EMITTED_TYPEHASH = keccak256("ApprovalEmitted(uint256 id,bool support)");
    bytes32 public constant DISAPPROVAL_EMITTED_TYPEHASH = keccak256("DisapprovalEmitted(uint256 id,bool support)");

    constructor(string memory _name) {
        name = _name;

        // TODO: We will use CREATE2 to deterministically deploy the VertexPolicyNFT,
        // all initial strategies, and the executor. These contracts can be fully confgiured
        // from their constructors. We will then use these addresses to set the policy,
        // authorizedStrategies, and executor.
        policy = VertexPolicyNFT(address(0x1337));
        executor = address(0x1338);
    }

    modifier onlyVertexExecutor() {
        if (msg.sender != executor) revert OnlyExecutor();
        _;
    }

    /// @inheritdoc IVertexRouter
    function createAction(
        VertexStrategy strategy,
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
        //     want to validate their policy at the previous or this block number

        uint256 previousActionCount = actionsCount;
        Action storage newAction = actions[previousActionCount];
        newAction.id = previousActionCount;
        newAction.creator = msg.sender;
        newAction.strategy = strategy;
        newAction.target = target;
        newAction.value = value;
        newAction.signature = signature;
        newAction.data = data;
        newAction.startBlockNumber = block.number;
        // TODO: approvalDuration should return a block number
        newAction.endBlockNumber = block.number + strategy.approvalDuration();

        unchecked {
            ++actionsCount;
        }

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
        if (!(msg.sender == action.creator || action.strategy.isActionCanceletionValid(actionId))) revert ActionCannotBeCanceled();

        action.canceled = true;
        queuedActions[actionId] = false;

        emit ActionCanceled(actionId);
    }

    /// @inheritdoc IVertexRouter
    function queueAction(uint256 actionId) external override {
        if (getActionState(actionId) != ActionState.Succeeded) revert InvalidStateForQueue();
        Action storage action = actions[actionId];
        uint256 executionTime = block.timestamp + action.strategy.executionDelay();

        if (queuedActions[actionId]) revert DuplicateAction();
        queuedActions[actionId] = true;

        action.executionTime = executionTime;

        emit ActionQueued(actionId, msg.sender, action.strategy, action.creator, executionTime);
    }

    /// @inheritdoc IVertexRouter
    function executeAction(uint256 actionId) external payable override returns (bytes memory) {
        // TODO: Do we need both of these checks?
        if (getActionState(actionId) != ActionState.Queued) revert OnlyQueuedActions();
        if (!queuedActions[actionId]) revert OnlyQueuedActions();

        Action storage action = actions[actionId];
        if (block.timestamp < action.executionTime) revert TimelockNotFinished();
        if (block.timestamp >= action.executionTime + action.strategy.expirationDelay()) revert ActionHasExpired();

        action.executed = true;
        queuedActions[actionId] = false;

        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory result) = address(executor).call(
            abi.encodeWithSelector(VertexExecutor.execute.selector, action.target, action.value, action.signature, action.data)
        );

        if (!success) revert FailedActionExecution();

        emit ActionExecuted(actionId, msg.sender, action.strategy, action.creator);

        // TODO: should we return arbitrary data?
        return result;
    }

    /// @inheritdoc IVertexRouter
    function submitApproval(uint256 actionId, bool support) external override {
        return _submitApproval(msg.sender, actionId, support);
    }

    // TODO: Is this pattern outdated?? Is there a better way to give our users an optionally gasless UX?
    /// @inheritdoc IVertexRouter
    function submitApprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external override {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this))),
                keccak256(abi.encode(APPROVAL_EMITTED_TYPEHASH, actionId, support))
            )
        );
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        return _submitApproval(signer, actionId, support);
    }

    /// @inheritdoc IVertexRouter
    function submitDisapproval(uint256 actionId, bool support) external override {
        return _submitDisapproval(msg.sender, actionId, support);
    }

    // TODO: Is this pattern outdated?? Is there a better way to give our users an optionally gasless UX?
    /// @inheritdoc IVertexRouter
    function submitDisapprovalBySignature(uint256 actionId, bool support, uint8 v, bytes32 r, bytes32 s) external override {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this))),
                keccak256(abi.encode(DISAPPROVAL_EMITTED_TYPEHASH, actionId, support))
            )
        );
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        return _submitDisapproval(signer, actionId, support);
    }

    function getActionWithoutApprovals(uint256 actionId) external view override returns (ActionWithoutApprovals memory) {
        Action storage action = actions[actionId];
        ActionWithoutApprovals memory actionWithoutApprovals = ActionWithoutApprovals({
            id: action.id,
            creator: action.creator,
            strategy: action.strategy,
            target: action.target,
            value: action.value,
            signature: action.signature,
            data: action.data,
            startBlockNumber: action.startBlockNumber,
            endBlockNumber: action.endBlockNumber,
            executionTime: action.executionTime,
            queueTime: action.queueTime,
            totalApprovals: action.totalApprovals,
            totalDisapprovals: action.totalDisapprovals,
            executed: action.executed,
            canceled: action.canceled
        });

        return actionWithoutApprovals;
    }

    function getActionState(uint256 actionId) public view override returns (ActionState) {
        if (actionId >= actionsCount) revert InvalidActionId();
        Action storage action = actions[actionId];
        if (action.canceled) {
            return ActionState.Canceled;
        }

        if (block.number <= action.endBlockNumber && (action.strategy.isFixedLengthApprovalPeriod() || !action.strategy.isActionPassed(actionId))) {
            return ActionState.Active;
        }

        if (!action.strategy.isActionPassed(actionId)) {
            return ActionState.Failed;
        }

        if (action.executionTime == 0) {
            return ActionState.Succeeded;
        }

        if (action.executed) {
            return ActionState.Executed;
        }

        if (isActionExpired(actionId)) {
            return ActionState.Expired;
        }

        return ActionState.Queued;
    }

    /**
     * @dev Add new addresses to the list of authorized strategies
     * @param strategies list of new addresses to be authorized strategies
     **/
    function createAndAuthorizeStrategies(VertexStrategy[] memory strategies) public override onlyVertexExecutor {
        //  TODO: this function needs to accept Strategy[]. Strategy should include all the arguments to deploy a new strategy
        //  It should use create2 to deploy and get all the addresses in an array, loop through them, and authorize them all
        uint256 stragiesLength = strategies.length;
        unchecked {
            for (uint256 i = 0; i < stragiesLength; ++i) {
                _authorizeStrategy(strategies[i]);
            }
        }
    }

    /**
     * @dev Remove addresses to the list of authorized strategies
     * @param strategies list of addresses to be removed as authorized strategies
     **/
    function unauthorizeStrategies(VertexStrategy[] memory strategies) public override onlyVertexExecutor {
        uint256 stragiesLength = strategies.length;
        unchecked {
            for (uint256 i = 0; i < stragiesLength; ++i) {
                _unauthorizeStrategy(strategies[i]);
            }
        }
    }

    function _authorizeStrategy(VertexStrategy strategy) internal {
        authorizedStrategies[strategy] = true;
        emit VertexStrategyAuthorized(strategy);
    }

    function _unauthorizeStrategy(VertexStrategy strategy) internal {
        authorizedStrategies[strategy] = false;
        emit VertexStrategyUnauthorized(strategy);
    }

    function _submitApproval(address policyHolder, uint256 actionId, bool support) internal {
        if (getActionState(actionId) != ActionState.Active) revert SignalingClosed();
        Action storage action = actions[actionId];
        Approval storage approval = action.approvals[policyHolder];

        // TODO: should we support changing approvals?
        if (approval.weight != 0) revert ApprovalAlreadySubmitted();

        uint256 weight = action.strategy.getApprovalWeightAt(policyHolder, action.startBlockNumber);

        if (support) {
            action.totalApprovals += weight;
        }

        approval.support = support;
        approval.weight = uint248(weight);

        emit ApprovalEmitted(actionId, policyHolder, support, weight);
    }

    function _submitDisapproval(address policyHolder, uint256 actionId, bool support) internal {
        if (getActionState(actionId) != ActionState.Queued) revert SignalingClosed();
        Action storage action = actions[actionId];
        // TODO: add check here to see if the action's strategy allows for disapprovals
        Disapproval storage disapproval = action.disapprovals[policyHolder];

        // TODO: should we support changing disapprovals?
        if (disapproval.weight != 0) revert DisapprovalAlreadySubmitted();

        // TODO: Do we need to base approvals/disapprovals on startBlockNumber and endBlockNumber instead of timestamps to support snapshots?
        uint256 weight = action.strategy.getDisapprovalWeightAt(policyHolder, action.startBlockNumber);

        if (support) {
            action.totalDisapprovals += weight;
        }

        disapproval.support = support;
        disapproval.weight = uint248(weight);

        emit ApprovalEmitted(actionId, policyHolder, support, weight);
    }

    function isActionExpired(uint256 actionId) public view override returns (bool) {
        Action storage action = actions[actionId];
        // TODO: Should approvalDuration return a block number or timestamp?
        return block.timestamp > (action.executionTime + action.strategy.approvalDuration());
    }
}
