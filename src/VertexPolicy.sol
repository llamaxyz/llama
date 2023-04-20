// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LibString} from "@solady/utils/LibString.sol";

import {Checkpoints} from "src/lib/Checkpoints.sol";
import {ERC721NonTransferableMinimalProxy} from "src/lib/ERC721NonTransferableMinimalProxy.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";

/// @title Vertex Policy
/// @author Llama (devsdosomething@llama.xyz)
/// @notice An ERC721 contract where each token is non-transferable and has roles assigned to create, approve and
/// disapprove actions.
/// @dev TODO Add comments here around limitations/expectations of this contract, namely the "total
/// supply issue", the fact that quantities cannot be larger than 1, and burning a policy.
/// @dev The roles determine how the token can interact with the Vertex Core contract.
contract VertexPolicy is ERC721NonTransferableMinimalProxy {
  using Checkpoints for Checkpoints.History;

  // ======================================
  // ======== Errors and Modifiers ========
  // ======================================

  error AllHoldersRole();
  error AlreadyInitialized();
  error CallReverted(uint256 index, bytes revertData);
  error InvalidRoleHolderInput();
  error MissingAdmin();
  error NonTransferableToken();
  error OnlyVertex();
  error RoleNotInitialized(uint8 role);
  error UserDoesNotHoldPolicy(address user);

  modifier onlyVertex() {
    if (msg.sender != vertexCore) revert OnlyVertex();
    _;
  }

  modifier nonTransferableToken() {
    _; // We put this ahead of the revert so we don't get an unreachable code warning. TODO Confirm this is safe.
    revert NonTransferableToken();
  }

  // ========================
  // ======== Events ========
  // ========================

  event RoleAssigned(address indexed user, uint8 indexed role, uint256 expiration, RoleSupply roleSupply);
  event RoleInitialized(uint8 indexed role, RoleDescription description);
  event RolePermissionAssigned(uint8 indexed role, bytes32 indexed permissionId, bool hasPermission);

  // =============================================================
  // ======== Constants, Immutables and Storage Variables ========
  // =============================================================

  /// @notice A special role used to reference all policy holders.
  /// @dev DO NOT assign users this role directly. Doing so can result in the wrong total supply
  /// values for this role.
  // TODO Confirm zero is safe here.
  // TODO If zero is NOT safe, update the deploy script to add an 'AllHolders' role description.
  uint8 public constant ALL_HOLDERS_ROLE = 0;

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

  /// @notice The address of the `VertexCore` instance that governs this contract.
  address public vertexCore;

  /// @notice The address of the `VertexFactory` contract.
  VertexFactory public factory;

  // ======================================================
  // ======== Contract Creation and Initialization ========
  // ======================================================

  constructor() initializer {}

  function initialize(
    string calldata _name,
    RoleDescription[] calldata roleDescriptions,
    RoleHolderData[] calldata roleHolders,
    RolePermissionData[] calldata rolePermissions
  ) external initializer {
    __initializeERC721MinimalProxy(_name, string.concat("V_", LibString.slice(_name, 0, 3)));
    factory = VertexFactory(msg.sender);
    for (uint256 i = 0; i < roleDescriptions.length; i = _uncheckedIncrement(i)) {
      _initializeRole(roleDescriptions[i]);
    }

    for (uint256 i = 0; i < roleHolders.length; i = _uncheckedIncrement(i)) {
      _setRoleHolder(roleHolders[i].role, roleHolders[i].user, roleHolders[i].quantity, roleHolders[i].expiration);
    }

    for (uint256 i = 0; i < rolePermissions.length; i = _uncheckedIncrement(i)) {
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

  /// @notice Sets the address of the `VertexCore` contract.
  /// @dev This method can only be called once.
  /// @param _vertexCore The address of the `VertexCore` contract.
  function setVertex(address _vertexCore) external {
    if (vertexCore != address(0)) revert AlreadyInitialized();
    vertexCore = _vertexCore;
  }

  // -------- Role and Permission Management --------

  /// @notice Initializes a new role with the given `role` ID and `description`
  function initializeRole(RoleDescription description) external onlyVertex {
    _initializeRole(description);
  }

  /// @notice Assigns a role to a user.
  /// @param role ID of the role to set (uint8 ensures on-chain enumerability when burning policies).
  /// @param user User to assign the role to.
  /// @param quantity Quantity of the role to assign to the user, i.e. their (dis)approval quantity.
  /// @param expiration When the role expires.
  function setRoleHolder(uint8 role, address user, uint128 quantity, uint64 expiration) external onlyVertex {
    _setRoleHolder(role, user, quantity, expiration);
  }

  /// @notice Assigns a permission to a role.
  /// @param role Name of the role to set.
  /// @param permissionId Permission ID to assign to the role.
  /// @param hasPermission Whether to assign the permission or remove the permission.
  function setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) external onlyVertex {
    _setRolePermission(role, permissionId, hasPermission);
  }

  /// @notice Revokes an expired role.
  /// @param role Role that has expired.
  /// @param user User that held the role.
  /// @dev WARNING: The contract cannot enumerate all expired roles for a user, so the caller MUST
  /// provide the full list of expired roles to revoke. Not properly providing this data can result
  /// in an inconsistent internal state. It is expected that roles are revoked as needed before
  /// creating an action that uses that role as the `approvalRole` or `disapprovalRole`. Not doing
  /// so would mean the total supply is higher than expected. Depending on the strategy
  /// configuration this may not be a big deal, or it may mean it's impossible to reach quorum. It's
  /// not a big issue if quorum cannot be reached, because a new action can be created.
  function revokeExpiredRole(uint8 role, address user) external {
    _revokeExpiredRole(role, user);
  }

  /// @notice Revokes all roles from the `user` and burns their policy.
  function revokePolicy(address user) external onlyVertex {
    if (balanceOf(user) == 0) revert UserDoesNotHoldPolicy(user);
    // We start from i = 1 here because a value of zero is reserved for the "all holders" role, and
    // that will get automatically when the token is burned. Similarly, use we `<=` to make sure
    // the last role is also revoked.
    for (uint256 i = 1; i <= numRoles; i = _uncheckedIncrement(i)) {
      _setRoleHolder(uint8(i), user, 0, 0);
    }
    _burn(_tokenId(user));
  }

  /// @notice Revokes all `roles` from the `user` and burns their policy.
  /// @dev This method only exists to ensure policies can still be revoked in the case where the
  /// other `revokePolicy` method cannot be executed due to needed more gas than the block gas limit.
  function revokePolicy(address user, uint8[] calldata roles) external onlyVertex {
    if (balanceOf(user) == 0) revert UserDoesNotHoldPolicy(user);
    for (uint256 i = 0; i < roles.length; i = _uncheckedIncrement(i)) {
      if (roles[i] == 0) revert AllHoldersRole();
      _setRoleHolder(roles[i], user, 0, 0);
    }
    _burn(_tokenId(user));
  }

  /// @notice Updates the description of a role.
  /// @param role ID of the role to update.
  /// @param description New description of the role.
  function updateRoleDescription(uint8 role, RoleDescription description) external onlyVertex {
    emit RoleInitialized(role, description);
  }

  // -------- Role and Permission Getters --------

  /// @notice Returns the quantity of the `role` for the given `user`. The returned value is the
  /// quantity of the role when approving/disapproving (regardless of strategy).
  function getQuantity(address user, uint8 role) external view returns (uint256) {
    uint256 tokenId = _tokenId(user);
    return roleBalanceCkpts[tokenId][role].latest();
  }

  /// @notice Returns the quantity of the `role` for the given `user` at `timestamp`. The returned
  /// value is the quantity of the role when approving/disapproving (regardless of strategy).
  function getPastQuantity(address user, uint8 role, uint256 timestamp) external view returns (uint256) {
    uint256 tokenId = _tokenId(user);
    return roleBalanceCkpts[tokenId][role].getAtTimestamp(timestamp);
  }

  /// @notice Returns the total number of `role` holders.
  /// @dev The value returned by this method must equal the sum of the quantity of the role
  /// across all policyholders at that timestamp.
  function getRoleSupplyAsNumberOfHolders(uint8 role) public view returns (uint256) {
    return roleSupply[role].numberOfHolders;
  }

  /// @notice Returns the sum of `quantity` across all `role` holders.
  function getRoleSupplyAsQuantitySum(uint8 role) public view returns (uint256) {
    return roleSupply[role].totalQuantity;
  }

  /// @notice Returns all checkpoints for the given `user` and `role`.
  function roleBalanceCheckpoints(address user, uint8 role) external view returns (Checkpoints.History memory) {
    uint256 tokenId = _tokenId(user);
    return roleBalanceCkpts[tokenId][role];
  }

  /// @notice Returns true if the `user` has the `role`, false otherwise.
  function hasRole(address user, uint8 role) external view returns (bool) {
    (bool exists,,, uint128 quantity) = roleBalanceCkpts[_tokenId(user)][role].latestCheckpoint();
    return exists && quantity > 0;
  }

  /// @notice Returns true if the `user` has the `role` at `timestamp`, false otherwise.
  function hasRole(address user, uint8 role, uint256 timestamp) external view returns (bool) {
    uint256 quantity = roleBalanceCkpts[_tokenId(user)][role].getAtTimestamp(timestamp);
    return quantity > 0;
  }

  /// @notice Returns true if the given `user` has a given `permissionId` under the `role`,
  /// false otherwise.
  function hasPermissionId(address user, uint8 role, bytes32 permissionId) external view returns (bool) {
    uint128 quantity = roleBalanceCkpts[_tokenId(user)][role].latest();
    return quantity > 0 && canCreateAction[role][permissionId];
  }

  function isRoleExpired(address user, uint8 role) public view returns (bool) {
    (,, uint64 expiration, uint128 quantity) = roleBalanceCkpts[_tokenId(user)][role].latestCheckpoint();
    return quantity > 0 && block.timestamp > expiration;
  }

  function roleExpiration(address user, uint8 role) external view returns (uint256) {
    (,, uint64 expiration,) = roleBalanceCkpts[_tokenId(user)][role].latestCheckpoint();
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
    return factory.tokenURI(VertexCore(vertexCore), name, symbol, tokenId);
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

  function _setRoleHolder(uint8 role, address user, uint128 quantity, uint64 expiration) internal {
    // Scope to avoid stack too deep.
    {
      // Ensure role is initialized.
      if (role > numRoles) revert RoleNotInitialized(role);

      if (role == ALL_HOLDERS_ROLE) revert AllHoldersRole(); // Cannot set the ALL_HOLDERS_ROLE because this is handled
        // in
        // the _mint / _burn methods and can create duplicate entries if set here.

      // An expiration of zero is only allowed if the role is being removed. Roles are removed when
      // the quantity is zero. In other words, the relationships that are required between the role
      // quantity and expiration fields are:
      //   - quantity > 0 && expiration > block.timestamp: This means you are adding a role
      //   - quantity == 0 && expiration == 0: This means you are removing a role
      bool case1 = quantity > 0 && expiration > block.timestamp;
      bool case2 = quantity == 0 && expiration == 0;
      if (!(case1 || case2)) revert InvalidRoleHolderInput();
    }

    // Save off whether or not the user has a nonzero quantity of this role. This is used below when
    // updating the total supply of the role.
    uint256 tokenId = _tokenId(user);
    uint128 initialQuantity = roleBalanceCkpts[tokenId][role].latest();
    bool hadRoleQuantity = initialQuantity > 0;
    bool willHaveRole = quantity > 0 && expiration > block.timestamp;

    // Now we update the user's role balance checkpoint.
    roleBalanceCkpts[tokenId][role].push(willHaveRole ? quantity : 0, expiration);
    if (balanceOf(user) == 0) _mint(user);

    // Lastly we update the total supply of the role. If the expiration is zero, it means the role
    // was removed. Determining how to update total supply requires knowing if the user currently
    // has a nonzero quantity of this role. This is strictly a quantity check and ignores the
    // expiration because this is used to determine whether or not to update the total supply.
    uint128 quantityDiff = initialQuantity > quantity ? initialQuantity - quantity : quantity - initialQuantity;

    RoleSupply storage currentRoleSupply = roleSupply[role];
    uint128 newNumberOfHolders;
    uint128 newTotalQuantity;

    if (hadRoleQuantity && !willHaveRole) {
      newNumberOfHolders = currentRoleSupply.numberOfHolders - 1;
      newTotalQuantity = currentRoleSupply.totalQuantity - quantityDiff;
    } else if (!hadRoleQuantity && willHaveRole) {
      newNumberOfHolders = currentRoleSupply.numberOfHolders + 1;
      newTotalQuantity = currentRoleSupply.totalQuantity + quantityDiff;
    } else {
      newNumberOfHolders = currentRoleSupply.numberOfHolders;
      newTotalQuantity = currentRoleSupply.totalQuantity + quantityDiff;
    }

    currentRoleSupply.numberOfHolders = newNumberOfHolders;
    currentRoleSupply.totalQuantity = newTotalQuantity;
    emit RoleAssigned(user, role, expiration, currentRoleSupply);
  }

  function _setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) internal {
    canCreateAction[role][permissionId] = hasPermission;
    emit RolePermissionAssigned(role, permissionId, hasPermission);
  }

  function _revokeExpiredRole(uint8 role, address user) internal {
    // Read the most recent checkpoint for the user's role balance.
    if (!isRoleExpired(user, role)) revert InvalidRoleHolderInput();
    _setRoleHolder(role, user, 0, 0);
  }

  function _mint(address user) internal {
    uint256 tokenId = _tokenId(user);
    _mint(user, tokenId);

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

  function _tokenId(address user) internal pure returns (uint256) {
    return uint256(uint160(user));
  }

  function _uncheckedIncrement(uint256 i) internal pure returns (uint256) {
    unchecked {
      return i + 1;
    }
  }
}
