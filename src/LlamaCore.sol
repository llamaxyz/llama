// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Clones} from "@openzeppelin/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";

import {IActionGuard} from "src/interfaces/IActionGuard.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionState} from "src/lib/Enums.sol";
import {Action, ActionInfo, PermissionData} from "src/lib/Structs.sol";
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

  error ApprovalQuantityZero(address policyholder, uint8 role);
  error CannotUseCoreOrPolicy();
  error DuplicateCast();
  error DisapprovalQuantityZero(address policyholder, uint8 role);
  error FailedActionExecution(bytes reason);
  error InfoHashMismatch();
  error InsufficientMsgValue();
  error InvalidActionState(ActionState expected);
  error InvalidPolicyholder();
  error InvalidSignature();
  error InvalidStrategy();
  error OnlyLlama();
  error PolicyholderDoesNotHavePermission();
  error Slot0Changed();
  error TimelockNotFinished();
  error UnauthorizedStrategyLogic();
  error UnsafeCast(uint256 n);

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
    address indexed target,
    uint256 value,
    bytes data,
    string description
  );
  event ActionCanceled(uint256 id);
  event ActionGuardSet(address indexed target, bytes4 indexed selector, IActionGuard actionGuard);
  event ActionQueued(
    uint256 id,
    address indexed caller,
    ILlamaStrategy indexed strategy,
    address indexed creator,
    uint256 minExecutionTime
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
    "CreateAction(uint8 role,address strategy,address target,uint256 value,bytes data,address policyholder,uint256 nonce)"
  );

  /// @notice EIP-712 castApproval typehash.
  bytes32 internal constant CAST_APPROVAL_TYPEHASH = keccak256(
    "CastApproval((uint256 id, address creator, ILlamaStrategy strategy, address target, uint256 value, bytes data),uint8 role,string reason,address policyholder,uint256 nonce)"
  );

  /// @notice EIP-712 castDisapproval typehash.
  bytes32 internal constant CAST_DISAPPROVAL_TYPEHASH = keccak256(
    "CastDisapproval((uint256 id, address creator, ILlamaStrategy strategy, address target, uint256 value, bytes data),uint8 role,string reason,address policyholder,uint256 nonce)"
  );

  /// @notice The NFT contract that defines the policies for this llama instance.
  /// @dev We intentionally put this first so it's packed with the `Initializable` storage
  // variables, which are the key variables we want to check before and after a delegatecall.
  LlamaPolicy public policy;

  /// @notice The LlamaFactory contract that deployed this llama instance.
  LlamaFactory public factory;

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

  /// @notice Mapping of policyholders to function selectors to current nonces for EIP-712 signatures.
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
  /// @return bootstrapPermissionId The permission ID that's used to set role permissions.
  function initialize(
    string memory _name,
    LlamaPolicy _policy,
    ILlamaStrategy _llamaStrategyLogic,
    LlamaAccount _llamaAccountLogic,
    bytes[] calldata initialStrategies,
    string[] calldata initialAccounts
  ) external initializer returns (bytes32 bootstrapPermissionId) {
    factory = LlamaFactory(msg.sender);
    name = _name;
    policy = _policy;
    llamaAccountLogic = _llamaAccountLogic;

    ILlamaStrategy bootstrapStrategy = _deployStrategies(_llamaStrategyLogic, initialStrategies);
    _deployAccounts(initialAccounts);

    // Now we compute the permission ID used to set role permissions and return it.
    bytes4 selector = LlamaPolicy.setRolePermission.selector;
    return keccak256(abi.encode(PermissionData(address(policy), bytes4(selector), bootstrapStrategy)));
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
  /// @param data Data to be called on the `target` when the action is executed.
  /// @return actionId actionId of the newly created action.
  function createAction(uint8 role, ILlamaStrategy strategy, address target, uint256 value, bytes calldata data)
    external
    returns (uint256 actionId)
  {
    actionId = _createAction(msg.sender, role, strategy, target, value, data, "");
  }

  /// @notice Creates an action. The creator needs to hold a policy with the permissionId of the provided
  /// {target, selector, strategy}.
  /// @param role The role that will be used to determine the permissionId of the policy holder.
  /// @param strategy The ILlamaStrategy contract that will determine how the action is executed.
  /// @param target The contract called when the action is executed.
  /// @param value The value in wei to be sent when the action is executed.
  /// @param data Data to be called on the `target` when the action is executed.
  /// @param description A human readable description of the action and the changes it will enact.
  /// @return actionId actionId of the newly created action.
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

  /// @notice Creates an action via an off-chain signature. The creator needs to hold a policy with the permissionId of
  /// the provided {target, selector, strategy}.
  /// @param role The role that will be used to determine the permissionId of the policy holder.
  /// @param strategy The ILlamaStrategy contract that will determine how the action is executed.
  /// @param target The contract called when the action is executed.
  /// @param value The value in wei to be sent when the action is executed.
  /// @param data Data to be called on the `target` when the action is executed.
  /// @param policyholder The policyholder that signed the message.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  /// @return actionId actionId of the newly created action.
  function createActionBySig(
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    address policyholder,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external returns (uint256) {
    return _createActionBySig(role, strategy, target, value, data, policyholder, v, r, s, "");
  }

  /// @notice Creates an action via an off-chain signature. The creator needs to hold a policy with the permissionId of
  /// the provided {target, selector, strategy}.
  /// @param role The role that will be used to determine the permissionId of the policy holder.
  /// @param strategy The ILlamaStrategy contract that will determine how the action is executed.
  /// @param target The contract called when the action is executed.
  /// @param value The value in wei to be sent when the action is executed.
  /// @param data Data to be called on the `target` when the action is executed.
  /// @param policyholder The policyholder that signed the message.
  /// @param description A human readable description of the action and the changes it will enact.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  /// @return actionId actionId of the newly created action.
  function createActionBySig(
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    address policyholder,
    uint8 v,
    bytes32 r,
    bytes32 s,
    string memory description
  ) external returns (uint256 actionId) {
    return _createActionBySig(role, strategy, target, value, data, policyholder, v, r, s, description);
  }

  /// @notice Queue an action by actionId if it's in Approved state.
  /// @param actionInfo Data required to create an action.
  function queueAction(ActionInfo calldata actionInfo) external {
    Action storage action = actions[actionInfo.id];
    _validateActionInfoHash(action.infoHash, actionInfo);
    if (getActionState(actionInfo) != ActionState.Approved) revert InvalidActionState(ActionState.Approved);

    uint64 minExecutionTime = actionInfo.strategy.minExecutionTime(actionInfo);
    action.minExecutionTime = minExecutionTime;
    emit ActionQueued(actionInfo.id, msg.sender, actionInfo.strategy, actionInfo.creator, minExecutionTime);
  }

  /// @notice Execute an action by actionId if it's in Queued state and executionTime has passed.
  /// @param actionInfo Data required to create an action.
  function executeAction(ActionInfo calldata actionInfo) external payable {
    Action storage action = actions[actionInfo.id];
    _validateActionInfoHash(action.infoHash, actionInfo);

    // Initial checks that action is ready to execute.
    if (getActionState(actionInfo) != ActionState.Queued) revert InvalidActionState(ActionState.Queued);
    if (block.timestamp < action.minExecutionTime) revert TimelockNotFinished();
    if (msg.value < actionInfo.value) revert InsufficientMsgValue();

    action.executed = true;

    // Check pre-execution action guard.
    IActionGuard guard = actionGuard[actionInfo.target][bytes4(actionInfo.data)];
    if (guard != IActionGuard(address(0))) guard.validatePreActionExecution(actionInfo);

    // Execute action.
    bool success;
    bytes memory result;

    if (authorizedScripts[actionInfo.target]) {
      // Whenever we're executing arbitrary code in the context of LlamaCore, we want to ensure that
      // none of the storage in this contract changes in unexpected ways, as this could let someone
      // who sneaks in a malicious (or buggy) target to effectively take ownership of this contract.
      // However, this contract has a lot of storage so it's not practical to check all slots,
      // especially since some may be expected to change. Therefore we instead just check slot0,
      // since that slot (1) contains core variables that should never be changed, and (2) is the
      // first slot so it's the most likely to be accidentally overwritten with a bad script. The
      // storage layout of this contract is below:
      //
      // | Variable Name        | Type                                                         | Slot | Offset | Bytes |
      // |----------------------|--------------------------------------------------------------|------|--------|-------|
      // | _initialized         | uint8                                                        | 0    | 0      | 1     |
      // | _initializing        | bool                                                         | 0    | 1      | 1     |
      // | policy               | contract LlamaPolicy                                         | 0    | 2      | 20    |
      // | factory              | contract LlamaFactory                                        | 1    | 0      | 20    |
      // | llamaAccountLogic    | contract LlamaAccount                                        | 2    | 0      | 20    |
      // | name                 | string                                                       | 3    | 0      | 32    |
      // | actionsCount         | uint256                                                      | 4    | 0      | 32    |
      // | actions              | mapping(uint256 => struct Action)                            | 5    | 0      | 32    |
      // | approvals            | mapping(uint256 => mapping(address => bool))                 | 6    | 0      | 32    |
      // | disapprovals         | mapping(uint256 => mapping(address => bool))                 | 7    | 0      | 32    |
      // | authorizedStrategies | mapping(contract ILlamaStrategy => bool)                     | 8    | 0      | 32    |
      // | authorizedScripts    | mapping(address => bool)                                     | 9    | 0      | 32    |
      // | nonces               | mapping(address => mapping(bytes4 => uint256))               | 10   | 0      | 32    |
      // | actionGuard          | mapping(address => mapping(bytes4 => contract IActionGuard)) | 11   | 0      | 32    |

      bytes32 originalStorage = _readSlot0();
      (success, result) = actionInfo.target.delegatecall(actionInfo.data);
      if (originalStorage != _readSlot0()) revert Slot0Changed();
    } else {
      (success, result) = actionInfo.target.call{value: actionInfo.value}(actionInfo.data);
    }

    if (!success) revert FailedActionExecution(result);

    // Check post-execution action guard.
    if (guard != IActionGuard(address(0))) guard.validatePostActionExecution(actionInfo);

    // Action successfully executed.
    emit ActionExecuted(actionInfo.id, msg.sender, actionInfo.strategy, actionInfo.creator, result);
  }

  /// @notice Cancels an action. Rules for cancelation are defined by the strategy.
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

  /// @notice How policyholders add their support of the approval of an action.
  /// @param actionInfo Data required to create an action.
  /// @param role The role the policyholder uses to cast their approval.
  function castApproval(ActionInfo calldata actionInfo, uint8 role) external {
    return _castApproval(msg.sender, role, actionInfo, "");
  }

  /// @notice How policyholders add their support of the approval of an action with a reason.
  /// @param actionInfo Data required to create an action.
  /// @param role The role the policyholder uses to cast their approval.
  /// @param reason The reason given for the approval by the policyholder.
  function castApproval(ActionInfo calldata actionInfo, uint8 role, string calldata reason) external {
    return _castApproval(msg.sender, role, actionInfo, reason);
  }

  /// @notice How policyholders add their support of the approval of an action via an off-chain signature.
  /// @param actionInfo Data required to create an action.
  /// @param role The role the policyholder uses to cast their approval.
  /// @param reason The reason given for the approval by the policyholder.
  /// @param policyholder The policyholder that signed the message.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  function castApprovalBySig(
    ActionInfo calldata actionInfo,
    uint8 role,
    string calldata reason,
    address policyholder,
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
            CAST_APPROVAL_TYPEHASH,
            actionInfo,
            role,
            keccak256(bytes(reason)),
            policyholder,
            _useNonce(policyholder, msg.sig)
          )
        )
      )
    );
    address signer = ecrecover(digest, v, r, s);
    if (signer == address(0) || signer != policyholder) revert InvalidSignature();
    return _castApproval(signer, role, actionInfo, reason);
  }

  /// @notice How policyholders add their support of the disapproval of an action.
  /// @param actionInfo Data required to create an action.
  /// @param role The role the policyholder uses to cast their disapproval.
  function castDisapproval(ActionInfo calldata actionInfo, uint8 role) external {
    return _castDisapproval(msg.sender, role, actionInfo, "");
  }

  /// @notice How policyholders add their support of the disapproval of an action with a reason.
  /// @param actionInfo Data required to create an action.
  /// @param role The role the policyholder uses to cast their disapproval.
  /// @param reason The reason given for the disapproval by the policyholder.
  function castDisapproval(ActionInfo calldata actionInfo, uint8 role, string calldata reason) external {
    return _castDisapproval(msg.sender, role, actionInfo, reason);
  }

  /// @notice How policyholders add their support of the disapproval of an action via an off-chain signature.
  /// @param actionInfo Data required to create an action.
  /// @param role The role the policyholder uses to cast their disapproval.
  /// @param reason The reason given for the approval by the policyholder.
  /// @param policyholder The policyholder that signed the message.
  /// @param v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param r ECDSA signature component: x-coordinate of `R`
  /// @param s ECDSA signature component: `s` value of the signature
  function castDisapprovalBySig(
    ActionInfo calldata actionInfo,
    uint8 role,
    string calldata reason,
    address policyholder,
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
            CAST_DISAPPROVAL_TYPEHASH,
            actionInfo,
            role,
            keccak256(bytes(reason)),
            policyholder,
            _useNonce(policyholder, msg.sig)
          )
        )
      )
    );
    address signer = ecrecover(digest, v, r, s);
    if (signer == address(0) || signer != policyholder) revert InvalidSignature();
    return _castDisapproval(signer, role, actionInfo, reason);
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
  /// @param actionInfo Data required to create an action.
  /// @return The current ActionState of the action.
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

  function _createAction(
    address policyholder,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    string memory description
  ) internal returns (uint256 actionId) {
    if (!authorizedStrategies[strategy]) revert InvalidStrategy();

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

    IActionGuard guard = actionGuard[target][bytes4(data)];
    if (guard != IActionGuard(address(0))) guard.validateActionCreation(actionInfo);

    // Save action.
    Action storage newAction = actions[actionId];
    newAction.infoHash = _infoHash(actionId, policyholder, role, strategy, target, value, data);
    newAction.creationTime = _toUint64(block.timestamp);
    actionsCount = _uncheckedIncrement(actionsCount); // Safety: Can never overflow a uint256 by incrementing.

    emit ActionCreated(actionId, policyholder, strategy, target, value, data, description);
  }

  function _createActionBySig(
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data,
    address policyholder,
    uint8 v,
    bytes32 r,
    bytes32 s,
    string memory description
  ) internal returns (uint256 actionId) {
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
            keccak256(data),
            policyholder,
            _useNonce(policyholder, msg.sig)
          )
        )
      )
    );
    address signer = ecrecover(digest, v, r, s);
    if (signer == address(0) || signer != policyholder) revert InvalidSignature();
    actionId = _createAction(signer, role, strategy, target, value, data, description);
  }

  function _castApproval(address policyholder, uint8 role, ActionInfo calldata actionInfo, string memory reason)
    internal
  {
    Action storage action = _preCastAssertions(actionInfo, policyholder, role, ActionState.Active);

    uint128 quantity = actionInfo.strategy.getApprovalQuantityAt(policyholder, role, action.creationTime);
    if (quantity == 0) revert ApprovalQuantityZero(policyholder, role);
    action.totalApprovals = _newCastCount(action.totalApprovals, quantity);
    approvals[actionInfo.id][policyholder] = true;
    emit ApprovalCast(actionInfo.id, policyholder, quantity, reason);
  }

  function _castDisapproval(address policyholder, uint8 role, ActionInfo calldata actionInfo, string memory reason)
    internal
  {
    Action storage action = _preCastAssertions(actionInfo, policyholder, role, ActionState.Queued);

    uint128 quantity = actionInfo.strategy.getDisapprovalQuantityAt(policyholder, role, action.creationTime);
    if (quantity == 0) revert DisapprovalQuantityZero(policyholder, role);
    action.totalDisapprovals = _newCastCount(action.totalDisapprovals, quantity);
    disapprovals[actionInfo.id][policyholder] = true;
    emit DisapprovalCast(actionInfo.id, policyholder, quantity, reason);
  }

  /// @dev The only `expectedState` values allowed to be passed into this method are Active or Queued.
  function _preCastAssertions(
    ActionInfo calldata actionInfo,
    address policyholder,
    uint8 role,
    ActionState expectedState
  ) internal returns (Action storage action) {
    action = actions[actionInfo.id];
    _validateActionInfoHash(action.infoHash, actionInfo);

    if (getActionState(actionInfo) != expectedState) revert InvalidActionState(expectedState);

    bool isApproval = expectedState == ActionState.Active;
    bool alreadyCast = isApproval ? approvals[actionInfo.id][policyholder] : disapprovals[actionInfo.id][policyholder];
    if (alreadyCast) revert DuplicateCast();

    bool hasRole = policy.hasRole(policyholder, role, action.creationTime);
    if (!hasRole) revert InvalidPolicyholder();

    isApproval
      ? actionInfo.strategy.isApprovalEnabled(actionInfo, msg.sender, role)
      : actionInfo.strategy.isDisapprovalEnabled(actionInfo, msg.sender, role);
  }

  /// @dev Returns the new total count of approvals or disapprovals.
  function _newCastCount(uint128 currentCount, uint128 quantity) internal pure returns (uint128) {
    if (currentCount == type(uint128).max || quantity == type(uint128).max) return type(uint128).max;
    return currentCount + quantity;
  }

  /// @dev Deploys strategies, and returns the address of the first strategy. This is only used
  /// during initialization so we can ensure someone (specifically, policyholders with role ID 1)
  /// have permission to assign role permissions.
  function _deployStrategies(ILlamaStrategy llamaStrategyLogic, bytes[] calldata strategies)
    internal
    returns (ILlamaStrategy firstStrategy)
  {
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
      if (i == 0) firstStrategy = strategy;
    }
  }

  function _deployAccounts(string[] calldata accounts) internal {
    uint256 accountLength = accounts.length;
    for (uint256 i = 0; i < accountLength; i = _uncheckedIncrement(i)) {
      bytes32 salt = bytes32(keccak256(abi.encodePacked(accounts[i])));
      LlamaAccount account = LlamaAccount(payable(Clones.cloneDeterministic(address(llamaAccountLogic), salt)));
      account.initialize(accounts[i]);
      emit AccountCreated(account, accounts[i]);
    }
  }

  function _infoHash(ActionInfo calldata actionInfo) internal pure returns (bytes32) {
    return _infoHash(
      actionInfo.id,
      actionInfo.creator,
      actionInfo.role,
      actionInfo.strategy,
      actionInfo.target,
      actionInfo.value,
      actionInfo.data
    );
  }

  function _infoHash(
    uint256 id,
    address creator,
    uint8 role,
    ILlamaStrategy strategy,
    address target,
    uint256 value,
    bytes calldata data
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(id, creator, role, strategy, target, value, data));
  }

  function _validateActionInfoHash(bytes32 actualHash, ActionInfo calldata actionInfo) internal pure {
    bytes32 expectedHash = _infoHash(actionInfo);
    if (actualHash != expectedHash) revert InfoHashMismatch();
  }

  function _useNonce(address policyholder, bytes4 selector) internal returns (uint256 nonce) {
    nonce = nonces[policyholder][selector];
    unchecked {
      nonces[policyholder][selector] = nonce + 1;
    }
  }

  /// @dev Reverts if `n` does not fit in a uint64.
  function _toUint64(uint256 n) internal pure returns (uint64) {
    if (n > type(uint64).max) revert UnsafeCast(n);
    return uint64(n);
  }

  /// @dev Reads slot 0 from storage, used to check that storage hasn't changed after delegatecall.
  function _readSlot0() internal view returns (bytes32 slot0) {
    assembly {
      slot0 := sload(0)
    }
  }

  /// @dev Increments a uint256 without checking for overflow.
  function _uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }
}
