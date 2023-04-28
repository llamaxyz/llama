// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IInterchainGasPaymaster} from "src/crosschain/interfaces/IInterchainGasPaymaster.sol";
import {IMailbox} from "src/crosschain/interfaces/IMailbox.sol";
import {TypeCasts} from "src/crosschain/lib/TypeCasts.sol";
import {Action} from "src/lib/Structs.sol";

contract LlamaCrosschainRelayer {
  IInterchainGasPaymaster private constant IGP = IInterchainGasPaymaster(0x56f52c0A1ddcD557285f7CBc782D3d83096CE1Cc);
  IMailbox private constant MAILBOX = IMailbox(0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70); // Same across all chains

  uint256 internal nonce;

  function relayCalls(uint32 destinationChain, address destinationRecipient, bytes calldata data)
    external
    payable
    returns (uint256)
  {
    bytes32 recipient = TypeCasts.addressToBytes32(destinationRecipient);
    bytes32 messageId = MAILBOX.dispatch(destinationChain, recipient, abi.encode(++nonce, msg.sender, data));

    IGP.payForGas{value: msg.value}(
      messageId,
      destinationChain,
      100_000, // 100k gas to use in the recipient's handle function
      address(this)
    );

    return nonce;
  }

  fallback() external payable {}

  receive() external payable {}
}
