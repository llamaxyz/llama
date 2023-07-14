// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LlamaRelativeStrategyBase} from "src/strategies/LlamaRelativeStrategyBase.sol";

// @dev A mock strategy implementation (logic) contract. To be used for testing the abstract `LlamaAbsoluteStrategyBase`
// contract
contract MockLlamaRelativeStrategyBase is LlamaAbsoluteStrategyBase {
  function validateActionCreation(ActionInfo calldata) external view override {}

  function getApprovalQuantityAt(address, /* policyholder */ uint8, /* role */ uint256 /* timestamp */ )
    external
    view
    override
    returns (uint128)
  {}

  function getDisapprovalQuantityAt(address, /* policyholder */ uint8, /* role */ uint256 /* timestamp */ )
    external
    view
    override
    returns (uint128)
  {}
}
