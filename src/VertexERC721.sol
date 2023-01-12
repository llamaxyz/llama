// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/token/ERC721/ERC721.sol";

contract VertexERC721 is ERC721 {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}
}
