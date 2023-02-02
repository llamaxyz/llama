# Action
[Git Source](https://github.com/llama-community/vertex-v1/blob/b01379c65f03514c141f06120861dc0d491ffeed/src/utils/Structs.sol)


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

