// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IVotes} from "@openzeppelin/governance/utils/IVotes.sol";

import {LlamaAccount} from "src/accounts/LlamaAccount.sol";
import {LlamaUtils} from "src/lib/LlamaUtils.sol";
import {LlamaBaseScript} from "src/llama-scripts/LlamaBaseScript.sol";

/// @title Llama Account Token Delegation Script
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A script that leverages the Llama account arbitrary execute function to allow users to delegate governance
/// tokens from their Llama accounts.
contract LlamaAccountTokenDelegationScript is LlamaBaseScript {
  // ==========================
  // ========= Structs ========
  // ==========================

  /// @dev Data for delegating voting tokens from an account to a delegatee.
  struct AccountTokenDelegateData {
    LlamaAccount account; // The account being delegated from.
    IVotes token; // The voting token to delegate.
    address delegatee; // The address being delegated to.
  }

  // =============================
  // ========= Constants =========
  // =============================

  /// @notice Token contract must be called not delegatecalled.
  bool internal constant WITH_DELEGATECALL = false;

  /// @notice `msg.value` is 0.
  uint256 internal constant VALUE = 0;

  /// @notice The function selector of the `IVotes` `delegate(address)` function.
  bytes4 internal constant DELEGATE_SELECTOR = 0x5c19a95c;

  // ========================================
  // ======= Delegate token functions =======
  // ========================================

  /// @notice Delegate voting tokens from an account to a delegatee.
  /// @param account The Llama account that holds the voting tokens.
  /// @param token The address of the token contract.
  /// @param delegatee The address of the delegatee.
  function delegateTokenFromAccount(LlamaAccount account, IVotes token, address delegatee) public onlyDelegateCall {
    account.execute(address(token), WITH_DELEGATECALL, VALUE, abi.encodeWithSelector(DELEGATE_SELECTOR, delegatee));
  }

  /// @notice Delegate multiple voting tokens from an account to a delegatee.
  /// @param accountTokenDelegateData The Llama account that holds the voting tokens, the token address, and the
  /// delegatee address.
  function delegateTokensFromAccount(AccountTokenDelegateData[] calldata accountTokenDelegateData)
    external
    onlyDelegateCall
  {
    uint256 length = accountTokenDelegateData.length;
    for (uint256 i = 0; i < length; i = LlamaUtils.uncheckedIncrement(i)) {
      delegateTokenFromAccount(
        accountTokenDelegateData[i].account, accountTokenDelegateData[i].token, accountTokenDelegateData[i].delegatee
      );
    }
  }
}
