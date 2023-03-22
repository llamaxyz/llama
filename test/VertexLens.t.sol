// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {VertexCore} from "src/VertexCore.sol";
import {VertexStrategy} from "src/VertexStrategy.sol";
import {VertexPolicy} from "src/VertexPolicy.sol";
import {VertexAccount} from "src/VertexAccount.sol";
import {Strategy, PermissionData} from "src/lib/Structs.sol";
import {VertexTestSetup} from "test/utils/VertexTestSetup.sol";

contract VertexLensTestSetup is VertexTestSetup {}

contract ComputeVertexCoreAddress is VertexLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected = address(lens.computeVertexCoreAddress("Root Vertex", address(coreLogic), address(factory)));
    assertEq(expected, address(rootCore));

    expected = address(lens.computeVertexCoreAddress("Mock Protocol Vertex", address(coreLogic), address(factory)));
    assertEq(expected, address(mpCore));
  }
}

contract ComputeVertexPolicyAddress is VertexLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected = address(lens.computeVertexPolicyAddress("Root Vertex", address(policyLogic), address(factory)));
    assertEq(expected, address(rootPolicy));

    expected = address(lens.computeVertexPolicyAddress("Mock Protocol Vertex", address(policyLogic), address(factory)));
    assertEq(expected, address(mpPolicy));
  }
}

contract ComputeVertexStrategyAddress is VertexLensTestSetup {
  function test_ProperlyComputesAddress() public {
    Strategy[] memory strategies = defaultStrategies();
    address expected =
      address(lens.computeVertexStrategyAddress(address(strategyLogic), strategies[0], address(rootCore)));
    assertEq(expected, address(rootStrategy1));

    expected = address(lens.computeVertexStrategyAddress(address(strategyLogic), strategies[1], address(rootCore)));
    assertEq(expected, address(rootStrategy2));

    expected = address(lens.computeVertexStrategyAddress(address(strategyLogic), strategies[0], address(mpCore)));
    assertEq(expected, address(mpStrategy1));

    expected = address(lens.computeVertexStrategyAddress(address(strategyLogic), strategies[1], address(mpCore)));
    assertEq(expected, address(mpStrategy2));
  }
}

contract ComputeVertexAccountAddress is VertexLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected =
      address(lens.computeVertexAccountAddress(address(accountLogic), "Llama Treasury", address(rootCore)));
    assertEq(expected, address(rootAccount1));

    expected = address(lens.computeVertexAccountAddress(address(accountLogic), "Llama Grants", address(rootCore)));
    assertEq(expected, address(rootAccount2));

    expected = address(lens.computeVertexAccountAddress(address(accountLogic), "MP Treasury", address(mpCore)));
    assertEq(expected, address(mpAccount1));

    expected = address(lens.computeVertexAccountAddress(address(accountLogic), "MP Grants", address(mpCore)));
    assertEq(expected, address(mpAccount2));
  }
}

contract ComputePermissionId is VertexLensTestSetup {
  function test_ProperlyComputesId() public {
    PermissionData memory _pausePermission =
      PermissionData(address(mpPolicy), mpPolicy.setRoleHoldersAndPermissions.selector, mpStrategy1);
    bytes32 computedPausePermissionId = lens.computePermissionId(_pausePermission);
    assertEq(
      keccak256(abi.encode(address(mpPolicy), mpPolicy.setRoleHoldersAndPermissions.selector, mpStrategy1)),
      computedPausePermissionId
    );
  }
}
