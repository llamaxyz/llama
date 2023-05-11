// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LibString} from "@solady/utils/LibString.sol";

import {Checkpoints} from "src/lib/Checkpoints.sol";
import {ERC721NonTransferableMinimalProxy} from "src/lib/ERC721NonTransferableMinimalProxy.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";

/// @title Llama Policy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice An ERC721 contract where each token is non-transferable and has roles assigned to create, approve and
/// disapprove actions.
/// @dev The roles determine how the token can interact with the  Core contract.
contract LlamaPolicy is ERC721NonTransferableMinimalProxy {
  using Checkpoints for Checkpoints.History;

  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error AllHoldersRole();
  error AlreadyInitialized();
  error InvalidRoleHolderInput();
  error NonTransferableToken();
  error OnlyLlama();
  error RoleNotInitialized(uint8 role);
  error AddressDoesNotHoldPolicy(address userAddress);

  modifier onlyLlama() {
    if (msg.sender != llamaCore) revert OnlyLlama();
    _;
  }

  modifier nonTransferableToken() {
    _; // We put this ahead of the revert so we don't get an unreachable code warning.
    revert NonTransferableToken();
  }

  // ========================
  // ======== Events ========
  // ========================

  event RoleAssigned(address indexed policyholder, uint8 indexed role, uint64 expiration, uint128 quantity);
  event RoleInitialized(uint8 indexed role, RoleDescription description);
  event RolePermissionAssigned(uint8 indexed role, bytes32 indexed permissionId, bool hasPermission);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice A special role used to reference all policy holders.
  /// @dev DO NOT assign policyholders this role directly. Doing so can result in the wrong total supply
  /// values for this role.
  uint8 public constant ALL_HOLDERS_ROLE = 0;

  /// @notice At deployment, this role is given permission to call the `setRolePermission` function.
  /// However, this may change depending on how the Llama instance is configured.
  /// @dev This is done to mitigate the chances of deploying a misconfigured Llama instance that is
  /// unusable. See the documentation for more info.
  uint8 public constant BOOTSTRAP_ROLE = 1;

  /// @notice Returns true if the `role` can create actions with the given `permissionId`.
  mapping(uint8 role => mapping(bytes32 permissionId => bool)) public canCreateAction;

  /// @notice Checkpoints a token ID's "balance" (quantity) of a given role. The quantity of the
  /// role is how much quantity the role-holder gets when approving/disapproving (regardless of
  /// strategy).
  mapping(uint256 tokenId => mapping(uint8 role => Checkpoints.History)) internal roleBalanceCkpts;

  /// @dev Stores the two different supply values for a role.
  struct RoleSupply {
    uint128 numberOfHolders;
    uint128 totalQuantity;
  }

  /// @notice Checkpoints the total supply of a given role.
  /// @dev At a given timestamp, the total supply of a role must equal the sum of the quantity of
  /// the role for each token ID that holds the role.
  mapping(uint8 role => RoleSupply) public roleSupply;

  /// @notice The highest role ID that has been initialized.
  uint8 public numRoles;

  /// @notice The address of the `LlamaCore` instance that governs this contract.
  address public llamaCore;

  /// @notice The address of the `LlamaFactory` contract.
  LlamaFactory public factory;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor() {
    _disableInitializers();
  }

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

  /// @notice Sets the address of the `LlamaCore` contract and gives holders of role ID 1 permission
  /// to change role permissions.
  /// @dev This method can only be called once.
  /// @param _llamaCore The address of the `LlamaCore` contract.
  /// @param bootstrapPermissionId The permission ID that allows holders to change role permissions.
  function finalizeInitialization(address _llamaCore, bytes32 bootstrapPermissionId) external {
    if (llamaCore != address(0)) revert AlreadyInitialized();

    llamaCore = _llamaCore;
    _setRolePermission(BOOTSTRAP_ROLE, bootstrapPermissionId, true);
  }

  // -------- Role and Permission Management --------

  /// @notice Initializes a new role with the given `role` ID and `description`
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

  /// @notice Assigns a permission to a role.
  /// @param role Name of the role to set.
  /// @param permissionId Permission ID to assign to the role.
  /// @param hasPermission Whether to assign the permission or remove the permission.
  function setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) external onlyLlama {
    _setRolePermission(role, permissionId, hasPermission);
  }

  /// @notice Revokes an expired role.
  /// @param role Role that has expired.
  /// @param policyholder Policyholder that held the role.
  /// @dev WARNING: The contract cannot enumerate all expired roles for a policyholder, so the caller MUST
  /// provide the full list of expired roles to revoke. Not properly providing this data can result
  /// in an inconsistent internal state. It is expected that roles are revoked as needed before
  /// creating an action that uses that role as the `approvalRole` or `disapprovalRole`. Not doing
  /// so would mean the total supply is higher than expected. Depending on the strategy
  /// configuration this may not be a big deal, or it may mean it's impossible to reach quorum. It's
  /// not a big issue if quorum cannot be reached, because a new action can be created.
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
      _setRoleHolder(uint8(i), policyholder, 0, 0);
    }
    _burn(_tokenId(policyholder));
  }

  /// @notice Revokes all `roles` from the `policyholder` and burns their policy.
  /// @dev This method only exists to ensure policies can still be revoked in the case where the
  /// other `revokePolicy` method cannot be executed due to needed more gas than the block gas limit.
  function revokePolicy(address policyholder, uint8[] calldata roles) external onlyLlama {
    if (balanceOf(policyholder) == 0) revert AddressDoesNotHoldPolicy(policyholder);
    for (uint256 i = 0; i < roles.length; i = LlamaUtils.uncheckedIncrement(i)) {
      if (roles[i] == 0) revert AllHoldersRole();
      _setRoleHolder(roles[i], policyholder, 0, 0);
    }
    _burn(_tokenId(policyholder));
  }

  /// @notice Updates the description of a role.
  /// @param role ID of the role to update.
  /// @param description New description of the role.
  function updateRoleDescription(uint8 role, RoleDescription description) external onlyLlama {
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

  /// @notice Returns the total number of `role` holders.
  /// @dev The value returned by this method must equal the total number of holders of this role
  /// across all policyholders at that timestamp.
  function getRoleSupplyAsNumberOfHolders(uint8 role) public view returns (uint128) {
    return roleSupply[role].numberOfHolders;
  }

  /// @notice Returns the sum of `quantity` across all `role` holders.
  function getRoleSupplyAsQuantitySum(uint8 role) public view returns (uint128) {
    return roleSupply[role].totalQuantity;
  }

  /// @notice Returns all checkpoints for the given `policyholder` and `role`.
  function roleBalanceCheckpoints(address policyholder, uint8 role) external view returns (Checkpoints.History memory) {
    uint256 tokenId = _tokenId(policyholder);
    return roleBalanceCkpts[tokenId][role];
  }

  /// @notice Returns true if the `policyholder` has the `role`, false otherwise.
  function hasRole(address policyholder, uint8 role) external view returns (bool) {
    (bool exists,,, uint128 quantity) = roleBalanceCkpts[_tokenId(policyholder)][role].latestCheckpoint();
    return exists && quantity > 0;
  }

  /// @notice Returns true if the `policyholder` has the `role` at `timestamp`, false otherwise.
  function hasRole(address policyholder, uint8 role, uint256 timestamp) external view returns (bool) {
    uint256 quantity = roleBalanceCkpts[_tokenId(policyholder)][role].getAtProbablyRecentTimestamp(timestamp);
    return quantity > 0;
  }

  /// @notice Returns true if the given `policyholder` has a given `permissionId` under the `role`,
  /// false otherwise.
  function hasPermissionId(address policyholder, uint8 role, bytes32 permissionId) external view returns (bool) {
    uint128 quantity = roleBalanceCkpts[_tokenId(policyholder)][role].latest();
    return quantity > 0 && canCreateAction[role][permissionId];
  }

  function isRoleExpired(address policyholder, uint8 role) public view returns (bool) {
    (,, uint64 expiration, uint128 quantity) = roleBalanceCkpts[_tokenId(policyholder)][role].latestCheckpoint();
    return quantity > 0 && block.timestamp > expiration;
  }

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

  /// @notice Returns the location of the policy metadata.
  /// @param tokenId The ID of the policy token.
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return factory.tokenURI(LlamaCore(llamaCore), name, tokenId);
  }

  /// @notice Returns a URI for the storefront-level metadata for your contract.
  /// @return The contract URI for the given Llama instance.
  function contractURI() public view returns (string memory) {
    return factory.contractURI(name);
  }

  // -------- ERC-721 Methods --------

  /// @dev overriding transferFrom to disable transfers
  function transferFrom(address, /* from */ address, /* to */ uint256 /* policyId */ )
    public
    pure
    override
    nonTransferableToken
  {}

  /// @dev overriding safeTransferFrom to disable transfers
  function safeTransferFrom(address, /* from */ address, /* to */ uint256 /* id */ )
    public
    pure
    override
    nonTransferableToken
  {}

  /// @dev overriding safeTransferFrom to disable transfers
  function safeTransferFrom(address, /* from */ address, /* to */ uint256, /* policyId */ bytes calldata /* data */ )
    public
    pure
    override
    nonTransferableToken
  {}

  /// @dev overriding approve to disable approvals
  function approve(address, /* spender */ uint256 /* id */ ) public pure override nonTransferableToken {}

  /// @dev overriding approve to disable approvals
  function setApprovalForAll(address, /* operator */ bool /* approved */ ) public pure override nonTransferableToken {}

  // ================================
  // ======== Internal Logic ========
  // ================================

  function _initializeRole(RoleDescription description) internal {
    numRoles += 1;
    emit RoleInitialized(numRoles, description);
  }

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

  function _setRoleHolder(uint8 role, address policyholder, uint128 quantity, uint64 expiration) internal {
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
    uint128 quantityDiff = initialQuantity > quantity ? initialQuantity - quantity : quantity - initialQuantity;

    RoleSupply storage currentRoleSupply = roleSupply[role];
    uint128 newNumberOfHolders;
    uint128 newTotalQuantity;

    if (hadRole && !willHaveRole) {
      newNumberOfHolders = currentRoleSupply.numberOfHolders - 1;
      newTotalQuantity = currentRoleSupply.totalQuantity - quantityDiff;
    } else if (!hadRole && willHaveRole) {
      newNumberOfHolders = currentRoleSupply.numberOfHolders + 1;
      newTotalQuantity = currentRoleSupply.totalQuantity + quantityDiff;
    } else if (hadRole && willHaveRole && initialQuantity > quantity) {
      newNumberOfHolders = currentRoleSupply.numberOfHolders;
      newTotalQuantity = currentRoleSupply.totalQuantity - quantityDiff;
    } else if (hadRole && willHaveRole && initialQuantity < quantity) {
      newNumberOfHolders = currentRoleSupply.numberOfHolders;
      newTotalQuantity = currentRoleSupply.totalQuantity + quantityDiff;
    } else {
      // The only way to reach this branch is with `hadRole` and `willHaveRole` both being
      // false. In that case, no changes are being made. We allow this no-op without reverting
      // because `revokePolicy(address policyholder)` relies on this behavior.
      newNumberOfHolders = currentRoleSupply.numberOfHolders;
      newTotalQuantity = currentRoleSupply.totalQuantity;
    }

    currentRoleSupply.numberOfHolders = newNumberOfHolders;
    currentRoleSupply.totalQuantity = newTotalQuantity;
    emit RoleAssigned(policyholder, role, expiration, quantity);
  }

  function _setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) internal {
    canCreateAction[role][permissionId] = hasPermission;
    emit RolePermissionAssigned(role, permissionId, hasPermission);
  }

  function _revokeExpiredRole(uint8 role, address policyholder) internal {
    // Read the most recent checkpoint for the policyholder's role balance.
    if (!isRoleExpired(policyholder, role)) revert InvalidRoleHolderInput();
    _setRoleHolder(role, policyholder, 0, 0);
  }

  function _mint(address policyholder) internal {
    uint256 tokenId = _tokenId(policyholder);
    _mint(policyholder, tokenId);

    RoleSupply storage allHoldersRoleSupply = roleSupply[ALL_HOLDERS_ROLE];
    allHoldersRoleSupply.numberOfHolders += 1;
    allHoldersRoleSupply.totalQuantity += 1;

    roleBalanceCkpts[tokenId][ALL_HOLDERS_ROLE].push(1);
  }

  function _burn(uint256 tokenId) internal override {
    ERC721NonTransferableMinimalProxy._burn(tokenId);

    RoleSupply storage allHoldersRoleSupply = roleSupply[ALL_HOLDERS_ROLE];
    allHoldersRoleSupply.numberOfHolders -= 1;
    allHoldersRoleSupply.totalQuantity -= 1;

    roleBalanceCkpts[tokenId][ALL_HOLDERS_ROLE].push(0);
  }

  function _tokenId(address policyholder) internal pure returns (uint256) {
    return uint256(uint160(policyholder));
  }
}
