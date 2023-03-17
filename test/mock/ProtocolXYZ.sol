// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ProtocolXYZ {
  error OnlyOwner();
  error Failed();

  address public immutable owner;
  bool public paused;

  constructor(address _owner) {
    owner = _owner;
  }

  modifier onlyOwner() {
    if (msg.sender != owner) revert OnlyOwner();
    _;
  }

  function receiveEth() external payable onlyOwner returns (uint256) {
    return msg.value;
  }

  function pause(bool isPaused) external onlyOwner {
    paused = isPaused;
  }

  function fail() external view onlyOwner {
    revert Failed();
  }
}
