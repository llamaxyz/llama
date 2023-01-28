// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable2Step} from "@openzeppelin/access/Ownable2Step.sol";
import {ProtocolXYZ} from "src/mock/OwnableProtocol.sol";

contract OwnableProtocol is Ownable2Step, ProtocolXYZ {
    constructor(address _vertex) ProtocolXYZ(_vertex) {}
}
