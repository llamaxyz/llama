# Action
[Git Source](https://github.com/llama-community/vertex-v1/blob/7aa68098b2ce738ab9dd3c6970d253d02689b4d9/src/utils/Structs.sol)


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

