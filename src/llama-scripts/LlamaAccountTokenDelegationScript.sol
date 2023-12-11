// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaBaseScript} from "src/llama-scripts/LlamaBaseScript.sol";
import {LlamaAccount} from "src/accounts/LlamaAccount.sol";

/// @title Llama Account Token Delegation Script
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A script that leverages the `LlamaAccount` arbitrary execute function to allow users to delegate governance
/// tokens from their Llama accounts.
contract LlamaAccountTokenDelegationScript is LlamaBaseScript {
  /// @notice Token contract must be called not delegatecalled.
  bool internal constant WITH_DELEGATECALL = false;

  /// @notice `msg.value` is 0.
  uint256 internal constant VALUE = 0;

  /// @notice The function selector of the `IVotes` `delegate(address)` function.
  bytes4 internal constant DELEGATE_SELECTOR = 0x5c19a95c;

  function delegateTokenFromAccount(LlamaAccount account, address token, address delegatee) external onlyDelegateCall {
    account.execute(token, WITH_DELEGATECALL, VALUE, abi.encodeWithSelector(DELEGATE_SELECTOR, delegatee));
  }

  function delegateTokensFromAccount(LlamaAccount account, address[] tokens, address delegatee)
    external
    onlyDelegateCall
  {
    account.execute(token, WITH_DELEGATECALL, VALUE, abi.encodeWithSelector(DELEGATE_SELECTOR, delegatee));
  }
}
