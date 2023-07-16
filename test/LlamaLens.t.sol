// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";
import {PermissionData} from "src/lib/Structs.sol";

contract LlamaLensTestSetup is LlamaTestSetup {}

contract ComputeLlamaCoreAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected = address(lens.computeLlamaCoreAddress("Root Llama", LLAMA_INSTANCE_DEPLOYER));
    assertEq(expected, address(rootCore));

    expected = address(lens.computeLlamaCoreAddress("Mock Protocol Llama", LLAMA_INSTANCE_DEPLOYER));
    assertEq(expected, address(mpCore));
  }
}

contract ComputeLlamaPolicyAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected = address(lens.computeLlamaPolicyAddress("Root Llama", LLAMA_INSTANCE_DEPLOYER));
    assertEq(expected, address(rootPolicy));

    expected = address(lens.computeLlamaPolicyAddress("Mock Protocol Llama", LLAMA_INSTANCE_DEPLOYER));
    assertEq(expected, address(mpPolicy));
  }
}

contract ComputeLlamaPolicyMetadataAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected = address(lens.computeLlamaPolicyMetadataAddress("Root Llama", LLAMA_INSTANCE_DEPLOYER, 1));
    assertEq(expected, address(rootPolicyMetadata));

    LlamaPolicy _rootPolicy = lens.computeLlamaPolicyAddress("Root Llama", LLAMA_INSTANCE_DEPLOYER);
    expected = address(lens.computeLlamaPolicyMetadataAddress(_rootPolicy, 1));
    assertEq(expected, address(rootPolicyMetadata));

    expected = address(lens.computeLlamaPolicyMetadataAddress("Mock Protocol Llama", LLAMA_INSTANCE_DEPLOYER, 1));
    assertEq(expected, address(mpPolicyMetadata));

    LlamaPolicy _mpPolicy = lens.computeLlamaPolicyAddress("Mock Protocol Llama", LLAMA_INSTANCE_DEPLOYER);
    expected = address(lens.computeLlamaPolicyMetadataAddress(_mpPolicy, 1));
    assertEq(expected, address(mpPolicyMetadata));
  }
}

contract ComputeLlamaStrategyAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    bytes[] memory strategyConfigs = strategyConfigsRootLlama();
    address expected =
      address(lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), strategyConfigs[1], address(rootCore)));
    assertEq(expected, address(rootStrategy1));

    expected =
      address(lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), strategyConfigs[2], address(rootCore)));
    assertEq(expected, address(rootStrategy2));

    expected =
      address(lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), strategyConfigs[1], address(mpCore)));
    assertEq(expected, address(mpStrategy1));

    expected =
      address(lens.computeLlamaStrategyAddress(address(relativeQuorumLogic), strategyConfigs[2], address(mpCore)));
    assertEq(expected, address(mpStrategy2));
  }
}

contract ComputeLlamaAccountAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    bytes[] memory rootAccounts = accountConfigsRootLlama();
    bytes[] memory mpAccounts = accountConfigsLlamaInstance();
    address expected =
      address(lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[0], address(rootCore)));
    assertEq(expected, address(rootAccount1));

    expected = address(lens.computeLlamaAccountAddress(address(accountLogic), rootAccounts[1], address(rootCore)));
    assertEq(expected, address(rootAccount2));

    expected = address(lens.computeLlamaAccountAddress(address(accountLogic), mpAccounts[0], address(mpCore)));
    assertEq(expected, address(mpAccount1));

    expected = address(lens.computeLlamaAccountAddress(address(accountLogic), mpAccounts[1], address(mpCore)));
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

contract ComputeLlamaExecutorAddress is LlamaLensTestSetup {
  function test_ProperlyComputesAddress() public {
    address expected = address(lens.computeLlamaExecutorAddress(address(rootCore)));
    assertEq(expected, address(rootExecutor));

    expected = address(lens.computeLlamaExecutorAddress("Root Llama", LLAMA_INSTANCE_DEPLOYER));
    assertEq(expected, address(rootExecutor));

    expected = address(lens.computeLlamaExecutorAddress(address(mpCore)));
    assertEq(expected, address(mpExecutor));

    expected = address(lens.computeLlamaExecutorAddress("Mock Protocol Llama", LLAMA_INSTANCE_DEPLOYER));
    assertEq(expected, address(mpExecutor));
  }
}
