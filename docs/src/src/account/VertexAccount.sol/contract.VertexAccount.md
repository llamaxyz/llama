# VertexAccount
[Git Source](https://github.com/llama-community/vertex-v1/blob/b7be32ad715d2dfcef6b3e36dc7666261d5f05ce/src/account/VertexAccount.sol)

**Inherits:**
[IVertexAccount](/src/account/IVertexAccount.sol/contract.IVertexAccount.md)

**Author:**
Llama (vertex@llama.xyz)

The contract that holds the Vertex system's assets.


## State Variables
### name
Name of this Vertex Account.


```solidity
string public name;
```


### vertex
Vertex system


```solidity
address public immutable vertex;
```


## Functions
### constructor


```solidity
constructor(string memory _name, address _vertex);
```

### onlyVertex


```solidity
modifier onlyVertex();
```

### receive

Function for Vertex Account to receive ETH


```solidity
receive() external payable;
```

### transfer

Function for Vertex to transfer native tokens to other parties


```solidity
function transfer(address payable recipient, uint256 amount) external onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address payable`|Transfer's recipient|
|`amount`|`uint256`|Amount to transfer|


### transferERC20

Function for Vertex to transfer ERC20 tokens to other parties


```solidity
function transferERC20(IERC20 token, address recipient, uint256 amount) external onlyVertex;
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
function approveERC20(IERC20 token, address recipient, uint256 amount) external onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the token to give allowance from|
|`recipient`|`address`|Allowance's recipient|
|`amount`|`uint256`|Allowance to approve|


## Errors
### OnlyVertex

```solidity
error OnlyVertex();
```

### Invalid0xRecipient

```solidity
error Invalid0xRecipient();
```

