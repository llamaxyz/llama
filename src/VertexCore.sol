// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {IActionGuard} from "src/interfaces/IActionGuard.sol";
import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, PermissionData, DefaultStrategyConfig} from "src/lib/Structs.sol";

/// @title Core of a Vertex system
/// @author Llama (vertex@llama.xyz)
/// @notice Main point of interaction with a Vertex system.
contract VertexCore is Initializable {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error InvalidStrategy();
  error InvalidPolicyholder();
  error InvalidCancelation();
  error InvalidActionId();
  error InvalidActionState(ActionState expected);
  error OnlyVertex();
  error InvalidSignature();
  error TimelockNotFinished();
  error FailedActionExecution();
  error DuplicateCast();
  error PolicyholderDoesNotHavePermission();
  error InsufficientMsgValue();
  error RoleHasZeroSupply(uint8 role);
  error UnauthorizedStrategyLogic();
  error UnauthorizedAccountLogic();
  error TargetCannotBeCoreOrPolicy();
  error ScriptCannotBeCoreOrPolicy();
  error ProhibitedByActionGuard(bytes32 reason);
  error ProhibitedByStrategy(bytes32 reason);

  modifier onlyVertex() {
    if (msg.sender != address(this)) revert OnlyVertex();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  event ActionCreated(
    uint256 id,
    address indexed creator,
    IVertexStrategy indexed strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes data
  );
  event ActionCanceled(uint256 id);
  event ActionGuardSet(address indexed target, bytes4 indexed selector, IActionGuard actionGuard);
  event ActionQueued(
    uint256 id, address indexed caller, IVertexStrategy indexed strategy, address indexed creator, uint256 executionTime
  );
  event ActionExecuted(uint256 id, address indexed caller, IVertexStrategy indexed strategy, address indexed creator);
  event ApprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event StrategyAuthorized(
    IVertexStrategy indexed strategy, IVertexStrategy indexed strategyLogic, bytes initializationData
  );
  event StrategyUnauthorized(IVertexStrategy indexed strategy);
  event AccountAuthorized(VertexAccount indexed account, VertexAccount indexed accountLogic, string name);
  event ScriptAuthorized(address indexed script, bool authorized);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice EIP-712 base typehash.
  bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @notice EIP-712 createAction typehash.
  bytes32 internal constant CREATE_ACTION_TYPEHASH = keccak256(
    "CreateAction(uint8 role,address strategy,address target,uint256 value,bytes4 selector,bytes data,address policyholder,uint256 nonce)"
  );

  /// @notice EIP-712 castApproval typehash.
  bytes32 internal constant CAST_APPROVAL_TYPEHASH =
    keccak256("CastApproval(uint256 actionId,uint8 role,string reason,address policyholder,uint256 nonce)");

  /// @notice EIP-712 castDisapproval typehash.
  bytes32 internal constant CAST_DISAPPROVAL_TYPEHASH =
    keccak256("CastDisapproval(uint256 actionId,uint8 role,string reason,address policyholder,uint256 nonce)");

  /// @notice Equivalent to 100%, but scaled for precision
  uint256 internal constant ONE_HUNDRED_IN_BPS = 10_000;

  /// @notice The VertexFactory contract that deployed this Vertex system.
  VertexFactory public factory;

  /// @notice The NFT contract that defines the policies for this Vertex system.
  VertexPolicy public policy;

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
  mapping(uint256 => mapping(address => bool)) public approvals;

  /// @notice Mapping of action ids to policyholders to disapprovals.
  mapping(uint256 => mapping(address => bool)) public disapprovals;

  /// @notice Mapping of all authorized strategies.
  mapping(IVertexStrategy => bool) public authorizedStrategies;

  /// @notice Mapping of all authorized scripts.
  mapping(address => bool) public authorizedScripts;

  /// @notice Mapping of users to function selectors to current nonces for EIP-712 signatures.
  /// @dev This is used to prevent replay attacks by incrementing the nonce for each operation (createAction,
  /// castApproval and castDisapproval) signed by the policyholder.
  mapping(address => mapping(bytes4 => uint256)) public nonces;

  /// @notice Mapping of target to selector to actionGuard address.
  mapping(address target => mapping(bytes4 selector => IActionGuard)) public actionGuard;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor() initializer {}

  /// @notice Initializes a new VertexCore clone.
  /// @param _name The name of the VertexCore clone.
  /// @param _policy This Vertex instance's policy contract.
  /// @param _vertexStrategyLogic The Vertex Strategy implementation (logic) contract.
  /// @param _vertexAccountLogic The Vertex Account implementation (logic) contract.
  /// @param initialStrategies The configuration of the initial strategies.
  /// @param initialAccounts The configuration of the initial strategies.
  function initialize(
    string memory _name,
    VertexPolicy _policy,
    IVertexStrategy _vertexStrategyLogic,
    VertexAccount _vertexAccountLogic,
    bytes[] calldata initialStrategies,
    string[] calldata initialAccounts
  ) external initializer {
    factory = VertexFactory(msg.sender);
    name = _name;
    policy = _policy;

    _deployStrategies(_vertexStrategyLogic, initialStrategies);
    _deployAccounts(_vertexAccountLogic, initialAccounts);
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Creates an action. The creator needs to hold a policy with the permissionId of the provided
  /// {target, selector, strategy}.
  /// @param role The role that will be used to determine the permissionId of the policy holder.
  /// @param strategy The IVertexStrategy contract that will determine how the action is executed.
  /// @param target The contract called when the action is executed.
  /// @param value The value in wei to be sent when the action is executed.
  /// @param selector The function selector that will be called when the action is executed.
  /// @param data The encoded arguments to be passed to the function that is called when the action is executed.
  /// @return actionId actionId of the newly created action.
  function createAction(
    uint8 role,
    IVertexStrategy strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes calldata data
  ) external returns (uint256 actionId) {
    actionId = _createAction(msg.sender, role, strategy, target, value, selector, data);
  }

  /// @notice Creates an action via an off-chain signature. The creator needs to hold a policy with the permissionId of
  /// the provided {target, selector, strategy}.
  /// @param role The role that will be used to determine the permissionId of the policy holder.
  /// @param strategy The IVertexStrategy contract that will determine how the action is executed.
  /// @param target The contract called when the action is executed.
  /// @param value The value in wei to be sent when the action is executed.
  /// @param selector The function selector that will be called when the action is executed.
  /// @param data The encoded arguments to be passed to the function that is called when the action is executed.
  /// @param user The user that signed the message.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  /// @return actionId actionId of the newly created action.
  function createActionBySig(
    uint8 role,
    IVertexStrategy strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes calldata data,
    address user,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 actionId) {
    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        keccak256(
          abi.encode(
            EIP712_DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes("1")), block.chainid, address(this)
          )
        ),
        keccak256(
          abi.encode(
            CREATE_ACTION_TYPEHASH,
            role,
            address(strategy),
            target,
            value,
            selector,
            keccak256(data),
            user,
            _useNonce(user, msg.sig)
          )
        )
      )
    );
    address signer = ecrecover(digest, v, r, s);
    if (signer == address(0) || signer != user) revert InvalidSignature();
    actionId = _createAction(signer, role, strategy, target, value, selector, data);
  }

  /// @notice Queue an action by actionId if it's in Approved state.
  /// @param actionId Id of the action to queue.
  function queueAction(uint256 actionId) external {
    if (getActionState(actionId) != ActionState.Approved) revert InvalidActionState(ActionState.Approved);

    Action storage action = actions[actionId];
    uint256 minExecutionTime = action.strategy.minExecutionTime(actionId);
    action.minExecutionTime = minExecutionTime;
    emit ActionQueued(actionId, msg.sender, action.strategy, action.creator, minExecutionTime);
  }

  /// @notice Execute an action by actionId if it's in Queued state and executionTime has passed.
  /// @param actionId Id of the action to execute.
  /// @return The result returned from the call to the target contract.
  function executeAction(uint256 actionId) external payable returns (bytes memory) {
    // Initial checks that action is ready to execute.
    if (getActionState(actionId) != ActionState.Queued) revert InvalidActionState(ActionState.Queued);

    Action storage action = actions[actionId];
    if (block.timestamp < action.minExecutionTime) revert TimelockNotFinished();
    if (msg.value < action.value) revert InsufficientMsgValue();

    // Check pre-execution action guard.
    IActionGuard guard = actionGuard[action.target][action.selector];
    if (guard != IActionGuard(address(0))) {
      (bool allowed, bytes32 reason) = guard.validatePreActionExecution(actionId);
      if (!allowed) revert ProhibitedByActionGuard(reason);
    }

    // Execute action.
    action.executed = true;
    bool success;
    bytes memory result;

    if (authorizedScripts[action.target]) {
      (success, result) = action.target.call{value: action.value}(abi.encodePacked(action.selector, action.data));
    } else {
      (success, result) = action.target.call{value: action.value}(abi.encodePacked(action.selector, action.data));
    }

    if (!success) revert FailedActionExecution();

    // Check post-execution action guard.
    if (guard != IActionGuard(address(0))) {
      (bool allowed, bytes32 reason) = guard.validatePostActionExecution(actionId);
      if (!allowed) revert ProhibitedByActionGuard(reason);
    }

    // Action successfully executed.
    emit ActionExecuted(actionId, msg.sender, action.strategy, action.creator);
    return result;
  }

  /// @notice Cancels an action. Rules for cancelation are defined by the strategy.
  /// @param actionId Id of the action to cancel.
  function cancelAction(uint256 actionId) external {
    // We don't need an explicit check on action existence because if it doesn't exist the strategy will be the zero
    // address, and Solidity will revert when the `isActionCancelationValid` call has no return data.
    Action storage action = actions[actionId];
    if (!action.strategy.isActionCancelationValid(actionId, msg.sender)) revert InvalidCancelation();

    action.canceled = true;
    emit ActionCanceled(actionId);
  }

  /// @notice How policyholders add their support of the approval of an action.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to cast their approval.
  function castApproval(uint256 actionId, uint8 role) external {
    return _castApproval(msg.sender, role, actionId, "");
  }

  /// @notice How policyholders add their support of the approval of an action with a reason.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to cast their approval.
  /// @param reason The reason given for the approval by the policyholder.
  function castApproval(uint256 actionId, uint8 role, string calldata reason) external {
    return _castApproval(msg.sender, role, actionId, reason);
  }

  /// @notice How policyholders add their support of the approval of an action via an off-chain signature.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to cast their approval.
  /// @param reason The reason given for the approval by the policyholder.
  /// @param user The user that signed the message.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  function castApprovalBySig(
    uint256 actionId,
    uint8 role,
    string calldata reason,
    address user,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        keccak256(
          abi.encode(
            EIP712_DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes("1")), block.chainid, address(this)
          )
        ),
        keccak256(
          abi.encode(CAST_APPROVAL_TYPEHASH, actionId, role, keccak256(bytes(reason)), user, _useNonce(user, msg.sig))
        )
      )
    );
    address signer = ecrecover(digest, v, r, s);
    if (signer == address(0) || signer != user) revert InvalidSignature();
    return _castApproval(signer, role, actionId, reason);
  }

  /// @notice How policyholders add their support of the disapproval of an action.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to cast their disapproval.
  function castDisapproval(uint256 actionId, uint8 role) external {
    return _castDisapproval(msg.sender, role, actionId, "");
  }

  /// @notice How policyholders add their support of the disapproval of an action with a reason.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to cast their disapproval.
  /// @param reason The reason given for the disapproval by the policyholder.
  function castDisapproval(uint256 actionId, uint8 role, string calldata reason) external {
    return _castDisapproval(msg.sender, role, actionId, reason);
  }

  /// @notice How policyholders add their support of the disapproval of an action via an off-chain signature.
  /// @param actionId The id of the action.
  /// @param role The role the policyholder uses to cast their disapproval.
  /// @param reason The reason given for the approval by the policyholder.
  /// @param user The user that signed the message.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  function castDisapprovalBySig(
    uint256 actionId,
    uint8 role,
    string calldata reason,
    address user,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        keccak256(
          abi.encode(
            EIP712_DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes("1")), block.chainid, address(this)
          )
        ),
        keccak256(
          abi.encode(
            CAST_DISAPPROVAL_TYPEHASH, actionId, role, keccak256(bytes(reason)), user, _useNonce(user, msg.sig)
          )
        )
      )
    );
    address signer = ecrecover(digest, v, r, s);
    if (signer == address(0) || signer != user) revert InvalidSignature();
    return _castDisapproval(signer, role, actionId, reason);
  }

  /// @notice Deploy new strategies and add them to the mapping of authorized strategies.
  /// @param vertexStrategyLogic address of the Vertex Strategy logic contract.
  /// @param strategies list of new Strategys to be authorized.
  function createAndAuthorizeStrategies(IVertexStrategy vertexStrategyLogic, bytes[] calldata strategies)
    external
    onlyVertex
  {
    _deployStrategies(vertexStrategyLogic, strategies);
  }

  /// @notice Remove strategies from the mapping of authorized strategies.
  /// @param strategies list of Strategys to be removed from the mapping of authorized strategies.
  function unauthorizeStrategies(IVertexStrategy[] calldata strategies) external onlyVertex {
    uint256 strategiesLength = strategies.length;
    for (uint256 i = 0; i < strategiesLength; i = _uncheckedIncrement(i)) {
      delete authorizedStrategies[strategies[i]];
      emit StrategyUnauthorized(strategies[i]);
    }
  }

  /// @notice Deploy new accounts and add them to the mapping of authorized accounts.
  /// @param vertexAccountLogic address of the Vertex Account logic contract.
  /// @param accounts list of new accounts to be authorized.
  function createAndAuthorizeAccounts(VertexAccount vertexAccountLogic, string[] calldata accounts) external onlyVertex {
    _deployAccounts(vertexAccountLogic, accounts);
  }

  /// @notice Sets `guard` as the action guard for the given `target` and `selector`.
  /// @dev To remove a guard, set `guard` to the zero address.
  function setGuard(address target, bytes4 selector, IActionGuard guard) external onlyVertex {
    if (target == address(this) || target == address(policy)) revert TargetCannotBeCoreOrPolicy();
    actionGuard[target][selector] = guard;
    emit ActionGuardSet(target, selector, guard);
  }

  /// @notice Authorizes `script` as the action guard for the given `target` and `selector`.
  /// @dev To remove a script, set `authorized` to false.
  function authorizeScript(address script, bool authorized) external onlyVertex {
    if (script == address(this) || script == address(policy)) revert ScriptCannotBeCoreOrPolicy();
    authorizedScripts[script] = authorized;
    emit ScriptAuthorized(script, authorized);
  }

  /// @notice Get an Action struct by actionId.
  /// @param actionId id of the action.
  /// @return The Action struct.
  function getAction(uint256 actionId) external view returns (Action memory) {
    return actions[actionId];
  }

  /// @notice Get the current ActionState of an action by its actionId.
  /// @param actionId id of the action.
  /// @return The current ActionState of the action.
  function getActionState(uint256 actionId) public view returns (ActionState) {
    if (actionId >= actionsCount) revert InvalidActionId();
    Action storage action = actions[actionId];

    if (action.canceled) return ActionState.Canceled;

    if (action.strategy.isActive(actionId)) return ActionState.Active;

    if (!action.strategy.isActionPassed(actionId)) return ActionState.Failed;

    if (action.minExecutionTime == 0) return ActionState.Approved;

    if (action.executed) return ActionState.Executed;

    if (action.strategy.isActionExpired(actionId)) return ActionState.Expired;

    return ActionState.Queued;
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  function _createAction(
    address policyholder,
    uint8 role,
    IVertexStrategy strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes calldata data
  ) internal returns (uint256 actionId) {
    if (!authorizedStrategies[strategy]) revert InvalidStrategy();

    PermissionData memory permission = PermissionData(target, selector, strategy);
    bytes32 permissionId = keccak256(abi.encode(permission));

    // Typically (such as in Governor contracts) this should check that the caller has permission
    // at `block.number|timestamp - 1` but here we're just checking if the caller *currently* has
    // permission. Technically this introduces a race condition if e.g. an action to revoke a role
    // from someone (or revoke a permission from a role) is ready to be executed at the same time as
    // an action is created, as the order of transactions in the block then affects if action
    // creation would succeed. However, we are ok with this tradeoff because it means we don't need
    // to checkpoint the `canCreateAction` mapping which is simpler and cheaper, and in practice
    // this race condition is unlikely to matter.
    if (!policy.hasPermissionId(policyholder, role, permissionId)) revert PolicyholderDoesNotHavePermission();

    actionId = actionsCount;
    Action storage newAction = actions[actionId];

    newAction.creator = policyholder;
    newAction.strategy = strategy;
    newAction.target = target;
    newAction.value = value;
    newAction.selector = selector;
    newAction.data = data;
    newAction.creationTime = block.timestamp;

    (bool allowed, bytes32 reason) = strategy.validateActionCreation(actionId);
    if (!allowed) revert ProhibitedByStrategy(reason);

    // If an action guard is present, call it to determine if the action can be created. We must do
    // this after the action is written to storage so that the action guard can any state it needs.
    IActionGuard guard = actionGuard[target][selector];
    if (guard != IActionGuard(address(0))) {
      (allowed, reason) = guard.validateActionCreation(actionId);
      if (!allowed) revert ProhibitedByActionGuard(reason);
    }

    unchecked {
      ++actionsCount;
    }

    emit ActionCreated(actionId, policyholder, strategy, target, value, selector, data);
  }

  function _castApproval(address policyholder, uint8 role, uint256 actionId, string memory reason) internal {
    Action storage action = _preCastAssertions(actionId, policyholder, role, ActionState.Active);

    uint256 quantity = action.strategy.getApprovalQuantityAt(policyholder, role, action.creationTime);
    action.totalApprovals = _newCastCount(action.totalApprovals, quantity);
    approvals[actionId][policyholder] = true;
    emit ApprovalCast(actionId, policyholder, quantity, reason);
  }

  function _castDisapproval(address policyholder, uint8 role, uint256 actionId, string memory reason) internal {
    Action storage action = _preCastAssertions(actionId, policyholder, role, ActionState.Queued);

    uint256 quantity = action.strategy.getDisapprovalQuantityAt(policyholder, role, action.creationTime);
    action.totalDisapprovals = _newCastCount(action.totalDisapprovals, quantity);
    disapprovals[actionId][policyholder] = true;
    emit DisapprovalCast(actionId, policyholder, quantity, reason);
  }

  /// @dev The only `expectedState` values allowed to be passed into this method are Active or Queued.
  function _preCastAssertions(uint256 actionId, address policyholder, uint8 role, ActionState expectedState)
    internal
    view
    returns (Action storage action)
  {
    if (getActionState(actionId) != expectedState) revert InvalidActionState(expectedState);

    bool isApproval = expectedState == ActionState.Active;
    bool alreadyCast = isApproval ? approvals[actionId][policyholder] : disapprovals[actionId][policyholder];
    if (alreadyCast) revert DuplicateCast();

    action = actions[actionId];
    bool hasRole = policy.hasRole(policyholder, role, action.creationTime);
    if (!hasRole) revert InvalidPolicyholder();

    (bool isEnabled, bytes32 reason) = isApproval
      ? action.strategy.isApprovalEnabled(actionId, msg.sender)
      : action.strategy.isDisapprovalEnabled(actionId, msg.sender);
    if (!isEnabled) revert ProhibitedByStrategy(reason);
  }

  /// @dev Returns the new total count of approvals or disapprovals.
  function _newCastCount(uint256 currentCount, uint256 quantity) internal pure returns (uint256) {
    if (currentCount == type(uint256).max || quantity == type(uint256).max) return type(uint256).max;
    return currentCount + quantity;
  }

  function _deployStrategies(IVertexStrategy vertexStrategyLogic, bytes[] calldata strategies) internal {
    if (address(factory).code.length > 0 && !factory.authorizedStrategyLogics(vertexStrategyLogic)) {
      // The only edge case where this check is skipped is if `_deployStrategies()` is called by Root Vertex Instance
      // during Vertex Factory construction. This is because there is no code at the Vertex Factory address yet.
      revert UnauthorizedStrategyLogic();
    }

    uint256 strategyLength = strategies.length;
    for (uint256 i; i < strategyLength; i = _uncheckedIncrement(i)) {
      bytes32 salt = bytes32(keccak256(strategies[i]));

      IVertexStrategy strategy = IVertexStrategy(Clones.cloneDeterministic(address(vertexStrategyLogic), salt));
      strategy.initialize(strategies[i]);
      authorizedStrategies[strategy] = true;
      emit StrategyAuthorized(strategy, vertexStrategyLogic, strategies[i]);
    }
  }

  function _deployAccounts(VertexAccount vertexAccountLogic, string[] calldata accounts) internal {
    if (address(factory).code.length > 0 && !factory.authorizedAccountLogics(vertexAccountLogic)) {
      // The only edge case where this check is skipped is if `_deployAccounts()` is called by Root Vertex Instance
      // during Vertex Factory construction. This is because there is no code at the Vertex Factory address yet.
      revert UnauthorizedAccountLogic();
    }

    uint256 accountLength = accounts.length;
    for (uint256 i; i < accountLength; i = _uncheckedIncrement(i)) {
      bytes32 salt = bytes32(keccak256(abi.encode(accounts[i])));
      VertexAccount account = VertexAccount(payable(Clones.cloneDeterministic(address(vertexAccountLogic), salt)));
      account.initialize(accounts[i]);
      emit AccountAuthorized(account, vertexAccountLogic, accounts[i]);
    }
  }

  function _useNonce(address user, bytes4 selector) internal returns (uint256 nonce) {
    nonce = nonces[user][selector];
    unchecked {
      nonces[user][selector] = nonce + 1;
    }
  }

  function _uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }
}
