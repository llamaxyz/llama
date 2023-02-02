// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexCollector} from "src/vault/IVertexCollector.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/utils/Address.sol";

/// @title Vertex Collector
/// @author Llama (vertex@llama.xyz)
/// @notice The contract that holds the Vertex system's assets.
contract VertexCollector is IVertexCollector {
    using SafeERC20 for IERC20;
    using Address for address payable;

    error OnlyVertex();
    error Invalid0xRecipient();

    /// @notice Mock address for ETH
    address public constant ETH_MOCK_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    /// @notice Vertex system
    address public immutable vertex;

    constructor(address _vertex) {
        vertex = _vertex;
    }

    modifier onlyVertex() {
        if (msg.sender != vertex) revert OnlyVertex();
        _;
    }

    /// @notice Function for Vertex Vault to receive ETH
    receive() external payable {}

    /// @inheritdoc IVertexCollector
    function approve(IERC20 token, address recipient, uint256 amount) external onlyVertex {
        token.safeApprove(recipient, amount);
    }

    /// @inheritdoc IVertexCollector
    function transfer(IERC20 token, address recipient, uint256 amount) external onlyVertex {
        if (recipient == address(0)) revert Invalid0xRecipient();

        if (address(token) == ETH_MOCK_ADDRESS) {
            payable(recipient).sendValue(amount);
        } else {
            token.safeTransfer(recipient, amount);
        }
    }
}
