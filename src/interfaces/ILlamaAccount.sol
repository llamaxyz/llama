// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC721Receiver} from "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";

/// @title Llama Account Interface
/// @author Llama (devsdosomething@llama.xyz)
/// @notice This is the interface for Llama accounts which can be used to hold assets for a Llama instance.
interface ILlamaAccount is IERC721Receiver, IERC1155Receiver {
  // -------- For Inspection --------

  /// @notice Returns the address of the Llama instance's executor.
  function llamaExecutor() external view returns (address);

  /// @notice Returns the name of the Llama account.
  function name() external view returns (string memory);

  // -------- At Account Creation --------

  /// @notice Initializes a new clone of the account.
  /// @param name The name of the `LlamaAccount` clone.
  function initialize(string memory name) external;
}
