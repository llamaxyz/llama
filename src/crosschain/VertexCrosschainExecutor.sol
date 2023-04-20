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
  error CallFailure(uint256 actionId, bytes errorData);
  error InvalidOriginChain();
  error InvalidSender();

  address private constant HYPERLANE_MAILBOX = 0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70; // Same across all chains
  IMailbox private constant mailbox = IMailbox(HYPERLANE_MAILBOX);
  uint256 private constant originDomain = 1; // Only accept from Polygon for extra security

  mapping(uint256 => bool) public executedNonces;

  modifier onlyTrustedInbox(uint32 originChain) {
    if (originChain != originDomain) revert InvalidOriginChain();
    if (msg.sender != address(mailbox)) revert InvalidSender();
    _;
  }

  function handle(uint32 originChain, bytes32 caller, bytes calldata message) external onlyTrustedInbox(originChain) {
    address payable addr = payable(TypeCasts.bytes32ToAddress(caller));
    VertexCrosschainRelayer relayer = VertexCrosschainRelayer(addr);

    (uint256 nonce, address actionSender, uint256 actionId, Action memory action) =
      abi.decode(message, (uint256, address, uint256, Action));

    _executeCalls(relayer, nonce, actionSender, actionId, action);
  }

  function _executeCalls(
    VertexCrosschainRelayer relayer,
    uint256 nonce,
    address sender,
    uint256 actionId,
    Action memory action
  ) internal {
    if (executedNonces[nonce]) revert CallsAlreadyExecuted(nonce);

    executedNonces[nonce] = true;

    (bool success, bytes memory returnData) = action.target.call(abi.encodePacked(action.selector, action.data));

    if (!success) revert CallFailure(actionId, returnData);

    emit ExecutedCalls(relayer, nonce);
  }
}
