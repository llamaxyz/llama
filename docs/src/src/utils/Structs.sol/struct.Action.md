# Action
[Git Source](https://github.com/llama-community/vertex-v1/blob/f39460fcaaa81cdf1a41d9edafc15a0f0252faef/src/utils/Structs.sol)


```solidity
struct Action {
    address creator;
    bool executed;
    bool canceled;
    bytes4 selector;
    VertexStrategy strategy;
    address target;
    bytes data;
    uint256 value;
    uint256 createdBlockNumber;
    uint256 executionTime;
    uint256 totalApprovals;
    uint256 totalDisapprovals;
    uint256 approvalPolicySupply;
    uint256 disapprovalPolicySupply;
}
```

