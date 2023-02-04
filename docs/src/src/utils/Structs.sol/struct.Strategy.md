# Strategy
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
struct Strategy {
    uint256 approvalPeriod;
    uint256 queuingDuration;
    uint256 expirationDelay;
    uint256 minApprovalPct;
    uint256 minDisapprovalPct;
    WeightByPermission[] approvalWeightByPermission;
    WeightByPermission[] disapprovalWeightByPermission;
    bool isFixedLengthApprovalPeriod;
}
```

