// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RoleDescription} from "src/lib/UDVTs.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @dev A script that allows users to aggregate common calls on the core and policy contracts.
contract GovernanceScript {
  // =============================
  // ========= Errors ============
  // =============================

  error CallReverted(uint256 index, bytes revertData);
  error MismatchedArrayLengths();
  error UnauthorizedTarget(address target);

  // ==============================
  // ========= Structs ============
  // ==============================

  struct UpdateRoleDescription {
    uint8 role;
    RoleDescription description;
  }

  struct RevokeExpiredRole {
    uint8 role;
    address policyholder;
  }

  struct SetRolePermission {
    uint8 role;
    bytes32 permissionId;
    bool hasPermission;
  }

  struct SetRoleHolder {
    uint8 role;
    address policyholder;
    uint128 quantity;
    uint64 expiration;
  }

  struct CreateStrategies {
    ILlamaStrategy llamaStrategyLogic;
    bytes[] strategies;
  }

  // =======================================
  // ======== Arbitrary Aggregation =========
  // =======================================
  /// @notice This method should be assigned carefully, since it allows for arbitrary calls to be made within the
  /// context
  /// of LlamaCore since this script will be delegatecalled. It is safer to permission out the functions below as
  /// needed than to permission the aggregate function itself
  function aggregate(address[] calldata targets, bytes[] calldata data) external returns (bytes[] memory returnData) {
    if (targets.length != data.length) revert MismatchedArrayLengths();
    (LlamaCore core, LlamaPolicy policy) = _context();
    uint256 length = data.length;
    returnData = new bytes[](length);
    for (uint256 i = 0; i < length; i++) {
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

  function initializeRolesAndSetRoleHolders(
    RoleDescription[] calldata description,
    SetRoleHolder[] calldata _setRoleHolders
  ) external {
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
  }

  function initializeRolesAndSetRolePermissions(
    RoleDescription[] calldata description,
    SetRolePermission[] calldata _setRolePermissions
  ) external {
    initializeRoles(description);
    setRolePermissions(_setRolePermissions);
  }

  function initializeRolesAndSetRoleHoldersAndSetRolePermissions(
    RoleDescription[] calldata description,
    SetRoleHolder[] calldata _setRoleHolders,
    SetRolePermission[] calldata _setRolePermissions
  ) external {
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
    setRolePermissions(_setRolePermissions);
  }

  function createNewStrategiesAndSetRoleHolders(
    CreateStrategies calldata _createStrategies,
    SetRoleHolder[] calldata _setRoleHolders
  ) external {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    setRoleHolders(_setRoleHolders);
  }

  function createNewStrategiesAndInitializeRolesAndSetRoleHolders(
    CreateStrategies calldata _createStrategies,
    RoleDescription[] calldata description,
    SetRoleHolder[] calldata _setRoleHolders
  ) external {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
  }

  function createNewStrategiesAndSetRolePermissions(
    CreateStrategies calldata _createStrategies,
    SetRolePermission[] calldata _setRolePermissions
  ) external {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    setRolePermissions(_setRolePermissions);
  }

  function createNewStrategiesAndNewRolesAndSetRoleHoldersAndSetRolePermissions(
    CreateStrategies calldata _createStrategies,
    RoleDescription[] calldata description,
    SetRoleHolder[] calldata _setRoleHolders,
    SetRolePermission[] calldata _setRolePermissions
  ) external {
    (LlamaCore core,) = _context();
    core.createStrategies(_createStrategies.llamaStrategyLogic, _createStrategies.strategies);
    initializeRoles(description);
    setRoleHolders(_setRoleHolders);
    setRolePermissions(_setRolePermissions);
  }

  function revokePoliciesAndUpdateRoleDescriptions(
    address[] calldata _revokePolicies,
    UpdateRoleDescription[] calldata _updateRoleDescriptions
  ) external {
    revokePolicies(_revokePolicies);
    updateRoleDescriptions(_updateRoleDescriptions);
  }

  function revokePoliciesAndUpdateRoleDescriptionsAndSetRoleHolders(
    address[] calldata _revokePolicies,
    UpdateRoleDescription[] calldata _updateRoleDescriptions,
    SetRoleHolder[] calldata _setRoleHolders
  ) external {
    revokePolicies(_revokePolicies);
    updateRoleDescriptions(_updateRoleDescriptions);
    setRoleHolders(_setRoleHolders);
  }

  // ========================================
  // ======== Batch Policy Functions ========
  // ========================================

  function initializeRoles(RoleDescription[] calldata description) public {
    (, LlamaPolicy policy) = _context();
    uint256 length = description.length;
    for (uint256 i = 0; i < length; i++) {
      policy.initializeRole(description[i]);
    }
  }

  function setRoleHolders(SetRoleHolder[] calldata _setRoleHolders) public {
    (, LlamaPolicy policy) = _context();
    uint256 length = _setRoleHolders.length;
    for (uint256 i = 0; i < length; i++) {
      policy.setRoleHolder(
        _setRoleHolders[i].role,
        _setRoleHolders[i].policyholder,
        _setRoleHolders[i].quantity,
        _setRoleHolders[i].expiration
      );
    }
  }

  function setRolePermissions(SetRolePermission[] calldata _setRolePermissions) public {
    (, LlamaPolicy policy) = _context();
    uint256 length = _setRolePermissions.length;
    for (uint256 i = 0; i < length; i++) {
      policy.setRolePermission(
        _setRolePermissions[i].role, _setRolePermissions[i].permissionId, _setRolePermissions[i].hasPermission
      );
    }
  }

  function revokeExpiredRoles(RevokeExpiredRole[] calldata _revokeExpiredRoles) public {
    (, LlamaPolicy policy) = _context();
    uint256 length = _revokeExpiredRoles.length;
    for (uint256 i = 0; i < length; i++) {
      policy.revokeExpiredRole(_revokeExpiredRoles[i].role, _revokeExpiredRoles[i].policyholder);
    }
  }

  /// @notice if the roles array is empty, it will revoke all roles iteratively. Pass all roles in as an array otherwise
  /// if the policyholder has too many roles.
  function revokePolicies(address[] calldata _revokePolicies) public {
    (, LlamaPolicy policy) = _context();
    for (uint256 i = 0; i < _revokePolicies.length; i++) {
      policy.revokePolicy(_revokePolicies[i]);
    }
  }

  function updateRoleDescriptions(UpdateRoleDescription[] calldata roleDescriptions) public {
    (, LlamaPolicy policy) = _context();
    for (uint256 i = 0; i < roleDescriptions.length; i++) {
      policy.updateRoleDescription(roleDescriptions[i].role, roleDescriptions[i].description);
    }
  }

  function _context() internal view returns (LlamaCore core, LlamaPolicy policy) {
    core = LlamaCore(LlamaExecutor(address(this)).LLAMA_CORE());
    policy = LlamaPolicy(core.policy());
  }
}
