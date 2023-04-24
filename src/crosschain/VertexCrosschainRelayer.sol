// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";

import {IInterchainGasPaymaster} from "./interfaces/IInterchainGasPaymaster.sol";
import {IMailbox} from "./interfaces/IMailbox.sol";
import {TypeCasts} from "./lib/TypeCasts.sol";
import {Action} from "src/lib/Structs.sol";

contract VertexCrosschainRelayer {
  address private constant HYPERLANE_MAILBOX = 0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70; // Same across all chains
  IMailbox private constant mailbox = IMailbox(HYPERLANE_MAILBOX);
  IInterchainGasPaymaster private constant igp = IInterchainGasPaymaster(0x56f52c0A1ddcD557285f7CBc782D3d83096CE1Cc);

  uint256 internal nonce;

  function relayCalls(bytes calldata data) external payable returns (uint256) {
    console2.logBytes(data);
    (uint32 destinationChain, address destinationRecipient, bytes memory executionData) =
      abi.decode(data, (uint32, address, bytes));
    bytes32 recipient = TypeCasts.addressToBytes32(destinationRecipient);
    bytes32 messageId = mailbox.dispatch(destinationChain, recipient, abi.encode(++nonce, msg.sender, executionData));

    igp.payForGas{value: msg.value}(
      messageId,
      destinationChain,
      100_000, // 100k gas to use in the recipient's handle function
      address(this)
    );

    return nonce;
  }

  fallback() external payable {
    console2.log("here");
  }

  receive() external payable {}
}
