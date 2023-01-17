// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";

error OnlyRouterCanExecute();
error ActionExecutionFailed();

contract VertexExecutor {
    IVertexRouter public immutable router;

    constructor(IVertexRouter _router) {
        router = _router;
    }

    function execute(address target, uint256 value, string memory signature, bytes memory data) external payable returns (bytes memory) {
        if (msg.sender != router) revert OnlyRouterCanExecute();
        bytes memory callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);

        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory result) = target.call{value: value}(callData);

        if (!success) revert ActionExecutionFailed();
        return result;
    }
}
