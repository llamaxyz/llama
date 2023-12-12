// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IVotes} from "@openzeppelin/governance/utils/IVotes.sol";

import {DeployUtils} from "script/DeployUtils.sol";

import {ILlamaAccount} from "src/interfaces/ILlamaAccount.sol";
import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {LlamaAccountWithDelegation} from "src/accounts/LlamaAccountWithDelegation.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";
import {ActionInfo, PermissionData} from "src/lib/Structs.sol";

contract LlamaAccountWithDelegationTest is LlamaTestSetup {
  IERC20 public constant UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
  IERC20 public constant ENS = IERC20(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);
  uint256 public constant UNI_AMOUNT = 1000e18;
  uint256 public constant ENS_AMOUNT = 28_600e18;

  ILlamaAccount accountWithDelegation;

  PermissionData public delegateTokenPermission;
  PermissionData public batchDelegateTokenPermission;

  function setUp() public virtual override {
    vm.createSelectFork(vm.rpcUrl("mainnet"), 18_642_270);
    LlamaTestSetup.setUp();

    LlamaAccountWithDelegation.Config[] memory newAccount = new LlamaAccountWithDelegation.Config[](3);
    newAccount[0] = LlamaAccount.Config({name: "LlamaAccountWithDelegation"});

    deal(address(UNI), address(accountWithDelegation), UNI_AMOUNT);
    deal(address(ENS), address(accountWithDelegation), ENS_AMOUNT);

    delegateTokenPermission =
      PermissionData(address(accountWithDelegation), LlamaAccountWithDelegation.delegateToken.selector, mpStrategy1);

    batchDelegateTokenPermission = PermissionData(
      address(accountWithDelegation), LlamaAccountWithDelegation.batchDelegateToken.selector, mpStrategy1
    );

    accountWithDelegation =
      lens.computeLlamaAccountAddress(address(accountWithDelegationLogic), abi.encode(newAccount[0]), address(mpCore));

    vm.startPrank(address(mpExecutor));
    mpCore.setAccountLogicAuthorization(accountWithDelegationLogic, true);
    mpCore.createAccounts(accountWithDelegationLogic, DeployUtils.encodeAccountConfigs(newAccount));
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), delegateTokenPermission, true);
    mpPolicy.setRolePermission(uint8(Roles.ActionCreator), batchDelegateTokenPermission, true);
    vm.stopPrank();
  }
}

contract DelegateToken is LlamaAccountWithDelegationTest {
  function executeDelegateTokenAction(LlamaAccountWithDelegation.TokenDelegateData memory tokenDelegateData) internal {
    bytes memory data = abi.encodeCall(LlamaAccountWithDelegation.delegateToken, (tokenDelegateData));

    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(accountWithDelegation), 0, data, "");

    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(accountWithDelegation), 0, data
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
    assertEq(UNI.balanceOf(address(accountWithDelegation)), 1000e18);
    assertEq(IVotes(address(UNI)).delegates(address(accountWithDelegation)), address(0));

    LlamaAccountWithDelegation.TokenDelegateData memory tokenDelegateData =
      LlamaAccountWithDelegation.TokenDelegateData(IVotes(address(UNI)), address(mpExecutor));

    executeDelegateTokenAction(tokenDelegateData);

    // After the action executes the account should still have 1,000 UNI tokens but the delegate is the executor address
    assertEq(UNI.balanceOf(address(accountWithDelegation)), 1000e18);
    assertEq(IVotes(address(UNI)).delegates(address(accountWithDelegation)), address(mpExecutor));
  }

  function test_TokensDelegatedToAnyAddress(address delegatee) external {
    // Assert that the account has 1,000 UNI tokens and hasn't delegated them yet
    assertEq(UNI.balanceOf(address(accountWithDelegation)), 1000e18);
    assertEq(IVotes(address(UNI)).delegates(address(accountWithDelegation)), address(0));

    LlamaAccountWithDelegation.TokenDelegateData memory tokenDelegateData =
      LlamaAccountWithDelegation.TokenDelegateData(IVotes(address(UNI)), delegatee);

    executeDelegateTokenAction(tokenDelegateData);

    // After the action executes the account should still have 1,000 UNI tokens but the delegate is the executor address
    assertEq(UNI.balanceOf(address(accountWithDelegation)), 1000e18);
    assertEq(IVotes(address(UNI)).delegates(address(accountWithDelegation)), delegatee);
  }
}

contract BatchDelegateToken is LlamaAccountWithDelegationTest {
  function executeBatchDelegateTokenAction(LlamaAccountWithDelegation.TokenDelegateData[] memory tokenDelegateData)
    internal
  {
    bytes memory data = abi.encodeCall(LlamaAccountWithDelegation.batchDelegateToken, (tokenDelegateData));

    vm.prank(actionCreatorAaron);
    uint256 actionId =
      mpCore.createAction(uint8(Roles.ActionCreator), mpStrategy1, address(accountWithDelegation), 0, data, "");

    ActionInfo memory actionInfo = ActionInfo(
      actionId, actionCreatorAaron, uint8(Roles.ActionCreator), mpStrategy1, address(accountWithDelegation), 0, data
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

  function test_BatchDelegateTokensFromAccount(address delegatee1, address delegatee2) external {
    // Assert that the account has UNI and ENS tokens and hasn't delegated them yet
    assertEq(UNI.balanceOf(address(accountWithDelegation)), 1000e18);
    assertEq(ENS.balanceOf(address(accountWithDelegation)), 28_600e18);
    assertEq(IVotes(address(UNI)).delegates(address(accountWithDelegation)), address(0));
    assertEq(IVotes(address(ENS)).delegates(address(accountWithDelegation)), address(0));

    LlamaAccountWithDelegation.TokenDelegateData[] memory tokenDelegateData =
      new LlamaAccountWithDelegation.TokenDelegateData[](2);

    for (uint256 i = 0; i < 2; LlamaUtils.uncheckedIncrement(i)) {
      tokenDelegateData[i] = LlamaAccountWithDelegation.TokenDelegateData(
        i % 2 == 0 ? IVotes(address(UNI)) : IVotes(address(ENS)), i % 2 == 0 ? delegatee1 : delegatee2
      );
    }

    executeBatchDelegateTokenAction(tokenDelegateData);

    // After the action executes the accounts should still have all UNI and ENS tokens but the delegate is the
    // delegatee
    assertEq(UNI.balanceOf(address(accountWithDelegation)), 1000e18);
    assertEq(ENS.balanceOf(address(accountWithDelegation)), 28_600e18);
    assertEq(IVotes(address(UNI)).delegates(address(accountWithDelegation)), delegatee1);
    assertEq(IVotes(address(ENS)).delegates(address(accountWithDelegation)), delegatee2);
  }
}
