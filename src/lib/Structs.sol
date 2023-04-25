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
  uint256 creationTime; // The timestamp when action was created (used for policy snapshots).
  uint256 minExecutionTime; // Only set when an action is queued. The timestamp when action execution can begin.
  uint256 totalApprovals; // The total quantity of policyholder approvals.
  uint256 totalDisapprovals; // The total quantity of policyholder disapprovals.
}

struct RelativeStrategyConfig {
  uint256 approvalPeriod; // The length of time of the approval period.
  uint256 queuingPeriod; // The length of time of the queuing period. The disapproval period is the queuing period when
    // enabled.
  uint256 expirationPeriod; // The length of time an action can be executed before it expires.
  uint256 minApprovalPct; // Minimum percentage of total approval quantity / total approval supply.
  uint256 minDisapprovalPct; // Minimum percentage of total disapproval quantity / total disapproval supply.
  bool isFixedLengthApprovalPeriod; // Determines if an action be queued before approvalEndTime.
  uint8 approvalRole; // Anyone with this role can cast approval of an action.
  uint8 disapprovalRole; // Anyone with this role can cast disapproval of an action.
  uint8[] forceApprovalRoles; // Anyone with this role can single-handedly approve an action.
  uint8[] forceDisapprovalRoles; // Anyone with this role can single-handedly disapprove an action.
}

struct AbsoluteStrategyConfig {
  uint256 approvalPeriod; // The length of time of the approval period.
  uint256 queuingPeriod; // The length of time of the queuing period. The disapproval period is the queuing period when
    // enabled.
  uint256 expirationPeriod; // The length of time an action can be executed before it expires.
  uint256 minApprovals; // Minimum number of total approval quantity.
  uint256 minDisapprovals; // Minimum number of total disapproval quantity.
  bool isFixedLengthApprovalPeriod; // Determines if an action be queued before approvalEndTime.
  uint8 approvalRole; // Anyone with this role can cast approval of an action.
  uint8 disapprovalRole; // Anyone with this role can cast disapproval of an action.
  uint8[] forceApprovalRoles; // Anyone with this role can single-handedly approve an action.
  uint8[] forceDisapprovalRoles; // Anyone with this role can single-handedly disapprove an action.
}

struct ERC20Data {
  IERC20 token; // The ERC20 token to transfer.
  address recipient; // The address to transfer the token to.
  uint256 amount; // The amount of tokens to transfer.
}

struct ERC721Data {
  IERC721 token; // The ERC721 token to transfer.
  address recipient; // The address to transfer the token to.
  uint256 tokenId; // The tokenId of the token to transfer.
}

struct ERC721OperatorData {
  IERC721 token; // The ERC721 token to transfer.
  address recipient; // The address to transfer the token to.
  bool approved; // Whether to approve or revoke allowance.
}

struct ERC1155Data {
  IERC1155 token; // The ERC1155 token to transfer.
  address recipient; // The address to transfer the token to.
  uint256 tokenId; // The tokenId of the token to transfer.
  uint256 amount; // The amount of tokens to transfer.
  bytes data; // The data to pass to the ERC1155 token.
}

struct ERC1155BatchData {
  IERC1155 token; // The ERC1155 token to transfer.
  address recipient; // The address to transfer the token to.
  uint256[] tokenIds; // The tokenId of the token to transfer.
  uint256[] amounts; // The amount of tokens to transfer.
  bytes data; // The data to pass to the ERC1155 token.
}

struct ERC1155OperatorData {
  IERC1155 token; // The ERC1155 token to transfer.
  address recipient; // The address to transfer the token to.
  bool approved; // Whether to approve or revoke allowance.
}
