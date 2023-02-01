# Strategy
[Git Source](https://github.com/llama-community/vertex-v1/blob/693b03f6823cb240f992102042b3702c0c97cf44/src/utils/Structs.sol)


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

