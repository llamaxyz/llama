// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCore} from "src/core/IVertexCore.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {getChainId} from "src/utils/Helpers.sol";
import {Action, Approval, Disapproval, Strategy} from "src/utils/Structs.sol";

/// @title Core of a Vertex system
/// @author Llama (vertex@llama.xyz)
/// @notice Main point of interaction with a Vertex system.
contract VertexCore is IVertexCore {
    error InvalidStrategy();
    error OnlyCancelBeforeExecuted();
    error InvalidActionId();
    error OnlyQueuedActions();
    error InvalidStateForQueue();
    error DuplicateAction();
    error ActionCannotBeCanceled();
    error OnlyVertex();
    error SignalingClosed();
    error InvalidSignature();
    error TimelockNotFinished();
    error ActionHasExpired();
    error FailedActionExecution();
    error DuplicateApproval();
    error DuplicateDisapproval();
    error DisapproveDisabled();

    /// @notice EIP-712 base typehash.
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice EIP-712 approval typehash.
    bytes32 public constant APPROVAL_EMITTED_TYPEHASH = keccak256("PolicyholderApproved(uint256 id,bool support)");

    /// @notice EIP-712 disapproval typehash.
    bytes32 public constant DISAPPROVAL_EMITTED_TYPEHASH = keccak256("PolicyholderDisapproved(uint256 id,bool support)");

    /// @notice Equivalent to 100%, but scaled for precision
    uint256 public constant ONE_HUNDRED_IN_BPS = 100_00;

    /// @notice The NFT contract that defines the policies for this Vertex system.
    VertexPolicyNFT public immutable policy;

    /// @notice Name of this Vertex system.
    string public name;

    /// @notice The current number of actions created.
    uint256 public actionsCount;

    /// @notice Mapping of actionIds to Actions.
    mapping(uint256 => Action) public actions;

    /// @notice Mapping of actionIds to polcyholders to approvals.
    mapping(uint256 => mapping(address => Approval)) public approvals;

    /// @notice Mapping of action ids to polcyholders to disapprovals.
    mapping(uint256 => mapping(address => Disapproval)) public disapprovals;

    /// @notice Mapping of all authorized strategies.
    mapping(VertexStrategy => bool) public authorizedStrategies;

    /// @notice Mapping of actionId's and bool that indicates if action is queued.
    mapping(uint256 => bool) public queuedActions;

    constructor(string memory _name, string memory _symbol, Strategy[] memory initialStrategies) {
        name = _name;
        bytes32 salt = bytes32(keccak256(abi.encode(_name, _symbol)));
        policy = VertexPolicyNFT(new VertexPolicyNFT{salt: salt}(_name, _symbol, IVertexCore(address(this))));

        uint256 strategyLength = initialStrategies.length;
        unchecked {
            for (uint256 i; i < strategyLength; ++i) {
                bytes32 strategySalt = bytes32(keccak256(abi.encode(initialStrategies[i])));
                VertexStrategy strategy = VertexStrategy(new VertexStrategy{salt: strategySalt}(initialStrategies[i], policy, IVertexCore(address(this))));
                authorizedStrategies[strategy] = true;
            }
        }

        emit StrategiesAuthorized(initialStrategies);
    }

    modifier onlyVertex() {
        if (msg.sender != address(this)) revert OnlyVertex();
        _;
    }

    /// @inheritdoc IVertexCore
    function createAction(VertexStrategy strategy, address target, uint256 value, string calldata signature, bytes calldata data)
        external
        override
        returns (uint256)
    {
        if (!authorizedStrategies[strategy]) revert InvalidStrategy();

        // TODO: @theo insert validation logic here
        // Eg. is msg.sender a VertexPolicyNFT holder and does
        //     their policy allow them create an action with this
        //     strategy, target, signature hash. You also probably
        //     want to validate their policy at the previous or this block number

        uint256 previousActionCount = actionsCount;
        Action storage newAction = actions[previousActionCount];

        uint256 approvalPolicySupply = strategy.approvalWeightByPermission(strategy.DEFAULT_OPERATOR()) > 0
            ? policy.totalSupply()
            : policy.getSupplyByPermissions(strategy.getApprovalPermissions());

        uint256 disapprovalPolicySupply = strategy.disapprovalWeightByPermission(strategy.DEFAULT_OPERATOR()) > 0
            ? policy.totalSupply()
            : policy.getSupplyByPermissions(strategy.getDisapprovalPermissions());

        newAction.id = previousActionCount;
        newAction.creator = msg.sender;
        newAction.strategy = strategy;
        newAction.target = target;
        newAction.value = value;
        newAction.signature = signature;
        newAction.data = data;
        newAction.createdBlockNumber = block.number;
        newAction.approvalEndTime = block.timestamp + strategy.approvalDuration();
        newAction.approvalPolicySupply = approvalPolicySupply;
        newAction.disapprovalPolicySupply = disapprovalPolicySupply;

        unchecked {
            ++actionsCount;
        }

        emit ActionCreated(previousActionCount, msg.sender, strategy, target, value, signature, data);

        return newAction.id;
    }

    /// @inheritdoc IVertexCore
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

    /// @inheritdoc IVertexCore
    function queueAction(uint256 actionId) external override {
        if (getActionState(actionId) != ActionState.Succeeded) revert InvalidStateForQueue();
        Action storage action = actions[actionId];
        uint256 executionTime = block.timestamp + action.strategy.queuingDuration();

        if (queuedActions[actionId]) revert DuplicateAction();
        queuedActions[actionId] = true;

        action.executionTime = executionTime;

        emit ActionQueued(actionId, msg.sender, action.strategy, action.creator, executionTime);
    }

    /// @inheritdoc IVertexCore
    function executeAction(uint256 actionId) external payable override returns (bytes memory) {
        if (getActionState(actionId) != ActionState.Queued || !queuedActions[actionId]) revert OnlyQueuedActions();

        Action storage action = actions[actionId];
        if (block.timestamp < action.executionTime) revert TimelockNotFinished();
        if (isActionExpired(actionId)) revert ActionHasExpired();

        action.executed = true;
        queuedActions[actionId] = false;

        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory result) = action.target.call{value: action.value}(abi.encodePacked(bytes4(keccak256(bytes(action.signature))), action.data));

        if (!success) revert FailedActionExecution();

        emit ActionExecuted(actionId, msg.sender, action.strategy, action.creator);

        return result;
    }

    /// @inheritdoc IVertexCore
    function submitApproval(uint256 actionId, bool support) external override {
        return _submitApproval(msg.sender, actionId, support);
    }

    /// @inheritdoc IVertexCore
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

    /// @inheritdoc IVertexCore
    function submitDisapproval(uint256 actionId, bool support) external override {
        return _submitDisapproval(msg.sender, actionId, support);
    }

    /// @inheritdoc IVertexCore
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

    /// @inheritdoc IVertexCore
    function getAction(uint256 actionId) external view override returns (Action memory) {
        return actions[actionId];
    }

    /// @inheritdoc IVertexCore
    function getActionState(uint256 actionId) public view override returns (ActionState) {
        if (actionId >= actionsCount) revert InvalidActionId();
        Action storage action = actions[actionId];
        if (action.canceled) {
            return ActionState.Canceled;
        }

        if (block.timestamp < action.approvalEndTime && (action.strategy.isFixedLengthApprovalPeriod() || !action.strategy.isActionPassed(actionId))) {
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

    /// @inheritdoc IVertexCore
    function createAndAuthorizeStrategies(Strategy[] memory strategies) public override onlyVertex {
        uint256 strategyLength = strategies.length;
        unchecked {
            for (uint256 i; i < strategyLength; ++i) {
                bytes32 salt = bytes32(keccak256(abi.encode(strategies[i])));
                VertexStrategy strategy = VertexStrategy(new VertexStrategy{salt: salt}(strategies[i], policy, IVertexCore(address(this))));
                authorizedStrategies[strategy] = true;
            }
        }

        emit StrategiesAuthorized(strategies);
    }

    /// @inheritdoc IVertexCore
    function unauthorizeStrategies(VertexStrategy[] memory strategies) public override onlyVertex {
        uint256 strategiesLength = strategies.length;
        unchecked {
            for (uint256 i = 0; i < strategiesLength; ++i) {
                authorizedStrategies[strategies[i]] = false;
            }
        }

        emit StrategiesUnauthorized(strategies);
    }

    /// @inheritdoc IVertexCore
    function isActionExpired(uint256 actionId) public view override returns (bool) {
        Action storage action = actions[actionId];
        return block.timestamp >= action.executionTime + action.strategy.expirationDelay();
    }

    function _submitApproval(address policyholder, uint256 actionId, bool support) internal {
        if (getActionState(actionId) != ActionState.Active) revert SignalingClosed();
        Action storage action = actions[actionId];
        Approval storage approval = approvals[actionId][policyholder];

        if (support == approval.support) revert DuplicateApproval();

        uint256 weight = action.strategy.getApprovalWeightAt(policyholder, action.createdBlockNumber);

        if (support) {
            action.totalApprovals += weight;
        } else {
            action.totalApprovals -= weight;
        }

        approval.support = support;
        approval.weight = uint248(support ? weight : 0);

        emit PolicyholderApproved(actionId, policyholder, support, weight);
    }

    function _submitDisapproval(address policyholder, uint256 actionId, bool support) internal {
        if (getActionState(actionId) != ActionState.Queued) revert SignalingClosed();
        Action storage action = actions[actionId];

        if (action.strategy.minDisapprovalPct() > ONE_HUNDRED_IN_BPS) revert DisapproveDisabled();

        Disapproval storage disapproval = disapprovals[actionId][policyholder];

        if (support == disapproval.support) revert DuplicateDisapproval();

        uint256 weight = action.strategy.getDisapprovalWeightAt(policyholder, action.createdBlockNumber);

        if (support) {
            action.totalDisapprovals += weight;
        } else {
            action.totalDisapprovals -= weight;
        }

        disapproval.support = support;
        disapproval.weight = uint248(support ? weight : 0);

        emit PolicyholderDisapproved(actionId, policyholder, support, weight);
    }
}
