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
  }
}

contract InitialTest is MultipleInstanceTestSetup {
  function test_Initial() external {
    assertTrue(true);
  }
}
