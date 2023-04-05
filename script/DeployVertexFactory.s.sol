// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexPolicyMetadata} from "src/VertexPolicyMetadata.sol";
import {Strategy, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";

import "forge-std/Script.sol";

contract DeployVertexFactory is Script {
  using stdJson for string;

  function run() public {
    // vm.broadcast();
    string memory _jsonInput = readInput();

    console2.log("Deploying VertexFactory via CREATE3 with following parameters to chain:", block.chainid);

    address _vertexCoreLogic = _jsonInput.readAddress(".vertexCoreLogic");
    console2.log("  VertexCoreLogic:", _vertexCoreLogic);

    address _vertexStrategyLogic = _jsonInput.readAddress(".initialVertexStrategyLogic");
    console2.log("  VertexStrategyLogic:", _vertexStrategyLogic);

    address _vertexAccountLogic = _jsonInput.readAddress(".initialVertexAccountLogic");
    console2.log("  VertexAccountLogic:", _vertexAccountLogic);

    address _vertexPolicyLogic = _jsonInput.readAddress(".vertexPolicyLogic");
    console2.log("  VertexPolicyLogic:", _vertexPolicyLogic);

    address _vertexPolicyMetadata = _jsonInput.readAddress(".vertexPolicyMetadata");
    console2.log("  VertexPolicyMetadata:", _vertexPolicyMetadata);

    // This salt must be unique and never have been used with CREATE3 on any
    // chain before. CREATE3 works by deploying a proxy with the salt via
    // CREATE2. So anyone who had used CREATE3 with the same salt would have
    // already deployed and initialized a proxy to the address. Hence, CREATE3
    // will just revert.
    bytes32 _salt = keccak256(bytes("Unique Llama Vertex Factory Salt On All Chains Dude"));

    bytes memory _constructorArgs = abi.encode(
      VertexCore(_vertexCoreLogic),
      _vertexStrategyLogic,
      _vertexAccountLogic,
      VertexPolicy(_vertexPolicyLogic),
      VertexPolicyMetadata(_vertexPolicyMetadata),
      _jsonInput.readString(".rootVertexName"),
      readStrategies(_jsonInput),
      _jsonInput.readStringArray(".initialAddressNames"),
      readRoleDescriptions(_jsonInput),
      readRoleHolders(_jsonInput),
      readRolePermissions(_jsonInput)
    );
    uint256 _doNotSendETHDuringDeploy = 0;

    address _factory = CREATE3.deploy(
      _salt,
      abi.encodePacked(type(VertexFactory).creationCode, _constructorArgs),
      _doNotSendETHDuringDeploy
    );

    console2.log("VertexFactory deployed at address:", _factory);
  }

  function readInput() internal returns (string memory) {
    string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
    string memory chainDir = string.concat(vm.toString(block.chainid), "/");
    return vm.readFile(string.concat(inputDir, chainDir, "deployVertexFactory.json"));
  }

  function readStrategies(string memory _jsonInput) internal returns (Strategy[] memory strategies) {
    address[] memory _strategyAddresses = _jsonInput.readAddressArray(".initialStrategies");
    strategies = new Strategy[](_strategyAddresses.length);
    for (uint256 i = 0; i < _strategyAddresses.length; i++) {
      strategies[i] = Strategy(_strategyAddresses[i]);
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
