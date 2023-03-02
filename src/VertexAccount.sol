// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/proxy/utils/Initializable.sol";
import {IVertexAccount} from "src/interfaces/IVertexAccount.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";
import {Address} from "@openzeppelin/utils/Address.sol";
import {ERC20Data} from "src/lib/Structs.sol";

/// @title Vertex Account
/// @author Llama (vertex@llama.xyz)
/// @notice The contract that holds the Vertex system's assets.
contract VertexAccount is IVertexAccount, ERC721Holder, ERC1155Holder, Initializable {
  using SafeERC20 for IERC20;
  using Address for address payable;

  error OnlyVertex();
  error Invalid0xRecipient();
  error InvalidInput();
  error FailedExecution(bytes result);

  /// @notice Name of this Vertex Account.
  string public name;
  /// @notice Vertex system
  address public vertex;

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
  function transferERC20(ERC20Data calldata erc20TransferData) external onlyVertex {
    if (erc20TransferData.recipient == address(0)) revert Invalid0xRecipient();
    erc20TransferData.token.safeTransfer(erc20TransferData.recipient, erc20TransferData.amount);
  }

  /// @inheritdoc IVertexAccount
  function batchTransferERC20(ERC20Data[] calldata erc20TransferData) external onlyVertex {
    uint256 length = erc20TransferData.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        if (erc20TransferData[i].recipient == address(0)) revert Invalid0xRecipient();
        erc20TransferData[i].token.safeTransfer(erc20TransferData[i].recipient, erc20TransferData[i].amount);
      }
    }
  }

  /// @inheritdoc IVertexAccount
  function approveERC20(ERC20Data calldata erc20ApproveData) external onlyVertex {
    erc20ApproveData.token.safeApprove(erc20ApproveData.recipient, erc20ApproveData.amount);
  }

  /// @inheritdoc IVertexAccount
  function batchApproveERC20(IERC20[] calldata tokens, address[] calldata recipients, uint256[] calldata amounts)
    external
    onlyVertex
  {
    uint256 length = tokens.length;
    if (length == 0 || length != recipients.length || length != amounts.length) revert InvalidInput();
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        tokens[i].safeApprove(recipients[i], amounts[i]);
      }
    }
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
  function batchTransferERC721(IERC721[] calldata tokens, address[] calldata recipients, uint256[] calldata tokenIds)
    external
    onlyVertex
  {
    uint256 length = tokens.length;
    if (length == 0 || length != recipients.length || length != tokenIds.length) revert InvalidInput();
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        if (recipients[i] == address(0)) revert Invalid0xRecipient();
        tokens[i].transferFrom(address(this), recipients[i], tokenIds[i]);
      }
    }
  }

  /// @inheritdoc IVertexAccount
  function approveERC721(IERC721 token, address recipient, uint256 tokenId) external onlyVertex {
    token.approve(recipient, tokenId);
  }

  /// @inheritdoc IVertexAccount
  function batchApproveERC721(IERC721[] calldata tokens, address[] calldata recipients, uint256[] calldata tokenIds)
    external
    onlyVertex
  {
    uint256 length = tokens.length;
    if (length == 0 || length != recipients.length || length != tokenIds.length) revert InvalidInput();
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        tokens[i].approve(recipients[i], tokenIds[i]);
      }
    }
  }

  /// @inheritdoc IVertexAccount
  function approveOperatorERC721(IERC721 token, address recipient, bool approved) external onlyVertex {
    token.setApprovalForAll(recipient, approved);
  }

  /// @inheritdoc IVertexAccount
  function batchApproveOperatorERC721(
    IERC721[] calldata tokens,
    address[] calldata recipients,
    bool[] calldata approved
  ) external onlyVertex {
    uint256 length = tokens.length;
    if (length == 0 || length != recipients.length || length != approved.length) revert InvalidInput();
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        tokens[i].setApprovalForAll(recipients[i], approved[i]);
      }
    }
  }

  // -------------------------------------------------------------------------
  // ERC1155 Token
  // -------------------------------------------------------------------------

  /// @inheritdoc IVertexAccount
  function transferERC1155(IERC1155 token, address recipient, uint256 tokenId, uint256 amount, bytes calldata data)
    external
    onlyVertex
  {
    if (recipient == address(0)) revert Invalid0xRecipient();
    token.safeTransferFrom(address(this), recipient, tokenId, amount, data);
  }

  /// @inheritdoc IVertexAccount
  function batchTransferSingleERC1155(
    IERC1155 token,
    address recipient,
    uint256[] calldata tokenIds,
    uint256[] calldata amounts,
    bytes calldata data
  ) external onlyVertex {
    if (recipient == address(0)) revert Invalid0xRecipient();
    token.safeBatchTransferFrom(address(this), recipient, tokenIds, amounts, data);
  }

  /// @inheritdoc IVertexAccount
  function batchTransferMultipleERC1155(
    IERC1155[] calldata tokens,
    address[] calldata recipients,
    uint256[][] calldata tokenIds,
    uint256[][] calldata amounts,
    bytes[] calldata data
  ) external onlyVertex {
    uint256 length = tokens.length;
    if (
      length == 0 || length != recipients.length || length != tokenIds.length || length != amounts.length
        || length != data.length
    ) revert InvalidInput();
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        if (recipients[i] == address(0)) revert Invalid0xRecipient();
        tokens[i].safeBatchTransferFrom(address(this), recipients[i], tokenIds[i], amounts[i], data[i]);
      }
    }
  }

  /// @inheritdoc IVertexAccount
  function approveOperatorERC1155(IERC1155 token, address recipient, bool approved) external onlyVertex {
    token.setApprovalForAll(recipient, approved);
  }

  /// @inheritdoc IVertexAccount
  function batchApproveOperatorERC1155(
    IERC1155[] calldata tokens,
    address[] calldata recipients,
    bool[] calldata approved
  ) external onlyVertex {
    uint256 length = tokens.length;
    if (length == 0 || length != recipients.length || length != approved.length) revert InvalidInput();
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        tokens[i].setApprovalForAll(recipients[i], approved[i]);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Generic Execution
  // -------------------------------------------------------------------------

  /// @inheritdoc IVertexAccount
  function execute(address target, bytes calldata callData, bool withDelegatecall)
    external
    payable
    onlyVertex
    returns (bytes memory)
  {
    bool success;
    bytes memory result;

    if (withDelegatecall) (success, result) = target.delegatecall(callData);
    else (success, result) = target.call{value: msg.value}(callData);

    if (!success) revert FailedExecution(result);
    return result;
  }
}
