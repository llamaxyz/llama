// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.11;

/**
 * @title IInterchainGasPaymaster
 * @notice Manages payments on a source chain to cover gas costs of relaying
 * messages to destination chains.
 */
interface IInterchainGasPaymaster {
  function payForGas(bytes32 messageId, uint32 destinationDomain, uint256 gasAmount, address refundAddress)
    external
    payable;
}
