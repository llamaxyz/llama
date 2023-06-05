// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LibString} from "@solady/utils/LibString.sol";

import {Checkpoints} from "src/lib/Checkpoints.sol";
import {ERC721NonTransferableMinimalProxy} from "src/lib/ERC721NonTransferableMinimalProxy.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";

/// @title Llama Policy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice An ERC721 contract where each token is non-transferable, functions as the respective policy for a given
/// policyholder and has roles assigned to `create`, `approve` and `disapprove` actions.
/// @dev The roles and permissions determine how the policyholder can interact with the Llama core contract.
contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
  using Checkpoints for Checkpoints.History;

  // =========================
  // ======== Structs ========
  // =========================

  /// @dev Stores the two different supply values for a role.
  struct RoleSupply {
    uint128 numberOfHolders; // The total number of unique policyholders holding a role.
    uint128 totalQuantity; // The sum of the quantity field for all unique policyholders holding a role.
  }

  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  /// @dev Roleholder cannot be set at the same timestamp as an action creation.
  error ActionCreationAtSameTimestamp();

  /// @dev Thrown when revoking a policy from an address without one
  /// @param userAddress The address of the possible policyholder.
  error AddressDoesNotHoldPolicy(address userAddress);

  /// @dev Cannot set "all holders" role.
  error AllHoldersRole();

  /// @dev Policy can only be initialized once.
  error AlreadyInitialized();

  /// @dev The indices would result in `Panic: Index Out of Bounds`.
  /// @dev Thrown when the `end` index is greater than array length or when the `start` index is greater than the `end`
  /// index.
  error InvalidIndices();

  /// @dev Thrown when the provided policyholder and role are not in the expected state for the function.
  error InvalidRoleHolderInput();

  /// @dev Policy tokens cannot be transferred.
  error NonTransferableToken();

  /// @dev Only callable by a Llama instance's executor.
  error OnlyLlama();

  /// @dev Operations can only occur on initialized roles.
  error RoleNotInitialized(uint8 role);

  /// @dev Checks that the caller is the Llama executor and reverts if not.
  modifier onlyLlama() {
    if (msg.sender != llamaExecutor) revert OnlyLlama();
    _;
  }

  /// @dev Ensures that none of the ERC721 `transfer` and `approval` functions can be called, so that the policies are
  /// soulbound.
  modifier nonTransferableToken() {
    _; // We put this ahead of the revert so we don't get an unreachable code warning.
    revert NonTransferableToken();
  }

  // ========================
  // ======== Events ========
  // ========================

  /// @dev Emitted when a policyholder is assigned a role.
  event RoleAssigned(address indexed policyholder, uint8 indexed role, uint64 expiration, uint128 quantity);

  /// @dev Emitted when a role is initialized with a description.
  event RoleInitialized(uint8 indexed role, RoleDescription description);

  /// @dev Emitted when a permission ID is assigned to a role.
  event RolePermissionAssigned(uint8 indexed role, bytes32 indexed permissionId, bool hasPermission);

  // =================================================
  // ======== Constants and Storage Variables ========
  // =================================================

  /// @dev Checkpoints a token ID's "balance" (quantity) of a given role. The quantity of the
  /// role is how much quantity the role-holder gets when approving/disapproving (regardless of
  /// strategy).
  mapping(uint256 tokenId => mapping(uint8 role => Checkpoints.History)) internal roleBalanceCkpts;

  /// @notice A special role used to reference all policyholders.
  /// @dev DO NOT assign policyholders this role directly. Doing so can result in the wrong total supply
  /// values for this role.
  uint8 public constant ALL_HOLDERS_ROLE = 0;

  /// @notice At deployment, this role is given permission to call the `setRolePermission` function.
  /// However, this may change depending on how the Llama instance is configured.
  /// @dev This is done to mitigate the chances of deploying a misconfigured Llama instance that is
  /// unusable. See the documentation for more info.
  uint8 public constant BOOTSTRAP_ROLE = 1;

  /// @notice Returns `true` if the role can create actions with the given permission ID.
  mapping(uint8 role => mapping(bytes32 permissionId => bool)) public canCreateAction;

  /// @notice Checkpoints the total supply of a given role.
  /// @dev At a given timestamp, the total supply of a role must equal the sum of the quantity of
  /// the role for each token ID that holds the role.
  mapping(uint8 role => RoleSupply) public roleSupply;

  /// @notice The highest role ID that has been initialized.
  uint8 public numRoles;

  /// @notice The address of the `LlamaExecutor` of this instance.
  address public llamaExecutor;

  /// @notice The address of the `LlamaFactory` contract.
  LlamaFactory public factory;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes a new `LlamaPolicy` clone.
  /// @param _name The name of the policy.
  /// @param roleDescriptions The role descriptions.
  /// @param roleHolders The `role`, `policyholder`, `quantity` and `expiration` of the role holders.
  /// @param rolePermissions The `role`, `permissionId` and whether the role has the permission of the role permissions.
  function initialize(
    string calldata _name,
    RoleDescription[] calldata roleDescriptions,
    RoleHolderData[] calldata roleHolders,
    RolePermissionData[] calldata rolePermissions
  ) external initializer {
    __initializeERC721MinimalProxy(_name, string.concat("LL-", LibString.replace(LibString.upper(_name), " ", "-")));
    factory = LlamaFactory(msg.sender);
    for (uint256 i = 0; i < roleDescriptions.length; i = LlamaUtils.uncheckedIncrement(i)) {
      _initializeRole(roleDescriptions[i]);
    }

    for (uint256 i = 0; i < roleHolders.length; i = LlamaUtils.uncheckedIncrement(i)) {
      _setRoleHolder(
        roleHolders[i].role, roleHolders[i].policyholder, roleHolders[i].quantity, roleHolders[i].expiration
      );
    }

    for (uint256 i = 0; i < rolePermissions.length; i = LlamaUtils.uncheckedIncrement(i)) {
      _setRolePermission(rolePermissions[i].role, rolePermissions[i].permissionId, rolePermissions[i].hasPermission);
    }

    // Must have assigned roles during initialization, otherwise the system cannot be used. However,
    // we do not check that roles were assigned "properly" as there is no single correct way, so
    // this is more of a sanity check, not a guarantee that the system will work after initialization.
    if (numRoles == 0 || getRoleSupplyAsNumberOfHolders(ALL_HOLDERS_ROLE) == 0) revert InvalidRoleHolderInput();
  }

  // ===========================================
  // ======== External and Public Logic ========
  // ===========================================

  /// @notice Sets the address of the `LlamaExecutor` contract and gives holders of role ID 1 permission
  /// to change role permissions.
  /// @dev This method can only be called once.
  /// @param _llamaExecutor The address of the `LlamaExecutor` contract.
  /// @param bootstrapPermissionId The permission ID that allows holders to change role permissions.
  function finalizeInitialization(address _llamaExecutor, bytes32 bootstrapPermissionId) external {
    if (llamaExecutor != address(0)) revert AlreadyInitialized();

    llamaExecutor = _llamaExecutor;
    _setRolePermission(BOOTSTRAP_ROLE, bootstrapPermissionId, true);
  }

  // -------- Role and Permission Management --------

  /// @notice Initializes a new role with the given role ID and description
  function initializeRole(RoleDescription description) external onlyLlama {
    _initializeRole(description);
  }

  /// @notice Assigns a role to a policyholder.
  /// @param role ID of the role to set (uint8 ensures on-chain enumerability when burning policies).
  /// @param policyholder Policyholder to assign the role to.
  /// @param quantity Quantity of the role to assign to the policyholder, i.e. their (dis)approval quantity.
  /// @param expiration When the role expires.
  function setRoleHolder(uint8 role, address policyholder, uint128 quantity, uint64 expiration) external onlyLlama {
    _setRoleHolder(role, policyholder, quantity, expiration);
  }

  /// @notice Assigns a permission ID to a role.
  /// @param role Name of the role to set.
  /// @param permissionId Permission ID to assign to the role.
  /// @param hasPermission Whether to assign the permission or remove the permission.
  function setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) external onlyLlama {
    _setRolePermission(role, permissionId, hasPermission);
  }

  /// @notice Revokes a policyholder's expired role.
  /// @param role Role that has expired.
  /// @param policyholder Policyholder that held the role.
  /// @dev WARNING: This function needs to be explicitly called to revoke expired roles by monitoring through offchain
  /// infrastructure, otherwise expired roles can continue to create actions (if they have the right permissions) and
  /// take part in the approval/disapproval process if the strategy allows it.
  function revokeExpiredRole(uint8 role, address policyholder) external {
    _revokeExpiredRole(role, policyholder);
  }

  /// @notice Revokes all roles from the `policyholder` and burns their policy.
  function revokePolicy(address policyholder) external onlyLlama {
    if (balanceOf(policyholder) == 0) revert AddressDoesNotHoldPolicy(policyholder);
    // We start from i = 1 here because a value of zero is reserved for the "all holders" role, and
    // that will get removed automatically when the token is burned. Similarly, use we `<=` to make sure
    // the last role is also revoked.
    for (uint256 i = 1; i <= numRoles; i = LlamaUtils.uncheckedIncrement(i)) {
      if (hasRole(policyholder, uint8(i))) _setRoleHolder(uint8(i), policyholder, 0, 0);
    }
    _burn(_tokenId(policyholder));
  }

  /// @notice Updates the description of a role.
  /// @param role ID of the role to update.
  /// @param description New description of the role.
  function updateRoleDescription(uint8 role, RoleDescription description) external onlyLlama {
    if (role > numRoles) revert RoleNotInitialized(role);
    emit RoleInitialized(role, description);
  }

  // -------- Role and Permission Getters --------

  /// @notice Returns the quantity of the `role` for the given `policyholder`. The returned value is the
  /// quantity of the role when approving/disapproving (regardless of strategy).
  function getQuantity(address policyholder, uint8 role) external view returns (uint128) {
    uint256 tokenId = _tokenId(policyholder);
    return roleBalanceCkpts[tokenId][role].latest();
  }

  /// @notice Returns the quantity of the `role` for the given `policyholder` at `timestamp`. The returned
  /// value is the quantity of the role when approving/disapproving (regardless of strategy).
  function getPastQuantity(address policyholder, uint8 role, uint256 timestamp) external view returns (uint128) {
    uint256 tokenId = _tokenId(policyholder);
    return roleBalanceCkpts[tokenId][role].getAtProbablyRecentTimestamp(timestamp);
  }

  /// @notice Returns the total number of role holders for given `role`.
  function getRoleSupplyAsNumberOfHolders(uint8 role) public view returns (uint128) {
    return roleSupply[role].numberOfHolders;
  }

  /// @notice Returns the sum of quantity across all role holders for given `role`.
  function getRoleSupplyAsQuantitySum(uint8 role) public view returns (uint128) {
    return roleSupply[role].totalQuantity;
  }

  /// @notice Returns all checkpoints for the given `policyholder` and `role`.
  function roleBalanceCheckpoints(address policyholder, uint8 role) external view returns (Checkpoints.History memory) {
    uint256 tokenId = _tokenId(policyholder);
    return roleBalanceCkpts[tokenId][role];
  }

  /// @notice Returns all checkpoints for the given policyholder and role between `start` and
  /// `end`, where `start` is inclusive and `end` is exclusive.
  /// @param policyholder Policyholder to get the checkpoints for.
  /// @param role Role held by policyholder to get the checkpoints for.
  /// @param start Start index of the checkpoints to get from their checkpoint history array. This index is inclusive.
  /// @param end End index of the checkpoints to get from their checkpoint history array. This index is exclusive.
  function roleBalanceCheckpoints(address policyholder, uint8 role, uint256 start, uint256 end)
    external
    view
    returns (Checkpoints.History memory)
  {
    if (start > end) revert InvalidIndices();
    uint256 checkpointsLength = roleBalanceCkpts[_tokenId(policyholder)][role]._checkpoints.length;
    if (end > checkpointsLength) revert InvalidIndices();

    uint256 tokenId = _tokenId(policyholder);
    uint256 sliceLength = end - start;
    Checkpoints.Checkpoint[] memory checkpoints = new Checkpoints.Checkpoint[](sliceLength);
    for (uint256 i = start; i < end; i = LlamaUtils.uncheckedIncrement(i)) {
      checkpoints[i - start] = roleBalanceCkpts[tokenId][role]._checkpoints[i];
    }
    return Checkpoints.History(checkpoints);
  }

  /// @notice Returns the number of checkpoints for the given `policyholder` and `role`.
  /// @dev Useful for knowing the max index when requesting a range of checkpoints in `roleBalanceCheckpoints`.
  function roleBalanceCheckpointsLength(address policyholder, uint8 role) external view returns (uint256) {
    uint256 tokenId = _tokenId(policyholder);
    return roleBalanceCkpts[tokenId][role]._checkpoints.length;
  }

  /// @notice Returns `true` if the `policyholder` has the `role`, `false` otherwise.
  function hasRole(address policyholder, uint8 role) public view returns (bool) {
    uint128 quantity = roleBalanceCkpts[_tokenId(policyholder)][role].latest();
    return quantity > 0;
  }

  /// @notice Returns `true` if the `policyholder` has the `role` at `timestamp`, `false` otherwise.
  function hasRole(address policyholder, uint8 role, uint256 timestamp) external view returns (bool) {
    uint256 quantity = roleBalanceCkpts[_tokenId(policyholder)][role].getAtProbablyRecentTimestamp(timestamp);
    return quantity > 0;
  }

  /// @notice Returns `true` if the given `policyholder` has a given `permissionId` under the `role`,
  /// `false` otherwise.
  function hasPermissionId(address policyholder, uint8 role, bytes32 permissionId) external view returns (bool) {
    uint128 quantity = roleBalanceCkpts[_tokenId(policyholder)][role].latest();
    return quantity > 0 && canCreateAction[role][permissionId];
  }

  /// @notice Returns `true` if the `role` held by `policyholder` is expired, `false` otherwise.
  function isRoleExpired(address policyholder, uint8 role) public view returns (bool) {
    (,, uint64 expiration, uint128 quantity) = roleBalanceCkpts[_tokenId(policyholder)][role].latestCheckpoint();
    return quantity > 0 && block.timestamp > expiration;
  }

  /// @notice Returns the expiration timestamp of the `role` held by `policyholder`.
  function roleExpiration(address policyholder, uint8 role) external view returns (uint64) {
    (,, uint64 expiration,) = roleBalanceCkpts[_tokenId(policyholder)][role].latestCheckpoint();
    return expiration;
  }

  /// @notice Returns the total number of policies in existence.
  /// @dev This is just an alias for convenience/familiarity.
  function totalSupply() public view returns (uint256) {
    return getRoleSupplyAsNumberOfHolders(ALL_HOLDERS_ROLE);
  }

  // -------- ERC-721 Getters --------

  /// @notice Returns the token URI for the given `tokenId` of this Llama instance.
  /// @param tokenId The ID of the policy token.
  /// @return The token URI for the given `tokenId` of this Llama instance.
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return factory.tokenURI(LlamaExecutor(llamaExecutor), name, tokenId);
  }

  /// @notice Returns a URI for the storefront-level metadata for your contract.
  /// @return The contract URI for the given Llama instance.
  function contractURI() public view returns (string memory) {
    return factory.contractURI(name);
  }

  // -------- ERC-721 Methods --------

  /// @dev overriding `transferFrom` to disable transfers
  function transferFrom(address, /* from */ address, /* to */ uint256 /* policyId */ )
    public
    pure
    override
    nonTransferableToken
  {}

  /// @dev overriding `safeTransferFrom` to disable transfers
  function safeTransferFrom(address, /* from */ address, /* to */ uint256 /* id */ )
    public
    pure
    override
    nonTransferableToken
  {}

  /// @dev overriding `safeTransferFrom` to disable transfers
  function safeTransferFrom(address, /* from */ address, /* to */ uint256, /* policyId */ bytes calldata /* data */ )
    public
    pure
    override
    nonTransferableToken
  {}

  /// @dev overriding `approve` to disable approvals
  function approve(address, /* spender */ uint256 /* id */ ) public pure override nonTransferableToken {}

  /// @dev overriding `approve` to disable approvals
  function setApprovalForAll(address, /* operator */ bool /* approved */ ) public pure override nonTransferableToken {}

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Initializes the next unassigned role with the given `description`.
  function _initializeRole(RoleDescription description) internal {
    numRoles += 1;
    emit RoleInitialized(numRoles, description);
  }

  /// @dev Because role supplies are not checkpointed for simplicity, the following issue can occur
  /// if each of the below is executed within the same timestamp:
  //    1. An action is created that saves off the current role supply.
  //    2. A policyholder is given a new role.
  //    3. Now the total supply in that block is different than what it was at action creation.
  // As a result, we disallow changes to roles if an action was created in the same block.
  function _assertNoActionCreationsAtCurrentTimestamp() internal view {
    if (llamaExecutor == address(0)) return; // Skip check during initialization.
    address llamaCore = LlamaExecutor(llamaExecutor).LLAMA_CORE();
    uint256 lastActionCreation = LlamaCore(llamaCore).getLastActionTimestamp();
    if (lastActionCreation == block.timestamp) revert ActionCreationAtSameTimestamp();
  }

  /// @dev Checks if the conditions are met for a `role` to be updated.
  function _assertValidRoleHolderUpdate(uint8 role, uint128 quantity, uint64 expiration) internal view {
    // Ensure role is initialized.
    if (role > numRoles) revert RoleNotInitialized(role);

    // Cannot set the ALL_HOLDERS_ROLE because this is handled in the _mint / _burn methods and can
    // create duplicate entries if set here.
    if (role == ALL_HOLDERS_ROLE) revert AllHoldersRole();

    // An expiration of zero is only allowed if the role is being removed. Roles are removed when
    // the quantity is zero. In other words, the relationships that are required between the role
    // quantity and expiration fields are:
    //   - quantity > 0 && expiration > block.timestamp: This means you are adding a role
    //   - quantity == 0 && expiration == 0: This means you are removing a role
    bool case1 = quantity > 0 && expiration > block.timestamp;
    bool case2 = quantity == 0 && expiration == 0;
    if (!(case1 || case2)) revert InvalidRoleHolderInput();
  }

  /// @dev Sets the `role` for the given `policyholder` to the given `quantity` and `expiration`.
  function _setRoleHolder(uint8 role, address policyholder, uint128 quantity, uint64 expiration) internal {
    _assertNoActionCreationsAtCurrentTimestamp();
    _assertValidRoleHolderUpdate(role, quantity, expiration);

    // Save off whether or not the policyholder has a nonzero quantity of this role. This is used
    // below when updating the total supply of the role. The policy contract has an invariant that
    // even when a role is expired, i.e. `block.timestamp > expiration`, that role is still active
    // until explicitly revoked with `revokeExpiredRole`. Based on the assertions above for
    // determining valid inputs to this method, this means we know if a user had a role simply by
    // checking if the quantity is nonzero, and we don't need to check the expiration when setting
    // the `hadRole` and `willHaveRole` variables.
    uint256 tokenId = _tokenId(policyholder);
    uint128 initialQuantity = roleBalanceCkpts[tokenId][role].latest();
    bool hadRole = initialQuantity > 0;
    bool willHaveRole = quantity > 0;

    // Now we update the policyholder's role balance checkpoint.
    roleBalanceCkpts[tokenId][role].push(willHaveRole ? quantity : 0, expiration);

    // If they don't hold a policy, we mint one for them. This means that even if you use 0 quantity
    // and 0 expiration, a policy is still minted even though they hold no roles. This is because
    // they do hold the ALL_HOLDERS_ROLE simply by having a policy, so we allow this.
    if (balanceOf(policyholder) == 0) _mint(policyholder);

    // Lastly we update the total supply of the role. If the expiration is zero, it means the role
    // was removed. Determining how to update total supply requires knowing if the policyholder currently
    // has a nonzero quantity of this role. This is strictly a quantity check and ignores the
    // expiration because this is used to determine whether or not to update the total supply.
    uint128 quantityDiff;
    unchecked {
      // Safety: Can never underflow due to ternary operator check.
      quantityDiff = initialQuantity > quantity ? initialQuantity - quantity : quantity - initialQuantity;
    }

    RoleSupply storage currentRoleSupply = roleSupply[role];

    if (hadRole && !willHaveRole) {
      currentRoleSupply.numberOfHolders -= 1;
      currentRoleSupply.totalQuantity -= quantityDiff;
    } else if (!hadRole && willHaveRole) {
      currentRoleSupply.numberOfHolders += 1;
      currentRoleSupply.totalQuantity += quantityDiff;
    } else if (hadRole && willHaveRole && initialQuantity > quantity) {
      // currentRoleSupply.numberOfHolders is unchanged
      currentRoleSupply.totalQuantity -= quantityDiff;
    } else if (hadRole && willHaveRole && initialQuantity < quantity) {
      // currentRoleSupply.numberOfHolders is unchanged
      currentRoleSupply.totalQuantity += quantityDiff;
    } else {
      // There are two ways to reach this branch, both of which are nop-ops:
      //   1. `hadRole` and `willHaveRole` are both false.
      //   2. `hadRole` and `willHaveRole` are both true, and `initialQuantity == quantity`.
      // We allow these no-ops without reverting so you can give someone a policy with only the
      // `ALL_HOLDERS_ROLE`.
    }
    emit RoleAssigned(policyholder, role, expiration, quantity);
  }

  /// @dev Sets a role's permission along with whether that permission is valid or not.
  function _setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) internal {
    if (role > numRoles) revert RoleNotInitialized(role);
    canCreateAction[role][permissionId] = hasPermission;
    emit RolePermissionAssigned(role, permissionId, hasPermission);
  }

  /// @dev Revokes a policyholder's expired `role`.
  function _revokeExpiredRole(uint8 role, address policyholder) internal {
    // Read the most recent checkpoint for the policyholder's role balance.
    if (!isRoleExpired(policyholder, role)) revert InvalidRoleHolderInput();
    _setRoleHolder(role, policyholder, 0, 0);
  }

  /// @dev Mints a policyholder's policy.
  function _mint(address policyholder) internal {
    uint256 tokenId = _tokenId(policyholder);
    _mint(policyholder, tokenId);

    RoleSupply storage allHoldersRoleSupply = roleSupply[ALL_HOLDERS_ROLE];
    unchecked {
      // Safety: Can never overflow a uint128 by incrementing.
      allHoldersRoleSupply.numberOfHolders += 1;
      allHoldersRoleSupply.totalQuantity += 1;
    }

    roleBalanceCkpts[tokenId][ALL_HOLDERS_ROLE].push(1);
  }

  /// @dev Burns a policyholder's policy.
  function _burn(uint256 tokenId) internal override {
    ERC721NonTransferableMinimalProxy._burn(tokenId);

    RoleSupply storage allHoldersRoleSupply = roleSupply[ALL_HOLDERS_ROLE];
    unchecked {
      // Safety: Can never underflow, since we only burn tokens that currently exist.
      allHoldersRoleSupply.numberOfHolders -= 1;
      allHoldersRoleSupply.totalQuantity -= 1;
    }

    roleBalanceCkpts[tokenId][ALL_HOLDERS_ROLE].push(0);
  }

  /// @dev Returns the token ID for a `policyholder`.
  function _tokenId(address policyholder) internal pure returns (uint256) {
    return uint256(uint160(policyholder));
  }
}
