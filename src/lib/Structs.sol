// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";

import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";

struct RoleHolderData {
  uint8 role; // ID of the role to set (uint8 ensures on-chain enumerability when burning policies).
  address user; // User to assign the role to.
  uint128 quantity; // Quantity of the role to assign to the user, i.e. their (dis)approval quantity.
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
  IVertexStrategy strategy; // Strategy used to govern the action.
}

struct Action {
  address creator; // msg.sender of createAction.
  bool executed; // has action executed.
  bool canceled; // is action canceled.
  bytes4 selector; // The function selector that will be called when the action is executed.
  IVertexStrategy strategy; // strategy that determines the validation process of this action.
  address target; // The contract called when the action is executed
  bytes data; //  The encoded arguments to be passed to the function that is called when the action is executed.
  uint256 value; // The value in wei to be sent when the action is executed.
  uint256 creationTime; // The timestamp when action was created (used for policy snapshots).
  uint256 minExecutionTime; // Only set when an action is queued. The timestamp when action execution can begin.
  uint256 totalApprovals; // The total quantity of policyholder approvals.
  uint256 totalDisapprovals; // The total quantity of policyholder disapprovals.
  uint32 destinationChain;
  address destinationRecipient;
  address relayer;
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
