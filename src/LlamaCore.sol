// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {IActionGuard} from "src/interfaces/IActionGuard.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, PermissionData} from "src/lib/Structs.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Core of a llama instance
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Main point of interaction of a llama instance (i.e. entry into and exit from).
contract LlamaCore is Initializable {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error InvalidStrategy();
  error InvalidPolicyholder();
  error InvalidCancelation();
  error InvalidActionId();
  error InvalidActionState(ActionState expected);
  error OnlyLlama();
  error InvalidSignature();
  error TimelockNotFinished();
  error FailedActionExecution(bytes reason);
  error DuplicateCast();
  error PolicyholderDoesNotHavePermission();
  error InsufficientMsgValue();
  error RoleHasZeroSupply(uint8 role);
  error UnauthorizedStrategyLogic();
  error CannotUseCoreOrPolicy();
  error ProhibitedByActionGuard(bytes32 reason);
  error ProhibitedByStrategy(bytes32 reason);

  modifier onlyLlama() {
    if (msg.sender != address(this)) revert OnlyLlama();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  event ActionCreated(
    uint256 id,
    address indexed creator,
    ILlamaStrategy indexed strategy,
    address target,
    uint256 value,
    bytes4 selector,
    bytes data
  );
  event ActionCanceled(uint256 id);
  event ActionGuardSet(address indexed target, bytes4 indexed selector, IActionGuard actionGuard);
  event ActionQueued(
    uint256 id, address indexed caller, ILlamaStrategy indexed strategy, address indexed creator, uint256 executionTime
  );
  event ActionExecuted(
    uint256 id, address indexed caller, ILlamaStrategy indexed strategy, address indexed creator, bytes result
  );
  event ApprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event DisapprovalCast(uint256 id, address indexed policyholder, uint256 quantity, string reason);
  event StrategyAuthorized(
    ILlamaStrategy indexed strategy, ILlamaStrategy indexed strategyLogic, bytes initializationData
  );
  event StrategyUnauthorized(ILlamaStrategy indexed strategy);
  event AccountCreated(LlamaAccount indexed account, string name);
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

  /// @notice The LlamaFactory contract that deployed this llama instance.
  LlamaFactory public factory;

  /// @notice The NFT contract that defines the policies for this llama instance.
  LlamaPolicy public policy;

  /// @notice The Llama Account implementation (logic) contract.
  LlamaAccount public llamaAccountLogic;

  /// @notice Name of this llama instance.
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
  mapping(ILlamaStrategy => bool) public authorizedStrategies;

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

  /// @notice Initializes a new LlamaCore clone.
  /// @param _name The name of the LlamaCore clone.
  /// @param _policy This llama instance's policy contract.
  /// @param _llamaStrategyLogic The Llama Strategy implementation (logic) contract.
  /// @param _llamaAccountLogic The Llama Account implementation (logic) contract.
  /// @param initialStrategies The configuration of the initial strategies.
  /// @param initialAccounts The configuration of the initial strategies.
  function initialize(
    string memory _name,
    LlamaPolicy _policy,
    ILlamaStrategy _llamaStrategyLogic,
    LlamaAccount _llamaAccountLogic,
    bytes[] calldata initialStrategies,
    string[] calldata initialAccounts
  ) external initializer {
    factory = LlamaFactory(msg.sender);
    name = _name;
    policy = _policy;
    llamaAccountLogic = _llamaAccountLogic;

    _deployStrategies(_llamaStrategyLogic, initialStrategies);
    _deployAccounts(initialAccounts);
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Creates an action. The creator needs to hold a policy with the permissionId of the provided
  /// {target, selector, strategy}.
  /// @param role The role that will be used to determine the permissionId of the policy holder.
  /// @param strategy The ILlamaStrategy contract that will determine how the action is executed.
  /// @param target The contract called when the action is executed.
  /// @param value The value in wei to be sent when the action is executed.
  /// @param selector The function selector that will be called when the action is executed.
  /// @param data The encoded arguments to be passed to the function that is called when the action is executed.
  /// @return actionId actionId of the newly created action.
  function createAction(
    uint8 role,
    ILlamaStrategy strategy,
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
  /// @param strategy The ILlamaStrategy contract that will determine how the action is executed.
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
    ILlamaStrategy strategy,
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
  function executeAction(uint256 actionId) external payable {
    // Initial checks that action is ready to execute.
    if (getActionState(actionId) != ActionState.Queued) revert InvalidActionState(ActionState.Queued);

    Action storage action = actions[actionId];
    if (block.timestamp < action.minExecutionTime) revert TimelockNotFinished();
    if (msg.value < action.value) revert InsufficientMsgValue();

    action.executed = true;

    // Check pre-execution action guard.
    IActionGuard guard = actionGuard[action.target][action.selector];
    if (guard != IActionGuard(address(0))) {
      (bool allowed, bytes32 reason) = guard.validatePreActionExecution(actionId);
      if (!allowed) revert ProhibitedByActionGuard(reason);
    }

    // Execute action.
    bool success;
    bytes memory result;

    if (authorizedScripts[action.target]) {
      (success, result) = action.target.delegatecall(abi.encodePacked(action.selector, action.data));
    } else {
      (success, result) = action.target.call{value: action.value}(abi.encodePacked(action.selector, action.data));
    }

    if (!success) revert FailedActionExecution(result);

    // Check post-execution action guard.
    if (guard != IActionGuard(address(0))) {
      (bool allowed, bytes32 reason) = guard.validatePostActionExecution(actionId);
      if (!allowed) revert ProhibitedByActionGuard(reason);
    }

    // Action successfully executed.
    emit ActionExecuted(actionId, msg.sender, action.strategy, action.creator, result);
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
  /// @param llamaStrategyLogic address of the Llama Strategy logic contract.
  /// @param strategies list of new Strategys to be authorized.
  function createAndAuthorizeStrategies(ILlamaStrategy llamaStrategyLogic, bytes[] calldata strategies)
    external
    onlyLlama
  {
    _deployStrategies(llamaStrategyLogic, strategies);
  }

  /// @notice Remove strategies from the mapping of authorized strategies.
  /// @param strategies list of Strategys to be removed from the mapping of authorized strategies.
  function unauthorizeStrategies(ILlamaStrategy[] calldata strategies) external onlyLlama {
    uint256 strategiesLength = strategies.length;
    for (uint256 i = 0; i < strategiesLength; i = _uncheckedIncrement(i)) {
      delete authorizedStrategies[strategies[i]];
      emit StrategyUnauthorized(strategies[i]);
    }
  }

  /// @notice Deploy new accounts.
  /// @param accounts List of names of new accounts to be created.
  function createAccounts(string[] calldata accounts) external onlyLlama {
    _deployAccounts(accounts);
  }

  /// @notice Sets `guard` as the action guard for the given `target` and `selector`.
  /// @dev To remove a guard, set `guard` to the zero address.
  function setGuard(address target, bytes4 selector, IActionGuard guard) external onlyLlama {
    if (target == address(this) || target == address(policy)) revert CannotUseCoreOrPolicy();
    actionGuard[target][selector] = guard;
    emit ActionGuardSet(target, selector, guard);
  }

  /// @notice Authorizes `script` as the action guard for the given `target` and `selector`.
  /// @dev To remove a script, set `authorized` to false.
  function authorizeScript(address script, bool authorized) external onlyLlama {
    if (script == address(this) || script == address(policy)) revert CannotUseCoreOrPolicy();
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
    ILlamaStrategy strategy,
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

    // Safety: Can never overflow a uint256 by incrementing.
    actionsCount = _uncheckedIncrement(actionsCount);

    (bool allowed, bytes32 reason) = strategy.validateActionCreation(actionId);
    if (!allowed) revert ProhibitedByStrategy(reason);

    // If an action guard is present, call it to determine if the action can be created. We must do
    // this after the action is written to storage so that the action guard can any state it needs.
    IActionGuard guard = actionGuard[target][selector];
    if (guard != IActionGuard(address(0))) {
      (allowed, reason) = guard.validateActionCreation(actionId);
      if (!allowed) revert ProhibitedByActionGuard(reason);
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

  function _deployStrategies(ILlamaStrategy llamaStrategyLogic, bytes[] calldata strategies) internal {
    if (address(factory).code.length > 0 && !factory.authorizedStrategyLogics(llamaStrategyLogic)) {
      // The only edge case where this check is skipped is if `_deployStrategies()` is called by root llama instance
      // during Llama Factory construction. This is because there is no code at the Llama Factory address yet.
      revert UnauthorizedStrategyLogic();
    }

    uint256 strategyLength = strategies.length;
    for (uint256 i = 0; i < strategyLength; i = _uncheckedIncrement(i)) {
      bytes32 salt = bytes32(keccak256(strategies[i]));

      ILlamaStrategy strategy = ILlamaStrategy(Clones.cloneDeterministic(address(llamaStrategyLogic), salt));
      strategy.initialize(strategies[i]);
      authorizedStrategies[strategy] = true;
      emit StrategyAuthorized(strategy, llamaStrategyLogic, strategies[i]);
    }
  }

  function _deployAccounts(string[] calldata accounts) internal {
    uint256 accountLength = accounts.length;
    for (uint256 i = 0; i < accountLength; i = _uncheckedIncrement(i)) {
      bytes32 salt = bytes32(keccak256(abi.encode(accounts[i])));
      LlamaAccount account = LlamaAccount(payable(Clones.cloneDeterministic(address(llamaAccountLogic), salt)));
      account.initialize(accounts[i]);
      emit AccountCreated(account, accounts[i]);
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
