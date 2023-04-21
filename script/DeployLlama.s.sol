// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaFactory} from "src/LlamaFactory.sol";
import {LlamaLens} from "src/LlamaLens.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {LlamaPolicyTokenURI} from "src/LlamaPolicyTokenURI.sol";
import {LlamaPolicyTokenURIParamRegistry} from "src/LlamaPolicyTokenURIParamRegistry.sol";
import {AbsoluteStrategy} from "src/strategies/AbsoluteStrategy.sol";
import {RelativeStrategy} from "src/strategies/RelativeStrategy.sol";
import {AbsoluteStrategyConfig, RelativeStrategyConfig, RoleHolderData, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";

contract DeployLlama is Script {
  using stdJson for string;

  // Logic contracts.
  LlamaCore coreLogic;
  RelativeStrategy relativeStrategyLogic;
  AbsoluteStrategy absoluteStrategyLogic;
  LlamaAccount accountLogic;
  LlamaPolicy policyLogic;

  // Core Protocol.
  LlamaFactory factory;
  LlamaPolicyTokenURI policyTokenURI;
  LlamaPolicyTokenURIParamRegistry policyTokenURIParamRegistry;
  LlamaLens lens;

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
    print(string.concat("Deploying Llama framework to chain:", vm.toString(block.chainid)));

    vm.broadcast();
    coreLogic = new LlamaCore();
    print(string.concat("  LlamaCoreLogic:", vm.toString(address(coreLogic))));

    vm.broadcast();
    relativeStrategyLogic = new RelativeStrategy();
    print(string.concat("  LlamaRelativeStrategyLogic:", vm.toString(address(relativeStrategyLogic))));

    vm.broadcast();
    absoluteStrategyLogic = new AbsoluteStrategy();
    print(string.concat("  LlamaAbsoluteStrategyLogic:", vm.toString(address(absoluteStrategyLogic))));

    vm.broadcast();
    accountLogic = new LlamaAccount();
    print(string.concat("  LlamaAccountLogic:", vm.toString(address(accountLogic))));

    vm.broadcast();
    policyLogic = new LlamaPolicy();
    print(string.concat("  LlamaPolicyLogic:", vm.toString(address(policyLogic))));

    vm.broadcast();
    policyTokenURI = new LlamaPolicyTokenURI();
    print(string.concat("  LlamaPolicyTokenURI:", vm.toString(address(policyTokenURI))));

    string memory jsonInput = readScriptInput();

    vm.broadcast();
    factory = new LlamaFactory(
      coreLogic,
      relativeStrategyLogic,
      accountLogic,
      policyLogic,
      policyTokenURI,
      jsonInput.readString(".rootLlamaName"),
      encodeStrategyConfigs(readStrategies(jsonInput)),
      jsonInput.readStringArray(".initialAccountNames"),
      readRoleDescriptions(jsonInput),
      readRoleHolders(jsonInput),
      readRolePermissions(jsonInput)
    );
    print(string.concat("  LlamaFactory:", vm.toString(address(factory))));

    policyTokenURIParamRegistry = factory.LLAMA_POLICY_TOKEN_URI_PARAM_REGISTRY();
    print(string.concat("  LlamaPolicyTokenURIParamRegistry:", vm.toString(address(policyTokenURIParamRegistry))));

    vm.broadcast();
    lens = new LlamaLens();
    print(string.concat("  LlamaLens:", vm.toString(address(lens))));
  }

  function readScriptInput() internal view returns (string memory) {
    string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
    string memory chainDir = string.concat(vm.toString(block.chainid), "/");
    return vm.readFile(string.concat(inputDir, chainDir, "deployLlama.json"));
  }

  function readStrategies(string memory jsonInput)
    internal
    pure
    returns (RelativeStrategyConfig[] memory strategyConfigs)
  {
    bytes memory strategyData = jsonInput.parseRaw(".initialStrategies");
    RawStrategyData[] memory rawStrategyConfigs = abi.decode(strategyData, (RawStrategyData[]));

    strategyConfigs = new RelativeStrategyConfig[](rawStrategyConfigs.length);
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
    for (uint256 i = 0; i < descriptions.length; i++) {
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

  function toRelativeStrategy(ILlamaStrategy strategy) internal pure returns (RelativeStrategy converted) {
    assembly {
      converted := strategy
    }
  }

  function toAbsoluteStrategy(ILlamaStrategy strategy) internal pure returns (AbsoluteStrategy converted) {
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
