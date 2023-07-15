// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaPolicyMetadata} from "src/interfaces/ILlamaPolicyMetadata.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

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
  uint96 totalApprovals; // The total quantity of policyholder approvals.
  uint96 totalDisapprovals; // The total quantity of policyholder disapprovals.
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
  uint96 quantity; // Quantity of the role to assign to the policyholder, i.e. their (dis)approval quantity.
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

struct LlamaCoreInitializationConfig {
  string name; // The name of the `LlamaCore` clone.
  LlamaPolicy policyLogic; // This Llama instance's policy contract.
  ILlamaStrategy strategyLogic; // The Llama Strategy implementation (logic) contract.
  ILlamaAccount accountLogic; // The Llama Account implementation (logic) contract.
  bytes[] initialStrategies; // Array of initial strategy configurations.
  bytes[] initialAccounts; // Array of initial account configurations.
  RoleDescription[] initialRoleDescriptions; // Array of initial role descriptions.
  RoleHolderData[] initialRoleHolders; // Array of initial role holders, their quantities and their role expirations.
  RolePermissionData[] initialRolePermissions; // Array of initial permissions given to roles.
  ILlamaPolicyMetadata llamaPolicyMetadataLogic; // The metadata logic contract for the policy NFT.
  string color; // The background color as any valid SVG color (e.g. #00FF00) for the deployed Llama instance's NFT.
  string logo; // The SVG string representing the logo for the deployed Llama instance's NFT.
  address deployer; // The caller of the factory's deploy function
}

struct LlamaPolicyInitializationConfig {
  string name; // The name of the policy.
  RoleDescription[] roleDescriptions; // The role descriptions.
  RoleHolderData[] roleHolders; // The `role`, `policyholder`, `quantity` and `expiration` of the role holders.
  RolePermissionData[] rolePermissions; // The `role`, `permissionId` and whether the role has the permission of the
    // role permissions.
  ILlamaPolicyMetadata llamaPolicyMetadataLogic; // The metadata logic contract for the policy NFT.
  string color; // The background color as any valid SVG color (e.g. #00FF00) for the deployed Llama instance's NFT.
  string logo; // The SVG string representing the logo for the deployed Llama instance's NFT.
  address llamaExecutor; // The address of the instance's LlamaExecutor
  bytes32 bootstrapPermissionId; // The permission ID that allows holders to change role permissions.
}
