# Strategy
[Git Source](https://github.com/llama-community/vertex-v1/blob/03d08e6c7301e4733b286ff6b820e92b844b5f79/src/utils/Structs.sol)


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

