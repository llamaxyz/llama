// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";

/// @dev Data required to create an action.
struct ActionInfo {
  uint256 id; // ID of the action.
  address creator; // Address that created the action.
  uint8 creatorRole; // The role that created the action.
  ILlamaStrategy strategy; // Strategy used to govern the action.
  address target; // Contract being called by an action.
  uint256 value; // Value in wei to be sent when the action is executed.
  bytes data; // Data to be called on the target when the action is executed.
}

/// @dev Data that represents an action.
struct Action {
  // Instead of storing all data required to execute an action in storage, we only save the hash to
  // make action creation cheaper. The hash is computed by taking the keccak256 hash of the concatenation of each
  // field in the `ActionInfo` struct.
  bytes32 infoHash;
  bool executed; // Has action executed.
  bool canceled; // Is action canceled.
  bool isScript; // Is the action's target a script.
  uint64 creationTime; // The timestamp when action was created (used for policy snapshots).
  uint64 minExecutionTime; // Only set when an action is queued. The timestamp when action execution can begin.
  uint128 totalApprovals; // The total quantity of policyholder approvals.
  uint128 totalDisapprovals; // The total quantity of policyholder disapprovals.
}

/// @dev Data that represents a permission.
struct PermissionData {
  address target; // Contract being called by an action.
  bytes4 selector; // Selector of the function being called by an action.
  ILlamaStrategy strategy; // Strategy used to govern the action.
}

/// @dev Data required to assign/revoke a role to/from a policyholder.
struct RoleHolderData {
  uint8 role; // ID of the role to set (uint8 ensures on-chain enumerability when burning policies).
  address policyholder; // Policyholder to assign the role to.
  uint128 quantity; // Quantity of the role to assign to the policyholder, i.e. their (dis)approval quantity.
  uint64 expiration; // When the role expires.
}

/// @dev Data required to assign/revoke a permission to/from a role.
struct RolePermissionData {
  uint8 role; // ID of the role to set (uint8 ensures on-chain enumerability when burning policies).
  // Permission ID to assign to the role. It's a hash computed by taking the keccak256 hash of the concatenation of
  // each field in the `PermissionData` struct.
  bytes32 permissionId;
  bool hasPermission; // Whether to assign the permission or remove the permission.
}

/// @dev Data for sending ERC20 tokens to recipients.
struct ERC20Data {
  IERC20 token; // The ERC20 token to transfer.
  address recipient; // The address to transfer the token to.
  uint256 amount; // The amount of tokens to transfer.
}

/// @dev Data for sending ERC721 tokens to recipients.
struct ERC721Data {
  IERC721 token; // The ERC721 token to transfer.
  address recipient; // The address to transfer the token to.
  uint256 tokenId; // The tokenId of the token to transfer.
}

/// @dev Data for operator allowance for ERC721 transfers.
struct ERC721OperatorData {
  IERC721 token; // The ERC721 token to transfer.
  address recipient; // The address to transfer the token to.
  bool approved; // Whether to approve or revoke allowance.
}

/// @dev Data for sending ERC1155 tokens to recipients.
struct ERC1155Data {
  IERC1155 token; // The ERC1155 token to transfer.
  address recipient; // The address to transfer the token to.
  uint256 tokenId; // The tokenId of the token to transfer.
  uint256 amount; // The amount of tokens to transfer.
  bytes data; // The data to pass to the ERC1155 token.
}

/// @dev Data for batch sending ERC1155 tokens to recipients.
struct ERC1155BatchData {
  IERC1155 token; // The ERC1155 token to transfer.
  address recipient; // The address to transfer the token to.
  uint256[] tokenIds; // The tokenId of the token to transfer.
  uint256[] amounts; // The amount of tokens to transfer.
  bytes data; // The data to pass to the ERC1155 token.
}

/// @dev Data for operator allowance for ERC1155 transfers.
struct ERC1155OperatorData {
  IERC1155 token; // The ERC1155 token to transfer.
  address recipient; // The address to transfer the token to.
  bool approved; // Whether to approve or revoke allowance.
}
