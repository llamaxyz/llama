// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LlamaBaseScript} from "src/llama-scripts/LlamaBaseScript.sol";
import {ILlamaStrategy} from "src/interfaces/ILlamaStrategy.sol";
import {LlamaCore} from "src/LlamaCore.sol";
import {LlamaExecutor} from "src/LlamaExecutor.sol";
import {LlamaPolicy} from "src/LlamaPolicy.sol";

/// @dev Upgrade the llama instance calling this script to version 1.
contract MockInstanceUpdateVersion1 is LlamaBaseScript {
  function updateInstance() external onlyDelegateCall {
    (LlamaCore core,) = _context();
    // Authorize `LlamaAbsolutePeerReview`
    core.setStrategyLogicAuthorization(ILlamaStrategy(0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3), true);
    // Authorize `LlamaRelativeUniqueHolderQuorum`
    core.setStrategyLogicAuthorization(ILlamaStrategy(0xd21060559c9beb54fC07aFd6151aDf6cFCDDCAeB), true);
  }

  // ================================
  // ======== Internal Logic ========
  // ================================

  /// @dev Get the core and policy contracts.
  function _context() internal view returns (LlamaCore core, LlamaPolicy policy) {
    core = LlamaCore(LlamaExecutor(address(this)).LLAMA_CORE());
    policy = LlamaPolicy(core.policy());
  }
}
