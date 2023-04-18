// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/Script.sol";

import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

library DeployUtils {
  using stdJson for string;

  address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
  Vm internal constant vm = Vm(VM_ADDRESS);

  struct RawStrategyData {
    // Attributes need to be in alphabetical order so JSON decodes properly.
    uint256 approvalPeriod;
    uint8 approvalRole;
    uint8 disapprovalRole;
    uint256 expirationPeriod;
    uint8[] forceApprovalRoles;
    uint8[] forceDisapprovalRoles;
    bool isFixedLengthApprovalPeriod;
    uint256 minApprovalPct;
    uint256 minDisapprovalPct;
    uint256 queuingPeriod;
  }

  struct RawRoleHolderData {
    // Attributes need to be in alphabetical order so JSON decodes properly.
    string comment;
    uint64 expiration;
    uint128 quantity;
    uint8 role;
    address user;
  }

  struct RawRolePermissionData {
    // Attributes need to be in alphabetical order so JSON decodes properly.
    string comment;
    bytes32 permissionId;
    uint8 role;
  }

  function readScriptInput(string memory filename) internal view returns (string memory) {
    string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
    string memory chainDir = string.concat(vm.toString(block.chainid), "/");
    return vm.readFile(string.concat(inputDir, chainDir, filename));
  }

  function readStrategies(string memory jsonInput) internal pure returns (Strategy[] memory strategies) {
    bytes memory strategyData = jsonInput.parseRaw(".initialStrategies");
    RawStrategyData[] memory rawStrategies = abi.decode(strategyData, (RawStrategyData[]));

    strategies = new Strategy[](rawStrategies.length);
    for (uint256 i = 0; i < rawStrategies.length; i++) {
      RawStrategyData memory rawStrategy = rawStrategies[i];
      strategies[i].approvalPeriod = rawStrategy.approvalPeriod;
      strategies[i].queuingPeriod = rawStrategy.queuingPeriod;
      strategies[i].expirationPeriod = rawStrategy.expirationPeriod;
      strategies[i].minApprovalPct = rawStrategy.minApprovalPct;
      strategies[i].minDisapprovalPct = rawStrategy.minDisapprovalPct;
      strategies[i].isFixedLengthApprovalPeriod = rawStrategy.isFixedLengthApprovalPeriod;
      strategies[i].approvalRole = rawStrategy.approvalRole;
      strategies[i].disapprovalRole = rawStrategy.disapprovalRole;
      strategies[i].forceApprovalRoles = rawStrategy.forceApprovalRoles;
      strategies[i].forceDisapprovalRoles = rawStrategy.forceDisapprovalRoles;
    }
  }

  function readRoleDescriptions(string memory jsonInput)
    internal
    returns (RoleDescription[] memory roleDescriptions)
  {
    string[] memory descriptions = jsonInput.readStringArray(".initialRoleDescriptions");
    for (uint256 i; i < descriptions.length; i++) {
      require(bytes(descriptions[i]).length <= 32, "Role description is too long");
    }
    roleDescriptions = abi.decode(abi.encode(descriptions), (RoleDescription[]));
  }

  function readRoleHolders(string memory jsonInput) internal pure returns (RoleHolderData[] memory roleHolders) {
    bytes memory roleHolderData = jsonInput.parseRaw(".initialRoleHolders");
    RawRoleHolderData[] memory rawRoleHolders = abi.decode(roleHolderData, (RawRoleHolderData[]));

    roleHolders = new RoleHolderData[](rawRoleHolders.length);
    for (uint256 i = 0; i < rawRoleHolders.length; i++) {
      RawRoleHolderData memory rawRoleHolder = rawRoleHolders[i];
      roleHolders[i].role = rawRoleHolder.role;
      roleHolders[i].user = rawRoleHolder.user;
      roleHolders[i].quantity = rawRoleHolder.quantity;
      roleHolders[i].expiration = rawRoleHolder.expiration;
    }
  }

  function readRolePermissions(string memory jsonInput)
    internal
    pure
    returns (RolePermissionData[] memory rolePermissions)
  {
    bytes memory rolePermissionData = jsonInput.parseRaw(".initialRolePermissions");
    RawRolePermissionData[] memory rawRolePermissions = abi.decode(rolePermissionData, (RawRolePermissionData[]));

    rolePermissions = new RolePermissionData[](rawRolePermissions.length);
    for (uint256 i = 0; i < rawRolePermissions.length; i++) {
      RawRolePermissionData memory rawRolePermission = rawRolePermissions[i];
      rolePermissions[i].role = rawRolePermission.role;
      rolePermissions[i].permissionId = rawRolePermission.permissionId;
      rolePermissions[i].hasPermission = true;
    }
  }
}
