// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/Script.sol";

import {AbsoluteStrategyConfig, RelativeStrategyConfig, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

library DeployUtils {
  using stdJson for string;

  address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
  Vm internal constant vm = Vm(VM_ADDRESS);

  struct RawRelativeStrategyData {
    // Attributes need to be in alphabetical order so JSON decodes properly.
    uint64 approvalPeriod;
    uint8 approvalRole;
    uint8 disapprovalRole;
    uint64 expirationPeriod;
    uint8[] forceApprovalRoles;
    uint8[] forceDisapprovalRoles;
    bool isFixedLengthApprovalPeriod;
    uint16 minApprovalPct;
    uint16 minDisapprovalPct;
    uint64 queuingPeriod;
  }

  struct RawRoleHolderData {
    // Attributes need to be in alphabetical order so JSON decodes properly.
    string comment;
    uint64 expiration;
    address policyholder;
    uint128 quantity;
    uint8 role;
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

  function readRelativeStrategies(string memory jsonInput) internal pure returns (bytes[] memory) {
    bytes memory strategyData = jsonInput.parseRaw(".initialStrategies");
    RawRelativeStrategyData[] memory rawStrategyConfigs = abi.decode(strategyData, (RawRelativeStrategyData[]));

    RelativeStrategyConfig[] memory strategyConfigs = new RelativeStrategyConfig[](rawStrategyConfigs.length);
    for (uint256 i = 0; i < rawStrategyConfigs.length; i++) {
      RawRelativeStrategyData memory rawStrategy = rawStrategyConfigs[i];
      strategyConfigs[i].approvalPeriod = rawStrategy.approvalPeriod;
      strategyConfigs[i].queuingPeriod = rawStrategy.queuingPeriod;
      strategyConfigs[i].expirationPeriod = rawStrategy.expirationPeriod;
      strategyConfigs[i].minApprovalPct = rawStrategy.minApprovalPct;
      strategyConfigs[i].minDisapprovalPct = rawStrategy.minDisapprovalPct;
      strategyConfigs[i].isFixedLengthApprovalPeriod = rawStrategy.isFixedLengthApprovalPeriod;
      strategyConfigs[i].approvalRole = rawStrategy.approvalRole;
      strategyConfigs[i].disapprovalRole = rawStrategy.disapprovalRole;
      strategyConfigs[i].forceApprovalRoles = rawStrategy.forceApprovalRoles;
      strategyConfigs[i].forceDisapprovalRoles = rawStrategy.forceDisapprovalRoles;
    }

    return encodeStrategyConfigs(strategyConfigs);
  }

  function readRoleDescriptions(string memory jsonInput) internal returns (RoleDescription[] memory roleDescriptions) {
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
      roleHolders[i].policyholder = rawRoleHolder.policyholder;
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

  function encodeStrategy(RelativeStrategyConfig memory strategy) internal pure returns (bytes memory encoded) {
    encoded = abi.encode(strategy);
  }

  function encodeStrategy(AbsoluteStrategyConfig memory strategy) internal pure returns (bytes memory encoded) {
    encoded = abi.encode(strategy);
  }

  function encodeStrategyConfigs(RelativeStrategyConfig[] memory strategies)
    internal
    pure
    returns (bytes[] memory encoded)
  {
    encoded = new bytes[](strategies.length);
    for (uint256 i = 0; i < strategies.length; i++) {
      encoded[i] = encodeStrategy(strategies[i]);
    }
  }

  function encodeStrategyConfigs(AbsoluteStrategyConfig[] memory strategies)
    internal
    pure
    returns (bytes[] memory encoded)
  {
    encoded = new bytes[](strategies.length);
    for (uint256 i; i < strategies.length; i++) {
      encoded[i] = encodeStrategy(strategies[i]);
    }
  }
}
