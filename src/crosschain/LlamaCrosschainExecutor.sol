// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {console2} from "forge-std/Test.sol";
import {IMessageRecipient} from "./interfaces/IMessageRecipient.sol";
import {TypeCasts} from "./lib/TypeCasts.sol";
import {LlamaCrosschainRelayer} from "./LlamaCrosschainRelayer.sol";
import {Action} from "src/lib/Structs.sol";

contract LlamaCrosschainExecutor is IMessageRecipient {
  event ExecutedCalls(LlamaCrosschainRelayer indexed relayer, uint256 indexed nonce);

  error CallsAlreadyExecuted(uint256 nonce);
  error CallFailure(bytes errorData);
  error InvalidOriginChain();
  error InvalidSender();

  address private constant MAILBOX = 0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70; // Same for all supported chains
  uint256 private immutable ORIGIN_DOMAIN;

  mapping(uint256 => bool) public executedNonces;

  constructor() {
    ORIGIN_DOMAIN = block.chainid;
  }

  modifier onlyTrustedInbox(uint32 originChain) {
    if (originChain != ORIGIN_DOMAIN) revert InvalidOriginChain();
    if (msg.sender != MAILBOX) revert InvalidSender();
    _;
  }

  function handle(uint32 originChain, bytes32 caller, bytes calldata message) external onlyTrustedInbox(originChain) {
    address payable addr = payable(TypeCasts.bytes32ToAddress(caller));
    LlamaCrosschainRelayer relayer = LlamaCrosschainRelayer(addr);

    (uint256 nonce, address actionSender, bytes memory data) = abi.decode(message, (uint256, address, bytes));

    _executeCalls(relayer, nonce, actionSender, data);
  }

  function _executeCalls(LlamaCrosschainRelayer relayer, uint256 nonce, address sender, bytes memory data) internal {
    if (executedNonces[nonce]) revert CallsAlreadyExecuted(nonce);

    executedNonces[nonce] = true;

    (address target, bytes memory targetData) = abi.decode(data, (address, bytes));

    (bool success, bytes memory returnData) = target.call(targetData);

    if (!success) revert CallFailure(returnData);

    emit ExecutedCalls(relayer, nonce);
  }
}
