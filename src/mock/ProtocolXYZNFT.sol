// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721Votes} from "@openzeppelin/token/ERC721/extensions/ERC721Votes.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {EIP712} from "@openzeppelin/utils/cryptography/EIP712.sol";

contract ProtocolXYZNFT is ERC721Votes {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) EIP712(name, "1") {} // solhint-disable-line no-empty-blocks

    function getTotalSupply() public view returns (uint256) {
        return _getTotalSupply();
    }

    function mint(address account, uint256 tokenId) public {
        _mint(account, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function getChainId() external view returns (uint256) {
        return block.chainid;
    }
}
