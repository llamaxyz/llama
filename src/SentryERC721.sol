// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/token/ERC721/ERC721.sol";

struct Permission {
    address target;
    bytes4 signature;
    address executor;
}

contract SentryERC721 is ERC721 {
    mapping(string => Permission[]) permissions;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}
}
