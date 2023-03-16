// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721NonTransferableMinimalProxy} from "src/lib/ERC721NonTransferableMinimalProxy.sol";
import {LibString} from "@solady/utils/LibString.sol";
import {IVertexPolicy} from "src/interfaces/IVertexPolicy.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";
import {ExpiredRole, SetRoleHolder, SetRolePermission} from "src/lib/Structs.sol";
import {Checkpoints} from "src/lib/Checkpoints.sol";

/// @title VertexPolicy
/// @author Llama (vertex@llama.xyz)
/// @dev VertexPolicy is a (TODO: pick a soulbound standard) ERC721 contract where each token has permissions
/// @dev TODO Add comments here around limitations/expectations of this contract, namely the "total
/// supply issue", the fact that quantities cannot be larger than 1, and burning a policy.
/// @notice The permissions determine how the token can interact with the vertex administrator contract
contract VertexPolicy2 is ERC721NonTransferableMinimalProxy {
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
    SetRoleHolder[] memory roleHolders,
    SetRolePermission[] memory rolePermissions
  ) external initializer {
    __initializeERC721MinimalProxy(_name, string.concat("V_", LibString.slice(_name, 0, 3)));
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
    string[11] memory parts;

    parts[0] =
      '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" />';
    parts[1] =
      '<path transform="translate(10,10)" d="M3.0543 18.4836C3.05685 18.2679 3.14276 18.0616 3.29402 17.908C3.44526 17.7544 3.65009 17.6653 3.86553 17.6596H14.6671C15.177 17.6606 15.682 17.5611 16.1534 17.3667C16.6248 17.1724 17.0533 16.8869 17.4143 16.5267C17.7754 16.1665 18.062 15.7386 18.2577 15.2674C18.4534 14.7963 18.5545 14.2912 18.555 13.781V0H15.4987V13.781C15.4961 13.9967 15.4102 14.2029 15.2589 14.3566C15.1077 14.5102 14.9029 14.5993 14.6874 14.605H3.87567C2.84811 14.6061 1.86294 15.0151 1.13634 15.7422C0.409745 16.4694 0.00107373 17.4553 0 18.4836V27.9963H3.0543V18.4836Z" fill="url(#paint0_linear_2141_86430)"/><path transform="translate(10,10)" d="M19.9061 2.62599H19.7701L19.8999 2.7559V5.59734H22.7109L24.0292 6.92876C23.1533 7.10776 22.3661 7.58374 21.8004 8.27633C21.2346 8.96892 20.9252 9.83566 20.924 10.7302V28H23.9662V10.7261C23.9694 10.5086 24.0571 10.3008 24.2108 10.1469C24.3646 9.99309 24.5723 9.90526 24.7896 9.90211H25.2581C27.0529 9.90211 27.6615 8.90152 27.8419 8.4814C28.0224 8.06126 28.3003 6.91455 27.0308 5.63994L24.0534 2.63615H23.1265" fill="url(#paint1_linear_2141_86430)"/><path transform="translate(10,10)" d="M11.828 26.4971C12.4952 26.4965 13.1559 26.6289 13.7715 26.8864C14.3871 27.1439 14.9453 27.5214 15.4137 27.9969H19.1109C18.4455 26.6309 17.4099 25.4796 16.1222 24.6742C14.8345 23.8688 13.3465 23.4418 11.828 23.4418C10.3095 23.4418 8.82159 23.8688 7.53388 24.6742C6.2462 25.4796 5.21058 26.6309 4.54515 27.9969H8.24237C8.71076 27.5214 9.269 27.1439 9.88461 26.8864C10.5002 26.6289 11.1608 26.4965 11.828 26.4971Z" fill="url(#paint2_linear_2141_86430)"/><path transform="translate(10,10)" d="M36.616 11.494V11.824L41.17 23H44.756L49.288 11.824V11.494H45.878L43.062 19.678H42.842L40.026 11.494H36.616ZM49.53 17.236C49.53 21.152 52.214 23.264 55.712 23.264C59.166 23.264 60.816 21.196 61.3 19.59V19.26H58.286C58.066 19.986 57.428 21.02 55.712 21.02C53.908 21.02 52.874 19.656 52.83 18.006H61.498V17.06C61.498 13.32 59.078 11.23 55.624 11.23C52.214 11.23 49.53 13.32 49.53 17.236ZM52.852 16.048C52.962 14.618 53.908 13.474 55.668 13.474C57.406 13.474 58.33 14.618 58.396 16.048H52.852ZM63.6437 11.494V23H66.8777V17.324C66.8777 14.97 67.9337 13.914 70.0237 13.914H72.1357V11.45H70.1117C68.3077 11.45 67.4057 12.22 66.9657 13.254H66.7457V11.494H63.6437ZM73.3455 11.494V13.65H76.7115V19.854C76.7115 21.9 77.9875 23 80.0775 23H83.9055V20.734H80.1215L79.9455 20.558V13.65H83.6855V11.494H79.9455V7.6H79.6155L76.7115 8.964V11.494H73.3455ZM85.2181 17.236C85.2181 21.152 87.9021 23.264 91.4001 23.264C94.8541 23.264 96.5041 21.196 96.9881 19.59V19.26H93.9741C93.7541 19.986 93.1161 21.02 91.4001 21.02C89.5961 21.02 88.5621 19.656 88.5181 18.006H97.1861V17.06C97.1861 13.32 94.7661 11.23 91.3121 11.23C87.9021 11.23 85.2181 13.32 85.2181 17.236ZM88.5401 16.048C88.6501 14.618 89.5961 13.474 91.3561 13.474C93.0941 13.474 94.0181 14.618 94.0841 16.048H88.5401ZM98.0558 11.494V11.824L101.994 17.082L97.5498 22.67V23H101.048L103.952 19.172H104.172L106.944 23H110.354V22.67L106.306 17.302L110.64 11.824V11.494H107.186L104.348 15.212H104.128L101.466 11.494H98.0558Z" fill="white"/><defs><linearGradient id="paint0_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient><linearGradient id="paint1_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient><linearGradient id="paint2_linear_2141_86430" x1="15.9481" y1="2.22356e-07" x2="8.77168" y2="26.0208" gradientUnits="userSpaceOnUse"><stop stop-color="#0C97D4"/><stop offset="1" stop-color="#21CE99"/></linearGradient></defs>';
    parts[2] = '<text x="10" y="60" class="base">';
    parts[3] = string.concat("Policy Id: ", LibString.toString(tokenId));
    parts[5] = '</text><text x="10" y="80" class="base">';
    parts[6] = name;
    parts[8] = '</text><text x="10" y="100" class="base">';
    parts[9] = symbol;
    parts[10] = "</text></svg>";

    string memory output = string(
      abi.encodePacked(
        parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8], parts[9], parts[10]
      )
    );

    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "Vertex Policy ID: ',
            LibString.toString(tokenId),
            '", "description": "Vertex is a identity access system for privledged smart contract functions", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(output)),
            '"}'
          )
        )
      )
    );
    return string(abi.encodePacked("data:application/json;base64,", json));
  }
}
