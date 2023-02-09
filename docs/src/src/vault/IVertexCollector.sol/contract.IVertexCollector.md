# IVertexAccount
[Git Source](https://github.com/llama-community/vertex-v1/blob/1010800eca40d89a7523a4694106df66636f891a/src/vault/IVertexAccount.sol)


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


