// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721NonTransferableMinimalProxy} from "src/lib/ERC721NonTransferableMinimalProxy.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";
import {ExpiredRole, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {Checkpoints} from "src/lib/Checkpoints.sol";

/// @title VertexPolicy
/// @author Llama (vertex@llama.xyz)
/// @dev VertexPolicy is a (TODO: pick a soulbound standard) ERC721 contract where each token has permissions
/// @dev TODO Add comments here around limitations/expectations of this contract, namely the "total
/// supply issue", the fact that quantities cannot be larger than 1, and burning a policy.
/// @notice The permissions determine how the token can interact with the vertex administrator contract
contract VertexPolicy is ERC721NonTransferableMinimalProxy {
  using Checkpoints for Checkpoints.History;

  /// @notice A special role used to reference all policy holders.
  /// @dev DO NOT assign users this role directly. Doing so can result in the wrong total supply
  /// values for this role.
  uint8 public constant ALL_HOLDERS_ROLE = 0; // TODO Confirm zero is safe here.

  /// @notice A special role to designate an Admin, who can always create actions.
  uint8 public constant ADMIN_ROLE = 1;

  /// @notice Returns true if the `role` can create actions with the given `permissionId`.
  mapping(uint8 role => mapping(bytes32 permissionId => bool)) public canCreateAction;

  /// @notice Checkpoints a token ID's "balance" (quantity) of a given role. The quantity of the
  /// role is how much weight the role-holder gets when approving/disapproving (regardless of
  /// strategy).
  /// @dev The current implementation does not allow a user's quantity to be anything other than 1.
  mapping(uint256 tokenId => mapping(uint8 role => Checkpoints.History)) internal roleBalanceCkpts;

  /// @notice Checkpoints the total supply of a given role.
  /// @dev At a given timestamp, the total supply of a role must equal the sum of the quantity of
  /// the role for each token ID that holds the role.
  mapping(uint8 role => Checkpoints.History) internal roleSupplyCkpts;

  /// @notice The highest role ID that has been initialized.
  uint8 public numRoles;

  /// @notice The address of the `VertexCore` instance that governs this contract.
  address public vertex;

  /// @notice The address of the `VertexFactory` contract.
  VertexFactory public factory;

  error AlreadyInitialized();
  error InvalidInput();
  error MissingAdmin();
  error NonTransferableToken();
  error OnlyVertex();
  error RoleNotInitialized(uint8 role);

  event RoleAssigned(address indexed user, uint8 indexed role, uint256 expiration, uint256 roleSupply);
  event RoleInitialized(uint8 indexed role, string description);
  event RolePermissionAssigned(uint8 indexed role, bytes32 indexed permissionId, bool hasPermission);

  modifier onlyVertex() {
    if (msg.sender != vertex) revert OnlyVertex();
    _;
  }

  modifier nonTransferableToken() {
    _; // We put this ahead of the revert so we don't get an unreachable code warning.
    revert NonTransferableToken();
  }

  constructor() initializer {}

  function initialize(
    string calldata _name,
    string[] calldata roleDescriptions,
    RoleHolderData[] calldata roleHolders,
    RolePermissionData[] calldata rolePermissions
  ) external initializer {
    __initializeERC721MinimalProxy(_name, string.concat("V_", LibString.slice(_name, 0, 3)));
    factory = VertexFactory(msg.sender);

    numRoles = 1;
    emit RoleInitialized(numRoles, "Admin");
    for (uint256 i = 0; i < roleDescriptions.length; i = _uncheckedIncrement(i)) {
      _initializeRole(roleDescriptions[i]);
    }

    for (uint256 i = 0; i < roleHolders.length; i = _uncheckedIncrement(i)) {
      _setRoleHolder(roleHolders[i].role, roleHolders[i].user, roleHolders[i].quantity, roleHolders[i].expiration);
    }

    for (uint256 i = 0; i < rolePermissions.length; i = _uncheckedIncrement(i)) {
      _setRolePermission(rolePermissions[i].role, rolePermissions[i].permissionId, rolePermissions[i].hasPermission);
    }

    _assertAdminsExist();
  }

  function setVertex(address _vertex) external {
    if (vertex != address(0)) revert AlreadyInitialized();
    vertex = _vertex;
  }

  // =======================================
  // ======== Permission Management ========
  // =======================================

  /// @notice Initializes a new role with the given `role` ID and `description`
  function initializeRole(string calldata description) external onlyVertex {
    _initializeRole(description);
  }

  /// @notice Assigns roles to users.
  function setRoleHolders(RoleHolderData[] calldata roleHolders) external onlyVertex {
    for (uint256 i = 0; i < roleHolders.length; i = _uncheckedIncrement(i)) {
      _setRoleHolder(roleHolders[i].role, roleHolders[i].user, roleHolders[i].quantity, roleHolders[i].expiration);
    }
    _assertAdminsExist();
  }

  /// @notice Sets the permissions for a given role.
  function setRolePermissions(RolePermissionData[] calldata rolePermissions) external onlyVertex {
    for (uint256 i = 0; i < rolePermissions.length; i = _uncheckedIncrement(i)) {
      _setRolePermission(rolePermissions[i].role, rolePermissions[i].permissionId, rolePermissions[i].hasPermission);
    }
  }

  /// @notice Assigns roles to users and sets permissions for roles.
  function setRoleHoldersAndPermissions(
    RoleHolderData[] calldata roleHolders,
    RolePermissionData[] calldata rolePermissions
  ) external onlyVertex {
    for (uint256 i = 0; i < roleHolders.length; i = _uncheckedIncrement(i)) {
      _setRoleHolder(roleHolders[i].role, roleHolders[i].user, roleHolders[i].quantity, roleHolders[i].expiration);
    }
    for (uint256 i = 0; i < rolePermissions.length; i = _uncheckedIncrement(i)) {
      _setRolePermission(rolePermissions[i].role, rolePermissions[i].permissionId, rolePermissions[i].hasPermission);
    }
    _assertAdminsExist();
  }

  /// @notice Revokes expired roles.
  /// @dev WARNING: The contract cannot enumerate all expired roles for a user, so the caller MUST
  /// provide the full list of expired roles to revoke. Not properly providing this data can result
  /// in an inconsistent internal state. It is expected that roles are revoked as needed before
  /// creating an action that uses that role as the `approvalRole` or `disapprovalRole`. Not doing
  /// so would mean the total supply is higher than expected. Depending on the strategy
  /// configuration this may not be a big deal, or it may mean it's impossible to reach quorum. It's
  /// not a big issue if quorum cannot be reached, because a new action can be created.
  function revokeExpiredRoles(ExpiredRole[] calldata expiredRoles) external {
    for (uint256 i = 0; i < expiredRoles.length; i = _uncheckedIncrement(i)) {
      _revokeExpiredRole(expiredRoles[i]);
    }
    _assertAdminsExist();
  }

  /// @notice Revokes all roles from the user and burns their policy.
  /// @dev WARNING: The contract cannot enumerate all roles for a user, so the caller MUST provide
  /// the full list of roles held by user. Not properly providing this data can result in an
  /// inconsistent internal state. It is expected that policies are revoked as needed before
  // creating an action using the `ALL_HOLDERS_ROLE`.
  function revokePolicy(address user, uint8[] calldata roles) external onlyVertex {
    for (uint256 i = 0; i < roles.length; i = _uncheckedIncrement(i)) {
      _setRoleHolder(roles[i], user, 0, 0);
    }
    _burn(_tokenId(user));
    _assertAdminsExist();
  }

  // =================================
  // ======== ERC-721 Methods ========
  // =================================

  /// @dev overriding transferFrom to disable transfers
  /// @dev this is a temporary solution, we will need to conform to a Soulbound standard
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

  // ====================================
  // ======== Permission Getters ========
  // ====================================

  /// @notice Returns the quantity of the `role` for the given `user`. The returned value is the
  /// weight of the role when approving/disapproving (regardless of strategy).
  function getWeight(address user, uint8 role) external view returns (uint256) {
    uint256 tokenId = _tokenId(user);
    return roleBalanceCkpts[tokenId][role].latest();
  }

  /// @notice Returns the quantity of the `role` for the given `user` at `timestamp`. The returned
  /// value is the weight of the role when approving/disapproving (regardless of strategy).
  function getPastWeight(address user, uint8 role, uint256 timestamp) external view returns (uint256) {
    uint256 tokenId = _tokenId(user);
    return roleBalanceCkpts[tokenId][role].getAtTimestamp(timestamp);
  }

  /// @notice Returns the total supply of `role` holders at the given `timestamp`. The returned
  /// value is the value used to determine if quorum has been reached when approving/disapproving.
  /// @dev The value returned by this method must equal the sum of the quantity of the role
  /// across all policyholders at that timestamp.
  function getSupply(uint8 role) public view returns (uint256) {
    (,,, uint128 quantity) = roleSupplyCkpts[role].latestCheckpoint();
    return quantity;
  }

  /// @notice Returns the total supply of `role` holders at the given `timestamp`. The returned
  /// value is the value used to determine if quorum has been reached when approving/disapproving.
  /// @dev The value returned by this method must equal the sum of the quantity of the role
  /// across all policyholders at that timestamp.
  function getPastSupply(uint8 role, uint256 timestamp) external view returns (uint256) {
    return roleSupplyCkpts[role].getAtTimestamp(timestamp);
  }

  /// @notice Returns all checkpoints for the given `user` and `role`.
  function roleBalanceCheckpoints(address user, uint8 role) external view returns (Checkpoints.History memory) {
    uint256 tokenId = _tokenId(user);
    return roleBalanceCkpts[tokenId][role];
  }

  /// @notice Returns all supply checkpoints for the given `role`.
  function roleSupplyCheckpoints(uint8 role) external view returns (Checkpoints.History memory) {
    return roleSupplyCkpts[role];
  }

  /// @notice Returns true if the `user` has the `role`, false otherwise.
  function hasRole(address user, uint8 role) external view returns (bool) {
    (bool exists,, uint64 expiration, uint128 quantity) = roleBalanceCkpts[_tokenId(user)][role].latestCheckpoint();
    return exists && quantity > 0 && expiration > block.timestamp;
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

  /// @notice Returns the total number of policies in existence.
  /// @dev This is just an alias for convenience/familiarity.
  function totalSupply() public view returns (uint256) {
    return getSupply(ALL_HOLDERS_ROLE);
  }

  // =================================
  // ======== ERC-721 Getters ========
  // =================================

  /// @notice Returns the location of the policy metadata.
  /// @param tokenId The ID of the policy token.
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return factory.tokenURI(name, symbol, tokenId);
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  function _initializeRole(string calldata description) internal {
    numRoles += 1;
    emit RoleInitialized(numRoles, description);
  }

  /// @dev Verifies that admin supply is non-zero to avoid the system being locked. Any changes to
  /// roles that result in zero admin supply will revert.
  function _assertAdminsExist() internal view {
    if (getSupply(ADMIN_ROLE) == 0) revert MissingAdmin();
  }

  function _setRoleHolder(uint8 role, address user, uint128 quantity, uint64 expiration) internal {
    // Scope to avoid stack too deep.
    {
      // Ensure role is initialized.
      if (role > numRoles) revert RoleNotInitialized(role);

      // An expiration of zero is only allowed if the role is being removed. Roles are removed when
      // the quantity is zero. In other words, the relationships that are required between the role
      // quantity and expiration fields are:
      //   - quantity > 0 && expiration > block.timestamp: This means you are adding a role
      //   - quantity == 0 && expiration == 0: This means you are removing a role
      bool case1 = quantity > 0 && expiration > block.timestamp;
      bool case2 = quantity == 0 && expiration == 0;
      if (!(case1 || case2)) revert InvalidInput();
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
    uint128 currentRoleSupply = roleSupplyCkpts[role].latest();
    uint128 newRoleSupply;
    if (hadRoleQuantity && !willHaveRole) newRoleSupply = currentRoleSupply - quantityDiff;
    else if (!hadRoleQuantity && willHaveRole) newRoleSupply = currentRoleSupply + quantityDiff;
    else newRoleSupply = currentRoleSupply;

    roleSupplyCkpts[role].push(newRoleSupply);
    emit RoleAssigned(user, role, expiration, newRoleSupply);
  }

  function _setRolePermission(uint8 role, bytes32 permissionId, bool hasPermission) internal {
    canCreateAction[role][permissionId] = hasPermission;
    emit RolePermissionAssigned(role, permissionId, hasPermission);
  }

  function _revokeExpiredRole(ExpiredRole calldata expiredRole) internal {
    // Read the most recent checkpoint for the user's role balance.
    uint256 tokenId = _tokenId(expiredRole.user);
    (,, uint64 expiration, uint128 quantity) = roleBalanceCkpts[tokenId][expiredRole.role].latestCheckpoint();
    if (quantity == 0 || expiration == 0 || expiration > block.timestamp) revert InvalidInput();
    _setRoleHolder(expiredRole.role, expiredRole.user, 0, 0);
  }

  function _mint(address user) internal {
    uint256 tokenId = _tokenId(user);
    _mint(user, tokenId);
    roleSupplyCkpts[ALL_HOLDERS_ROLE].push(roleSupplyCkpts[ALL_HOLDERS_ROLE].latest() + 1);
    roleBalanceCkpts[tokenId][ALL_HOLDERS_ROLE].push(1);
  }

  function _burn(uint256 tokenId) internal override {
    ERC721NonTransferableMinimalProxy._burn(tokenId);
    roleSupplyCkpts[ALL_HOLDERS_ROLE].push(roleSupplyCkpts[ALL_HOLDERS_ROLE].latest() - 1);
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
