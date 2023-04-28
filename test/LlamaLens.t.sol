// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {LlamaAccount} from "src/LlamaAccount.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {PermissionData} from "src/lib/Structs.sol";

contract LlamaLensTestSetup is LlamaTestSetup {}

contract ComputeLlamaCoreAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected = address(lens.computeLlamaCoreAddress("Root Llama", address(coreLogic), address(factory)));
    assertEq(expected, address(rootCore));

    expected = address(lens.computeLlamaCoreAddress("Mock Protocol Llama", address(coreLogic), address(factory)));
    assertEq(expected, address(mpCore));
  }
}

contract ComputeLlamaPolicyAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected = address(lens.computeLlamaPolicyAddress("Root Llama", address(policyLogic), address(factory)));
    assertEq(expected, address(rootPolicy));

    expected = address(lens.computeLlamaPolicyAddress("Mock Protocol Llama", address(policyLogic), address(factory)));
    assertEq(expected, address(mpPolicy));
  }
}

contract ComputeLlamaStrategyAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    address expected =
      address(lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(rootCore)));
    assertEq(expected, address(rootStrategy1));

    expected =
      address(lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[2], address(rootCore)));
    assertEq(expected, address(rootStrategy2));

    expected =
      address(lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[1], address(mpCore)));
    assertEq(expected, address(mpStrategy1));

    expected =
      address(lens.computeLlamaStrategyAddress(address(relativeStrategyLogic), strategyConfigs[2], address(mpCore)));
    assertEq(expected, address(mpStrategy2));
  }
}

contract ComputeLlamaAccountAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected =
      address(lens.computeLlamaAccountAddress(address(accountLogic), "Llama Treasury", address(rootCore)));
    assertEq(expected, address(rootAccount1));

    expected = address(lens.computeLlamaAccountAddress(address(accountLogic), "Llama Grants", address(rootCore)));
    assertEq(expected, address(rootAccount2));

    expected = address(lens.computeLlamaAccountAddress(address(accountLogic), "MP Treasury", address(mpCore)));
    assertEq(expected, address(mpAccount1));

    expected = address(lens.computeLlamaAccountAddress(address(accountLogic), "MP Grants", address(mpCore)));
    assertEq(expected, address(mpAccount2));
  }
}

contract ComputePermissionId is LlamaLensTestSetup {
  function test_ProperlyComputesId() public {
    PermissionData memory _pausePermission =
      PermissionData(address(mpPolicy), mpPolicy.setRolePermission.selector, mpStrategy1);
    bytes32 computedPausePermissionId = lens.computePermissionId(_pausePermission);
    assertEq(
      keccak256(abi.encode(address(mpPolicy), mpPolicy.setRolePermission.selector, mpStrategy1)),
      computedPausePermissionId
    );
  }
}
