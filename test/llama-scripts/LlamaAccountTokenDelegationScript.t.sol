// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IVotes} from "@openzeppelin/governance/utils/IVotes.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";
import {LlamaAccountTokenDelegationScript} from "src/llama-scripts/LlamaAccountTokenDelegationScript.sol";
import {ActionInfo, PermissionData} from "src/lib/Structs.sol";

contract LlamaAccountTokenDelegationScriptTest is LlamaTestSetup {
  IERC20 public constant UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
  address public constant UNI_WHALE = 0x878f0822A9e77c1dD7883E543747147Be8D63C3B;
  uint256 public constant UNI_AMOUNT = 1000e18;

  address delegationScriptAddress;

  PermissionData public delegateTokensPermission;

  function setUp() public virtual override {
    vm.createSelectFork(vm.rpcUrl("mainnet"), 18_642_270);
    LlamaTestSetup.setUp();

    deal(address(UNI), address(mpAccount1), UNI_AMOUNT);

    delegationScriptAddress = address(new LlamaAccountTokenDelegationScript());

    delegateTokensPermission = PermissionData(
      address(delegationScriptAddress),
      LlamaAccountTokenDelegationScript.delegateAccountTokenToExecutor.selector,
      mpStrategy1
    );

    vm.startPrank(address(mpExecutor));
    mpCore.setScriptAuthorization(address(delegationScriptAddress), true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), delegateTokensPermission, true);
    vm.stopPrank();
  }
}

contract DelegateToExecutor is LlamaAccountTokenDelegationScriptTest {
  function executeDelegateTokensAction() internal {
    bytes memory data = abi.encodeCall(
      LlamaAccountTokenDelegationScript.delegateAccountTokenToExecutor,
      (LlamaAccount(payable(address(mpAccount1))), address(UNI))
    );

    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, delegationScriptAddress, 0, data, "");

    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, delegationScriptAddress, 0, data
    );
    vm.warp(block.timestamp + 1);

    vm.prank(approverAdam);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");
    vm.prank(approverAlicia);
    mpCore.castApproval(uint8(Roles.Approver), actionInfo, "");

    vm.warp(block.timestamp + 6 days);

    mpCore.queueAction(actionInfo);

    vm.warp(block.timestamp + 5 days);

    mpCore.executeAction(actionInfo);
  }

  function test_TokensDelegatedToExecutor() external {
    // Assert that the account has 1,000 UNI tokens and hasn't delegated them yet
    assertEq(UNI.balanceOf(address(mpAccount1)), 1000e18);
    assertEq(IVotes(address(UNI)).delegates(address(mpAccount1)), address(0));

    executeDelegateTokensAction();

    // After the action executes the account should still have 1,000 UNI tokens but the delegate is the executor address
    assertEq(UNI.balanceOf(address(mpAccount1)), 1000e18);
    assertEq(IVotes(address(UNI)).delegates(address(mpAccount1)), address(mpExecutor));
  }
}
