// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {console2} from "forge-std/Test.sol";

contract MockTarget {
  function receiveMessage(bytes calldata message) external view {
    console2.log(string(message));
  }
}
