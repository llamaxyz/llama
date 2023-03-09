// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721MinimalProxy} from "../../src/lib/ERC721MinimalProxy.sol";

contract MockERC721 is ERC721MinimalProxy {
  function initialize(string memory _name, string memory _symbol) external initializer {
    __initializeERC721MinimalProxy(_name, _symbol);
  }

  function tokenURI(uint256) public pure virtual override returns (string memory) {}

  function mint(address to, uint256 tokenId) public virtual {
    _mint(to, tokenId);
  }

  function burn(uint256 tokenId) public virtual {
    _burn(tokenId);
  }

  function safeMint(address to, uint256 tokenId) public virtual {
    _safeMint(to, tokenId);
  }

  function safeMint(address to, uint256 tokenId, bytes memory data) public virtual {
    _safeMint(to, tokenId, data);
  }
}
