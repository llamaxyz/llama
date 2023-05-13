// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract LlamaExecutor {
  // ======================================
  // ============= Errors =================
  // ======================================
  error OnlyLlamaCore();

  /// @notice The core contract for this llama instance.
  address public immutable LLAMA_CORE;

  constructor() {
    LLAMA_CORE = msg.sender;
  }

  function execute(address target, uint256 value, bool isScript, bytes calldata data)
    external
    returns (bool success, bytes memory result)
  {
    if (msg.sender != LLAMA_CORE) revert OnlyLlamaCore();
    (success, result) = isScript ? target.delegatecall(data) : target.call{value: value}(data);
  }
}
