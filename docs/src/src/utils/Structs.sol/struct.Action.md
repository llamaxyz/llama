# Action
<<<<<<< HEAD
<<<<<<< HEAD
[Git Source](https://github.com/llama-community/vertex-v1/blob/61ef774889dd82e8f91f589d8c7893861f840536/src/utils/Structs.sol)
=======
[Git Source](https://github.com/llama-community/vertex-v1/blob/273c5d72ad31cc2754f7da37333566f14375808b/src/utils/Structs.sol)
>>>>>>> a2cac96 (Generate updated docs)
=======
[Git Source](https://github.com/llama-community/vertex-v1/blob/273c5d72ad31cc2754f7da37333566f14375808b/src/utils/Structs.sol)
>>>>>>> b75ab96f95c20c97992964be967cc575cc176f07


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

