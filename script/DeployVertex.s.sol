// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, stdJson, console2} from "forge-std/Script.sol";

import {VertexAccount} from "src/VertexAccount.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexFactory} from "src/VertexFactory.sol";
import {VertexLens} from "src/VertexLens.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexPolicyTokenURI} from "src/VertexPolicyTokenURI.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {Strategy, RolePermissionData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {DeployUtils} from "script/DeployUtils.sol";

contract DeployVertex is Script {
  using stdJson for string;

  // Logic contracts.
  VertexCore coreLogic;
  VertexStrategy strategyLogic;
  VertexAccount accountLogic;
  VertexPolicy policyLogic;

  // Core Protocol.
  VertexFactory factory;
  VertexPolicyTokenURI policyTokenUri;
  VertexLens lens;

  function run() public {
    console2.log("Deploying Vertex infrastructure to chain:", block.chainid);

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
    policyTokenUri = new VertexPolicyTokenURI();
    console2.log("  VertexPolicyTokenURI:", address(policyTokenUri));

    string memory jsonInput = DeployUtils.readScriptInput("deployVertex.json");

    vm.broadcast();
    factory = new VertexFactory(
      coreLogic,
      strategyLogic,
      accountLogic,
      policyLogic,
      policyTokenUri,
      jsonInput.readString(".rootVertexName"),
      DeployUtils.readStrategies(jsonInput),
      jsonInput.readStringArray(".initialAccountNames"),
      DeployUtils.readRoleDescriptions(jsonInput),
      DeployUtils.readRoleHolders(jsonInput),
      DeployUtils.readRolePermissions(jsonInput)
    );
    console2.log("  VertexFactory:", address(factory));

    vm.broadcast();
    lens = new VertexLens();
    console2.log("  VertexLens:", address(lens));
  }
}
