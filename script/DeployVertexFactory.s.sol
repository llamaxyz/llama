// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexPolicyMetadata} from "src/VertexPolicyMetadata.sol";
import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

import "forge-std/Script.sol";

contract DeployVertexFactory is Script {
  using stdJson for string;

  struct Vars {
    string jsonInput;
    address vertexCoreLogic;
    address vertexStrategyLogic;
    address vertexAccountLogic;
    address vertexPolicyLogic;
    address vertexPolicyMetadata;
    VertexFactory factory;
  }

  function run() public {
    Vars memory _vars;

    _vars.jsonInput = readInput();

    console2.log("Deploying VertexFactory with following parameters to chain:", block.chainid);

    _vars.vertexCoreLogic = _vars.jsonInput.readAddress(".vertexCoreLogic");
    console2.log("  VertexCoreLogic:", _vars.vertexCoreLogic);

    _vars.vertexStrategyLogic = _vars.jsonInput.readAddress(".initialVertexStrategyLogic");
    console2.log("  VertexStrategyLogic:", _vars.vertexStrategyLogic);

    _vars.vertexAccountLogic = _vars.jsonInput.readAddress(".initialVertexAccountLogic");
    console2.log("  VertexAccountLogic:", _vars.vertexAccountLogic);

    _vars.vertexPolicyLogic = _vars.jsonInput.readAddress(".vertexPolicyLogic");
    console2.log("  VertexPolicyLogic:", _vars.vertexPolicyLogic);

    _vars.vertexPolicyMetadata = _vars.jsonInput.readAddress(".vertexPolicyMetadata");
    console2.log("  VertexPolicyMetadata:", _vars.vertexPolicyMetadata);

    // TODO vm.broadcast();
    _vars.factory = new VertexFactory(
      VertexCore(_vars.vertexCoreLogic),
      _vars.vertexStrategyLogic,
      _vars.vertexAccountLogic,
      VertexPolicy(_vars.vertexPolicyLogic),
      VertexPolicyMetadata(_vars.vertexPolicyMetadata),
      _vars.jsonInput.readString(".rootVertexName"),
      readStrategies(_vars.jsonInput),
      _vars.jsonInput.readStringArray(".initialAddressNames"),
      readRoleDescriptions(_vars.jsonInput),
      readRoleHolders(_vars.jsonInput),
      readRolePermissions(_vars.jsonInput)
    );

    console2.log("VertexFactory deployed at address:", address(_vars.factory));
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
