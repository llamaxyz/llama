// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {console2} from "forge-std/Test.sol";
import {IMailbox} from "./interfaces/IMailbox.sol";
import {IMessageRecipient} from "./interfaces/IMessageRecipient.sol";
import {TypeCasts} from "./lib/TypeCasts.sol";
import {VertexCrosschainRelayer} from "./VertexCrosschainRelayer.sol";
import {Action} from "src/lib/Structs.sol";

contract VertexCrosschainExecutor is IMessageRecipient {
  event ExecutedCalls(VertexCrosschainRelayer indexed relayer, uint256 indexed nonce);

  error CallsAlreadyExecuted(uint256 nonce);
  error CallFailure(bytes errorData);
  error InvalidOriginChain();
  error InvalidSender();

  address private constant HYPERLANE_MAILBOX = 0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70; // Same across all chains
  IMailbox private constant mailbox = IMailbox(HYPERLANE_MAILBOX);
  uint256 private constant originDomain = 1; // Only accept from Mainnet for extra security

  mapping(uint256 => bool) public executedNonces;

  modifier onlyTrustedInbox(uint32 originChain) {
    if (originChain != originDomain) revert InvalidOriginChain();
    if (msg.sender != address(mailbox)) revert InvalidSender();
    _;
  }

  function handle(uint32 originChain, bytes32 caller, bytes calldata message) external onlyTrustedInbox(originChain) {
    address payable addr = payable(TypeCasts.bytes32ToAddress(caller));
    VertexCrosschainRelayer relayer = VertexCrosschainRelayer(addr);

    (uint256 nonce, address actionSender, bytes memory data) = abi.decode(message, (uint256, address, bytes));

    _executeCalls(relayer, nonce, actionSender, data);
  }

  function _executeCalls(VertexCrosschainRelayer relayer, uint256 nonce, address sender, bytes memory data) internal {
    if (executedNonces[nonce]) revert CallsAlreadyExecuted(nonce);

    executedNonces[nonce] = true;

    (address target, bytes4 selector, bytes memory targetData) = abi.decode(data, (address, bytes4, bytes));

    (bool success, bytes memory returnData) = target.call(abi.encodePacked(selector, targetData));

    if (!success) revert CallFailure(returnData);

    emit ExecutedCalls(relayer, nonce);
  }
}
