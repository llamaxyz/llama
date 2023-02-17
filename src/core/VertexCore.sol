// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";
import {IVertexCore} from "src/core/IVertexCore.sol";
import {VertexStrategy} from "src/strategy/VertexStrategy.sol";
import {VertexPolicyNFT} from "src/policy/VertexPolicyNFT.sol";
import {VertexAccount} from "src/account/VertexAccount.sol";
import {Action, Approval, Disapproval, PermissionData, Strategy} from "src/utils/Structs.sol";

/// @title Core of a Vertex system
/// @author Llama (vertex@llama.xyz)
/// @notice Main point of interaction with a Vertex system.
contract VertexCore is IVertexCore, Initializable {
    error InvalidStrategy();
    error InvalidCancelation();
    error InvalidActionId();
    error OnlyQueuedActions();
    error InvalidStateForQueue();
    error ActionCannotBeCanceled();
    error OnlyVertex();
    error ActionNotActive();
    error ActionNotQueued();
    error InvalidSignature();
    error TimelockNotFinished();
    error FailedActionExecution();
    error DuplicateApproval();
    error DuplicateDisapproval();
    error DisapproveDisabled();
    error PolicyholderDoesNotHavePermission();

    /// @notice EIP-712 base typehash.
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice EIP-712 approval typehash.
    bytes32 public constant APPROVAL_EMITTED_TYPEHASH = keccak256("PolicyholderApproved(uint256 id,bool support)");

    /// @notice EIP-712 disapproval typehash.
    bytes32 public constant DISAPPROVAL_EMITTED_TYPEHASH = keccak256("PolicyholderDisapproved(uint256 id,bool support)");

    /// @notice Equivalent to 100%, but scaled for precision
    uint256 private constant ONE_HUNDRED_IN_BPS = 100_00;

    /// @notice The NFT contract that defines the policies for this Vertex system.
    VertexPolicyNFT public policy;

    /// @notice Name of this Vertex system.
    string public name;

    /// @notice The current number of actions created.
    uint256 public actionsCount;

    /// @notice Mapping of actionIds to Actions.
    /// @dev Making this `public` results in stack too deep with no optimizer, but this data can be
    /// accessed with the `getAction` function so this is ok. We want the contracts to compile
    /// without the optimizer so `forge coverage` can be used.
    mapping(uint256 => Action) internal actions;

    /// @notice Mapping of actionIds to policyholders to approvals.
    mapping(uint256 => mapping(address => Approval)) public approvals;

    /// @notice Mapping of action ids to policyholders to disapprovals.
    mapping(uint256 => mapping(address => Disapproval)) public disapprovals;

    /// @notice Mapping of all authorized strategies.
    mapping(VertexStrategy => bool) public authorizedStrategies;

    /// @notice Mapping of all authorized accounts.
    mapping(VertexAccount => bool) public authorizedAccounts;

    /// @notice Mapping of actionId's and bool that indicates if action is queued.
    mapping(uint256 => bool) public queuedActions;

    // solhint-disable-next-line no-empty-blocks
    constructor() initializer {}

    modifier onlyVertex() {
        if (msg.sender != address(this)) revert OnlyVertex();
        _;
    }

    function initialize(string memory _name, VertexPolicyNFT _policy, Strategy[] calldata initialStrategies, string[] calldata initialAccounts)
        external
        override
        initializer
    {
        name = _name;
        policy = _policy;

        _deployStrategies(initialStrategies, _policy);
        _deployAccounts(initialAccounts);
    }

    /// @inheritdoc IVertexCore
    function createAction(VertexStrategy strategy, address target, uint256 value, bytes4 selector, bytes calldata data) external override returns (uint256) {
        if (!authorizedStrategies[strategy]) revert InvalidStrategy();

        PermissionData memory permission = PermissionData({target: target, selector: selector, strategy: strategy});
        bytes8 permissionSignature = policy.hashPermission(permission);
        policy.checkExpiration(uint256(uint160(msg.sender)), permissionSignature);
        if (!policy.hasPermission(uint256(uint160(msg.sender)), permissionSignature)) revert PolicyholderDoesNotHavePermission();

        uint256 previousActionCount = actionsCount;
        Action storage newAction = actions[previousActionCount];

        uint256 approvalPolicySupply = strategy.approvalWeightByPermission(strategy.DEFAULT_OPERATOR()) > 0
            ? policy.totalSupply()
            : _getSupplyByPermissions(strategy.getApprovalPermissions());

        uint256 disapprovalPolicySupply = strategy.disapprovalWeightByPermission(strategy.DEFAULT_OPERATOR()) > 0
            ? policy.totalSupply()
            : _getSupplyByPermissions(strategy.getDisapprovalPermissions());

        newAction.creator = msg.sender;
        newAction.strategy = strategy;
        newAction.target = target;
        newAction.value = value;
        newAction.selector = selector;
        newAction.data = data;
        newAction.createdBlockNumber = block.number;
        newAction.approvalPolicySupply = approvalPolicySupply;
        newAction.disapprovalPolicySupply = disapprovalPolicySupply;

        unchecked {
            ++actionsCount;
        }

        emit ActionCreated(previousActionCount, msg.sender, strategy, target, value, selector, data);

        return previousActionCount;
    }

    /// @inheritdoc IVertexCore
    function queueAction(uint256 actionId) external override {
        if (getActionState(actionId) != ActionState.Approved) revert InvalidStateForQueue();
        Action storage action = actions[actionId];
        uint256 executionTime = block.timestamp + action.strategy.queuingDuration();

        queuedActions[actionId] = true;
        action.executionTime = executionTime;

        emit ActionQueued(actionId, msg.sender, action.strategy, action.creator, executionTime);
    }

    /// @inheritdoc IVertexCore
    function executeAction(uint256 actionId) external payable override returns (bytes memory) {
        if (getActionState(actionId) != ActionState.Queued || !queuedActions[actionId]) revert OnlyQueuedActions();

        Action storage action = actions[actionId];
        if (block.timestamp < action.executionTime) revert TimelockNotFinished();

        action.executed = true;
        queuedActions[actionId] = false;

        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory result) = action.target.call{value: action.value}(abi.encodePacked(action.selector, action.data));

        if (!success) revert FailedActionExecution();

        emit ActionExecuted(actionId, msg.sender, action.strategy, action.creator);

        return result;
    }

    /// @inheritdoc IVertexCore
    function cancelAction(uint256 actionId) external override {
        ActionState state = getActionState(actionId);
        if (state == ActionState.Executed || state == ActionState.Canceled || state == ActionState.Expired || state == ActionState.Failed) {
            revert InvalidCancelation();
        }

        Action storage action = actions[actionId];
        if (!(msg.sender == action.creator || action.strategy.isActionCanceletionValid(actionId))) revert ActionCannotBeCanceled();

        action.canceled = true;
        queuedActions[actionId] = false;

        emit ActionCanceled(actionId);
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
                keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), block.chainid, address(this))),
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
                keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), block.chainid, address(this))),
                keccak256(abi.encode(DISAPPROVAL_EMITTED_TYPEHASH, actionId, support))
            )
        );
        address signer = ecrecover(digest, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
        return _submitDisapproval(signer, actionId, support);
    }

    /// @inheritdoc IVertexCore
    function createAndAuthorizeStrategies(Strategy[] calldata strategies) public override onlyVertex {
        _deployStrategies(strategies, policy);
    }

    /// @inheritdoc IVertexCore
    function unauthorizeStrategies(VertexStrategy[] calldata strategies) public override onlyVertex {
        uint256 strategiesLength = strategies.length;
        unchecked {
            for (uint256 i = 0; i < strategiesLength; ++i) {
                delete authorizedStrategies[strategies[i]];
                emit StrategyUnauthorized(strategies[i]);
            }
        }
    }

    /// @inheritdoc IVertexCore
    function createAndAuthorizeAccounts(string[] calldata accounts) public override onlyVertex {
        _deployAccounts(accounts);
    }

    /// @inheritdoc IVertexCore
    function isActionExpired(uint256 actionId) public view override returns (bool) {
        Action storage action = actions[actionId];
        return block.timestamp >= action.executionTime + action.strategy.expirationDelay();
    }

    /// @inheritdoc IVertexCore
    function getAction(uint256 actionId) external view override returns (Action memory) {
        return actions[actionId];
    }

    /// @inheritdoc IVertexCore
    function getActionState(uint256 actionId) public view override returns (ActionState) {
        if (actionId >= actionsCount) revert InvalidActionId();
        Action storage action = actions[actionId];
        uint256 approvalEndBlock = action.createdBlockNumber + action.strategy.approvalPeriod();

        if (action.canceled) {
            return ActionState.Canceled;
        }

        if (block.number < approvalEndBlock && (action.strategy.isFixedLengthApprovalPeriod() || !action.strategy.isActionPassed(actionId))) {
            return ActionState.Active;
        }

        if (!action.strategy.isActionPassed(actionId)) {
            return ActionState.Failed;
        }

        if (action.executionTime == 0) {
            return ActionState.Approved;
        }

        if (action.executed) {
            return ActionState.Executed;
        }

        if (isActionExpired(actionId)) {
            return ActionState.Expired;
        }

        return ActionState.Queued;
    }

    function _submitApproval(address policyholder, uint256 actionId, bool support) internal {
        if (getActionState(actionId) != ActionState.Active) revert ActionNotActive();
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
        if (getActionState(actionId) != ActionState.Queued) revert ActionNotQueued();
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

    function _deployAccounts(string[] calldata accounts) internal {
        uint256 accountLength = accounts.length;
        unchecked {
            for (uint256 i; i < accountLength; ++i) {
                bytes32 salt = bytes32(keccak256(abi.encode(accounts[i])));
                VertexAccount account = new VertexAccount{salt: salt}(accounts[i], address(this));
                authorizedAccounts[account] = true;
                emit AccountAuthorized(account, accounts[i]);
            }
        }
    }

    function _deployStrategies(Strategy[] calldata strategies, VertexPolicyNFT _policy) internal {
        uint256 strategyLength = strategies.length;
        unchecked {
            for (uint256 i; i < strategyLength; ++i) {
                bytes32 salt = bytes32(keccak256(abi.encode(strategies[i])));
                VertexStrategy strategy = new VertexStrategy{salt: salt}(strategies[i], _policy, IVertexCore(address(this)));
                authorizedStrategies[strategy] = true;
                emit StrategyAuthorized(strategy, strategies[i]);
            }
        }
    }

    function _getSupplyByPermissions(bytes8[] memory permissions) internal view returns (uint256) {
        return policy.getSupplyByPermissions(permissions);
    }
}
