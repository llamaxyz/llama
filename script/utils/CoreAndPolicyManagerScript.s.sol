// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {BaseScript} from "./BaseScript.s.sol";

/// @dev A script that allows users to aggregate common calls on the core and policy contracts.
contract CoreAndPolicyManagerScript /* is BaseScript */ {
  function setRoleHolders(uint8[] roles, address[] policyholders, uint128[] quantities, uint64[] expirations) external {
    uint256 length = roles.length;
    require(length == policyholders.length && length = quantities.length && length == expirations.length, "roles and policyholders must be the same length");
    for (uint256 i = 0; i < length; i++) {
      policy.setRoleHolder(roles[i], policyholders[i], quantities[i], expirations[i]);
    }
  }

  function initializeRoles(RoleDescription[] description) {
    policy.initializeRole(RoleDescription description)
  }

  //TODO add the rest of policy and core functions, then add functions that execute common combinations of them
  
}
