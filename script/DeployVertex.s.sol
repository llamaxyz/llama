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
    return vm.readFile(string.concat(inputDir, chainDir, "deployVertexFactory.json"));
  }

  function readStrategies(string memory _jsonInput) internal returns (Strategy[] memory strategies) {
    string[] memory _strategyObjects = _jsonInput.readStringArray(".initialStrategies");
    strategies = new Strategy[](_strategyObjects.length);
    for (uint256 i = 0; i < _strategyObjects.length; i++) {
      string memory _strategyObject = _strategyObjects[i];
      strategies[i].approvalPeriod = _strategyObject.readUint(".approvalPeriod");
      strategies[i].queuingPeriod = _strategyObject.readUint(".queuingPeriod");
      strategies[i].expirationPeriod = _strategyObject.readUint(".expirationPeriod");
      strategies[i].minApprovalPct = _strategyObject.readUint(".minApprovalPct");
      strategies[i].minDisapprovalPct = _strategyObject.readUint(".minDisapprovalPct");
      strategies[i].isFixedLengthApprovalPeriod = _strategyObject.readBool(".isFixedLengthApprovalPeriod");
      strategies[i].approvalRole = uint8(_strategyObject.readUint(".approvalRole"));
      strategies[i].disapprovalRole = uint8(_strategyObject.readUint(".disapprovalRole"));

      uint256[] memory _approvalRoles = _strategyObject.readUintArray(".forceApprovalRoles");
      uint8[] memory _forceApprovalRoles = new uint8[](_approvalRoles.length);
      for (uint256 j = 0; j < _approvalRoles.length; j++) {
        _forceApprovalRoles[j] = uint8(_approvalRoles[j]);
      }
      strategies[i].forceApprovalRoles = _forceApprovalRoles;

      uint256[] memory _disapprovalRoles = _strategyObject.readUintArray(".forcedisapprovalRoles");
      uint8[] memory _forceDisapprovalRoles = new uint8[](_disapprovalRoles.length);
      for (uint256 k = 0; k < _disapprovalRoles.length; k++) {
        _forceDisapprovalRoles[k] = uint8(_disapprovalRoles[k]);
      }
      strategies[i].forceDisapprovalRoles = _forceDisapprovalRoles;
    }
  }

  function readRoleDescriptions(string memory _jsonInput) internal returns (RoleDescription[] memory _descriptions) {
    bytes32[] memory _descriptionBytes = _jsonInput.readBytes32Array(".initialRoleDescriptions");
    _descriptions = new RoleDescription[](_descriptionBytes.length);
    for (uint256 i = 0; i < _descriptionBytes.length; i++) {
      _descriptions[i] = RoleDescription.wrap(_descriptionBytes[i]);
    }
  }

  function readRoleHolders(string memory _jsonInput) internal returns (RoleHolderData[] memory _roleHolders) {
    string[] memory _roleHolderObjects = _jsonInput.readStringArray(".initialRoleHolders");
    _roleHolders = new RoleHolderData[](_roleHolderObjects.length);
    for (uint256 i = 0; i < _roleHolderObjects.length; i++) {
      string memory _roleHolderObject = _roleHolderObjects[i];
      RoleHolderData memory _roleHolder;
      _roleHolder.role = uint8(_roleHolderObject.readUint(".role"));
      _roleHolder.user = _roleHolderObject.readAddress(".user");
      _roleHolder.quantity = uint128(_roleHolderObject.readUint(".quantity"));
      _roleHolder.expiration = uint64(_roleHolderObject.readUint(".expiration"));
      _roleHolders[i] = _roleHolder;
    }
  }

  function readRolePermissions(string memory _jsonInput) internal returns (RolePermissionData[] memory _rolePermissions) {
    string[] memory _rolePermissionObjects = _jsonInput.readStringArray("initialRolePermissions");
    _rolePermissions = new RolePermissionData[](_rolePermissionObjects.length);
    for (uint256 i = 0; i < _rolePermissionObjects.length; i++) {
      string memory _rolePermissionObject = _rolePermissionObjects[i];
      _rolePermissions[i].role = uint8(_rolePermissionObject.readUint(".role"));
      _rolePermissions[i].permissionId = _rolePermissionObject.readBytes32(".permissionId");
      _rolePermissions[i].hasPermission = _rolePermissionObject.readBool(".hasPermission");
    }
  }
}
