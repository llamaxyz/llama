// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaActionGuard} from "src/interfaces/ILlamaActionGuard.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {Action, ActionInfo, PermissionData} from "src/lib/Structs.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @title Llama Core
/// @author Llama (devsdosomething@llama.xyz)
/// @notice Manages the action process from creation to execution.
contract LlamaCore is Initializable {
  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  /// @dev Policyholder cannot cast if it has 0 quantity of role.
  /// @param policyholder Address of policyholder.
  /// @param role The role being used in the cast.
  error CannotCastWithZeroQuantity(address policyholder, uint8 role);

  /// @dev An action's target contract cannot be the executor.
  error CannotSetExecutorAsTarget();

  /// @dev Address cannot be used.
  error RestrictedAddress();

  /// @dev Policyholders can only cast once.
  error DuplicateCast();

  /// @dev Action execution failed.
  /// @param reason Data returned by the function called by the action.
  error FailedActionExecution(bytes reason);

  /// @dev `ActionInfo` does not hash to the correct value.
  error InfoHashMismatch();

  /// @dev `msg.value` does not equal the action's value.
  error IncorrectMsgValue();

  /// @dev The action is not in the expected state.
  /// @param current The current state of the action.
  error InvalidActionState(ActionState current);

  /// @dev The policyholder does not have the role at action creation time.
  error InvalidPolicyholder();

  /// @dev The recovered signer does not match the expected policyholder.
  error InvalidSignature();

  /// @dev The provided address does not map to a deployed strategy.
  error InvalidStrategy();

  /// @dev An action cannot queue successfully if it's `minExecutionTime` is less than `block.timestamp`.
  error MinExecutionTimeCannotBeInThePast();

  /// @dev Only callable by a Llama instance's executor.
  error OnlyLlama();

  /// @dev Policyholder does not have the permission ID to create the action.
  error PolicyholderDoesNotHavePermission();

  /// @dev If `block.timestamp` is less than `minExecutionTime`, the action cannot be executed.
  error MinExecutionTimeNotReached();

  /// @dev Strategies can only be created with valid logic contracts.
  error UnauthorizedStrategyLogic();

  /// @dev Accounts can only be created with valid logic contracts.
  error UnauthorizedAccountLogic();

  /// @dev Checks that the caller is the Llama Executor and reverts if not.
  modifier onlyLlama() {
    if (msg.sender != address(executor)) revert OnlyLlama();
    _;
  }

  // ========================
  // ======== Events ========
  // ========================

  /// @dev Emitted when an action is created.
  event ActionCreated(
    uint256 id,
    address indexed creator,
    uint8 role,
    ILlamaStrategy indexed strategy,
    address indexed target,
    uint256 value,
    bytes data,
    string description
  );

  /// @dev Emitted when an action is canceled.
  event ActionCanceled(uint256 id);

  /// @dev Emitted when an action guard is set.
  event ActionGuardSet(address indexed target, bytes4 indexed selector, ILlamaActionGuard actionGuard);

  /// @dev Emitted when an action is queued.
  event ActionQueued(
    uint256 id,
    address indexed caller,
    ILlamaStrategy indexed strategy,
    address indexed creator,
    uint256 minExecutionTime
  );

  /// @dev Emitted when an action is executed.
  event ActionExecuted(
    uint256 id, address indexed caller, ILlamaStrategy indexed strategy, address indexed creator, bytes result
  );

  /// @dev Emitted when an approval is cast.
  event ApprovalCast(uint256 id, address indexed policyholder, uint8 indexed role, uint256 quantity, string reason);

  /// @dev Emitted when a disapproval is cast.
  event DisapprovalCast(uint256 id, address indexed policyholder, uint8 indexed role, uint256 quantity, string reason);

  /// @dev Emitted when a strategy is created and authorized.
  event StrategyCreated(ILlamaStrategy strategy, ILlamaStrategy indexed strategyLogic, bytes initializationData);

  /// @dev Emitted when an account is created.
  event AccountCreated(ILlamaAccount account, ILlamaAccount indexed accountLogic, bytes initializationData);

  /// @dev Emitted when a script is authorized.
  event ScriptAuthorized(address script, bool authorized);

  // =================================================
  // ======== Constants and Storage Variables ========
  // =================================================

  /// @dev EIP-712 base typehash.
  bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @dev EIP-712 createAction typehash.
  bytes32 internal constant CREATE_ACTION_TYPEHASH = keccak256(
    "CreateAction(address policyholder,uint8 role,address strategy,address target,uint256 value,bytes data,string description,uint256 nonce)"
  );

  /// @dev EIP-712 castApproval typehash.
  bytes32 internal constant CAST_APPROVAL_TYPEHASH = keccak256(
    "CastApproval(address policyholder,uint8 role,ActionInfo actionInfo,string reason,uint256 nonce)ActionInfo(uint256 id,address creator,uint8 creatorRole,address strategy,address target,uint256 value,bytes data)"
  );

  /// @dev EIP-712 castDisapproval typehash.
  bytes32 internal constant CAST_DISAPPROVAL_TYPEHASH = keccak256(
    "CastDisapproval(address policyholder,uint8 role,ActionInfo actionInfo,string reason,uint256 nonce)ActionInfo(uint256 id,address creator,uint8 creatorRole,address strategy,address target,uint256 value,bytes data)"
  );

  /// @dev EIP-712 actionInfo typehash.
  bytes32 internal constant ACTION_INFO_TYPEHASH = keccak256(
    "ActionInfo(uint256 id,address creator,uint8 creatorRole,address strategy,address target,uint256 value,bytes data)"
  );

  /// @dev Mapping of actionIds to Actions.
  /// @dev Making this `public` results in stack too deep with no optimizer, but this data can be
  /// accessed with the `getAction` function so this is ok. We want the contracts to compile
  /// without the optimizer so `forge coverage` can be used.
  mapping(uint256 => Action) internal actions;

  /// @notice The contract that executes actions for this Llama instance.
  LlamaExecutor public executor;

  /// @notice The ERC721 contract that defines the policies for this Llama instance.
  /// @dev We intentionally put this first so it's packed with the `Initializable` storage
  // variables, which are the key variables we want to check before and after a delegatecall.
  LlamaPolicy public policy;

  /// @notice The `LlamaFactory` contract that deployed this Llama instance.
  LlamaFactory public factory;

  /// @notice Name of this Llama instance.
  string public name;

  /// @notice The current number of actions created.
  uint256 public actionsCount;

  /// @notice Mapping of actionIds to policyholders to approvals.
  mapping(uint256 => mapping(address => bool)) public approvals;

  /// @notice Mapping of actionIds to policyholders to disapprovals.
  mapping(uint256 => mapping(address => bool)) public disapprovals;

  /// @notice Mapping of all authorized strategies.
  mapping(ILlamaStrategy => bool) public strategies;

  /// @notice Mapping of all authorized scripts.
  mapping(address => bool) public authorizedScripts;

  /// @notice Mapping of policyholders to function selectors to current nonces for EIP-712 signatures.
  /// @dev This is used to prevent replay attacks by incrementing the nonce for each operation (`createAction`,
  /// `castApproval` and `castDisapproval`) signed by the policyholder.
  mapping(address => mapping(bytes4 => uint256)) public nonces;

  /// @notice Mapping of target to selector to actionGuard address.
  mapping(address target => mapping(bytes4 selector => ILlamaActionGuard)) public actionGuard;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes a new `LlamaCore` clone.
  /// @param _name The name of the `LlamaCore` clone.
  /// @param _policy This Llama instance's policy contract.
  /// @param _llamaStrategyLogic The Llama Strategy implementation (logic) contract.
  /// @param _llamaAccountLogic The Llama Account implementation (logic) contract.
  /// @param initialStrategies Array of initial strategy configurations.
  /// @param initialAccounts Array of initial account configurations.
  /// @return bootstrapPermissionId The permission ID that's used to set role permissions.
  function initialize(
    string memory _name,
    LlamaPolicy _policy,
    ILlamaStrategy _llamaStrategyLogic,
    ILlamaAccount _llamaAccountLogic,
    bytes[] calldata initialStrategies,
    bytes[] calldata initialAccounts
  ) external initializer returns (bytes32 bootstrapPermissionId) {
    factory = LlamaFactory(msg.sender);
    name = _name;
    executor = new LlamaExecutor();
    policy = _policy;

    ILlamaStrategy bootstrapStrategy = _deployStrategies(_llamaStrategyLogic, initialStrategies);
    _deployAccounts(_llamaAccountLogic, initialAccounts);

    // Now we compute the permission ID used to set role permissions and return it.
    bytes4 selector = LlamaPolicy.setRolePermission.selector;
    return keccak256(abi.encode(PermissionData(address(policy), bytes4(selector), bootstrapStrategy)));
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Creates an action. The creator needs to hold a policy with the permission ID of the provided
  /// `(target, selector, strategy)`.
  /// @dev Use `""` for `description` if there is no description.
  /// @param role The role that will be used to determine the permission ID of the policyholder.
  /// @param strategy The strategy contract that will determine how the action is executed.
  /// @param target The contract called when the action is executed.
  /// @param value The value in wei to be sent when the action is executed.
  /// @param data Data to be called on the target when the action is executed.
  /// @param description A human readable description of the action and the changes it will enact.
  /// @return actionId Action ID of the newly created action.
  function createAction(
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    string memory description
  ) external returns (uint256 actionId) {
    actionId = _createAction(msg.sender, role, strategy, target, value, data, description);
  }

  /// @notice Creates an action via an off-chain signature. The creator needs to hold a policy with the permission ID
  /// of the provided `(target, selector, strategy)`.
  /// @dev Use `""` for `description` if there is no description.
  /// @param policyholder The policyholder that signed the message.
  /// @param role The role that will be used to determine the permission ID of the policyholder.
  /// @param strategy The strategy contract that will determine how the action is executed.
  /// @param target The contract called when the action is executed.
  /// @param value The value in wei to be sent when the action is executed.
  /// @param data Data to be called on the target when the action is executed.
  /// @param description A human readable description of the action and the changes it will enact.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  /// @return actionId Action ID of the newly created action.
  function createActionBySig(
    address policyholder,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    string memory description,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256 actionId) {
    bytes32 digest = _getCreateActionTypedDataHash(policyholder, role, strategy, target, value, data, description);
    address signer = ecrecover(digest, v, r, s);
    if (signer == address(0) || signer != policyholder) revert InvalidSignature();
    actionId = _createAction(signer, role, strategy, target, value, data, description);
  }

  /// @notice Queue an action by its `actionInfo` struct if it's in Approved state.
  /// @param actionInfo Data required to create an action.
  function queueAction(ActionInfo calldata actionInfo) external {
    Action storage action = actions[actionInfo.id];
    ActionState currentState = getActionState(actionInfo);
    if (currentState != ActionState.Approved) revert InvalidActionState(currentState);

    uint64 minExecutionTime = actionInfo.strategy.minExecutionTime(actionInfo);
    if (minExecutionTime < block.timestamp) revert MinExecutionTimeCannotBeInThePast();
    action.minExecutionTime = minExecutionTime;
    emit ActionQueued(actionInfo.id, msg.sender, actionInfo.strategy, actionInfo.creator, minExecutionTime);
  }

  /// @notice Execute an action by its `actionInfo` struct if it's in Queued state and `minExecutionTime` has passed.
  /// @param actionInfo Data required to create an action.
  function executeAction(ActionInfo calldata actionInfo) external payable {
    // Initial checks that action is ready to execute.
    Action storage action = actions[actionInfo.id];
    ActionState currentState = getActionState(actionInfo);

    if (currentState != ActionState.Queued) revert InvalidActionState(currentState);
    if (block.timestamp < action.minExecutionTime) revert MinExecutionTimeNotReached();
    if (msg.value != actionInfo.value) revert IncorrectMsgValue();

    action.executed = true;

    // Check pre-execution action guard.
    ILlamaActionGuard guard = actionGuard[actionInfo.target][bytes4(actionInfo.data)];
    if (guard != ILlamaActionGuard(address(0))) guard.validatePreActionExecution(actionInfo);

    // Execute action.
    (bool success, bytes memory result) =
      executor.execute{value: msg.value}(actionInfo.target, actionInfo.value, action.isScript, actionInfo.data);

    if (!success) revert FailedActionExecution(result);

    // Check post-execution action guard.
    if (guard != ILlamaActionGuard(address(0))) guard.validatePostActionExecution(actionInfo);

    // Action successfully executed.
    emit ActionExecuted(actionInfo.id, msg.sender, actionInfo.strategy, actionInfo.creator, result);
  }

  /// @notice Cancels an action by its `actionInfo` struct.
  /// @dev Rules for cancelation are defined by the strategy.
  /// @param actionInfo Data required to create an action.
  function cancelAction(ActionInfo calldata actionInfo) external {
    Action storage action = actions[actionInfo.id];
    _validateActionInfoHash(action.infoHash, actionInfo);

    // We don't need an explicit check on action existence because if it doesn't exist the strategy will be the zero
    // address, and Solidity will revert since there is no code at the zero address.
    actionInfo.strategy.validateActionCancelation(actionInfo, msg.sender);

    action.canceled = true;
    emit ActionCanceled(actionInfo.id);
  }

  /// @notice How policyholders add their support of the approval of an action with a reason.
  /// @dev Use `""` for `reason` if there is no reason.
  /// @param role The role the policyholder uses to cast their approval.
  /// @param actionInfo Data required to create an action.
  /// @param reason The reason given for the approval by the policyholder.
  function castApproval(uint8 role, ActionInfo calldata actionInfo, string calldata reason) external {
    return _castApproval(msg.sender, role, actionInfo, reason);
  }

  /// @notice How policyholders add their support of the approval of an action via an off-chain signature.
  /// @dev Use `""` for `reason` if there is no reason.
  /// @param policyholder The policyholder that signed the message.
  /// @param role The role the policyholder uses to cast their approval.
  /// @param actionInfo Data required to create an action.
  /// @param reason The reason given for the approval by the policyholder.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  function castApprovalBySig(
    address policyholder,
    uint8 role,
    ActionInfo calldata actionInfo,
    string calldata reason,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    bytes32 digest = _getCastApprovalTypedDataHash(policyholder, role, actionInfo, reason);
    address signer = ecrecover(digest, v, r, s);
    if (signer == address(0) || signer != policyholder) revert InvalidSignature();
    return _castApproval(signer, role, actionInfo, reason);
  }

  /// @notice How policyholders add their support of the disapproval of an action with a reason.
  /// @dev Use `""` for `reason` if there is no reason.
  /// @param role The role the policyholder uses to cast their disapproval.
  /// @param actionInfo Data required to create an action.
  /// @param reason The reason given for the disapproval by the policyholder.
  function castDisapproval(uint8 role, ActionInfo calldata actionInfo, string calldata reason) external {
    return _castDisapproval(msg.sender, role, actionInfo, reason);
  }

  /// @notice How policyholders add their support of the disapproval of an action via an off-chain signature.
  /// @dev Use `""` for `reason` if there is no reason.
  /// @param policyholder The policyholder that signed the message.
  /// @param role The role the policyholder uses to cast their disapproval.
  /// @param actionInfo Data required to create an action.
  /// @param reason The reason given for the approval by the policyholder.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  function castDisapprovalBySig(
    address policyholder,
    uint8 role,
    ActionInfo calldata actionInfo,
    string calldata reason,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    bytes32 digest = _getCastDisapprovalTypedDataHash(policyholder, role, actionInfo, reason);
    address signer = ecrecover(digest, v, r, s);
    if (signer == address(0) || signer != policyholder) revert InvalidSignature();
    return _castDisapproval(signer, role, actionInfo, reason);
  }

  /// @notice Deploy new strategies and add them to the mapping of authorized strategies.
  /// @param llamaStrategyLogic address of the Llama strategy logic contract.
  /// @param strategyConfigs Array of new strategy configurations.
  function createStrategies(ILlamaStrategy llamaStrategyLogic, bytes[] calldata strategyConfigs) external onlyLlama {
    _deployStrategies(llamaStrategyLogic, strategyConfigs);
  }

  /// @notice Deploy new accounts.
  /// @param llamaAccountLogic address of the Llama account logic contract.
  /// @param accountConfigs Array of new account configurations.
  function createAccounts(ILlamaAccount llamaAccountLogic, bytes[] calldata accountConfigs) external onlyLlama {
    _deployAccounts(llamaAccountLogic, accountConfigs);
  }

  /// @notice Sets `guard` as the action guard for the given `target` and `selector`.
  /// @param target The target contract where the `guard` will apply.
  /// @param selector The function selector where the `guard` will apply.
  /// @dev To remove a guard, set `guard` to the zero address.
  function setGuard(address target, bytes4 selector, ILlamaActionGuard guard) external onlyLlama {
    if (target == address(this) || target == address(policy)) revert RestrictedAddress();
    actionGuard[target][selector] = guard;
    emit ActionGuardSet(target, selector, guard);
  }

  /// @notice Authorizes `script` to be eligible to be delegatecalled from the executor.
  /// @param script The address of the script contract.
  /// @param authorized The boolean that determines if the `script` is being authorized or unauthorized.
  /// @dev To remove a `script`, set `authorized` to `false`.
  function authorizeScript(address script, bool authorized) external onlyLlama {
    if (script == address(this) || script == address(policy)) revert RestrictedAddress();
    authorizedScripts[script] = authorized;
    emit ScriptAuthorized(script, authorized);
  }

  /// @notice Increments the caller's nonce for the given `selector`. This is useful for revoking
  /// signatures that have not been used yet.
  /// @param selector The function selector to increment the nonce for.
  function incrementNonce(bytes4 selector) external {
    // Safety: Can never overflow a uint256 by incrementing.
    nonces[msg.sender][selector] = LlamaUtils.uncheckedIncrement(nonces[msg.sender][selector]);
  }

  /// @notice Get an Action struct by `actionId`.
  /// @param actionId ID of the action.
  /// @return The Action struct.
  function getAction(uint256 actionId) external view returns (Action memory) {
    return actions[actionId];
  }

  /// @notice Returns the timestamp of most recently created action.
  /// @dev Used by `LlamaPolicy` to ensure policy management does not occur immediately after action
  /// creation in the same timestamp, as this could result in invalid role supply counts being used.
  function getLastActionTimestamp() external view returns (uint256 timestamp) {
    return actionsCount == 0 ? 0 : actions[actionsCount - 1].creationTime;
  }

  /// @notice Get the current action state of an action by its `actionInfo` struct.
  /// @param actionInfo Data required to create an action.
  /// @return The current action state of the action.
  function getActionState(ActionInfo calldata actionInfo) public view returns (ActionState) {
    // We don't need an explicit check on the action ID to make sure it exists, because if the
    // action does not exist, the expected payload hash from storage will be `bytes32(0)`, so
    // bypassing this check by providing a non-existent actionId would require finding a collision
    // to get a hash of zero.
    Action storage action = actions[actionInfo.id];
    _validateActionInfoHash(action.infoHash, actionInfo);

    if (action.canceled) return ActionState.Canceled;

    if (action.executed) return ActionState.Executed;

    if (actionInfo.strategy.isActive(actionInfo)) return ActionState.Active;

    if (!actionInfo.strategy.isActionApproved(actionInfo)) return ActionState.Failed;

    if (action.minExecutionTime == 0) return ActionState.Approved;

    if (actionInfo.strategy.isActionDisapproved(actionInfo)) return ActionState.Failed;

    if (actionInfo.strategy.isActionExpired(actionInfo)) return ActionState.Expired;

    return ActionState.Queued;
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Creates an action. The creator needs to hold a policy with the permission ID of the provided
  /// `(target, selector, strategy)`.
  function _createAction(
    address policyholder,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    string memory description
  ) internal returns (uint256 actionId) {
    if (target == address(executor)) revert CannotSetExecutorAsTarget();
    if (!strategies[strategy]) revert InvalidStrategy();

    PermissionData memory permission = PermissionData(target, bytes4(data), strategy);
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

    // Validate action creation.
    actionId = actionsCount;

    ActionInfo memory actionInfo = ActionInfo(actionId, policyholder, role, strategy, target, value, data);
    strategy.validateActionCreation(actionInfo);

    // Scope to avoid stack too deep
    {
      ILlamaActionGuard guard = actionGuard[target][bytes4(data)];
      if (guard != ILlamaActionGuard(address(0))) guard.validateActionCreation(actionInfo);

      // Save action.
      Action storage newAction = actions[actionId];
      newAction.infoHash = _infoHash(actionId, policyholder, role, strategy, target, value, data);
      newAction.creationTime = LlamaUtils.toUint64(block.timestamp);
      newAction.isScript = authorizedScripts[target];
    }

    actionsCount = LlamaUtils.uncheckedIncrement(actionsCount); // Safety: Can never overflow a uint256 by incrementing.

    emit ActionCreated(actionId, policyholder, role, strategy, target, value, data, description);
  }

  /// @dev How policyholders that have the right role contribute towards the approval of an action with a reason.
  function _castApproval(address policyholder, uint8 role, ActionInfo calldata actionInfo, string memory reason)
    internal
  {
    (Action storage action, uint128 quantity) = _preCastAssertions(actionInfo, policyholder, role, ActionState.Active);

    action.totalApprovals = _newCastCount(action.totalApprovals, quantity);
    approvals[actionInfo.id][policyholder] = true;
    emit ApprovalCast(actionInfo.id, policyholder, role, quantity, reason);
  }

  /// @dev How policyholders that have the right role contribute towards the disapproval of an action with a reason.
  function _castDisapproval(address policyholder, uint8 role, ActionInfo calldata actionInfo, string memory reason)
    internal
  {
    (Action storage action, uint128 quantity) = _preCastAssertions(actionInfo, policyholder, role, ActionState.Queued);

    action.totalDisapprovals = _newCastCount(action.totalDisapprovals, quantity);
    disapprovals[actionInfo.id][policyholder] = true;
    emit DisapprovalCast(actionInfo.id, policyholder, role, quantity, reason);
  }

  /// @dev The only `expectedState` values allowed to be passed into this method are Active or Queued.
  function _preCastAssertions(
    ActionInfo calldata actionInfo,
    address policyholder,
    uint8 role,
    ActionState expectedState
  ) internal returns (Action storage action, uint128 quantity) {
    action = actions[actionInfo.id];
    ActionState currentState = getActionState(actionInfo);
    if (currentState != expectedState) revert InvalidActionState(currentState);

    bool isApproval = expectedState == ActionState.Active;
    bool alreadyCast = isApproval ? approvals[actionInfo.id][policyholder] : disapprovals[actionInfo.id][policyholder];
    if (alreadyCast) revert DuplicateCast();

    bool hasRole = policy.hasRole(policyholder, role, action.creationTime);
    if (!hasRole) revert InvalidPolicyholder();

    if (isApproval) {
      actionInfo.strategy.isApprovalEnabled(actionInfo, policyholder, role);
      quantity = actionInfo.strategy.getApprovalQuantityAt(policyholder, role, action.creationTime);
      if (quantity == 0) revert CannotCastWithZeroQuantity(policyholder, role);
    } else {
      actionInfo.strategy.isDisapprovalEnabled(actionInfo, policyholder, role);
      quantity = actionInfo.strategy.getDisapprovalQuantityAt(policyholder, role, action.creationTime);
      if (quantity == 0) revert CannotCastWithZeroQuantity(policyholder, role);
    }
  }

  /// @dev Returns the new total count of approvals or disapprovals.
  function _newCastCount(uint128 currentCount, uint128 quantity) internal pure returns (uint128) {
    if (currentCount == type(uint128).max || quantity == type(uint128).max) return type(uint128).max;
    return currentCount + quantity;
  }

  /// @dev Deploys new strategies. Takes in the strategy logic contract to be used and an array of configurations to
  /// initialize the new strategies with. Returns the address of the first strategy, which is only used during the
  /// `LlamaCore` initialization so that we can ensure someone (specifically, policyholders with role ID 1) has the
  /// permission to assign role permissions.
  function _deployStrategies(ILlamaStrategy llamaStrategyLogic, bytes[] calldata strategyConfigs)
    internal
    returns (ILlamaStrategy firstStrategy)
  {
    if (address(factory).code.length > 0 && !factory.authorizedStrategyLogics(llamaStrategyLogic)) {
      // The only edge case where this check is skipped is if `_deployStrategies()` is called by root llama instance
      // during Llama Factory construction. This is because there is no code at the Llama Factory address yet.
      revert UnauthorizedStrategyLogic();
    }

    uint256 strategyLength = strategyConfigs.length;
    for (uint256 i = 0; i < strategyLength; i = LlamaUtils.uncheckedIncrement(i)) {
      bytes32 salt = bytes32(keccak256(strategyConfigs[i]));
      ILlamaStrategy strategy = ILlamaStrategy(Clones.cloneDeterministic(address(llamaStrategyLogic), salt));
      strategy.initialize(strategyConfigs[i]);
      strategies[strategy] = true;
      emit StrategyCreated(strategy, llamaStrategyLogic, strategyConfigs[i]);
      if (i == 0) firstStrategy = strategy;
    }
  }

  /// @dev Deploys new accounts. Takes in the account logic contract to be used and an array of configurations to
  /// initialize the new accounts with.
  function _deployAccounts(ILlamaAccount llamaAccountLogic, bytes[] calldata accountConfigs) internal {
    if (address(factory).code.length > 0 && !factory.authorizedAccountLogics(llamaAccountLogic)) {
      // The only edge case where this check is skipped is if `_deployAccounts()` is called by root llama instance
      // during Llama Factory construction. This is because there is no code at the Llama Factory address yet.
      revert UnauthorizedAccountLogic();
    }

    uint256 accountLength = accountConfigs.length;
    for (uint256 i = 0; i < accountLength; i = LlamaUtils.uncheckedIncrement(i)) {
      bytes32 salt = bytes32(keccak256(accountConfigs[i]));
      ILlamaAccount account = ILlamaAccount(Clones.cloneDeterministic(address(llamaAccountLogic), salt));
      account.initialize(accountConfigs[i]);
      emit AccountCreated(account, llamaAccountLogic, accountConfigs[i]);
    }
  }

  /// @dev Returns the hash of the `createAction` parameters using the `actionInfo` struct.
  function _infoHash(ActionInfo calldata actionInfo) internal pure returns (bytes32) {
    return _infoHash(
      actionInfo.id,
      actionInfo.creator,
      actionInfo.creatorRole,
      actionInfo.strategy,
      actionInfo.target,
      actionInfo.value,
      actionInfo.data
    );
  }

  /// @dev Returns the hash of the `createAction` parameters.
  function _infoHash(
    uint256 id,
    address creator,
    uint8 creatorRole,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(id, creator, creatorRole, strategy, target, value, data));
  }

  /// @dev Validates that the hash of the `actionInfo` struct matches the provided hash.
  function _validateActionInfoHash(bytes32 actualHash, ActionInfo calldata actionInfo) internal pure {
    bytes32 expectedHash = _infoHash(actionInfo);
    if (actualHash != expectedHash) revert InfoHashMismatch();
  }

  /// @dev Returns the current nonce for a given policyholder and selector, and increments it. Used to prevent
  /// replay attacks.
  function _useNonce(address policyholder, bytes4 selector) internal returns (uint256 nonce) {
    nonce = nonces[policyholder][selector];
    nonces[policyholder][selector] = LlamaUtils.uncheckedIncrement(nonce);
  }

  // -------- EIP-712 Getters --------

  /// @dev Returns the EIP-712 domain separator.
  function _getDomainHash() internal view returns (bytes32) {
    return keccak256(
      abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes("1")), block.chainid, address(this))
    );
  }

  /// @dev Returns the hash of the ABI-encoded EIP-712 message for the `CreateAction` domain, which can be used to
  /// recover the signer.
  function _getCreateActionTypedDataHash(
    address policyholder,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    string memory description
  ) internal returns (bytes32) {
    // Calculating and storing nonce in memory and using that below, instead of calculating in place to prevent stack
    // too deep error.
    uint256 nonce = _useNonce(policyholder, msg.sig);

    bytes32 createActionHash = keccak256(
      abi.encode(
        CREATE_ACTION_TYPEHASH,
        policyholder,
        role,
        address(strategy),
        target,
        value,
        keccak256(data),
        keccak256(bytes(description)),
        nonce
      )
    );

    return keccak256(abi.encodePacked("\x19\x01", _getDomainHash(), createActionHash));
  }

  /// @dev Returns the hash of the ABI-encoded EIP-712 message for the `CastApproval` domain, which can be used to
  /// recover the signer.
  function _getCastApprovalTypedDataHash(
    address policyholder,
    uint8 role,
    ActionInfo calldata actionInfo,
    string calldata reason
  ) internal returns (bytes32) {
    bytes32 castApprovalHash = keccak256(
      abi.encode(
        CAST_APPROVAL_TYPEHASH,
        policyholder,
        role,
        _getActionInfoHash(actionInfo),
        keccak256(bytes(reason)),
        _useNonce(policyholder, msg.sig)
      )
    );

    return keccak256(abi.encodePacked("\x19\x01", _getDomainHash(), castApprovalHash));
  }

  /// @dev Returns the hash of the ABI-encoded EIP-712 message for the `CastDisapproval` domain, which can be used to
  /// recover the signer.
  function _getCastDisapprovalTypedDataHash(
    address policyholder,
    uint8 role,
    ActionInfo calldata actionInfo,
    string calldata reason
  ) internal returns (bytes32) {
    bytes32 castDisapprovalHash = keccak256(
      abi.encode(
        CAST_DISAPPROVAL_TYPEHASH,
        policyholder,
        role,
        _getActionInfoHash(actionInfo),
        keccak256(bytes(reason)),
        _useNonce(policyholder, msg.sig)
      )
    );

    return keccak256(abi.encodePacked("\x19\x01", _getDomainHash(), castDisapprovalHash));
  }

  /// @dev Returns the hash of `actionInfo`.
  function _getActionInfoHash(ActionInfo calldata actionInfo) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        ACTION_INFO_TYPEHASH,
        actionInfo.id,
        actionInfo.creator,
        actionInfo.creatorRole,
        address(actionInfo.strategy),
        actionInfo.target,
        actionInfo.value,
        keccak256(actionInfo.data)
      )
    );
  }
}
