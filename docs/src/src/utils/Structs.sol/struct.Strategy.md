# Strategy

[Git Source](https://github.com/llama-community/vertex-v1/blob/28b1b0e095ba3c46d62387b2c29c8768bc213a6c/src/utils/Structs.sol)

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
