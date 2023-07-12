// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";

contract LlamaIntegrationsTest is LlamaTestSetup {
  function setUp() public virtual override {
    LlamaTestSetup.setUp();
  }
}

contract Setup is LlamaIntegrationsTest {
  function test_setUp() public {
    assertEq(mpCore.name(), "Mock Protocol Llama");

    assertTrue(mpCore.strategies(mpStrategy1).authorized);
    assertTrue(mpCore.strategies(mpStrategy2).authorized);
    assertTrue(mpCore.strategies(mpStrategy1).deployed);
    assertTrue(mpCore.strategies(mpStrategy2).deployed);

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount1.initialize("LlamaAccount0");

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount2.initialize("LlamaAccount1");
  }
}

contract Integration is LlamaIntegrationsTest {
  function test_CompleteActionFlow() public {
    // TODO
    // We can use _executeCompleteActionFlow() from LlamaCore.t.sol
  }

  function testFuzz_NewLlamaInstancesCanBeDeployed() public {
    // TODO
    // Test that the root/llama LlamaIntegrations can deploy new client LlamaIntegrations
    // instances by creating an action to call LlamaFactory.deploy.
  }

  function testFuzz_ETHSendFromAccountViaActionApproval(uint256 _ethAmount) public {
    // TODO test that funds can be moved from LlamaAccounts via actions
    // submitted and approved through LlamaIntegrations
  }

  function testFuzz_ERC20SendFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be moved from LlamaAccounts via actions
    // submitted and approved through LlamaIntegrations
  }

  function testFuzz_ERC20ApprovalFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be approved + transferred from LlamaAccounts via actions
    // submitted and approved through LlamaIntegrations
  }
}
