# Action
[Git Source](https://github.com/llama-community/vertex-v1/blob/b9be9bc31164da407ed5af3d8e0d2bcfd09559e6/src/utils/Structs.sol)


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

