// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import {ERC20Data, ERC721Data, ERC721OperatorData, ERC1155Data, ERC1155BatchData} from "src/lib/Structs.sol";

interface IVertexAccount is IERC721Receiver, IERC1155Receiver {
  /// @notice Initializes a new VertexAccount clone.
  /// @param name The name of the VertexAccount clone.
  /// @param vertex This Vertex instance's core contract
  function initialize(string memory name, address vertex) external;

  // -------------------------------------------------------------------------
  // Native Token
  // -------------------------------------------------------------------------

  /// @notice Function for Vertex Account to receive native token
  receive() external payable;

  /// @notice Function for Vertex to transfer native tokens to other parties
  /// @param recipient Transfer's recipient
  /// @param amount Amount to transfer
  function transfer(address payable recipient, uint256 amount) external;

  // -------------------------------------------------------------------------
  // ERC20 Token
  // -------------------------------------------------------------------------

  /// @notice Function for Vertex to transfer ERC20 tokens to other parties
  /// @param erc20Data The data of the ERC20 transfer
  function transferERC20(ERC20Data calldata erc20Data) external;

  /// @notice Function for Vertex to batch transfer ERC20 tokens to other parties
  /// @param erc20Data The data of the ERC20 transfers
  function batchTransferERC20(ERC20Data[] calldata erc20Data) external;

  /// @notice Function for Vertex to give ERC20 allowance to other parties
  /// @param erc20Data The data of the ERC20 allowance
  function approveERC20(ERC20Data calldata erc20Data) external;

  /// @notice Function for Vertex to batch give ERC20 allowance to other parties
  /// @param erc20Data The data of the ERC20 allowances
  function batchApproveERC20(ERC20Data[] calldata erc20Data) external;

  // -------------------------------------------------------------------------
  // ERC721 Token
  // -------------------------------------------------------------------------

  /// @notice Function for Vertex to transfer ERC721 tokens to other parties
  /// @param erc721Data The data of the ERC721 transfer
  function transferERC721(ERC721Data calldata erc721Data) external;

  /// @notice Function for Vertex to batch transfer ERC721 tokens to other parties
  /// @param erc721Data The data of the ERC721 transfers
  function batchTransferERC721(ERC721Data[] calldata erc721Data) external;

  /// @notice Function for Vertex to give ERC721 allowance to other parties
  /// @param erc721Data The data of the ERC721 allowance
  function approveERC721(ERC721Data calldata erc721Data) external;

  /// @notice Function for Vertex to batch give ERC721 allowance to other parties
  /// @param erc721Data The data of the ERC721 allowances
  function batchApproveERC721(ERC721Data[] calldata erc721Data) external;

  /// @notice Function for Vertex to give ERC721 operator allowance to other parties
  /// @param erc721OperatorData The data of the ERC721 operator allowance
  function approveOperatorERC721(ERC721OperatorData calldata erc721OperatorData) external;

  /// @notice Function for Vertex to batch give ERC721 operator allowance to other parties
  /// @param erc721OperatorData The data of the ERC721 operator allowances
  function batchApproveOperatorERC721(ERC721OperatorData[] calldata erc721OperatorData) external;

  // -------------------------------------------------------------------------
  // ERC1155 Token
  // -------------------------------------------------------------------------

  /// @notice Function for Vertex to transfer ERC1155 tokens to other parties
  /// @param erc1155Data The data of the ERC1155 transfer
  function transferERC1155(ERC1155Data calldata erc1155Data) external;

  /// @notice Function for Vertex to batch transfer ERC1155 tokens of a single ERC1155 collection to other parties
  /// @param erc1155BatchData The data of the ERC1155 batch transfer
  function batchTransferSingleERC1155(ERC1155BatchData calldata erc1155BatchData) external;

  /// @notice Function for Vertex to batch transfer ERC1155 tokens of multiple ERC1155 collections to other parties
  /// @param erc1155BatchData The data of the ERC1155 batch transfers
  function batchTransferMultipleERC1155(ERC1155BatchData[] calldata erc1155BatchData) external;

  /// @notice Function for Vertex to give ERC1155 operator allowance to other parties
  /// @param token The address of the token to give allowance from
  /// @param recipient Allowance's recipient
  /// @param approved Whether to approve or revoke allowance
  function approveOperatorERC1155(IERC1155 token, address recipient, bool approved) external;

  /// @notice Function for Vertex to batch give ERC1155 operator allowance to other parties
  /// @param tokens The addresses of the tokens to give allowance from
  /// @param recipients Allowances' recipients
  /// @param approved Whether to approve or revoke allowance
  function batchApproveOperatorERC1155(
    IERC1155[] calldata tokens,
    address[] calldata recipients,
    bool[] calldata approved
  ) external;

  // -------------------------------------------------------------------------
  // Generic Execution
  // -------------------------------------------------------------------------

  /// @notice Function for Vertex to execute arbitrary calls
  /// @param target The address of the contract to call
  /// @param callData The call data to pass to the contract
  /// @param withDelegatecall Whether to use delegatecall or call
  function execute(address target, bytes calldata callData, bool withDelegatecall)
    external
    payable
    returns (bytes memory);
}
