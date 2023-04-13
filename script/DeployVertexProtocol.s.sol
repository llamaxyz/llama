// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

import {Script, stdJson, console2} from "forge-std/Script.sol";

contract DeployVertexProtocol is Script {
  using stdJson for string;

  // Logic contracts.
  VertexCore coreLogic;
  VertexStrategy strategyLogic;
  VertexAccount accountLogic;
  VertexPolicy policyLogic;

  // Core Protocol.
  VertexFactory factory;
  VertexPolicyTokenURI policyMetadata;
  VertexLens lens;

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
    bytes32 permissionId;
    uint8 role;
  }

  function run() public {
    console2.log("Deploying VertexFactory with following parameters to chain:", block.chainid);

    vm.broadcast();
    coreLogic = new VertexCore();
    console2.log("  VertexCoreLogic:", address(coreLogic));

    vm.broadcast();
    strategyLogic = new VertexStrategy();
    console2.log("  VertexStrategyLogic:", address(strategyLogic));

    vm.broadcast();
    accountLogic = new VertexAccount();
    console2.log("  VertexAccountLogic:", address(accountLogic));

    vm.broadcast();
    policyLogic = new VertexPolicy();
    console2.log("  VertexPolicyLogic:", address(policyLogic));

    vm.broadcast();
    policyMetadata = new VertexPolicyTokenURI();
    console2.log("  VertexPolicyTokenURI:", address(policyMetadata));

    vm.broadcast();
    lens = new VertexLens();
    console2.log("  VertexLens:", address(lens));

    string memory jsonInput = readScriptInput();

    vm.broadcast();
    factory = new VertexFactory(
      coreLogic,
      strategyLogic,
      accountLogic,
      policyLogic,
      policyMetadata,
      jsonInput.readString(".rootVertexName"),
      readStrategies(jsonInput),
      jsonInput.readStringArray(".initialAccountNames"),
      readRoleDescriptions(jsonInput),
      readRoleHolders(jsonInput),
      readRolePermissions(jsonInput)
    );

    console2.log("VertexFactory deployed at address:", address(factory));
  }

  function readScriptInput() internal view returns (string memory) {
    string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
    string memory chainDir = string.concat(vm.toString(block.chainid), "/");
    return vm.readFile(string.concat(inputDir, chainDir, "deployVertex.json"));
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
