# Strategy
[Git Source](https://github.com/llama-community/vertex-v1/blob/bebc34645ed954bf693ee3ddf5ddd21359ce35fc/src/utils/Structs.sol)


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

