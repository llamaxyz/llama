// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {IVertexStrategy} from "src/interfaces/IVertexStrategy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {DefaultStrategy} from "src/strategies/DefaultStrategy.sol";
import {DefaultStrategyConfig, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

contract DeployVertexProtocol is Script {
  using stdJson for string;

  // Logic contracts.
  VertexCore coreLogic;
  DefaultStrategy strategyLogic;
  VertexAccount accountLogic;
  VertexPolicy policyLogic;

  // Core Protocol.
  VertexFactory factory;
  VertexPolicyTokenURI policyTokenUri;
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
    print(string.concat("Deploying Vertex infrastructure to chain:", vm.toString(block.chainid)));

    vm.broadcast();
    coreLogic = new VertexCore();
    print(string.concat("  VertexCoreLogic:", vm.toString(address(coreLogic))));

    vm.broadcast();
    strategyLogic = new DefaultStrategy();
    print(string.concat("  VertexStrategyLogic:", vm.toString(address(strategyLogic))));

    vm.broadcast();
    accountLogic = new VertexAccount();
    print(string.concat("  VertexAccountLogic:", vm.toString(address(accountLogic))));

    vm.broadcast();
    policyLogic = new VertexPolicy();
    print(string.concat("  VertexPolicyLogic:", vm.toString(address(policyLogic))));

    vm.broadcast();
    policyTokenUri = new VertexPolicyTokenURI();
    print(string.concat("  VertexPolicyTokenURI:", vm.toString(address(policyTokenUri))));

    string memory jsonInput = readScriptInput();

    vm.broadcast();
    factory = new VertexFactory(
      coreLogic,
      strategyLogic,
      accountLogic,
      policyLogic,
      policyTokenUri,
      jsonInput.readString(".rootVertexName"),
      encodeStrategyConfigs(readStrategies(jsonInput)),
      jsonInput.readStringArray(".initialAccountNames"),
      readRoleDescriptions(jsonInput),
      readRoleHolders(jsonInput),
      readRolePermissions(jsonInput)
    );
    print(string.concat("  VertexFactory:", vm.toString(address(factory))));

    vm.broadcast();
    lens = new VertexLens();
    print(string.concat("  VertexLens:", vm.toString(address(lens))));
  }

  function readScriptInput() internal view returns (string memory) {
    string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
    string memory chainDir = string.concat(vm.toString(block.chainid), "/");
    return vm.readFile(string.concat(inputDir, chainDir, "deployVertex.json"));
  }

  function readStrategies(string memory jsonInput)
    internal
    pure
    returns (DefaultStrategyConfig[] memory strategyConfigs)
  {
    bytes memory strategyData = jsonInput.parseRaw(".initialStrategies");
    RawStrategyData[] memory rawStrategyConfigs = abi.decode(strategyData, (RawStrategyData[]));

    strategyConfigs = new DefaultStrategyConfig[](rawStrategyConfigs.length);
    for (uint256 i = 0; i < rawStrategyConfigs.length; i++) {
      RawStrategyData memory rawStrategy = rawStrategyConfigs[i];
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

  function encodeStrategy(DefaultStrategyConfig memory strategy) internal pure returns (bytes memory encoded) {
    encoded = abi.encode(strategy);
  }

  function encodeStrategyConfigs(DefaultStrategyConfig[] memory strategies)
    internal
    pure
    returns (bytes[] memory encoded)
  {
    encoded = new bytes[](strategies.length);
    for (uint256 i; i < strategies.length; i++) {
      encoded[i] = encodeStrategy(strategies[i]);
    }
  }

  function toDefaultStrategy(IVertexStrategy strategy) internal pure returns (DefaultStrategy converted) {
    assembly {
      converted := strategy
    }
  }

  function print(string memory message) internal view {
    // Avoid getting flooded with logs during tests. Note that fork tests will show logs with this
    // approach, because there's currently no way to tell which environment we're in, e.g. script
    // or test. This is being tracked in https://github.com/foundry-rs/foundry/issues/2900.
    if (block.chainid != 31_337) console2.log(message);
  }
}
