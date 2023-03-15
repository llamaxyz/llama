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
import {
  ERC20Data,
  ERC721Data,
  ERC721OperatorData,
  ERC1155Data,
  ERC1155BatchData,
  ERC1155OperatorData
} from "src/lib/Structs.sol";

/// @title Vertex Account
/// @author Llama (vertex@llama.xyz)
/// @notice The contract that holds the Vertex system's assets.
contract VertexAccount is IVertexAccount, ERC721Holder, ERC1155Holder, Initializable {
  using SafeERC20 for IERC20;
  using Address for address payable;

  /// @notice Name of this Vertex Account.
  string public name;

  /// @notice Vertex system
  address public vertex;

  constructor() initializer {}

  /// @inheritdoc IVertexAccount
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
  function transferERC20(ERC20Data calldata erc20Data) public onlyVertex {
    if (erc20Data.recipient == address(0)) revert Invalid0xRecipient();
    erc20Data.token.safeTransfer(erc20Data.recipient, erc20Data.amount);
  }

  /// @inheritdoc IVertexAccount
  function batchTransferERC20(ERC20Data[] calldata erc20Data) external onlyVertex {
    uint256 length = erc20Data.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        transferERC20(erc20Data[i]);
      }
    }
  }

  /// @inheritdoc IVertexAccount
  function approveERC20(ERC20Data calldata erc20Data) public onlyVertex {
    erc20Data.token.safeApprove(erc20Data.recipient, erc20Data.amount);
  }

  /// @inheritdoc IVertexAccount
  function batchApproveERC20(ERC20Data[] calldata erc20Data) external onlyVertex {
    uint256 length = erc20Data.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        approveERC20(erc20Data[i]);
      }
    }
  }

  // -------------------------------------------------------------------------
  // ERC721 Token
  // -------------------------------------------------------------------------

  /// @inheritdoc IVertexAccount
  function transferERC721(ERC721Data calldata erc721Data) public onlyVertex {
    if (erc721Data.recipient == address(0)) revert Invalid0xRecipient();
    erc721Data.token.transferFrom(address(this), erc721Data.recipient, erc721Data.tokenId);
  }

  /// @inheritdoc IVertexAccount
  function batchTransferERC721(ERC721Data[] calldata erc721Data) external onlyVertex {
    uint256 length = erc721Data.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        transferERC721(erc721Data[i]);
      }
    }
  }

  /// @inheritdoc IVertexAccount
  function approveERC721(ERC721Data calldata erc721Data) public onlyVertex {
    erc721Data.token.approve(erc721Data.recipient, erc721Data.tokenId);
  }

  /// @inheritdoc IVertexAccount
  function batchApproveERC721(ERC721Data[] calldata erc721Data) external onlyVertex {
    uint256 length = erc721Data.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        approveERC721(erc721Data[i]);
      }
    }
  }

  /// @inheritdoc IVertexAccount
  function approveOperatorERC721(ERC721OperatorData calldata erc721OperatorData) public onlyVertex {
    erc721OperatorData.token.setApprovalForAll(erc721OperatorData.recipient, erc721OperatorData.approved);
  }

  /// @inheritdoc IVertexAccount
  function batchApproveOperatorERC721(ERC721OperatorData[] calldata erc721OperatorData) external onlyVertex {
    uint256 length = erc721OperatorData.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        approveOperatorERC721(erc721OperatorData[i]);
      }
    }
  }

  // -------------------------------------------------------------------------
  // ERC1155 Token
  // -------------------------------------------------------------------------

  /// @inheritdoc IVertexAccount
  function transferERC1155(ERC1155Data calldata erc1155Data) external onlyVertex {
    if (erc1155Data.recipient == address(0)) revert Invalid0xRecipient();
    erc1155Data.token.safeTransferFrom(
      address(this), erc1155Data.recipient, erc1155Data.tokenId, erc1155Data.amount, erc1155Data.data
    );
  }

  /// @inheritdoc IVertexAccount
  function batchTransferSingleERC1155(ERC1155BatchData calldata erc1155BatchData) public onlyVertex {
    if (erc1155BatchData.recipient == address(0)) revert Invalid0xRecipient();
    erc1155BatchData.token.safeBatchTransferFrom(
      address(this),
      erc1155BatchData.recipient,
      erc1155BatchData.tokenIds,
      erc1155BatchData.amounts,
      erc1155BatchData.data
    );
  }

  /// @inheritdoc IVertexAccount
  function batchTransferMultipleERC1155(ERC1155BatchData[] calldata erc1155BatchData) external onlyVertex {
    uint256 length = erc1155BatchData.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        batchTransferSingleERC1155(erc1155BatchData[i]);
      }
    }
  }

  /// @inheritdoc IVertexAccount
  function approveOperatorERC1155(ERC1155OperatorData calldata erc1155OperatorData) public onlyVertex {
    erc1155OperatorData.token.setApprovalForAll(erc1155OperatorData.recipient, erc1155OperatorData.approved);
  }

  /// @inheritdoc IVertexAccount
  function batchApproveOperatorERC1155(ERC1155OperatorData[] calldata erc1155OperatorData) external onlyVertex {
    uint256 length = erc1155OperatorData.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        approveOperatorERC1155(erc1155OperatorData[i]);
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
