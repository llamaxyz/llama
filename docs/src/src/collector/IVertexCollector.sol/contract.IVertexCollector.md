# IVertexCollector
[Git Source](https://github.com/llama-community/vertex-v1/blob/5b218a8dd0bc635c09c9b3b94d2fdd2e8abeb7c2/src/collector/IVertexCollector.sol)


## Functions
### transfer

Function for Vertex to transfer native tokens to other parties


```solidity
function transfer(address recipient, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|Transfer's recipient|
|`amount`|`uint256`|Amount to transfer|


### transferERC20

Function for Vertex to transfer ERC20 tokens to other parties


```solidity
function transferERC20(IERC20 token, address recipient, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the token to transfer|
|`recipient`|`address`|Transfer's recipient|
|`amount`|`uint256`|Amount to transfer|


### approveERC20

Function for Vertex to give ERC20 allowance to other parties


```solidity
function approveERC20(IERC20 token, address recipient, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the token to give allowance from|
|`recipient`|`address`|Allowance's recipient|
|`amount`|`uint256`|Allowance to approve|


