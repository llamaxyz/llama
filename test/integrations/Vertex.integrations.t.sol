// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {VertexTestSetup} from "test/utils/VertexTestSetup.sol";

contract VertexIntegrationsTest is VertexTestSetup {
  function setUp() public virtual override {
    VertexTestSetup.setUp();
  }
}

contract Setup is VertexIntegrationsTest {
  function test_setUp() public {
    assertEq(mpCore.name(), "Mock Protocol Vertex");

    assertTrue(mpCore.authorizedStrategies(mpStrategy1));
    assertTrue(mpCore.authorizedStrategies(mpStrategy1));

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount1.initialize("VertexAccount0");

    vm.expectRevert(bytes("Initializable: contract is already initialized"));
    mpAccount2.initialize("VertexAccount1");
  }
}

contract Integration is VertexIntegrationsTest {
  function test_CompleteActionFlow() public {
    // TODO
    // We can use _executeCompleteActionFlow() from VertexCore.t.sol
  }

  function testFuzz_NewVertexInstancesCanBeDeployed() public {
    // TODO
    // Test that the root/llama VertexIntegrations can deploy new client VertexIntegrations
    // instances by creating an action to call VertexFactory.deploy.
  }

  function testFuzz_ETHSendFromAccountViaActionApproval(uint256 _ethAmount) public {
    // TODO test that funds can be moved from VertexAccounts via actions
    // submitted and approved through VertexIntegrations
  }

  function testFuzz_ERC20SendFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be moved from VertexAccounts via actions
    // submitted and approved through VertexIntegrations
  }

  function testFuzz_ERC20ApprovalFromAccountViaActionApproval(uint256 _tokenAmount, IERC20 _token) public {
    // TODO test that funds can be approved + transferred from VertexAccounts via actions
    // submitted and approved through VertexIntegrations
  }
}
