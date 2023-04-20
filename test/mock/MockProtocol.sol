// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockProtocol {
  event Paused();

  error OnlyOwner();
  error Failed();

  address public immutable OWNER;
  bool public paused;

  constructor(address owner) {
    OWNER = owner;
  }

  modifier onlyOwner() {
    if (msg.sender != OWNER) revert OnlyOwner();
    _;
  }

  function receiveEth() external payable onlyOwner returns (uint256) {
    return msg.value;
  }

  function pause(bool isPaused) external onlyOwner {
    paused = isPaused;
    emit Paused();
  }

  function fail() external view onlyOwner {
    revert Failed();
  }
}
