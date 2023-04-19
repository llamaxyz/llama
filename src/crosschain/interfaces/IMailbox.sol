// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

interface IMailbox {
  function dispatch(uint32 destinationDomain, bytes32 recipientAddress, bytes calldata messageBody)
    external
    returns (bytes32);

  function process(bytes calldata metadata, bytes calldata message) external;
}
