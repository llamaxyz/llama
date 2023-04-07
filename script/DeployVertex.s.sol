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

import "forge-std/Script.sol";

contract DeployVertex is Script {
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
    // These attributes need to be in alphabetical order, otherwise the JSON
    // will not decode properly.
    uint256 approvalPeriod;
    uint8 approvalRole;
    string approvalRoleComment;
    uint8 disapprovalRole;
    string disapprovalRoleComment;
    uint256 expirationPeriod;
    uint8[] forceApprovalRoles;
    string forceApprovalRolesComment;
    uint8[] forceDisapprovalRoles;
    bool isFixedLengthApprovalPeriod;
    uint256 minApprovalPct;
    uint256 minDisapprovalPct;
    uint256 queuingPeriod;
  }

  struct RawRoleHolderData {
    // These attributes need to be in alphabetical order, otherwise the JSON
    // will not decode properly.
    uint64 expiration;
    string expirationComment;
    uint128 quantity;
    uint8 role;
    string roleComment;
    address user;
    string userComment;
  }

  struct RawRolePermissionData {
    bytes32 permissionId;
    uint8 role;
  }

  function run() public {
    console2.log("Deploying VertexFactory with following parameters to chain:", block.chainid);

    // TODO vm.broadcast();
    coreLogic = new VertexCore();
    console2.log("  VertexCoreLogic:", address(coreLogic));

    // TODO vm.broadcast();
    strategyLogic = new VertexStrategy();
    console2.log("  VertexStrategyLogic:", address(strategyLogic));

    // TODO vm.broadcast();
    accountLogic = new VertexAccount();
    console2.log("  VertexAccountLogic:", address(accountLogic));

    // TODO vm.broadcast();
    policyLogic = new VertexPolicy();
    console2.log("  VertexPolicyLogic:", address(policyLogic));

    // TODO vm.broadcast();
    policyMetadata = new VertexPolicyTokenURI();
    console2.log("  VertexPolicyMetadata:", address(policyMetadata));

    // TODO vm.broadcast();
    lens = new VertexLens();
    console2.log("  VertexLens:", address(lens));

    string memory jsonInput = readInput();

    // TODO vm.broadcast();
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

  function readInput() internal view returns (string memory) {
    string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
    string memory chainDir = string.concat(vm.toString(block.chainid), "/");
    return vm.readFile(string.concat(inputDir, chainDir, "deployVertex.json"));
  }

  function readStrategies(string memory _jsonInput) internal returns (Strategy[] memory strategies) {
    bytes memory _strategyData = _jsonInput.parseRaw(".initialStrategies");
    RawStrategyData[] memory _rawStrategies = abi.decode(_strategyData, (RawStrategyData[]));

    strategies = new Strategy[](_rawStrategies.length);
    for (uint256 i = 0; i < _rawStrategies.length; i++) {
      RawStrategyData memory _rawStrategy = _rawStrategies[i];
      strategies[i].approvalPeriod = _rawStrategy.approvalPeriod;
      strategies[i].queuingPeriod = _rawStrategy.queuingPeriod;
      strategies[i].expirationPeriod = _rawStrategy.expirationPeriod;
      strategies[i].minApprovalPct = _rawStrategy.minApprovalPct;
      strategies[i].minDisapprovalPct = _rawStrategy.minDisapprovalPct;
      strategies[i].isFixedLengthApprovalPeriod = _rawStrategy.isFixedLengthApprovalPeriod;
      strategies[i].approvalRole = _rawStrategy.approvalRole;
      strategies[i].disapprovalRole = _rawStrategy.disapprovalRole;
      strategies[i].forceApprovalRoles = _rawStrategy.forceApprovalRoles;
      strategies[i].forceDisapprovalRoles = _rawStrategy.forceDisapprovalRoles;
    }
  }

  function readRoleDescriptions(string memory _jsonInput) internal returns (RoleDescription[] memory _descriptions) {
    bytes memory _descriptionBytes = _jsonInput.parseRaw(".initialRoleDescriptions");
    _descriptions = abi.decode(_descriptionBytes, (RoleDescription[]));
  }

  function readRoleHolders(string memory _jsonInput) internal returns (RoleHolderData[] memory _roleHolders) {
    bytes memory _roleHolderData = _jsonInput.parseRaw(".initialRoleHolders");
    RawRoleHolderData[] memory _rawRoleHolders = abi.decode(_roleHolderData, (RawRoleHolderData[]));

    _roleHolders = new RoleHolderData[](_rawRoleHolders.length);
    for (uint256 i = 0; i < _rawRoleHolders.length; i++) {
      RawRoleHolderData memory _rawRoleHolder = _rawRoleHolders[i];
      _roleHolders[i].role = _rawRoleHolder.role;
      _roleHolders[i].user = _rawRoleHolder.user;
      _roleHolders[i].quantity = _rawRoleHolder.quantity;
      _roleHolders[i].expiration = _rawRoleHolder.expiration;
    }
  }

  function readRolePermissions(string memory _jsonInput)
    internal
    returns (RolePermissionData[] memory _rolePermissions)
  {
    bytes memory _rolePermissionData = _jsonInput.parseRaw(".initialRolePermissions");
    RawRolePermissionData[] memory _rawRolePermissions = abi.decode(_rolePermissionData, (RawRolePermissionData[]));

    _rolePermissions = new RolePermissionData[](_rawRolePermissions.length);
    for (uint256 i = 0; i < _rawRolePermissions.length; i++) {
      RawRolePermissionData memory _rawRolePermission = _rawRolePermissions[i];
      _rolePermissions[i].role = _rawRolePermission.role;
      _rolePermissions[i].permissionId = _rawRolePermission.permissionId;
      _rolePermissions[i].hasPermission = true;
    }
  }
}
