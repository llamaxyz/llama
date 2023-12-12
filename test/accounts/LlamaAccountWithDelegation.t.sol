// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IVotes} from "@openzeppelin/governance/utils/IVotes.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {LlamaAccountWithDelegation} from "src/accounts/LlamaAccountWithDelegation.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {Roles, LlamaTestSetup} from "test/utils/LlamaTestSetup.sol";
import {LlamaAccountTokenDelegationScript} from "src/llama-scripts/LlamaAccountTokenDelegationScript.sol";
import {ActionInfo, PermissionData} from "src/lib/Structs.sol";

contract LlamaAccountWithDelegationTest is LlamaTestSetup {
  IERC20 public constant UNI = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
  uint256 public constant UNI_AMOUNT = 1000e18;

  PermissionData public delegateTokenPermission;
  PermissionData public batchDelegateTokenPermission;

  function setUp() public virtual override {
    vm.createSelectFork(vm.rpcUrl("mainnet"), 18_642_270);
    LlamaTestSetup.setUp();

    deal(address(UNI), address(mpAccount1), UNI_AMOUNT);

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

contract DelegateToken is LlamaAccountWithDelegationTest {}

contract BatchDelegateToken is LlamaAccountWithDelegationTest {}
