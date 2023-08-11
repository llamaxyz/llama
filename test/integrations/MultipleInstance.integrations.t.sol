// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/Script.sol";

import {MockProtocol} from "test/mock/MockProtocol.sol";
import {MockScript} from "test/mock/MockScript.sol";

import {DeployLlamaFactory} from "script/DeployLlamaFactory.s.sol";
import {DeployLlamaInstance} from "script/DeployLlamaInstance.s.sol";
import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {ILlamaPolicyMetadata} from "src/interfaces/ILlamaPolicyMetadata.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {ActionInfo, PermissionData, RoleHolderData} from "src/lib/Structs.sol";
import {RoleDescription} from "src/lib/UDVTs.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

contract MultipleInstanceTestSetup is DeployLlamaFactory, DeployLlamaInstance, Test {
  address LLAMA_INSTANCE_DEPLOYER = 0x3d9fEa8AeD0249990133132Bb4BC8d07C6a8259a;
  address llamaAlice;
  uint256 llamaAlicePrivateKey;
  address llamaBob;
  uint256 llamaBobPrivateKey;
  address llamaCharlie;
  uint256 llamaCharliePrivateKey;
  address llamaDale;
  uint256 llamaDalePrivateKey;
  address llamaErica;
  uint256 llamaEricaPrivateKey;

  LlamaCore llamaInstanceCore;
  LlamaPolicy llamaInstancePolicy;
  LlamaExecutor llamaInstanceExecutor;

  LlamaCore mockCore;
  LlamaPolicy mockPolicy;
  LlamaExecutor mockExecutor;

  function mineBlock() internal {
    vm.roll(block.number + 1);
    vm.warp(block.timestamp + 1);
  }

  function setUp() public virtual {
    // Setting up user addresses and private keys.
    (llamaAlice, llamaAlicePrivateKey) = makeAddrAndKey("llamaAlice");
    (llamaBob, llamaBobPrivateKey) = makeAddrAndKey("llamaBob");
    (llamaCharlie, llamaCharliePrivateKey) = makeAddrAndKey("llamaCharlie");
    (llamaDale, llamaDalePrivateKey) = makeAddrAndKey("llamaDale");
    (llamaErica, llamaEricaPrivateKey) = makeAddrAndKey("llamaErica");

    // Deploy the factory
    DeployLlamaFactory.run();

    // Deploy llama's Llama instance
    DeployLlamaInstance.run(LLAMA_INSTANCE_DEPLOYER, "internalLlamaInstance.json");
    llamaInstanceCore = core;
    llamaInstancePolicy = llamaInstanceCore.policy();
    llamaInstanceExecutor = llamaInstanceCore.executor();

    // Deploy mock protocol's Llama instance
    DeployLlamaInstance.run(LLAMA_INSTANCE_DEPLOYER, "mockProtocol.json");
    mockCore = core;
    mockPolicy = mockCore.policy();
    mockExecutor = mockCore.executor();

    mineBlock();

    );

    // 0x0845B312d2D91bD864FAb7C8B732783E81e6CAd4 - MP LlamaCore
    // 0xa359FE9c585FbD6DAAEE4efF9c3bF6bd45D498bC - instant execution strategy
    // 0x0a853184 - selector
    // Llama role 1 can setScriptAuthorization for mock protocol with instant execution and then mock protocol can
    // execute optimistically (these permissions can be set at deploy)
    // Llama role 1 can call the script for mock protocol with instant execution and then mock protocol can execute
    // optimistically (these permissions need to be updated after the script deploy)
  }
}

contract InitialTest is MultipleInstanceTestSetup {
  function test_InitiaXl() external {
    /*
      1. Llama instance adds permission to role 1:
          {
      "comment": "This gives role #1 permission to call `createAction` on the mock protocol's core with the third strategy.",
      "permissionData": {
        "selector": "0xb3c678b0",
        "strategy": "0xa359FE9c585FbD6DAAEE4efF9c3bF6bd45D498bC",
        "target": "0x0845B312d2D91bD864FAb7C8B732783E81e6CAd4"
      },
      "role": 1
    }
      2. Deploy script contract
      3. llamaAlice calls createAction on llama instance to create action instantly on mock protocol
      4. We test that the action creation, queueAction, executeAction can happen in the same block
      5. Mock protocol gives llama instance a permission to create actions for (target: upgradeScript, strategy: optimistic, target: authorizeScriptAndGivePermissionToCoreTeamToCall)
      6. Optimistically passes so the mock protocol instance authorize the LlamaV1Upgrade script and role 1 has permission to propose calling this newly created target's execute finction with the voting strategy
      7. Core team member creates action to call upgrade with voting, LlamaV1Upgrade script, execute function
    */

    bytes memory scriptCalldata = abi.encodeWithSignature("setScriptAuthorization(address,bool)", address(0), true);
    console2.log(address(llamaInstanceExecutor));
    vm.prank(address(llamaInstanceExecutor));
    mockCore.createAction(
      2, ILlamaStrategy(0x25B47aEb31b20254E2D8c1814E2648Aa1A68CCC3), address(mockCore), 0, scriptCalldata, "Hello"
  }
}
