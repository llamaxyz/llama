// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";

struct RoleHolderData {
  uint8 role; // ID of the role to set (uint8 ensures on-chain enumerability when burning policies).
  address policyholder; // Policyholder to assign the role to.
  uint128 quantity; // Quantity of the role to assign to the policyholder, i.e. their (dis)approval quantity.
  uint64 expiration; // When the role expires.
}

struct RolePermissionData {
  uint8 role; // Name of the role to set.
  bytes32 permissionId; // Permission ID to assign to the role.
  bool hasPermission; // Whether to assign the permission or remove the permission.
}

struct PermissionData {
  address target; // Contract being called by an action.
  bytes4 selector; // Selector of the function being called by an action.
  ILlamaStrategy strategy; // Strategy used to govern the action.
}

struct ActionInfo {
  uint256 id; // ID of the action.
  address creator; // Address that created the action.
  uint8 creatorRole; // The role that created the action.
  ILlamaStrategy strategy; // Strategy used to govern the action.
  address target; // Contract being called by an action.
  uint256 value; // Value in wei to be sent when the action is executed.
  bytes data; // Data to be called on the `target` when the action is executed.
}

struct Action {
  // Instead of storing all data required to execute an action in storage, we only save the hash to
  // make action creation cheaper. The hash is computed by taking the keccak256 hash of the
  // concatenation of the each field in the `ActionInfo` struct.
  bytes32 infoHash;
  bool executed; // Has action executed.
  bool canceled; // Is action canceled.
  bool isScript; // Is the action's target a script.
  uint64 creationTime; // The timestamp when action was created (used for policy snapshots).
  uint64 minExecutionTime; // Only set when an action is queued. The timestamp when action execution can begin.
  uint128 totalApprovals; // The total quantity of policyholder approvals.
  uint128 totalDisapprovals; // The total quantity of policyholder disapprovals.
}
