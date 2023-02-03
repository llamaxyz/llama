# IVertexCollector
[Git Source](https://github.com/llama-community/vertex-v1/blob/1a5b9d40afe2b86db921cb268a555e6bb0a0a840/src/collector/IVertexCollector.sol)


## Functions
### approve

Function for Vertex to give ERC20 allowance to other parties


```solidity
function approve(IERC20 token, address recipient, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the token to give allowance from|
|`recipient`|`address`|Allowance's recipient|
|`amount`|`uint256`|Allowance to approve|


### transfer

Function for Vertex to transfer ERC20 tokens to other parties


```solidity
function transfer(IERC20 token, address recipient, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the token to transfer|
|`recipient`|`address`|Transfer's recipient|
|`amount`|`uint256`|Amount to transfer|


