// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721NonTransferableMinimalProxy} from "src/lib/ERC721NonTransferableMinimalProxy.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";
import {ExpiredRole, SetRoleHolder, SetRolePermission} from "src/lib/Structs.sol";
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
  /// @dev DO NOT assign users this role directly. Nothing bad will happen if you do, but it may be
  /// confusing since this is a special role used to (1) track the total supply of all policy
  /// holders, and (2) signal that all policyholders can approve/disapprove for a Strategy.
  bytes32 public constant ALL_HOLDERS_ROLE = bytes32(uint256(keccak256("all-policy-holders")) - 1);

  /// @notice Returns true if the `role` can create actions with the given `permissionId`.
  mapping(bytes32 role => mapping(bytes32 permissionId => bool)) public canCreateAction;

  /// @notice Checkpoints a token ID's "balance" (quantity) of a given role. The quantity of the
  /// role is how much weight the role-holder gets when approving/disapproving (regardless of
  /// strategy).
  /// @dev The current implementation does not allow a user's quantity to be anything other than 1.
  mapping(uint256 tokenId => mapping(bytes32 role => Checkpoints.History)) internal roleBalanceCkpts;

  /// @notice Checkpoints the total supply of a given role.
  /// @dev At a given timestamp, the total supply of a role must equal the sum of the quantity of
  /// the role for each token ID that holds the role.
  mapping(bytes32 role => Checkpoints.History) internal roleSupplyCkpts;

  /// @notice The base URI for all tokens.
  string public baseURI;

  /// @notice The address of the `VertexCore` instance that governs this contract.
  address public vertex;

  VertexFactory public factory;

  error AlreadyInitialized();
  error InvalidInput();
  error NonTransferableToken();
  error OnlyVertex();

  event RoleAssigned(address indexed user, bytes32 indexed role, uint256 expiration, uint256 roleSupply);
  event RolePermissionSet(bytes32 indexed role, bytes32 indexed permissionId, bool hasPermission);


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
    string memory _name,
    address _factory,
    SetRoleHolder[] memory roleHolders,
    SetRolePermission[] memory rolePermissions
  ) external initializer {
    __initializeERC721MinimalProxy(_name, string.concat("V_", LibString.slice(_name, 0, 3)));
    factory = VertexFactory(_factory);
    setRoleHoldersAndPermissions(roleHolders, rolePermissions);
  }

  function setVertex(address _vertex) external {
    if (vertex != address(0)) revert AlreadyInitialized();
    vertex = _vertex;
  }

  /// @notice Returns the quantity of the `role` for the given `user` at `timestamp`. The returned
  /// value is the weight of the role when approving/disapproving (regardless of strategy).
  /// @dev In the current implementation, this will always return 0 or 1 since quantities larger
  /// than 1 are not supported.
  function getPastWeight(address user, bytes32 role, uint256 timestamp) external view returns (uint256) {
    uint256 tokenId = _tokenId(user);
    (uint256 quantity, uint256 expiration) = roleBalanceCkpts[tokenId][role].getCheckpointAtTimestamp(timestamp);
    return quantity > 0 && expiration > block.timestamp ? quantity : 0;
  }

  /// @notice Returns the total supply of `role` holders at the given `timestamp`. The returned
  /// value is the value used to determine if quorum has been reached when approving/disapproving.
  /// @dev The value returned by this method must equal the sum of the quantity of the role for
  /// across all policyholders at that timestamp.
  function getPastSupply(bytes32 role, uint256 timestamp) external view returns (uint256) {
    return roleSupplyCkpts[role].getAtTimestamp(timestamp);
  }

  /// @notice Assigns roles to users.
  function setRoleHolders(SetRoleHolder[] memory roleHolders) public onlyVertex {
    for (uint256 i = 0; i < roleHolders.length; i++) {
      _setRoleHolder(roleHolders[i]);
    }
  }

  /// @notice Sets the permissions for a given role.
  function setRolePermissions(SetRolePermission[] memory rolePermissions) public onlyVertex {
    for (uint256 i = 0; i < rolePermissions.length; i++) {
      _setRolePermission(rolePermissions[i]);
    }
  }

  /// @notice Assigns roles to users and sets permissions for roles.
  function setRoleHoldersAndPermissions(SetRoleHolder[] memory roleHolders, SetRolePermission[] memory rolePermissions)
    public
  {
    setRoleHolders(roleHolders);
    setRolePermissions(rolePermissions);
  }

  /// @notice Revokes expired roles.
  function revokeExpiredRoles(ExpiredRole[] memory expiredRoles) external {
    for (uint256 i = 0; i < expiredRoles.length; i++) {
      _revokeExpiredRole(expiredRoles[i]);
    }
  }

  /// @notice Revokes all roles from the user and burns their policy.
  /// @dev The contract cannot enumerate all roles for a user, so the caller MUST provide the full
  /// list of roles held by user.
  function revokePolicy(address user, bytes32[] memory roles) external {
    for (uint256 i = 0; i < roles.length; i++) {
      _setRoleHolder(SetRoleHolder(roles[i], user, 0));
    }
    _burn(_tokenId(user));
  }

  /// @notice Returns all checkpoints for the given `user` and `role`.
  function roleBalanceCheckpoints(address user, bytes32 role) external view returns (Checkpoints.History memory) {
    uint256 tokenId = _tokenId(user);
    return roleBalanceCkpts[tokenId][role];
  }

  /// @notice Returns all supply checkpoints for the given `role`.
  function roleSupplyCheckpoints(bytes32 role) external view returns (Checkpoints.History memory) {
    return roleSupplyCkpts[role];
  }

  /// @notice Returns true if the given `user` has a given `permissionId`, false otherwise.
  function hasPermissionId(address user, bytes32 permissionId) external view returns (bool) {
    return _hasPermission(user, permissionId);
  }

  function _setRoleHolder(SetRoleHolder memory roleHolder) internal {
    (bytes32 role, address user, uint256 expiration) = (roleHolder.role, roleHolder.user, roleHolder.expiration);
    if (expiration > 0 && expiration <= block.timestamp) revert InvalidInput();

    // Check if the user currently holds this role.
    uint256 tokenId = _tokenId(user);
    (,, uint64 currentExpiration, uint128 currentQuantity) = roleBalanceCkpts[tokenId][role].latestCheckpoint();
    bool hadRole = currentQuantity > 0 && currentExpiration > block.timestamp;

    // If the expiration is zero, the role is being removed. Otherwise, the role is being added.
    bool willHaveRole = expiration != 0;

    // Now we update the user's role balance checkpoint.
    if (balanceOf(user) == 0) _mint(user);
    roleBalanceCkpts[tokenId][role].push(willHaveRole ? 1 : 0, expiration);

    // Lastly we update the total supply of the role. If the expiration is zero, it means the role was removed.
    uint128 currentRoleSupply = roleSupplyCkpts[role].latest();
    uint128 newRoleSupply;
    if (hadRole && !willHaveRole) newRoleSupply = currentRoleSupply - 1;
    else if (!hadRole && willHaveRole) newRoleSupply = currentRoleSupply + 1;
    else newRoleSupply = currentRoleSupply;

    roleSupplyCkpts[role].push(newRoleSupply);

    emit RoleAssigned(user, role, expiration, newRoleSupply);
  }

  function _setRolePermission(SetRolePermission memory rolePermission) internal {
    (bytes32 role, bytes32 permissionId, bool hasPermission) =
      (rolePermission.role, rolePermission.permissionId, rolePermission.hasPermission);

    canCreateAction[role][permissionId] = hasPermission;
    emit RolePermissionSet(role, permissionId, hasPermission);
  }

  function _revokeExpiredRole(ExpiredRole memory expiredRole) internal {
    // Read the most recent checkpoint for the user's role balance.
    uint256 tokenId = _tokenId(expiredRole.user);
    (,, uint64 expiration, uint128 quantity) = roleBalanceCkpts[tokenId][expiredRole.role].latestCheckpoint();
    if (quantity == 0 || expiration == 0 || expiration > block.timestamp) revert InvalidInput();
    _setRoleHolder(SetRoleHolder(expiredRole.role, expiredRole.user, 0));
  }

  function _tokenId(address user) internal pure returns (uint256) {
    return uint256(uint160(user));
  }

  function _mint(address user) internal {
    _mint(user, _tokenId(user));
    roleSupplyCkpts[ALL_HOLDERS_ROLE].push(roleSupplyCkpts[ALL_HOLDERS_ROLE].latest() + 1);
  }

  function _burn(address user) internal {
    _burn(_tokenId(user));
    roleSupplyCkpts[ALL_HOLDERS_ROLE].push(roleSupplyCkpts[ALL_HOLDERS_ROLE].latest() - 1);
  }

  /// @notice sets the base URI for the contract
  /// @param _baseURI the base URI string to set
  function setBaseURI(string calldata _baseURI) public onlyVertex {
    baseURI = _baseURI;
  }

  /// @dev overriding transferFrom to disable transfers
  /// @dev this is a temporary solution, we will need to conform to a Souldbound standard
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

  /// @notice Returns the total number of policies in existence.
  function totalSupply() public view returns (uint256) {
    return roleSupplyCkpts[ALL_HOLDERS_ROLE].latest();
  }

  /// @notice returns the location of the policy metadata
  /// @param tokenId the id of the policy token
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    return factory.tokenURI(name, symbol, tokenId);
  }

  function getTokenPermissionCheckpoints(uint256 policyId, bytes32 permissionId)
    external
    view
    returns (PermissionIdCheckpoint[] memory)
  {
    return tokenPermissionCheckpoints[policyId][permissionId];
  }

  function getTokenPermissionSupplyCheckpoints(bytes32 permissionId)
    external
    view
    returns (PermissionIdCheckpoint[] memory)
  {
    return permissionSupplyCheckpoints[permissionId];
  }
}