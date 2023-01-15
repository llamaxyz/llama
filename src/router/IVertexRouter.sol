// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IVertexStrategy} from "src/strategies/IVertexStrategy.sol";

interface IVertexRouter {
    enum ActionState {
        Active,
        Canceled,
        Failed,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    struct Action {
        uint256 id;
        address creator;
        IVertexStrategy strategy;
        address target;
        uint256 value;
        string signature;
        bytes callData;
        bool canceled;
        bool executed;
    }

    event ActionCreated(uint256 id, address indexed creator, IVertexStrategy indexed strategy, address target, uint256 value, string signature, bytes callData);

    event ActionCanceled(uint256 id);

    event ActionExecuted(uint256 id, address indexed caller, address indexed strategy, address indexed creator);

    event VertexStrategyAuthorized(address indexed strategy, address indexed creator);

    event VertexStrategyUnauthorized(address indexed strategy, address indexed creator);

    function name() external view returns (string memory);

    function createAction(
        IVertexStrategy strategy,
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata callData
    ) external returns (uint256);

    function cancel(uint256 actionId) external;

    function execute(uint256 actionId) external payable;

    function getStrategies() external view returns (IVertexStrategy[] memory);

    function isStrategyAuthorized(address strategy) external view returns (bool);

    function getActionsCount() external view returns (uint256);

    function getActionsById(uint256 actionId) external view returns (Action memory);

    function getActionState(uint256 actionId) external view returns (ActionState);
}
