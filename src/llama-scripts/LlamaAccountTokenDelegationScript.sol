// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaBaseScript} from "src/llama-scripts/LlamaBaseScript.sol";
import {LlamaAccount} from "src/accounts/LlamaAccount.sol";

/// @title Llama Account Token Delegation Script
/// @author Llama (devsdosomething@llama.xyz)
/// @notice A script that allows users to delegate governance tokens in their Llama accounts.
contract LlamaAccountTokenDelegationScript is LlamaBaseScript {
  function delegateAccountTokenToExecutor(LlamaAccount account, address token) external onlyDelegateCall {
    // TODO: add checks for isERC20Votes or isERC721Votes token and isLlamaAccount
    account.execute(token, false, 0, abi.encodeWithSelector(0x5c19a95c, address(this)));
  }
}
