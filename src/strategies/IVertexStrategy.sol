// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexRouter} from "src/router/IVertexRouter.sol";

interface IVertexStrategy {
    /**
     * @dev emitted when a new strategy is deployed.
     * @param name Name of the strategy
     **/
    event NewStrategyCreated(string name);

    /**
     * @dev emitted when a new action is Queued.
     * @param actionHash hash of the action
     * @param target address of the targeted contract
     * @param value wei value of the transaction
     * @param signature function signature of the transaction
     * @param data function arguments of the transaction
     * @param executionTime time at which to execute the transaction
     **/
    event QueuedAction(bytes32 actionHash, address indexed target, uint256 value, string signature, bytes data, uint256 executionTime);

    /**
     * @dev emitted when an action is Cancelled
     * @param actionHash hash of the action
     * @param target address of the targeted contract
     * @param value wei value of the transaction
     * @param signature function signature of the transaction
     * @param data function arguments of the transaction
     **/
    event CanceledAction(bytes32 actionHash, address indexed target, uint256 value, string signature, bytes data);

    /**
     * @dev emitted when an action is Executed
     * @param actionHash hash of the action
     * @param target address of the targeted contract
     * @param value wei value of the transaction
     * @param signature function signature of the transaction
     * @param data function arguments of the transaction
     * @param resultData the actual callData used on the target
     **/
    event ExecutedAction(bytes32 actionHash, address indexed target, uint256 value, string signature, bytes data, bytes resultData);

    /**
     * @dev Function, called by Router, that cancels an action, returns action hash
     * @param target The contract called by action's associated transaction
     * @param value The value in wei of the action's associated transaction
     * @param signature The function signature that will be called by the action's associated transaction
     * @param data The arguments passed to the function that is called by the action's associated transaction
     * @param executionTime time when action underlying transactions can be executed
     **/
    function cancelAction(address target, uint256 value, string calldata signature, bytes calldata data, uint256 executionTime) external returns (bytes32);

    /**
     * @dev Function, called by Router, that queue an action, returns action hash
     * @param target The contract called by action's associated transaction
     * @param value The value in wei of the action's associated transaction
     * @param signature The function signature that will be called by the action's associated transaction
     * @param data The arguments passed to the function that is called by the action's associated transaction
     * @param executionTime time when action underlying transactions can be executed
     **/
    function queueAction(address target, uint256 value, string calldata signature, bytes calldata data, uint256 executionTime) external returns (bytes32);

    /**
     * @dev Function, called by Router, that executes a transaction, returns the callData executed
     * @param target The contract called by action's associated transaction
     * @param value The value in wei of the action's associated transaction
     * @param signature The function signature that will be called by the action's associated transaction
     * @param data The arguments passed to the function that is called by the action's associated transaction
     * @param executionTime time when action underlying transactions can be executed
     **/
    function executeAction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 executionTime
    ) external payable returns (bytes memory);

    /**
     * @dev Getter of the delay between queuing and execution
     * @return The delay in seconds
     **/
    function delay() external view returns (uint256);

    /**
     * @dev Returns whether an action (via actionHash) is queued
     * @param actionHash hash of the action to be checked
     * keccak256(abi.encode(target, value, signature, data, executionTime, withDelegatecall))
     * @return true if underlying action of actionHash is queued
     **/
    function isActionQueued(bytes32 actionHash) external view returns (bool);

    /**
     * @dev Checks whether a proposal is over its expiration delay
     * @param actionId Id of the action against which to test
     * @return true of proposal is over its expiration delay
     **/
    function isActionExpired(uint256 actionId) external view returns (bool);
}
