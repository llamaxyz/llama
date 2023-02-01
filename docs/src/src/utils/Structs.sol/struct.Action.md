# Action
[Git Source](https://github.com/llama-community/vertex-v1/blob/693b03f6823cb240f992102042b3702c0c97cf44/src/utils/Structs.sol)


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

