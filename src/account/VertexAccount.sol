// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";
import {IVertexAccount} from "src/account/IVertexAccount.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";
import {Address} from "@openzeppelin/utils/Address.sol";

/// @title Vertex Account
/// @author Llama (vertex@llama.xyz)
/// @notice The contract that holds the Vertex system's assets.
contract VertexAccount is IVertexAccount, ERC721Holder, ERC1155Holder, Initializable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    error OnlyVertex();
    error Invalid0xRecipient();
    error FailedExecution(bytes result);

    /// @notice Name of this Vertex Account.
    string public name;
    /// @notice Vertex system
    address public vertex;

    // solhint-disable-next-line no-empty-blocks
    constructor() initializer {}

    function initialize(string memory _name, address _vertex) external override initializer {
        name = _name;
        vertex = _vertex;
    }

    modifier onlyVertex() {
        if (msg.sender != vertex) revert OnlyVertex();
        _;
    }

    // -------------------------------------------------------------------------
    // Native Token
    // -------------------------------------------------------------------------

    /// @inheritdoc IVertexAccount
    receive() external payable {}

    /// @inheritdoc IVertexAccount
    function transfer(address payable recipient, uint256 amount) external onlyVertex {
        if (recipient == address(0)) revert Invalid0xRecipient();
        recipient.sendValue(amount);
    }

    // -------------------------------------------------------------------------
    // ERC20 Token
    // -------------------------------------------------------------------------

    /// @inheritdoc IVertexAccount
    function transferERC20(IERC20 token, address recipient, uint256 amount) external onlyVertex {
        if (recipient == address(0)) revert Invalid0xRecipient();
        token.safeTransfer(recipient, amount);
    }

    /// @inheritdoc IVertexAccount
    function approveERC20(IERC20 token, address recipient, uint256 amount) external onlyVertex {
        token.safeApprove(recipient, amount);
    }

    // -------------------------------------------------------------------------
    // ERC721 Token
    // -------------------------------------------------------------------------

    /// @inheritdoc IVertexAccount
    function transferERC721(IERC721 token, address recipient, uint256 tokenId) external onlyVertex {
        if (recipient == address(0)) revert Invalid0xRecipient();
        token.transferFrom(address(this), recipient, tokenId);
    }

    /// @inheritdoc IVertexAccount
    function approveERC721(IERC721 token, address recipient, uint256 tokenId) external onlyVertex {
        token.approve(recipient, tokenId);
    }

    /// @inheritdoc IVertexAccount
    function approveOperatorERC721(IERC721 token, address recipient, bool approved) external onlyVertex {
        token.setApprovalForAll(recipient, approved);
    }

    // -------------------------------------------------------------------------
    // ERC1155 Token
    // -------------------------------------------------------------------------

    /// @inheritdoc IVertexAccount
    function transferERC1155(IERC1155 token, address recipient, uint256 tokenId, uint256 amount, bytes calldata data) external onlyVertex {
        if (recipient == address(0)) revert Invalid0xRecipient();
        token.safeTransferFrom(address(this), recipient, tokenId, amount, data);
    }

    /// @inheritdoc IVertexAccount
    function transferBatchERC1155(IERC1155 token, address recipient, uint256[] calldata tokenIds, uint256[] calldata amounts, bytes calldata data)
        external
        onlyVertex
    {
        if (recipient == address(0)) revert Invalid0xRecipient();
        token.safeBatchTransferFrom(address(this), recipient, tokenIds, amounts, data);
    }

    /// @inheritdoc IVertexAccount
    function approveERC1155(IERC1155 token, address recipient, bool approved) external onlyVertex {
        token.setApprovalForAll(recipient, approved);
    }

    // -------------------------------------------------------------------------
    // Generic Execution
    // -------------------------------------------------------------------------

    /// @inheritdoc IVertexAccount
    function execute(address target, bytes4 selector, bytes calldata data, bool withDelegatecall) external payable onlyVertex returns (bytes memory) {
        bytes memory callData = abi.encodePacked(selector, data);
        bool success;
        bytes memory result;

        if (withDelegatecall) {
            // solhint-disable avoid-low-level-calls
            (success, result) = target.delegatecall(callData);
        } else {
            // solhint-disable avoid-low-level-calls
            (success, result) = address(this).call{value: msg.value}(callData);
        }

        if (!success) revert FailedExecution(result);
        return result;
    }
}
