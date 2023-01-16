// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

error OnlyStrategyCanExecute();
error ActionExecutionFailed();

contract VertexExecutor {
    mapping(address => bool) public strategies;

    modifier onlyStrategy(address strategy) {
        if (!strategies[strategy]) revert OnlyStrategyCanExecute();
        _;
    }

    function updateStrategy(address strategy, bool isStrategy) external {
        // TODO: add modifier that only allows VertexVotingWithVetoStrategy to update
        strategies[strategy] = isStrategy;
    }

    function execute(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    ) external payable onlyStrategy(msg.sender) returns (bytes memory) {
        bytes memory callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);

        // solhint-disable avoid-low-level-calls
        (bool success, bytes memory result) = target.call{value: value}(callData);

        if (!success) revert ActionExecutionFailed();
        return result;
    }
}
