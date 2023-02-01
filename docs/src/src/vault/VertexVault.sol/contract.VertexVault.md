# VertexVault
[Git Source](https://github.com/llama-community/vertex-v1/blob/8f0c32f021139cdafca13c86e5a5d1185dab4c15/src/vault/VertexVault.sol)

**Inherits:**
[IVertexVault](/src/vault/IVertexVault.sol/contract.IVertexVault.md)

**Author:**
Llama (vertex@llama.xyz)

The contract that holds the Vertex system's assets.


## State Variables
### ETH_MOCK_ADDRESS
Mock address for ETH


```solidity
address public constant ETH_MOCK_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
```


### vertex
Vertex system


```solidity
address public immutable vertex;
```


## Functions
### constructor


```solidity
constructor(address _vertex);
```

### onlyVertex


```solidity
modifier onlyVertex();
```

### receive

Function for Vertex Vault to receive ETH


```solidity
receive() external payable;
```

### approve

Function for Vertex to give ERC20 allowance to other parties


```solidity
function approve(IERC20 token, address recipient, uint256 amount) external onlyVertex;
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
function transfer(IERC20 token, address recipient, uint256 amount) external onlyVertex;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the token to transfer|
|`recipient`|`address`|Transfer's recipient|
|`amount`|`uint256`|Amount to transfer|


## Errors
### OnlyVertex

```solidity
error OnlyVertex();
```

### Invalid0xRecipient

```solidity
error Invalid0xRecipient();
```

