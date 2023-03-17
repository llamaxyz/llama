// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {VertexFactoryTest} from "./VertexFactory.t.sol";
import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {Strategy, PolicyGrantData} from "src/lib/Structs.sol";
import {VertexTestSetup} from "test/utils/VertexTestSetup.sol";

contract ComputeAddress is VertexTestSetup {
  // TODO Tests for Vertex Lens.

  event StrategyAuthorized(VertexStrategy indexed strategy, Strategy strategyData);

  function test_ComputesExpectedAddressForVertexCore() public {
    VertexCore computedVertexCore = lens.computeVertexCoreAddress("NewProject", address(coreLogic), address(factory));
    VertexCore deployedVertexCore = deployVertex();
    assertEq(address(computedVertexCore), address(deployedVertexCore));
  }

  function test_ComputesExpectedAddressForPolicy() public {
    VertexPolicy computedVertexPolicy =
      lens.computeVertexPolicyAddress("NewProject", address(policyLogic), address(factory));
    VertexCore deployedVertexCore = deployVertex();
    VertexPolicy deployedVertexPolicy = VertexPolicy(VertexCore(deployedVertexCore).policy());
    assertEq(address(computedVertexPolicy), address(deployedVertexPolicy));
  }

  function test_ComputeVertexStrategyAddress() public {
    // Strategy memory _strategy, VertexPolicy _policy, VertexCore _vertex
    (Strategy[] memory strategies,,) = getDefaultVertexDeployParameters();
    VertexCore computedVertexCore = lens.computeVertexCoreAddress("NewProject", address(coreLogic), address(factory));

    VertexStrategy computedVertexStrategy =
      lens.computeVertexStrategyAddress(address(strategyLogic), strategies[0], address(computedVertexCore));

    vm.expectEmit(true, true, true, true);
    emit StrategyAuthorized(computedVertexStrategy, strategies[0]);
    deployVertex();
  }

  function deployVertex() public returns (VertexCore) {
    (Strategy[] memory strategies, string[] memory accounts, PolicyGrantData[] memory policies) =
      getDefaultVertexDeployParameters();
    vm.prank(address(core));
    return factory.deploy("NewProject", address(strategyLogic), address(accountLogic), strategies, accounts, policies);
  }
}
