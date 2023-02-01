# Strategy
[Git Source](https://github.com/llama-community/vertex-v1/blob/3feb9e8a0ba73bc3a932244e1fa6880b4ebeac04/src/utils/Structs.sol)


```solidity
struct Strategy {
    uint256 approvalPeriod;
    uint256 queuingDuration;
    uint256 expirationDelay;
    bool isFixedLengthApprovalPeriod;
    uint256 minApprovalPct;
    uint256 minDisapprovalPct;
    WeightByPermission[] approvalWeightByPermission;
    WeightByPermission[] disapprovalWeightByPermission;
}
```

