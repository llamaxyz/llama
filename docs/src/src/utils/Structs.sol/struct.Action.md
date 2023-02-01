# Action
[Git Source](https://github.com/llama-community/vertex-v1/blob/cc88cdb8bad11e53bd46d72467d70a467b8b1b95/src/utils/Structs.sol)


```solidity
struct Action {
    address creator;
    bool executed;
    bool canceled;
    VertexStrategy strategy;
    address target;
    uint256 value;
    bytes4 selector;
    bytes data;
    uint256 createdBlockNumber;
    uint256 executionTime;
    uint256 totalApprovals;
    uint256 totalDisapprovals;
    uint256 approvalPolicySupply;
    uint256 disapprovalPolicySupply;
}
```

