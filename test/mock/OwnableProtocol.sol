// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable2Step} from "@openzeppelin/access/Ownable2Step.sol";
import {ProtocolXYZ} from "test/mock/ProtocolXYZ.sol";

contract OwnableProtocol is Ownable2Step, ProtocolXYZ {
  constructor(address _vertex) ProtocolXYZ(_vertex) {}
}
