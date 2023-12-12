// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IVotes} from "@openzeppelin/governance/utils/IVotes.sol";

import {LlamaAccountWithDelegation} from "src/accounts/LlamaAccountWithDelegation.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";
import {ActionInfo, PermissionData} from "src/lib/Structs.sol";

contract LlamaAccountWithDelegationTest is LlamaTestSetup {
  IERC20 public constant UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
  IERC20 public constant AAVE = IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
  uint256 public constant UNI_AMOUNT = 1000e18;
  uint256 public constant AAVE_AMOUNT = 28_600e18;

  PermissionData public delegateTokenPermission;
  PermissionData public batchDelegateTokenPermission;

  function setUp() public virtual override {
    vm.createSelectFork(vm.rpcUrl("mainnet"), 18_642_270);
    LlamaTestSetup.setUp();

    deal(address(UNI), address(mpAccount1), UNI_AMOUNT);
    deal(address(AAVE), address(mpAccount1), AAVE_AMOUNT);

    delegateTokenPermission =
      PermissionData(address(mpAccount1), LlamaAccountWithDelegation.delegateToken.selector, mpStrategy1);

    batchDelegateTokenPermission =
      PermissionData(address(mpAccount1), LlamaAccountWithDelegation.batchDelegateToken.selector, mpStrategy1);

    vm.startPrank(address(mpExecutor));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), delegateTokenPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), batchDelegateTokenPermission, true);
    vm.stopPrank();
  }
}

contract DelegateToken is LlamaAccountWithDelegationTest {
  function executeDelegateTokenAction(LlamaAccountWithDelegation.TokenDelegateData memory tokenDelegateData) internal {
    bytes memory data = abi.encodeCall(LlamaAccountWithDelegation.delegateToken, (tokenDelegateData));

    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mpAccount1), 0, data, "");

    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mpAccount1), 0, data);
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

    LlamaAccountWithDelegation.TokenDelegateData memory tokenDelegateData =
      LlamaAccountWithDelegation.TokenDelegateData(IVotes(address(UNI)), address(mpExecutor));

    executeDelegateTokenAction(tokenDelegateData);

    // After the action executes the account should still have 1,000 UNI tokens but the delegate is the executor address
    assertEq(UNI.balanceOf(address(mpAccount1)), 1000e18);
    assertEq(IVotes(address(UNI)).delegates(address(mpAccount1)), address(mpExecutor));
  }

  function test_TokensDelegatedToAnyAddress(address delegatee) external {
    // Assert that the account has 1,000 UNI tokens and hasn't delegated them yet
    assertEq(UNI.balanceOf(address(mpAccount1)), 1000e18);
    assertEq(IVotes(address(UNI)).delegates(address(mpAccount1)), address(0));

    LlamaAccountWithDelegation.TokenDelegateData memory tokenDelegateData =
      LlamaAccountWithDelegation.TokenDelegateData(IVotes(address(UNI)), delegatee);

    executeDelegateTokenAction(tokenDelegateData);

    // After the action executes the account should still have 1,000 UNI tokens but the delegate is the executor address
    assertEq(UNI.balanceOf(address(mpAccount1)), 1000e18);
    assertEq(IVotes(address(UNI)).delegates(address(mpAccount1)), delegatee);
  }
}

contract BatchDelegateToken is LlamaAccountWithDelegationTest {
  function executeBatchDelegateTokenAction(LlamaAccountWithDelegation.TokenDelegateData[] memory tokenDelegateData)
    internal
  {
    bytes memory data = abi.encodeCall(LlamaAccountWithDelegation.batchDelegateToken, (tokenDelegateData));

    vm.prank(actionCreatorAaron);
    uint256 actionId = mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(mpAccount1), 0, data, "");

    ActionInfo memory actionInfo =
      ActionInfo(actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(mpAccount1), 0, data);
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

  function test_BatchDelegateTokensFromAccount(address delegatee1, address delegatee2) external {
    // Assert that the account has UNI and AAVE tokens and hasn't delegated them yet
    assertEq(UNI.balanceOf(address(mpAccount1)), 1000e18);
    assertEq(AAVE.balanceOf(address(mpAccount1)), 28_600e18);
    assertEq(IVotes(address(UNI)).delegates(address(mpAccount1)), address(0));
    assertEq(IVotes(address(AAVE)).delegates(address(mpAccount1)), address(0));

    LlamaAccountWithDelegation.TokenDelegateData[] memory tokenDelegateData =
      new LlamaAccountWithDelegation.TokenDelegateData[](2);

    for (uint256 i = 0; i < 2; LlamaUtils.uncheckedIncrement(i)) {
      tokenDelegateData[i] = LlamaAccountWithDelegation.TokenDelegateData(
        i % 2 == 0 ? IVotes(address(UNI)) : IVotes(address(AAVE)), i % 2 == 0 ? delegatee1 : delegatee2
      );
    }

    executeBatchDelegateTokenAction(tokenDelegateData);

    // After the action executes the accounts should still have all UNI and AAVE tokens but the delegate is the
    // delegatee
    assertEq(UNI.balanceOf(address(mpAccount1)), 1000e18);
    assertEq(AAVE.balanceOf(address(mpAccount1)), 28_600e18);
    assertEq(IVotes(address(UNI)).delegates(address(mpAccount1)), delegatee1);
    assertEq(IVotes(address(AAVE)).delegates(address(mpAccount1)), delegatee2);
  }
}
