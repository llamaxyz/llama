// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaBaseScript} from "src/llama-scripts/LlamaBaseScript.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

/// @title Llama Governance Script
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A script that allows users to aggregate common calls on the core and policy contracts.
/// @notice How to use this script:
///   - The `aggregate` method is for ignoring all the functions in the contract and crafting your own payload. This
///     method only allows `LlamaCore` and `LlamaPolicy` as targets.
///   - The "Batch Policy Functions" section has public methods that (1) can be called directly as part of an action,
///     and (2) are also used by methods in the "Common Aggregate Calls" section.
///   - The "Common Aggregate Calls" section has external methods for common batch actions.
contract LlamaGovernanceScript is LlamaBaseScript {
  // ==========================
  // ========= Structs ========
  // ==========================

  /// @dev Struct for holding data for the `updateRoleDescription` method in `LlamaPolicy`.
  struct UpdateRoleDescription {
    uint8 role; // Role to update.
    RoleDescription description; // New role description.
  }

  /// @dev Struct for holding data for the `createStrategies` method in `LlamaCore`.
  struct CreateStrategies {
    ILlamaStrategy llamaStrategyLogic; // Logic contract for the strategies.
    bytes[] strategies; // Array of configurations to initialize new strategies with.
  }

  // ========================
  // ======== Errors ========
  // ========================

  /// @dev The call did not succeed.
  /// @param index Index of the arbitrary function being called.
  /// @param revertData Data returned by the called function.
  error CallReverted(uint256 index, bytes revertData);

  /// @dev The provided arrays do not have the same length.
  error MismatchedArrayLengths();

  /// @dev The target address is neither the `LlamaCore` nor the `LlamaPolicy`.
  /// @param target The target address provided.
  error UnauthorizedTarget(address target);

  // =======================================
  // ======== Arbitrary Aggregation ========
  // =======================================

  /// @notice Batch arbitrary calls to `LlamaCore` and `LlamaPolicy` in a single action.
  /// @dev This method should be assigned carefully, since it allows for arbitrary calls to be made within the context
  /// of `LlamaExecutor` as this script will be delegatecalled. It is safer to permission the functions below as needed
  /// than to permission the aggregate function itself.
  /// @param targets Array of target addresses to call.
  /// @param data Array of data to call the targets with.
  /// @return returnData Array of return data from the calls.
  function aggregate(address[] calldata targets, bytes[] calldata data)
    external
    onlyDelegateCall
    returns (bytes[] memory returnData)
  {
    if (targets.length != data.length) revert MismatchedArrayLengths();
    (LlamaCore core, LlamaPolicy policy) = _context();
    uint256 length = data.length;
    returnData = new bytes[](length);
    for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
      bool addressIsCore = targets[i] == address(core);
      bool addressIsPolicy = targets[i] == address(policy);
      if (!addressIsCore && !addressIsPolicy) revert UnauthorizedTarget(targets[i]);
      (bool success, bytes memory response) = targets[i].call(data[i]);
      if (!success) revert CallReverted(i, response);
      returnData[i] = response;
    }
  }

  // ========================================
  // ======== Common Aggregate Calls ========
  // ========================================

  /// @notice Initialize new roles and set their holders with the provided data.
  /// @param description Array of role descriptions to initialize.
  /// @param _setRoleHolders Array of role holders to set.
  function initializeRolesAndSetRoleHolders(
    RoleDescription[] calldata description,
    RoleHolderData[] calldata _setRoleHolders
  ) external onlyDelegateCall {
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
  }

  /// @notice Initialize new roles and set their permissions with the provided data.
  /// @param description Array of role descriptions to initialize.
  /// @param _setRolePermissions Array of role permissions to set.
  function initializeRolesAndSetRolePermissions(
    RoleDescription[] calldata description,
    RolePermissionData[] calldata _setRolePermissions
  ) external onlyDelegateCall {
    initializeRoles(description);
    setRolePermissions(_setRolePermissions);
  }

  /// @notice Initialize new roles, set their holders, and set their permissions with the provided data.
  /// @param description Array of role descriptions to initialize.
  /// @param _setRoleHolders Array of role holders to set.
  /// @param _setRolePermissions Array of role permissions to set.
  function initializeRolesAndSetRoleHoldersAndSetRolePermissions(
    RoleDescription[] calldata description,
    RoleHolderData[] calldata _setRoleHolders,
    RolePermissionData[] calldata _setRolePermissions
  ) external onlyDelegateCall {
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
    setRolePermissions(_setRolePermissions);
  }

  /// @notice Create new strategies and set role holders with the provided data.
  /// @param _createStrategies Struct of data for the `createStrategies` method in `LlamaCore`.
  /// @param _setRoleHolders Array of role holders to set.
  function createNewStrategiesAndSetRoleHolders(
    CreateStrategies calldata _createStrategies,
    RoleHolderData[] calldata _setRoleHolders
  ) external onlyDelegateCall {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    setRoleHolders(_setRoleHolders);
  }

  /// @notice Create new strategies, initialize new roles and set their holders with the provided data.
  /// @param _createStrategies Struct of data for the `createStrategies` method in `LlamaCore`.
  /// @param description Array of role descriptions to initialize.
  /// @param _setRoleHolders Array of role holders to set.
  function createNewStrategiesAndInitializeRolesAndSetRoleHolders(
    CreateStrategies calldata _createStrategies,
    RoleDescription[] calldata description,
    RoleHolderData[] calldata _setRoleHolders
  ) external onlyDelegateCall {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
  }

  /// @notice Create new strategies and set role permissions with the provided data.
  /// @param _createStrategies Struct of data for the `createStrategies` method in `LlamaCore`.
  /// @param _setRolePermissions Array of role permissions to set.
  function createNewStrategiesAndSetRolePermissions(
    CreateStrategies calldata _createStrategies,
    RolePermissionData[] calldata _setRolePermissions
  ) external onlyDelegateCall {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    setRolePermissions(_setRolePermissions);
  }

  /// @notice Create new strategies, initialize new roles, set their holders and set their permissions with the provided
  /// data.
  /// @param _createStrategies Struct of data for the `createStrategies` method in `LlamaCore`.
  /// @param description Array of role descriptions to initialize.
  /// @param _setRoleHolders Array of role holders to set.
  /// @param _setRolePermissions Array of role permissions to set.
  function createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissions(
    CreateStrategies calldata _createStrategies,
    RoleDescription[] calldata description,
    RoleHolderData[] calldata _setRoleHolders,
    RolePermissionData[] calldata _setRolePermissions
  ) external onlyDelegateCall {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
    setRolePermissions(_setRolePermissions);
  }

  /// @notice Revoke policies and update role descriptions with the provided data.
  /// @param _revokePolicies Array of policies to revoke.
  /// @param _updateRoleDescriptions Array of role descriptions to update.
  function revokePoliciesAndUpdateRoleDescriptions(
    address[] calldata _revokePolicies,
    UpdateRoleDescription[] calldata _updateRoleDescriptions
  ) external onlyDelegateCall {
    revokePolicies(_revokePolicies);
    updateRoleDescriptions(_updateRoleDescriptions);
  }

  /// @notice Revoke policies, update role descriptions, and set role holders with the provided data.
  /// @param _revokePolicies Array of policies to revoke.
  /// @param _updateRoleDescriptions Array of role descriptions to update.
  /// @param _setRoleHolders Array of role holders to set.
  function revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders(
    address[] calldata _revokePolicies,
    UpdateRoleDescription[] calldata _updateRoleDescriptions,
    RoleHolderData[] calldata _setRoleHolders
  ) external onlyDelegateCall {
    revokePolicies(_revokePolicies);
    updateRoleDescriptions(_updateRoleDescriptions);
    setRoleHolders(_setRoleHolders);
  }

  // ========================================
  // ======== Batch Policy Functions ========
  // ========================================

  /// @notice Batch initialize new roles with the provided data.
  /// @param description Array of role descriptions to initialize.
  function initializeRoles(RoleDescription[] calldata description) public onlyDelegateCall {
    (, LlamaPolicy policy) = _context();
    uint256 length = description.length;
    for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
      policy.initializeRole(description[i]);
    }
  }

  /// @notice Batch set role holders with the provided data.
  /// @param _setRoleHolders Array of role holders to set.
  function setRoleHolders(RoleHolderData[] calldata _setRoleHolders) public onlyDelegateCall {
    (, LlamaPolicy policy) = _context();
    uint256 length = _setRoleHolders.length;
    for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
      policy.setRoleHolder(
        _setRoleHolders[i].role,
        _setRoleHolders[i].policyholder,
        _setRoleHolders[i].quantity,
        _setRoleHolders[i].expiration
      );
    }
  }

  /// @notice Batch set role permissions with the provided data.
  /// @param _setRolePermissions Array of role permissions to set.
  function setRolePermissions(RolePermissionData[] calldata _setRolePermissions) public onlyDelegateCall {
    (, LlamaPolicy policy) = _context();
    uint256 length = _setRolePermissions.length;
    for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
      policy.setRolePermission(
        _setRolePermissions[i].role, _setRolePermissions[i].permissionData, _setRolePermissions[i].hasPermission
      );
    }
  }

  /// @notice Batch revoke policies with the provided data.
  /// @param _revokePolicies Array of policies to revoke.
  function revokePolicies(address[] calldata _revokePolicies) public onlyDelegateCall {
    (, LlamaPolicy policy) = _context();
    for (uint256 i = 0; i < _revokePolicies.length; i = LlamaUtils.uncheckedIncrement(i)) {
      policy.revokePolicy(_revokePolicies[i]);
    }
  }

  /// @notice Batch update role descriptions with the provided data.
  /// @param roleDescriptions Array of role descriptions to update.
  function updateRoleDescriptions(UpdateRoleDescription[] calldata roleDescriptions) public onlyDelegateCall {
    (, LlamaPolicy policy) = _context();
    for (uint256 i = 0; i < roleDescriptions.length; i = LlamaUtils.uncheckedIncrement(i)) {
      policy.updateRoleDescription(roleDescriptions[i].role, roleDescriptions[i].description);
    }
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Get the core and policy contracts.
  function _context() internal view returns (LlamaCore core, LlamaPolicy policy) {
    core = LlamaCore(LlamaExecutor(address(this)).LLAMA_CORE());
    policy = LlamaPolicy(core.policy());
  }
}
