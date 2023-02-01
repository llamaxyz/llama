# Action

[Git Source](https://github.com/llama-community/vertex-v1/blob/7b69542e87e2655dea74dab5779f3939de9641f7/src/utils/Structs.sol)

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
