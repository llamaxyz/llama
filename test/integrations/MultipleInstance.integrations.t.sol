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
    DeployLlamaInstance.run(LLAMA_INSTANCE_DEPLOYER, "llamaInstanceConfig.json");
    llamaInstanceCore = core;
    llamaInstancePolicy = llamaInstanceCore.policy();
    llamaInstanceExecutor = llamaInstanceCore.executor();

    // Deploy mock protocol's Llama instance
    DeployLlamaInstance.run(LLAMA_INSTANCE_DEPLOYER, "mockProtocolInstanceConfig.json");
    mockCore = core;
    mockPolicy = mockCore.policy();
    mockExecutor = mockCore.executor();

    mineBlock();
  }
}

contract InitialTest is MultipleInstanceTestSetup {
  function test_InitiaXl() external {
    // SCRIPT OPTIMIZATION

    /*
    1. Deploy llama and mock protocol instances
    2. Mock instance needs to have some authorized GovernanceScript and reserve a role for llama with permission to
    create actions for the functions on this
    script with an optimistic and high approval strategy. The permissioning happens in the config but the script must be
    authorized through an action.
    3. The script will have a function that allows a call to setScriptAuthorization and to setRolePermission to the
    governance maintenance role with one
   of the two strategies, the script being authorized, any target.
    4. Llama will deploy an upgrade contract and use a multisig like strategy to propose calling the governance script
    with this as a parameter.
    5. Now mock instance governance decides if they want to authorize this upgrade script, give llama the role
    permission to propose calling it. The upgrade script
   has the logic to unauthorize itself and remove all permissions after being called.
    6. The action executes.
    7. Llama proposes calling the script. The governance script forced llama to only have permission to make this
    proposal with high buy in
    8. Mock instance executes the action, the script is called, the script is unauthed and all permissions are removed.    */

    // BASE CASE

    /*
      1. Deploy llama and mock protocol instances ✅
    2. Mock protocol instance config has a role reserved for llama with proposal permissions for setScriptAuthorization.
    Proposal permission for calling the script
    needs to be set after it's deployed. The execute function of the script will also remove the permission from the
    role and unauth the script. The role
    includes two permissions: one to setScriptAuthorization with a long optimistic timelock and the other with high buy
    in shorter timelock. Mock also gives
    llama permission to propose calling setRolePermission so they can propose to give themselves the proposal perission
    to call the script.
    3. Llama adds a permission to call createAction on the mock instance shortly after instance launches. This action
    still needs to go through their governance
         and can be canceled so a simple multisig like permission will suffice.  
      4. Llama deploys a script
    5. The test starts with llama using either strategy to create, queue, execute calling setScriptAuth through mock's
    createAction.
      6. This goes through mock's governance with minimal input from them.
    7. Once the script is authorized, llama then goes through their action process to call mock's createAction to give
    themselves permission to call the script.
    8. Once that's complete llama goes through their action process to call mock's createAction to execute the script
    9. This requires high buy-in and when it executes it removes the permission to call it from the llama role and
    unauthorizes the script
    */

    // ARCHIVE
    /*
      1. Llama instance adds permission to role 1:
          {
    "comment": "This gives role #1 permission to call `createAction` on the mock protocol's core with the third
    strategy.",
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
    5. Mock protocol gives llama instance a permission to create actions for (target: upgradeScript, strategy:
    optimistic, target: authorizeScriptAndGivePermissionToCoreTeamToCall)
    6. Optimistically passes so the mock protocol instance authorize the LlamaV1Upgrade script and role 1 has permission
    to propose calling this newly created target's execute finction with the voting strategy
      7. Core team member creates action to call upgrade with voting, LlamaV1Upgrade script, execute function
    */

    bytes memory scriptCalldata = abi.encodeWithSignature("setScriptAuthorization(address,bool)", address(0), true);
    console2.log(address(llamaInstanceExecutor));
    vm.prank(address(llamaInstanceExecutor));
    mockCore.createAction(
      2, ILlamaStrategy(0x25B47aEb31b20254E2D8c1814E2648Aa1A68CCC3), address(mockCore), 0, scriptCalldata, "Hello"
    );
  }
}
