# IVertexStrategy
[Git Source](https://github.com/llama-community/vertex-v1/blob/b136bbc451b50fe1a9f96f39dbd8b8a1e42c7f72/src/strategy/IVertexStrategy.sol)


## Functions
### isActionPassed

Get whether an action has passed the approval process.


```solidity
function isActionPassed(uint256 actionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|id of the action.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Boolean value that is true if the action has passed the approval process.|


### isActionCanceletionValid

Get whether an action has eligible to be canceled.


```solidity
function isActionCanceletionValid(uint256 actionId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionId`|`uint256`|id of the action.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Boolean value that is true if the action can be canceled.|


### getApprovalWeightAt

Get the weight of an approval of a policyholder at a specific block number.


```solidity
function getApprovalWeightAt(address policyholder, uint256 blockNumber) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`policyholder`|`address`|Address of the policyholder.|
|`blockNumber`|`uint256`|The block number at which to get the approval weight.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The weight of the policyholder's approval.|


### getDisapprovalWeightAt

Get the weight of a disapproval of a policyholder at a specific block number.


```solidity
function getDisapprovalWeightAt(address policyholder, uint256 blockNumber) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`policyholder`|`address`|Address of the policyholder.|
|`blockNumber`|`uint256`|The block number at which to get the disapproval weight.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The weight of the policyholder's disapproval.|


### isApprovalQuorumValid

Determine if the total weight of policyholders in support of an approval has reached quorum.


```solidity
function isApprovalQuorumValid(uint256 approvals, uint256 blockNumber) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`approvals`|`uint256`|total weight of approvals|
|`blockNumber`|`uint256`|The block number at which to determine policyholder's approval weight.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Boolean value that is true if the approval of an action has reached quorum.|


### isDisapprovalQuorumValid

Determine if the total weight of policyholders in support of a disapproval has reached quorum.


```solidity
function isDisapprovalQuorumValid(uint256 disapprovals, uint256 blockNumber) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`disapprovals`|`uint256`|total weight of disapprovals|
|`blockNumber`|`uint256`|The block number at which to determine policyholder's disapproval weight.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Boolean value that is true if the disapproval of an action has reached quorum.|


### getMinimumAmountNeeded

Determine the minimum weight needed for an action to reach quorum.


```solidity
function getMinimumAmountNeeded(uint256 supply, uint256 minPercentage) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`supply`|`uint256`|Total number of policyholders eligible for participation.|
|`minPercentage`|`uint256`|Minimum percentage needed to reach quorum.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total weight needed to reach quorum.|


### getApprovalPermissions

Get the list of all permission signatures that are eligible for approvals.


```solidity
function getApprovalPermissions() external view returns (bytes8[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes8[]`|The list of all permission signatures that are eligible for approvals.|


### getDisapprovalPermissions

Get the list of all permission signatures that are eligible for disapprovals.


```solidity
function getDisapprovalPermissions() external view returns (bytes8[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes8[]`|The list of all permission signatures that are eligible for disapprovals.|


## Events
### NewStrategyCreated

```solidity
event NewStrategyCreated(IVertexCore vertex, VertexPolicyNFT policy);
```

