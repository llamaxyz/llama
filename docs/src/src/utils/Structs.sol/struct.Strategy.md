# Strategy
[Git Source](https://github.com/llama-community/vertex-v1/blob/8146b0e9a9ffa7cd971f2eedb0f6b4018cc535f8/src/utils/Structs.sol)


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

