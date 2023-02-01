# Strategy
[Git Source](https://github.com/llama-community/vertex-v1/blob/8f0c32f021139cdafca13c86e5a5d1185dab4c15/src/utils/Structs.sol)


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

