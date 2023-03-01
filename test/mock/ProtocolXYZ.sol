// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ProtocolXYZ {
  error OnlyVertex();
  error Failed();

  address public immutable vertex;
  bool public paused;

  constructor(address _vertex) {
    vertex = _vertex;
  }

  modifier onlyVertex() {
    if (msg.sender != address(vertex)) revert OnlyVertex();
    _;
  }

  function receiveEth() external payable onlyVertex returns (uint256) {
    return msg.value;
  }

  function pause(bool isPaused) external onlyVertex {
    paused = isPaused;
  }

  function fail() external view onlyVertex {
    revert Failed();
  }
}
