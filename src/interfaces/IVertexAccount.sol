// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import {IERC1155} from "@openzeppelin/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import {ERC20TransferData} from "src/lib/Structs.sol";

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
  /// @param erc20TransferData The data of the ERC20 transfer
  function transferERC20(ERC20TransferData calldata erc20TransferData) external;

  /// @notice Function for Vertex to batch transfer ERC20 tokens to other parties
  /// @param tokens The addresses of the tokens to transfer
  /// @param recipients Transfers' recipients
  /// @param amounts Amounts to transfer
  function batchTransferERC20(IERC20[] calldata tokens, address[] calldata recipients, uint256[] calldata amounts)
    external;

  /// @notice Function for Vertex to give ERC20 allowance to other parties
  /// @param token The address of the token to give allowance from
  /// @param recipient Allowance's recipient
  /// @param amount Allowance to approve
  function approveERC20(IERC20 token, address recipient, uint256 amount) external;

  /// @notice Function for Vertex to batch give ERC20 allowance to other parties
  /// @param tokens The addresses of the tokens to give allowance from
  /// @param recipients Allowances' recipients
  /// @param amounts Allowances to approve
  function batchApproveERC20(IERC20[] calldata tokens, address[] calldata recipients, uint256[] calldata amounts)
    external;

  // -------------------------------------------------------------------------
  // ERC721 Token
  // -------------------------------------------------------------------------

  /// @notice Function for Vertex to transfer ERC721 tokens to other parties
  /// @param token The address of the token to transfer
  /// @param recipient Transfer's recipient
  /// @param tokenId Token ID to transfer
  function transferERC721(IERC721 token, address recipient, uint256 tokenId) external;

  /// @notice Function for Vertex to batch transfer ERC721 tokens to other parties
  /// @param tokens The addresses of the tokens to transfer
  /// @param recipients Transfers' recipients
  /// @param tokenIds Token IDs to transfer
  function batchTransferERC721(IERC721[] calldata tokens, address[] calldata recipients, uint256[] calldata tokenIds)
    external;

  /// @notice Function for Vertex to give ERC721 allowance to other parties
  /// @param token The address of the token to give allowance from
  /// @param recipient Allowance's recipient
  /// @param tokenId Token ID to give allowance for
  function approveERC721(IERC721 token, address recipient, uint256 tokenId) external;

  /// @notice Function for Vertex to batch give ERC721 allowance to other parties
  /// @param tokens The addresses of the tokens to give allowance from
  /// @param recipients Allowances' recipients
  /// @param tokenIds Token IDs to give allowance for
  function batchApproveERC721(IERC721[] calldata tokens, address[] calldata recipients, uint256[] calldata tokenIds)
    external;

  /// @notice Function for Vertex to give ERC721 operator allowance to other parties
  /// @param token The address of the token to give allowance from
  /// @param recipient Allowance's recipient
  /// @param approved Whether to approve or revoke allowance
  function approveOperatorERC721(IERC721 token, address recipient, bool approved) external;

  /// @notice Function for Vertex to batch give ERC721 operator allowance to other parties
  /// @param tokens The addresses of the tokens to give allowance from
  /// @param recipients Allowances' recipients
  /// @param approved Whether to approve or revoke allowance
  function batchApproveOperatorERC721(
    IERC721[] calldata tokens,
    address[] calldata recipients,
    bool[] calldata approved
  ) external;

  // -------------------------------------------------------------------------
  // ERC1155 Token
  // -------------------------------------------------------------------------

  /// @notice Function for Vertex to transfer ERC1155 tokens to other parties
  /// @param token The address of the token to transfer
  /// @param recipient Transfer's recipient
  /// @param tokenId Token ID to transfer
  /// @param amount Amount to transfer
  /// @param data Data to pass to the receiver
  function transferERC1155(IERC1155 token, address recipient, uint256 tokenId, uint256 amount, bytes calldata data)
    external;

  /// @notice Function for Vertex to batch transfer ERC1155 tokens of a single ERC1155 collection to other parties
  /// @param token The address of the token to transfer
  /// @param recipient Transfer's recipient
  /// @param tokenIds Token IDs to transfer
  /// @param amounts Amounts to transfer
  /// @param data Data to pass to the receiver
  function batchTransferSingleERC1155(
    IERC1155 token,
    address recipient,
    uint256[] calldata tokenIds,
    uint256[] calldata amounts,
    bytes calldata data
  ) external;

  /// @notice Function for Vertex to batch transfer ERC1155 tokens of multiple ERC1155 collections to other parties
  /// @param tokens The addresses of the tokens to transfer
  /// @param recipients Transfers' recipients
  /// @param tokenIds Token IDs to transfer
  /// @param amounts Amounts to transfer
  /// @param data Data to pass to the receiver
  function batchTransferMultipleERC1155(
    IERC1155[] calldata tokens,
    address[] calldata recipients,
    uint256[][] calldata tokenIds,
    uint256[][] calldata amounts,
    bytes[] calldata data
  ) external;

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
