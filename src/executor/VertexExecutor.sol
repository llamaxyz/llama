// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexExecutor} from "src/executor/IVertexExecutor.sol";

error OnlyRouterCanExecute();
error ActionExecutionFailed();

contract VertexExecutor is IVertexExecutor {
    address public immutable router;

    constructor(address _router) {
        router = _router;
    }

    function execute(address target, uint256 value, string memory signature, bytes memory data) external returns (bytes memory) {
        if (msg.sender != router) revert OnlyRouterCanExecute();

        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory result) = target.call{value: value}(abi.encodeWithSignature(signature, data));

        if (!success) revert ActionExecutionFailed();
        return result;
    }
}
