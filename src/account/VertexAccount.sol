// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexAccount} from "src/account/IVertexAccount.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import {Address} from "@openzeppelin/utils/Address.sol";

/// @title Vertex Account
/// @author Llama (vertex@llama.xyz)
/// @notice The contract that holds the Vertex system's assets.
contract VertexAccount is IVertexAccount, ERC721Holder {
    using SafeERC20 for IERC20;
    using Address for address payable;

    error OnlyVertex();
    error Invalid0xRecipient();

    /// @notice Name of this Vertex Account.
    string public name;
    /// @notice Vertex system
    address public immutable vertex;

    constructor(string memory _name, address _vertex) {
        name = _name;
        vertex = _vertex;
    }

    modifier onlyVertex() {
        if (msg.sender != vertex) revert OnlyVertex();
        _;
    }

    /// @notice Function for Vertex Account to receive ETH
    receive() external payable {}

    /// @inheritdoc IVertexAccount
    function transfer(address payable recipient, uint256 amount) external onlyVertex {
        if (recipient == address(0)) revert Invalid0xRecipient();
        recipient.sendValue(amount);
    }

    /// @inheritdoc IVertexAccount
    function transferERC20(IERC20 token, address recipient, uint256 amount) external onlyVertex {
        if (recipient == address(0)) revert Invalid0xRecipient();
        token.safeTransfer(recipient, amount);
    }

    /// @inheritdoc IVertexAccount
    function approveERC20(IERC20 token, address recipient, uint256 amount) external onlyVertex {
        token.safeApprove(recipient, amount);
    }
}
