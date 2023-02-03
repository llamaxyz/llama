// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

interface IVertexCollector {
    /// @notice Function for Vertex to give ERC20 allowance to other parties
    /// @param token The address of the token to give allowance from
    /// @param recipient Allowance's recipient
    /// @param amount Allowance to approve
    function approve(IERC20 token, address recipient, uint256 amount) external;

    /// @notice Function for Vertex to transfer ERC20 tokens to other parties
    /// @param token The address of the token to transfer
    /// @param recipient Transfer's recipient
    /// @param amount Amount to transfer
    function transfer(IERC20 token, address recipient, uint256 amount) external;
}
